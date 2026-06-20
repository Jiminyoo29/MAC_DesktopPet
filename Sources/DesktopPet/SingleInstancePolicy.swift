import Foundation

struct RunningApplicationSnapshot: Equatable {
    let bundleIdentifier: String?
    let processIdentifier: Int32
}

enum SingleInstancePolicy {
    static func duplicateProcessIdentifiers(
        currentProcessIdentifier: Int32,
        currentBundleIdentifier: String?,
        runningApplications: [RunningApplicationSnapshot]
    ) -> [Int32] {
        guard let currentBundleIdentifier, !currentBundleIdentifier.isEmpty else {
            return []
        }

        return runningApplications
            .filter { application in
                application.processIdentifier != currentProcessIdentifier &&
                application.bundleIdentifier == currentBundleIdentifier
            }
            .map(\.processIdentifier)
    }
}
