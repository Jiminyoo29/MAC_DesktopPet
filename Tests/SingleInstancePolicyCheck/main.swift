import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let apps = [
    RunningApplicationSnapshot(bundleIdentifier: "io.github.mac-desktoppet", processIdentifier: 10),
    RunningApplicationSnapshot(bundleIdentifier: "io.github.mac-desktoppet", processIdentifier: 11),
    RunningApplicationSnapshot(bundleIdentifier: "com.apple.finder", processIdentifier: 12),
    RunningApplicationSnapshot(bundleIdentifier: nil, processIdentifier: 13)
]

let duplicates = SingleInstancePolicy.duplicateProcessIdentifiers(
    currentProcessIdentifier: 10,
    currentBundleIdentifier: "io.github.mac-desktoppet",
    runningApplications: apps
)

expect(duplicates == [11], "only other apps with the same bundle identifier should be treated as duplicates")

let noBundleDuplicates = SingleInstancePolicy.duplicateProcessIdentifiers(
    currentProcessIdentifier: 10,
    currentBundleIdentifier: nil,
    runningApplications: apps
)

expect(noBundleDuplicates.isEmpty, "apps without a bundle identifier should not terminate other processes")

print("single instance policy checks passed")
