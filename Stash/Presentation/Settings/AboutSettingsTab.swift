import SwiftUI
import AppKit

struct AboutSettingsTab: View {
    @State private var showLicenses = false

    private var version: String {
        let dict = Bundle.main.infoDictionary ?? [:]
        let short = dict["CFBundleShortVersionString"] as? String ?? "?"
        let build = dict["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    private var copyright: String {
        Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? ""
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Stash")
                            .font(.title2.bold())
                        Text("Version \(version)")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        if !copyright.isEmpty {
                            Text(copyright)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            Section("About") {
                Text("Local-first macOS menu-bar clipboard manager. History, pinned slots, snippets, Touch-ID vault. No backend, no telemetry, no login.")
                    .font(.callout)
            }

            Section("Third-party packages") {
                Button("Show licenses…") { showLicenses = true }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showLicenses) {
            LicensesSheet { showLicenses = false }
        }
    }
}

private struct LicensesSheet: View {
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Open-source packages")
                .font(.title3.bold())
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    licenseRow(name: "GRDB.swift", license: "MIT", url: "https://github.com/groue/GRDB.swift")
                    licenseRow(name: "HotKey", license: "MIT", url: "https://github.com/soffes/HotKey")
                    licenseRow(name: "Sparkle", license: "MIT", url: "https://sparkle-project.org")
                }
                .padding(.vertical, 4)
            }
            HStack {
                Spacer()
                Button("Close", action: onClose)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420, height: 240)
    }

    private func licenseRow(name: String, license: String, url: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(name).font(.callout.weight(.semibold))
                Spacer()
                Text(license).font(.caption).foregroundColor(.secondary)
            }
            Text(url).font(.caption2.monospaced()).foregroundColor(.secondary)
        }
    }
}
