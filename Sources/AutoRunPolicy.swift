import Foundation

enum AutoRunRisk: String {
    case harmlessCommands
    case createNewFiles
    case renameFiles
    case moveFiles
    case modifyFiles
    case changeFilesOutsideCurrentFolder
    case minorSideEffects
    case significantSideEffects
    case moveItemsToTrash
    case deleteOrOverwriteFiles
    case runUnknownScripts
    case commandsWithErrors

    var displayName: String {
        switch self {
        case .harmlessCommands: return "Harmless commands"
        case .createNewFiles: return "Create new files"
        case .renameFiles: return "Rename files"
        case .moveFiles: return "Move files"
        case .modifyFiles: return "Modify files"
        case .changeFilesOutsideCurrentFolder: return "Change files outside current folder"
        case .minorSideEffects: return "Have minor side effects"
        case .significantSideEffects: return "Have significant side effects"
        case .moveItemsToTrash: return "Move items to Trash"
        case .deleteOrOverwriteFiles: return "Delete or overwrite files"
        case .runUnknownScripts: return "Run unknown scripts or commands"
        case .commandsWithErrors: return "Commands with errors"
        }
    }
}

struct AutoRunDecision {
    let risk: AutoRunRisk
    let allowed: Bool

    var statusText: String {
        "Auto-running \(risk.displayName.lowercased())..."
    }
}

struct AutoRunPolicy {
    private static let prefix = "autoRun."

    var harmlessCommands: Bool
    var createNewFiles: Bool
    var renameFiles: Bool
    var moveFiles: Bool
    var modifyFiles: Bool
    var changeFilesOutsideCurrentFolder: Bool
    var minorSideEffects: Bool
    var significantSideEffects: Bool
    var moveItemsToTrash: Bool
    var deleteOrOverwriteFiles: Bool
    var runUnknownScripts: Bool
    var commandsWithErrors: Bool

    static func load() -> AutoRunPolicy {
        let defaults = UserDefaults.standard
        return AutoRunPolicy(
            harmlessCommands: bool(defaults, "harmlessCommands", defaultValue: true),
            createNewFiles: bool(defaults, "createNewFiles", defaultValue: false),
            renameFiles: bool(defaults, "renameFiles", defaultValue: false),
            moveFiles: bool(defaults, "moveFiles", defaultValue: false),
            modifyFiles: bool(defaults, "modifyFiles", defaultValue: false),
            changeFilesOutsideCurrentFolder: bool(defaults, "changeFilesOutsideCurrentFolder", defaultValue: false),
            minorSideEffects: bool(defaults, "minorSideEffects", defaultValue: false),
            significantSideEffects: bool(defaults, "significantSideEffects", defaultValue: false),
            moveItemsToTrash: bool(defaults, "moveItemsToTrash", defaultValue: false),
            deleteOrOverwriteFiles: bool(defaults, "deleteOrOverwriteFiles", defaultValue: false),
            runUnknownScripts: bool(defaults, "runUnknownScripts", defaultValue: false),
            commandsWithErrors: bool(defaults, "commandsWithErrors", defaultValue: false)
        )
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(harmlessCommands, forKey: key("harmlessCommands"))
        defaults.set(createNewFiles, forKey: key("createNewFiles"))
        defaults.set(renameFiles, forKey: key("renameFiles"))
        defaults.set(moveFiles, forKey: key("moveFiles"))
        defaults.set(modifyFiles, forKey: key("modifyFiles"))
        defaults.set(changeFilesOutsideCurrentFolder, forKey: key("changeFilesOutsideCurrentFolder"))
        defaults.set(minorSideEffects, forKey: key("minorSideEffects"))
        defaults.set(significantSideEffects, forKey: key("significantSideEffects"))
        defaults.set(moveItemsToTrash, forKey: key("moveItemsToTrash"))
        defaults.set(deleteOrOverwriteFiles, forKey: key("deleteOrOverwriteFiles"))
        defaults.set(runUnknownScripts, forKey: key("runUnknownScripts"))
        defaults.set(commandsWithErrors, forKey: key("commandsWithErrors"))
    }

    func decision(for command: String) -> AutoRunDecision {
        let risk = classify(command)
        return AutoRunDecision(risk: risk, allowed: isEnabled(risk))
    }

    private func isEnabled(_ risk: AutoRunRisk) -> Bool {
        switch risk {
        case .harmlessCommands: return harmlessCommands
        case .createNewFiles: return createNewFiles
        case .renameFiles: return renameFiles
        case .moveFiles: return moveFiles
        case .modifyFiles: return modifyFiles
        case .changeFilesOutsideCurrentFolder: return changeFilesOutsideCurrentFolder
        case .minorSideEffects: return minorSideEffects
        case .significantSideEffects: return significantSideEffects
        case .moveItemsToTrash: return moveItemsToTrash
        case .deleteOrOverwriteFiles: return deleteOrOverwriteFiles
        case .runUnknownScripts: return runUnknownScripts
        case .commandsWithErrors: return commandsWithErrors
        }
    }

    private func classify(_ command: String) -> AutoRunRisk {
        let lower = command
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let effective = lower
            .components(separatedBy: "&&")
            .last?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? lower

        if containsAny(lower, ["rm ", " rm -", "rmdir ", "unlink ", "srm ", "shred ", " > ", ">|", " -y "]) {
            return .deleteOrOverwriteFiles
        }
        if lower.contains(" to trash") {
            return .moveItemsToTrash
        }
        if containsAny(lower, ["defaults write", "killall finder", "shutdown", "reboot", "halt", "pmset ", "launchctl "]) {
            return .significantSideEffects
        }
        if containsAny(lower, ["curl |", "curl -", "bash -c", "sh -c", "zsh -c", "python ", "python3 ", "ruby ", "perl "]) {
            return .runUnknownScripts
        }
        if effective.hasPrefix("osascript ") {
            return .minorSideEffects
        }
        if effective.hasPrefix("open ") || effective.hasPrefix("lp ") || effective.hasPrefix("caffeinate ") || effective.contains("pbcopy") {
            return .minorSideEffects
        }
        if effective.hasPrefix("mv ") {
            return .moveFiles
        }
        if containsAny(effective, [" -i ", " -r ", " -crop ", " -resize ", " -rotate ", " -border "]) && effective.hasPrefix("magick ") {
            return .createNewFiles
        }
        if containsAny(effective, ["touch ", "mkdir ", "cp ", "zip ", "unzip ", "ffmpeg ", "pandoc ", "pdfunite ", "pdfseparate ", "pdftotext "]) {
            return .createNewFiles
        }
        if effective.contains(" --out ") || effective.contains(" -o ") {
            return .createNewFiles
        }
        if effective.hasPrefix("sips ") && !effective.contains(" --out ") {
            return .modifyFiles
        }
        if isHarmless(effective) || isHarmless(lower) {
            return .harmlessCommands
        }
        return .runUnknownScripts
    }

    private func isHarmless(_ command: String) -> Bool {
        let harmlessPrefixes = [
            "echo ", "pwd", "ls ", "find ", "file ", "mdls ", "xattr -l",
            "sips -g", "ffprobe ", "unzip -l", "wc ", "md5 ", "du ",
            "stat ", "sysctl ", "system_profiler", "bc "
        ]
        return harmlessPrefixes.contains { command.hasPrefix($0) } || command.contains("| bc")
    }

    private func containsAny(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { value.contains($0) }
    }

    private static func bool(_ defaults: UserDefaults, _ name: String, defaultValue: Bool) -> Bool {
        let fullKey = key(name)
        guard defaults.object(forKey: fullKey) != nil else { return defaultValue }
        return defaults.bool(forKey: fullKey)
    }

    private static func key(_ name: String) -> String {
        prefix + name
    }

    private func key(_ name: String) -> String {
        Self.key(name)
    }
}
