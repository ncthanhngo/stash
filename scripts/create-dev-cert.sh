#!/bin/bash
set -euo pipefail

CERT_NAME="Clipstash Dev"
LOGIN_KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

# Already exists?
if security find-identity -p codesigning -v "$LOGIN_KEYCHAIN" 2>/dev/null | grep -q "$CERT_NAME"; then
    echo "Code-signing identity '$CERT_NAME' already exists. Nothing to do."
    exit 0
fi

WORK_DIR=$(mktemp -d -t clipstash-cert-XXXX)
trap "rm -rf $WORK_DIR" EXIT

cat > "$WORK_DIR/openssl.cnf" <<EOF
[req]
distinguished_name = req_dn
prompt = no
x509_extensions = v3_codesign

[req_dn]
CN = $CERT_NAME

[v3_codesign]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
EOF

echo "==> Generating self-signed cert (rsa:2048, 10y validity)"
openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$WORK_DIR/key.pem" -out "$WORK_DIR/cert.pem" \
    -days 3650 -config "$WORK_DIR/openssl.cnf" 2>/dev/null

P12_PASS="clipstash-dev"

echo "==> Packaging into PKCS#12 (legacy format for security CLI compatibility)"
if openssl pkcs12 -export -name "$CERT_NAME" \
    -inkey "$WORK_DIR/key.pem" -in "$WORK_DIR/cert.pem" \
    -out "$WORK_DIR/cert.p12" -password "pass:$P12_PASS" \
    -legacy 2>/dev/null; then
    echo "   (used -legacy)"
else
    openssl pkcs12 -export -name "$CERT_NAME" \
        -inkey "$WORK_DIR/key.pem" -in "$WORK_DIR/cert.pem" \
        -out "$WORK_DIR/cert.p12" -password "pass:$P12_PASS"
    echo "   (used default format)"
fi

echo "==> Importing to login keychain"
security unlock-keychain "$LOGIN_KEYCHAIN" 2>/dev/null || true
security import "$WORK_DIR/cert.p12" -k "$LOGIN_KEYCHAIN" -P "$P12_PASS" \
    -T /usr/bin/codesign -T /usr/bin/security -A

# Mark the cert as trusted for code signing in this keychain
echo "==> Adding trust setting (code signing only, user-level)"
security add-trusted-cert -p codeSign -k "$LOGIN_KEYCHAIN" "$WORK_DIR/cert.pem" 2>/dev/null || \
    echo "   (skipped — non-fatal; codesign should still work)"

# Allow codesign to access the private key without prompting
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" "$LOGIN_KEYCHAIN" 2>/dev/null || true

echo ""
echo "==> Done. Verify:"
security find-identity -p codesigning -v "$LOGIN_KEYCHAIN" | grep "$CERT_NAME" || \
    echo "   WARNING: '$CERT_NAME' not visible in codesigning identities yet"
