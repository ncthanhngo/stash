import Foundation
import Combine

@MainActor
final class ExclusionList: ObservableObject {
    @Published private(set) var userBundleIDs: Set<String> = []

    let defaultBundleIDs: Set<String> = PrivacyFilter.defaultExcludedBundleIDs

    private let defaults: UserDefaults
    private let storageKey = "stash.exclusions.user"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: storageKey) ?? []
        self.userBundleIDs = Set(stored)
    }

    var sortedUserBundleIDs: [String] {
        userBundleIDs.sorted()
    }

    var sortedDefaultBundleIDs: [String] {
        defaultBundleIDs.sorted()
    }

    func currentFilter() -> PrivacyFilter {
        PrivacyFilter(
            excludedBundleIDs: defaultBundleIDs.union(userBundleIDs),
            concealedTypes: PrivacyFilter.concealedTypes
        )
    }

    func add(_ bundleID: String) {
        let trimmed = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        userBundleIDs.insert(trimmed)
        persist()
    }

    func remove(_ bundleID: String) {
        userBundleIDs.remove(bundleID)
        persist()
    }

    private func persist() {
        defaults.set(Array(userBundleIDs).sorted(), forKey: storageKey)
    }
}
