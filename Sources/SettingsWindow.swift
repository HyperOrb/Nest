import AppKit
import SwiftUI

class SettingsWindow: NSWindow {
    convenience init() {
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        title = "Nest Settings"
        isReleasedWhenClosed = false
        center()
        
        // Ensure the window can receive keyboard events
        isMovableByWindowBackground = true
        
        contentView = NSHostingView(rootView: SettingsView())
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Force handle Cmd+V etc. if the system fails to route them.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifierFlags == .command {
            switch event.charactersIgnoringModifiers {
            case "v":
                if performTextEditAction(#selector(NSText.paste(_:))) { return true }
                if NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self) { return true }
            case "c":
                if performTextEditAction(#selector(NSText.copy(_:))) { return true }
                if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self) { return true }
            case "x":
                if performTextEditAction(#selector(NSText.cut(_:))) { return true }
                if NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self) { return true }
            case "a":
                if performTextEditAction(#selector(NSText.selectAll(_:))) { return true }
                if NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self) { return true }
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    private func performTextEditAction(_ action: Selector) -> Bool {
        if let textView = firstResponder as? NSTextView, textView.responds(to: action) {
            return textView.perform(action, with: self) != nil
        }

        if let textField = firstResponder as? NSTextField,
           let editor = textField.currentEditor(),
           editor.responds(to: action) {
            return editor.perform(action, with: self) != nil
        }

        return false
    }
}

// MARK: - Native AppKit TextField for better Paste support

struct NativeTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeNSView(context: Context) -> NSTextField {
        let tf = PasteFriendlyTextField()
        tf.placeholderString = placeholder
        tf.bezelStyle = .roundedBezel
        tf.isEditable = true
        tf.isSelectable = true
        tf.delegate = context.coordinator
        tf.font = .systemFont(ofSize: 13)
        return tf
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NativeTextField
        init(_ parent: NativeTextField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            if let tf = obj.object as? NSTextField {
                parent.text = tf.stringValue
            }
        }
    }
}

final class PasteFriendlyTextField: NSTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifierFlags == .command else {
            return super.performKeyEquivalent(with: event)
        }

        switch event.charactersIgnoringModifiers?.lowercased() {
        case "x":
            currentEditor()?.cut(self)
            return true
        case "c":
            currentEditor()?.copy(self)
            return true
        case "v":
            currentEditor()?.paste(self)
            return true
        case "a":
            selectText(nil)
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case general = "General"
        case autoRun = "Auto-run"
        case aiModels = "AI Models"
        case extraTools = "Extra Tools"
        case about = "About"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .general: return "gearshape"
            case .autoRun: return "point.topleft.down.curvedto.point.bottomright.up"
            case .aiModels: return "brain"
            case .extraTools: return "hammer"
            case .about: return "info.circle"
            }
        }
    }

    @State private var selectedTab: Tab = .general
    @State private var provider: AIProvider = .gemini
    @State private var apiKey: String = ""
    @State private var model: String = AIProvider.gemini.defaultModel
    @State private var baseURL: String = AIProvider.gemini.defaultBaseURL
    @State private var providerConfigs: [AIProvider: AIProviderConfig] = [:]
    @State private var saved = false
    @State private var isTestingProvider = false
    @State private var providerTestMessage = "Not tested yet"
    @State private var providerTestOK: Bool? = nil
    @State private var accessibilityOK = AXIsProcessTrusted()

    var configPath: String {
        NSString(string: "~/.finder_ai_config.json").expandingTildeInPath
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack(spacing: 18) {
                    ForEach(Tab.allCases) { tab in
                        SettingsTabButton(tab: tab, isSelected: selectedTab == tab) {
                            selectedTab = tab
                        }
                    }
                }
                Text(selectedTab.rawValue)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .general:
                        generalContent
                    case .autoRun:
                        AutoRunSettingsView()
                    case .aiModels:
                        aiModelsContent
                    case .extraTools:
                        ExtraToolsSettingsView()
                    case .about:
                        aboutContent
                    }
                }
                .padding(24)
            }
        }
        .onAppear {
            load()
            refreshPermissionHealth()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissionHealth()
        }
    }

    @ViewBuilder
    var generalContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.system(size: 32))
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("Nest")
                    .font(.system(size: 16, weight: .semibold))
                Text("A Finder-native AI agent for your files.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }

        Divider()

        VStack(alignment: .leading, spacing: 10) {
            Text("Health")
                .font(.system(size: 13, weight: .bold))

            HealthRow(
                title: "Accessibility",
                message: accessibilityOK ? "Nest can follow Finder windows." : "Grant access, then Recheck. If it stays red, quit and reopen Nest.",
                isOK: accessibilityOK
            )

            HStack(spacing: 8) {
                Button("Recheck") {
                    refreshPermissionHealth()
                }
                Button("Open Accessibility Settings") {
                    openAccessibilitySettings()
                }
            }
            .font(.system(size: 11))

            HealthRow(
                title: "Automation",
                message: "macOS will ask the first time Nest reads Finder selection or moves files.",
                isOK: nil
            )

            HealthRow(
                title: "AI Provider",
                message: providerTestMessage,
                isOK: providerTestOK
            )
        }

        Divider()

        VStack(alignment: .leading, spacing: 6) {
            Text("Shortcuts")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("• ⌃Space : Toggle Command Bar")
                Text("• ↑ / ↓ : Navigate History")
                Text("• Enter : Execute Action")
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }

        actionRow
    }

    @ViewBuilder
    var aiModelsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI Provider")
                .font(.system(size: 13, weight: .bold))

            Picker("", selection: providerBinding) {
                ForEach(AIProvider.allCases) { p in
                    Text(p.displayName).tag(p)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 6) {
                Text("Model")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                NativeTextField(text: $model, placeholder: provider.defaultModel)
                    .frame(height: 24)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("API Base URL")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                NativeTextField(text: $baseURL, placeholder: provider.defaultBaseURL)
                    .frame(height: 24)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(provider.requiresAPIKey ? "API Key" : "API Key (not needed for local Ollama)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    providerLink
                        .font(.system(size: 11))
                }
                NativeTextField(text: $apiKey, placeholder: provider.requiresAPIKey ? "Paste provider API key here" : "Ollama runs locally without an API key")
                    .frame(height: 24)
                    .disabled(!provider.requiresAPIKey)
            }

            Text("Provider settings and API keys are stored locally in ~/.finder_ai_config.json.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            HStack {
                Button(isTestingProvider ? "Testing..." : "Test AI Provider") {
                    testProvider()
                }
                .disabled(isTestingProvider || !canSave)

                Spacer()

                if saved {
                    Text("✓ Saved")
                        .foregroundColor(.green)
                        .font(.system(size: 12, weight: .medium))
                        .transition(.opacity)
                }

                Button("Save Configuration") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
        }

        Divider()

        VStack(alignment: .leading, spacing: 6) {
            Text("Provider Notes")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(providerNote)
                Text("Vision answers require a vision-capable model.")
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    var aboutContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 36))
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text("Nest")
                    .font(.system(size: 18, weight: .semibold))
                Text("Version 1.0 preview")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }

        Text("Nest is a Finder-native AI agent that understands selected files, answers questions, and turns natural-language requests into useful local actions.")
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)

        Button("Welcome to Nest…") {
            NotificationCenter.default.post(name: .openOnboarding, object: nil)
        }

        actionRow
    }

    @ViewBuilder
    var actionRow: some View {
        HStack {
            Button("Quit App") { NSApp.terminate(nil) }
                .buttonStyle(.link)
                .foregroundColor(.red)

            Spacer()
        }
    }

    struct SettingsTabButton: View {
        let tab: Tab
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                VStack(spacing: 3) {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 22, weight: .regular))
                    Text(tab.rawValue)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                }
                .foregroundColor(isSelected ? .blue : .secondary)
                .frame(width: 72, height: 54)
                .background(isSelected ? Color.blue.opacity(0.12) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    var providerLink: some View {
        switch provider {
        case .gemini:
            Link("Get key", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
        case .openRouter:
            Link("Get key", destination: URL(string: "https://openrouter.ai/keys")!)
        case .openAICompatible:
            Link("Get key", destination: URL(string: "https://platform.openai.com/api-keys")!)
        case .ollama:
            Link("Install", destination: URL(string: "https://ollama.com")!)
        }
    }

    var providerNote: String {
        switch provider {
        case .gemini:
            return "Uses Google's Gemini API and supports image questions."
        case .openRouter:
            return "Use models like meta-llama/llama-3.2-3b-instruct:free, or any OpenRouter model."
        case .openAICompatible:
            return "Works with OpenAI or any compatible /chat/completions server. OpenAI API billing is separate from ChatGPT."
        case .ollama:
            return "Runs locally at localhost:11434. Try model llava for image questions."
        }
    }

    var canSave: Bool {
        !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (!provider.requiresAPIKey || !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var providerBinding: Binding<AIProvider> {
        Binding(
            get: { provider },
            set: { newProvider in
                persistFields(for: provider)
                provider = newProvider
                loadFields(for: newProvider)
            }
        )
    }

    func load() {
        providerConfigs = AIProviderConfig.loadAll()
        let active = AIProviderConfig.load().provider
        provider = active
        loadFields(for: active)
        refreshPermissionHealth()
    }

    func save() {
        persistFields(for: provider)
        AIProviderConfig.saveAll(activeProvider: provider, configs: providerConfigs)
        withAnimation { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { saved = false }
        }
    }

    private func testProvider() {
        persistFields(for: provider)
        let config = providerConfigs[provider] ?? AIProviderConfig(provider: provider, apiKey: apiKey, model: model, baseURL: baseURL)

        isTestingProvider = true
        providerTestOK = nil
        providerTestMessage = "Testing \(provider.displayName)..."

        Task {
            do {
                _ = try await AIAgent.shared.test(config: config)
                await MainActor.run {
                    providerTestOK = true
                    providerTestMessage = "\(provider.displayName) is working."
                    isTestingProvider = false
                }
            } catch {
                await MainActor.run {
                    providerTestOK = false
                    providerTestMessage = error.localizedDescription
                    isTestingProvider = false
                }
            }
        }
    }

    private func persistFields(for provider: AIProvider) {
        providerConfigs[provider] = AIProviderConfig(
            provider: provider,
            apiKey: AIProviderConfig.cleanAPIKey(apiKey, provider: provider),
            model: model,
            baseURL: baseURL
        )
    }

    private func loadFields(for provider: AIProvider) {
        let config = providerConfigs[provider] ?? AIProviderConfig(
            provider: provider,
            apiKey: "",
            model: provider.defaultModel,
            baseURL: provider.defaultBaseURL
        )
        apiKey = config.apiKey
        model = config.model
        baseURL = config.baseURL
        providerTestOK = nil
        providerTestMessage = "Not tested yet"
        accessibilityOK = AXIsProcessTrusted()
    }

    private func refreshPermissionHealth() {
        accessibilityOK = AXIsProcessTrusted()
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

struct AutoRunSettingsView: View {
    @State private var policy = AutoRunPolicy.load()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Nest can run commands with or without confirmation")
                    .font(.system(size: 13, weight: .bold))

                Text("What kinds of commands should run without asking?")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            HStack(alignment: .top, spacing: 38) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(AutoRunRisk.harmlessCommands.displayName, isOn: binding(\.harmlessCommands))
                    Toggle(AutoRunRisk.createNewFiles.displayName, isOn: binding(\.createNewFiles))
                    Toggle(AutoRunRisk.renameFiles.displayName, isOn: binding(\.renameFiles))
                    Toggle(AutoRunRisk.moveFiles.displayName, isOn: binding(\.moveFiles))
                    Toggle(AutoRunRisk.modifyFiles.displayName, isOn: binding(\.modifyFiles))
                    Toggle(AutoRunRisk.changeFilesOutsideCurrentFolder.displayName, isOn: binding(\.changeFilesOutsideCurrentFolder))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Toggle(AutoRunRisk.minorSideEffects.displayName, isOn: binding(\.minorSideEffects))
                    Toggle(AutoRunRisk.significantSideEffects.displayName, isOn: binding(\.significantSideEffects))
                    Toggle(AutoRunRisk.moveItemsToTrash.displayName, isOn: binding(\.moveItemsToTrash))
                    Toggle(AutoRunRisk.deleteOrOverwriteFiles.displayName, isOn: binding(\.deleteOrOverwriteFiles))
                    Toggle("Run unknown scripts\nor commands", isOn: binding(\.runUnknownScripts))
                    Toggle(AutoRunRisk.commandsWithErrors.displayName, isOn: binding(\.commandsWithErrors))
                }
            }
            .toggleStyle(.checkbox)
            .font(.system(size: 12))

            HStack(alignment: .top, spacing: 36) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Minor side effects include:")
                        .font(.system(size: 11, weight: .medium))
                    Text("• Opening an app or file\n• Network access\n• Reading from clipboard\n• Long running commands")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Significant side effects include:")
                        .font(.system(size: 11, weight: .medium))
                    Text("• Modifying system settings\n• Force-quitting an app\n• Shutting down your Mac\n• Indefinite running commands")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text("Commands that are not allowed here still show the preview card before running.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    private func binding(_ keyPath: WritableKeyPath<AutoRunPolicy, Bool>) -> Binding<Bool> {
        Binding(
            get: { policy[keyPath: keyPath] },
            set: { newValue in
                policy[keyPath: keyPath] = newValue
                policy.save()
            }
        )
    }
}

struct ExtraToolsSettingsView: View {
    @State private var imageMagickInstalled = ToolManager.isInstalled("magick")
    @State private var imageMagickMessage = ToolManager.isInstalled("magick") ? ToolManager.version(for: "magick") : "Not installed"
    @State private var isInstallingImageMagick = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Extra tools")
                    .font(.system(size: 13, weight: .bold))

                Text("Nest can use optional command-line tools for more powerful file actions. Install only the ones you need.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(imageMagickInstalled ? Color.green : Color.orange)
                        .frame(width: 9, height: 9)
                        .padding(.top, 5)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("ImageMagick")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Used for grids/contact sheets, text overlays, trims, borders, crops, compositing, and advanced image edits.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(imageMagickMessage.isEmpty ? "Not installed" : imageMagickMessage)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(imageMagickInstalled ? .secondary : .orange)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 8) {
                    Button("Check") {
                        refreshImageMagick()
                    }

                    Button(isInstallingImageMagick ? "Installing..." : "Install with Homebrew") {
                        installImageMagick()
                    }
                    .disabled(isInstallingImageMagick || imageMagickInstalled)
                }
                .font(.system(size: 11))
            }

            Divider()

            VStack(alignment: .leading, spacing: 5) {
                Text("Try commands like:")
                    .font(.system(size: 12, weight: .semibold))
                Text("• Make a 3x3 grid of these images\n• Put text \"Nest\" on this image\n• Trim transparent edges\n• Add a 10px border")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            refreshImageMagick()
        }
    }

    private func refreshImageMagick() {
        imageMagickInstalled = ToolManager.isInstalled("magick")
        imageMagickMessage = imageMagickInstalled ? ToolManager.version(for: "magick") : "Not installed"
    }

    private func installImageMagick() {
        isInstallingImageMagick = true
        imageMagickMessage = "Running brew install imagemagick..."

        DispatchQueue.global(qos: .userInitiated).async {
            let result = ToolManager.installImageMagick()
            DispatchQueue.main.async {
                isInstallingImageMagick = false
                imageMagickInstalled = ToolManager.isInstalled("magick")
                if imageMagickInstalled {
                    imageMagickMessage = ToolManager.version(for: "magick")
                } else {
                    imageMagickMessage = result.message.isEmpty ? "ImageMagick install did not finish." : result.message
                }
            }
        }
    }
}

struct HealthRow: View {
    let title: String
    let message: String
    let isOK: Bool?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(message)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var color: Color {
        switch isOK {
        case true: return .green
        case false: return .red
        case nil: return .yellow
        }
    }
}
