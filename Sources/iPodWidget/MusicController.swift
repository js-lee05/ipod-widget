import AppKit

enum MusicError: Error {
    case permissionDenied
    case script(code: Int, message: String)
}

/// Runs AppleScript against Music.app on a single serial queue (NSAppleScript is not thread-safe).
final class MusicController: @unchecked Sendable {
    private static let bundleID = "com.apple.Music"
    private static let errAEEventNotPermitted = -1743
    private let queue = DispatchQueue(label: "local.ipodwidget.applescript")

    /// Checked before polling, because any `tell application "Music"` would launch it.
    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).isEmpty
    }

    func text(_ source: String) async throws -> String {
        try await run(source).stringValue ?? ""
    }

    func data(_ source: String) async throws -> Data {
        try await run(source).data
    }

    func perform(_ source: String) async throws {
        _ = try await run(source)
    }

    private func run(_ source: String) async throws -> NSAppleEventDescriptor {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                var errorInfo: NSDictionary?
                let result = NSAppleScript(source: source)?.executeAndReturnError(&errorInfo)
                if let result, errorInfo == nil {
                    continuation.resume(returning: result)
                    return
                }
                let code = errorInfo?[NSAppleScript.errorNumber] as? Int ?? 0
                let message = errorInfo?[NSAppleScript.errorMessage] as? String ?? "unknown"
                continuation.resume(throwing: code == Self.errAEEventNotPermitted
                    ? MusicError.permissionDenied
                    : MusicError.script(code: code, message: message))
            }
        }
    }
}
