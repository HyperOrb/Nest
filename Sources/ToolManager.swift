import Foundation

enum ToolManager {
    struct Result {
        let ok: Bool
        let message: String
    }

    static func isInstalled(_ tool: String) -> Bool {
        run("command -v \(shellQuote(tool)) >/dev/null").ok
    }

    static func version(for tool: String) -> String {
        let result = run("\(shellQuote(tool)) -version 2>/dev/null | head -n 1")
        return result.message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func installImageMagick() -> Result {
        run("""
        command -v brew >/dev/null || { echo 'Homebrew is required. Install it from https://brew.sh, then try again.'; exit 127; }
        brew install imagemagick
        """)
    }

    @discardableResult
    private static func run(_ command: String) -> Result {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-l", "-c", command]

        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return Result(ok: false, message: error.localizedDescription)
        }

        let output = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let message = (output + error).trimmingCharacters(in: .whitespacesAndNewlines)
        return Result(ok: task.terminationStatus == 0, message: message)
    }

    private static func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
