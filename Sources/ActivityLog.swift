import Foundation

enum ActivityKind: String, Codable {
    case command
    case answer
}

enum ActivityStatus: String, Codable {
    case generated
    case previewed
    case running
    case succeeded
    case failed
}

struct ActivityEntry: Identifiable, Codable, Equatable {
    let id: String
    var date: Date
    var kind: ActivityKind
    var status: ActivityStatus
    var prompt: String
    var command: String
    var output: String
    var mode: String
}

final class ActivityLog: ObservableObject {
    static let shared = ActivityLog()

    @Published private(set) var entries: [ActivityEntry] = []

    private let storageKey = "activityLog.entries"
    private let maxEntries = 80

    private init() {
        load()
    }

    @discardableResult
    func recordCommand(prompt: String, command: String, status: ActivityStatus, mode: String) -> String {
        let id = UUID().uuidString
        let entry = ActivityEntry(
            id: id,
            date: Date(),
            kind: .command,
            status: status,
            prompt: prompt,
            command: command,
            output: "",
            mode: mode
        )
        entries.insert(entry, at: 0)
        trimAndSave()
        return id
    }

    func markRunning(command: String) {
        updateLatestCommand(command: command) { entry in
            entry.status = .running
            entry.date = Date()
        }
    }

    func complete(command: String, status: ActivityStatus, output: String) {
        updateLatestCommand(command: command) { entry in
            entry.status = status
            entry.output = output.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.date = Date()
        }
    }

    func recordAnswer(prompt: String, answer: String, succeeded: Bool) {
        let entry = ActivityEntry(
            id: UUID().uuidString,
            date: Date(),
            kind: .answer,
            status: succeeded ? .succeeded : .failed,
            prompt: prompt,
            command: "",
            output: answer.trimmingCharacters(in: .whitespacesAndNewlines),
            mode: "AI answer"
        )
        entries.insert(entry, at: 0)
        trimAndSave()
    }

    func clear() {
        entries = []
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private func updateLatestCommand(command: String, update: (inout ActivityEntry) -> Void) {
        if let index = entries.firstIndex(where: { $0.kind == .command && $0.command == command }) {
            update(&entries[index])
        } else {
            var fallback = ActivityEntry(
                id: UUID().uuidString,
                date: Date(),
                kind: .command,
                status: .generated,
                prompt: "",
                command: command,
                output: "",
                mode: "Unknown"
            )
            update(&fallback)
            entries.insert(fallback, at: 0)
        }
        trimAndSave()
    }

    private func trimAndSave() {
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ActivityEntry].self, from: data) else {
            entries = []
            return
        }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
