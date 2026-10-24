import Foundation
import HelperInterface

enum HelperInstallerError: LocalizedError {
    case missingResource(String)
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .missingResource(let name): String(localized: "The app bundle is missing \(name).")
        case .cancelled: String(localized: "Helper installation was cancelled.")
        case .failed(let output): String(localized: "Helper installation failed: \(output)")
        }
    }
}

/// Installs the helper as a LaunchDaemon by running the bundled script as root.
enum HelperInstaller {
    static func install() async throws {
        let bundle = Bundle.main
        let tool = bundle.bundleURL.appending(path: "Contents/Library/LaunchServices/\(HelperIdentity.label)")
        guard FileManager.default.fileExists(atPath: tool.path) else {
            throw HelperInstallerError.missingResource(HelperIdentity.label)
        }
        guard let plist = bundle.url(forResource: HelperIdentity.label, withExtension: "plist") else {
            throw HelperInstallerError.missingResource("\(HelperIdentity.label).plist")
        }
        try await runPrivileged("install", tool.path, plist.path)
    }

    static func uninstall() async throws {
        try await runPrivileged("uninstall")
    }

    private static func runPrivileged(_ arguments: String...) async throws {
        guard let script = Bundle.main.url(forResource: "helper-tool", withExtension: "sh") else {
            throw HelperInstallerError.missingResource("helper-tool.sh")
        }
        let command = (["/bin/sh", script.path] + arguments).map(\.shellQuoted).joined(separator: " ")
        let prompt = String(localized: "Blow My Fans needs to install a helper to change fan speeds.")

        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/osascript")
        process.arguments = [
            "-e",
            "do shell script \(command.appleScriptQuoted) with prompt \(prompt.appleScriptQuoted) with administrator privileges",
        ]
        let errorPipe = Pipe()
        process.standardError = errorPipe

        try await process.runUntilExit()
        guard process.terminationStatus == 0 else {
            let output = String(decoding: errorPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw output.contains("-128") ? HelperInstallerError.cancelled : HelperInstallerError.failed(output)
        }
    }
}

private extension Process {
    func runUntilExit() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            terminationHandler = { _ in continuation.resume() }
            do {
                try run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

private extension String {
    var shellQuoted: String {
        "'" + replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }

    var appleScriptQuoted: String {
        "\"" + replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
