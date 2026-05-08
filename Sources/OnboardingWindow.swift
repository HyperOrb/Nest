import AppKit
import SwiftUI

class OnboardingWindow: NSWindow {
    var onOpenSettings: (() -> Void)?

    convenience init(onOpenSettings: @escaping () -> Void) {
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        title = "Welcome to Nest"
        isReleasedWhenClosed = false
        center()
        self.onOpenSettings = onOpenSettings
        contentView = NSHostingView(rootView: OnboardingView(
            onOpenSettings: { [weak self] in
                self?.close()
                self?.onOpenSettings?()
            },
            onFinish: { [weak self] in
                UserDefaults.standard.set(true, forKey: "didCompleteOnboarding")
                self?.close()
            }
        ))
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

struct OnboardingView: View {
    let onOpenSettings: () -> Void
    let onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome to Nest")
                        .font(.system(size: 26, weight: .semibold))
                    Text("A Finder-native AI agent that helps you understand, organize, and act on your files.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                SetupRow(
                    icon: "finder",
                    title: "Lives with Finder",
                    description: "Nest docks below your active Finder window, reads your selected files, and follows along while you work."
                )
                SetupRow(
                    icon: "lock.shield",
                    title: "Needs macOS permission",
                    description: "Accessibility lets Nest follow Finder. Automation lets Nest read selected files and move items to Trash when you ask."
                )
                SetupRow(
                    icon: "key",
                    title: "Bring your own AI",
                    description: "Choose Gemini, OpenRouter, OpenAI-compatible APIs, or local Ollama. Your keys stay in a local config file."
                )
                SetupRow(
                    icon: "text.cursor",
                    title: "Use natural language",
                    description: "Select a file and ask things like \"what is this?\", \"compress this\", \"delete this\", or \"make a zip\"."
                )
            }

            Spacer()

            HStack {
                Button("Set Up AI Provider") {
                    UserDefaults.standard.set(true, forKey: "didCompleteOnboarding")
                    onOpenSettings()
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Button("Start Using Nest") {
                    onFinish()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 560, height: 520)
    }
}

struct SetupRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
