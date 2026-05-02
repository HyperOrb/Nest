import Foundation

struct CommandExecutor {
    static func execute(command: String) {
        ActivityLog.shared.markRunning(command: command)

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-l", "-c", command]

        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe

        do {
            try task.run()
        } catch {
            DispatchQueue.main.async {
                CommandBarState.shared.finishProgress("I could not start that command", succeeded: false)
                ActivityLog.shared.complete(command: command, status: .failed, output: error.localizedDescription)
            }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            task.waitUntilExit()
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outData + errData, encoding: .utf8) ?? ""
            let status = task.terminationStatus

            DispatchQueue.main.async {
                if status == 0 {
                    let summary = CommandNarrator.success(for: command, output: output)
                    let display = inlineResult(summary: summary, output: output, succeeded: true)
                    CommandBarState.shared.finishProgress(display, succeeded: true, clearAfter: display == summary ? 3.5 : 6)
                    ActivityLog.shared.complete(command: command, status: .succeeded, output: output)
                } else {
                    let summary = CommandNarrator.failure(for: command, output: output)
                    let display = inlineResult(summary: summary, output: output, succeeded: false)
                    CommandBarState.shared.finishProgress(display, succeeded: false, clearAfter: 6)
                    ActivityLog.shared.complete(command: command, status: .failed, output: output)
                }
            }
        }
    }

    private static func inlineResult(summary: String, output: String, succeeded: Bool) -> String {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return summary }
        if succeeded {
            return trimmed.replacingOccurrences(of: "\n", with: "  ")
        }
        return "\(summary): \(trimmed.replacingOccurrences(of: "\n", with: "  "))"
    }
}
