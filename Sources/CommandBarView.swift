import SwiftUI
import AppKit

// MARK: - Shared State

class CommandBarState: ObservableObject {
    static let shared = CommandBarState()

    @Published var commandText = ""
    @Published var isProcessing = false
    @Published var selectedFiles: [String] = []
    @Published var currentFolder: String?
    @Published var statusText = ""
    @Published var historyIndex = -1
    @Published var progressVisible = false
    @Published var progressValue: CGFloat = 0
    @Published var progressSucceeded: Bool? = nil
    @Published var focusRequest = 0

    private(set) var history: [String] = []
    private var selectionTimer: Timer?
    private var progressTimer: Timer?

    init() {
        // Poll Finder selection every 0.5s so the indicator updates in real-time
        selectionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            DispatchQueue.global(qos: .utility).async {
                let context = FinderTracker.context()
                DispatchQueue.main.async {
                    if context.selectedFiles != self?.selectedFiles {
                        self?.selectedFiles = context.selectedFiles
                    }
                    if context.currentFolder != self?.currentFolder {
                        self?.currentFolder = context.currentFolder
                    }
                }
            }
        }
    }

    var fileLabel: String {
        let n = selectedFiles.count
        if n > 0 { return "\(n) item\(n == 1 ? "" : "s")" }
        return currentFolder == nil ? "No Finder" : "Folder"
    }

    var dotColor: Color {
        currentFolder == nil ? Color.orange : (selectedFiles.isEmpty ? Color.gray.opacity(0.5) : Color.blue)
    }

    func submit(currentText: String? = nil) {
        let rawText = currentText ?? commandText
        let text = rawText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isProcessing else { return }

        history.insert(text, at: 0)
        historyIndex = -1
        commandText = ""

        // Refresh once at submit time so commands do not run on stale Finder context.
        let context = FinderTracker.context()
        let files = context.selectedFiles.isEmpty ? selectedFiles : context.selectedFiles
        let folder = context.currentFolder ?? currentFolder
        selectedFiles = files
        currentFolder = folder
        isProcessing = true
        beginProgress("Working...")

        if folder == nil && files.isEmpty {
            isProcessing = false
            finishProgress("Can't see Finder. Check Automation permission.", succeeded: false)
            return
        }

        if AIAgent.shouldAnswerDirectly(text) {
            fireAnswerLoading()
            Task {
                do {
                    let answer = try await AIAgent.shared.answer(prompt: text, files: files, currentFolder: folder)
                    await MainActor.run {
                        self.isProcessing = false
                        ActivityLog.shared.recordAnswer(prompt: text, answer: answer, succeeded: true)
                        self.fireAnswer(answer)
                    }
                } catch {
                    await MainActor.run {
                        self.isProcessing = false
                        let message = "I couldn't get an answer: \(error.localizedDescription)"
                        ActivityLog.shared.recordAnswer(prompt: text, answer: message, succeeded: false)
                        self.fireAnswer(message, succeeded: false)
                    }
                }
            }
            return
        }

        if files.isEmpty && InstantActions.quickShortcutNeedsFiles(keyword: text) {
            isProcessing = false
            finishProgress("No Finder selection detected", succeeded: false)
            return
        }

        // Only exact short shortcuts run without AI; natural-language requests go through the agent.
        if let cmd = InstantActions.resolveQuickShortcut(keyword: text, files: files, currentFolder: folder) {
            isProcessing = false
            handleCommand(cmd, prompt: text, source: "Shortcut")
            return
        }

        // Otherwise ask Gemini to generate a shell command
        Task {
            do {
                let cmd = try await AIAgent.shared.translate(prompt: text, files: files, currentFolder: folder)
                await MainActor.run {
                    self.isProcessing = false
                    self.handleCommand(cmd, prompt: text, source: "AI command")
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.statusText = "⚠️ \(error.localizedDescription)"
                    self.finishProgress("Could not generate command", succeeded: false)
                    ActivityLog.shared.recordAnswer(prompt: text, answer: error.localizedDescription, succeeded: false)
                }
            }
        }
    }

    private func handleCommand(_ command: String, prompt: String, source: String) {
        let decision = AutoRunPolicy.load().decision(for: command)
        guard decision.allowed else {
            ActivityLog.shared.recordCommand(prompt: prompt, command: command, status: .previewed, mode: "\(source) preview")
            firePreview(command: command)
            return
        }

        ActivityLog.shared.recordCommand(prompt: prompt, command: command, status: .running, mode: "\(source) auto-run")
        beginProgress(decision.statusText)
        CommandExecutor.execute(command: command)
    }

    func beginProgress(_ message: String) {
        progressTimer?.invalidate()
        progressSucceeded = nil
        progressVisible = true
        progressValue = 0.08
        statusText = message

        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            let remaining = max(0, 0.9 - self.progressValue)
            self.progressValue = min(0.9, self.progressValue + max(0.006, remaining * 0.055))
        }
    }

    func finishProgress(_ message: String, succeeded: Bool, clearAfter: TimeInterval? = 3.5) {
        progressTimer?.invalidate()
        progressTimer = nil
        progressSucceeded = succeeded
        progressVisible = true
        withAnimation(.easeOut(duration: 0.24)) {
            progressValue = 1
        }
        statusText = message

        guard let clearAfter else { return }
        let captured = message
        DispatchQueue.main.asyncAfter(deadline: .now() + clearAfter) { [weak self] in
            guard let self, self.statusText == captured else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                self.clearProgress(focusInput: false)
            }
        }
    }

    func clearProgress(focusInput: Bool = true) {
        progressTimer?.invalidate()
        progressTimer = nil
        progressVisible = false
        progressValue = 0
        progressSucceeded = nil
        statusText = ""
        if focusInput {
            focusRequest += 1
        }
    }

    func historyUp() {
        if history.isEmpty { return }
        historyIndex = min(historyIndex + 1, history.count - 1)
        commandText = history[historyIndex]
    }

    func historyDown() {
        historyIndex = max(historyIndex - 1, -1)
        commandText = historyIndex >= 0 ? history[historyIndex] : ""
    }

    private func firePreview(command: String) {
        statusText = "Review command, press Enter to run"
        NotificationCenter.default.post(name: .showCommandPreview, object: command)
    }

    private func fireAnswerLoading() {
        beginProgress("Thinking...")
    }

    private func fireAnswer(_ answer: String, succeeded: Bool = true) {
        finishProgress(answer, succeeded: succeeded, clearAfter: 6)
    }

    func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }

    func openActivity() {
        NotificationCenter.default.post(name: .openActivity, object: nil)
    }
}

// MARK: - The SwiftUI View

struct CommandBarView: View {
    @StateObject private var state = CommandBarState.shared

    var body: some View {
        ZStack {
            RoundedPanelBackground()

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: PANEL_CORNER_RADIUS, style: .continuous)
                    .fill(progressColor.opacity(state.progressSucceeded == nil ? 0.24 : 0.42))
                    .frame(width: geo.size.width * max(0, min(1, state.progressValue)))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(state.progressVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.18), value: state.progressValue)
                    .animation(.easeOut(duration: 0.18), value: state.progressVisible)
            }
            .allowsHitTesting(false)

            // Top border line
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)
                Spacer()
            }

            // Content row
            HStack(spacing: 0) {
                // File indicator pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(state.dotColor)
                        .frame(width: 7, height: 7)
                        .animation(.easeInOut(duration: 0.2), value: state.selectedFiles.count)

                    Text(state.fileLabel)
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(width: 100, alignment: .leading)
                .padding(.leading, 14)

                // Separator
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1, height: 22)
                    .padding(.horizontal, 12)

                // Command input / live status
                Group {
                    if state.progressVisible || (!state.statusText.isEmpty && state.commandText.isEmpty) {
                        HStack(spacing: 8) {
                            if state.progressSucceeded == nil {
                                ProgressView()
                                    .scaleEffect(0.55)
                                    .frame(width: 14, height: 14)
                            } else {
                                Image(systemName: state.progressSucceeded == true ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(state.progressSucceeded == true ? .green : .orange)
                            }

                            Text(state.statusText)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            state.clearProgress(focusInput: true)
                        }
                    } else {
                        CommandTextField(
                            text: $state.commandText,
                            placeholder: "Type a command… (zip, jpg, compress, or describe anything)",
                            focusRequest: state.focusRequest,
                            onSubmit: { state.submit(currentText: $0) },
                            onUp: { state.historyUp() },
                            onDown: { state.historyDown() }
                        )
                        .frame(maxWidth: .infinity)
                    }
                }

                // Spinner or status text
                Group {
                    if state.isProcessing && !state.progressVisible {
                        ProgressView()
                            .scaleEffect(0.65)
                            .frame(width: 20, height: 20)
                    } else if !state.statusText.isEmpty && !state.progressVisible {
                        Text(state.statusText)
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(width: 160, alignment: .trailing)
                    }
                }
                .padding(.trailing, 6)

                // Activity and settings buttons
                IconButton(symbol: "clock.arrow.circlepath") { state.openActivity() }

                IconButton(symbol: "gearshape") { state.openSettings() }
                    .padding(.trailing, 14)
            }
        }
        .frame(height: BAR_HEIGHT)
        .clipShape(RoundedRectangle(cornerRadius: PANEL_CORNER_RADIUS, style: .continuous))
    }

    private var progressColor: Color {
        switch state.progressSucceeded {
        case true: return .green
        case false: return .orange
        case nil: return .blue
        }
    }
}

// MARK: - Helpers

struct IconButton: View {
    let symbol: String
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(hovered ? .primary : .secondary)
                .frame(width: 28, height: 28)
                .background(hovered ? Color.white.opacity(0.1) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovered = $0 }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
}

struct RoundedPanelBackground: View {
    var body: some View {
        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
            .clipShape(RoundedRectangle(cornerRadius: PANEL_CORNER_RADIUS, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PANEL_CORNER_RADIUS, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
    }
}

// MARK: - Custom TextField with arrow-key history navigation

struct CommandTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let focusRequest: Int
    var onSubmit: (String) -> Void
    var onUp: () -> Void
    var onDown: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let tf = InterceptTextField()
        tf.placeholderString = placeholder
        tf.isBordered = false
        tf.drawsBackground = false
        tf.font = .systemFont(ofSize: 14)
        tf.textColor = .labelColor
        tf.focusRingType = .none
        tf.delegate = context.coordinator
        tf.onReturn = onSubmit
        tf.onUp = onUp
        tf.onDown = onDown
        return tf
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        if context.coordinator.lastFocusRequest != focusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CommandTextField
        var lastFocusRequest: Int
        init(_ p: CommandTextField) {
            self.parent = p
            self.lastFocusRequest = p.focusRequest
        }

        func controlTextDidChange(_ obj: Notification) {
            if let tf = obj.object as? NSTextField {
                parent.text = tf.stringValue
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)):
                parent.text = textView.string
                parent.onSubmit(textView.string)
                return true
            case #selector(NSResponder.moveUp(_:)):
                parent.onUp()
                return true
            case #selector(NSResponder.moveDown(_:)):
                parent.onDown()
                return true
            default:
                return false
            }
        }
    }
}

class InterceptTextField: NSTextField {
    var onReturn: ((String) -> Void)?
    var onUp: (() -> Void)?
    var onDown: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76: onReturn?(stringValue) // Return / Enter
        case 126: onUp?()        // Arrow up
        case 125: onDown?()      // Arrow down
        default: super.keyDown(with: event)
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let showCommandPreview = Notification.Name("showCommandPreview")
    static let showAnswerLoading = Notification.Name("showAnswerLoading")
    static let showAnswer = Notification.Name("showAnswer")
    static let showCommandResult = Notification.Name("showCommandResult")
    static let openSettings = Notification.Name("openSettings")
    static let openActivity = Notification.Name("openActivity")
    static let openOnboarding = Notification.Name("openOnboarding")
}
