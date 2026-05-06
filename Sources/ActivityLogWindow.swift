import AppKit
import SwiftUI

class ActivityLogWindow: NSWindow {
    convenience init() {
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        title = "Nest Activity"
        isReleasedWhenClosed = false
        center()
        contentView = NSHostingView(rootView: ActivityLogView())
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

struct ActivityLogView: View {
    @ObservedObject private var log = ActivityLog.shared

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Activity")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Recent prompts, generated commands, outputs, and failures stay local on this Mac.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Clear") {
                        log.clear()
                    }
                    .disabled(log.entries.isEmpty)
                }

                if log.entries.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                        Text("No activity yet")
                            .font(.system(size: 12, weight: .medium))
                        Text("Ask Nest to inspect, convert, rename, answer, or run something and it will appear here.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 340)
                    }
                    .frame(maxWidth: .infinity, minHeight: 320)
                } else {
                    VStack(spacing: 10) {
                        ForEach(log.entries) { entry in
                            ActivityEntryRow(entry: entry, time: Self.dateFormatter.string(from: entry.date))
                        }
                    }
                }
            }
            .padding(22)
        }
        .frame(minWidth: 560, minHeight: 420)
    }
}

struct ActivityEntryRow: View {
    let entry: ActivityEntry
    let time: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)

                Text(entry.mode)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                Spacer()

                Text(time)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            if !entry.prompt.isEmpty {
                Text(entry.prompt)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }

            if !entry.command.isEmpty {
                Text(entry.command)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            if !entry.output.isEmpty {
                Text(entry.output)
                    .font(.system(size: 11))
                    .foregroundColor(entry.status == .failed ? .orange : .secondary)
                    .lineLimit(4)
                    .textSelection(.enabled)
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var title: String {
        switch entry.status {
        case .generated: return entry.kind == .answer ? "Answer generated" : "Command generated"
        case .previewed: return "Waiting for confirmation"
        case .running: return "Running"
        case .succeeded: return entry.kind == .answer ? "Answered" : "Succeeded"
        case .failed: return "Failed"
        }
    }

    private var icon: String {
        switch entry.status {
        case .generated, .previewed: return "terminal"
        case .running: return "play.circle"
        case .succeeded: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch entry.status {
        case .generated, .previewed: return .blue
        case .running: return .orange
        case .succeeded: return .green
        case .failed: return .orange
        }
    }
}
