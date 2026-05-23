import Foundation
import CryptoKit

enum HashTransforms {
    static func apply(_ transform: TextTransform, to input: String) -> Result<String, TransformError> {
        let bytes = Data(input.utf8)
        switch transform {
        case .md5:
            return .success(hex(Insecure.MD5.hash(data: bytes)))
        case .sha1:
            return .success(hex(Insecure.SHA1.hash(data: bytes)))
        case .sha256:
            return .success(hex(SHA256.hash(data: bytes)))
        case .sha512:
            return .success(hex(SHA512.hash(data: bytes)))
        default:
            return .failure(.unsupportedOperation)
        }
    }

    private static func hex<D: Sequence>(_ digest: D) -> String where D.Element == UInt8 {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}
