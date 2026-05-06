import AppKit
import SwiftUI

class PreviewCardWindow: NSPanel {
    private var onRun: (() -> Void)?
    private var onCancel: (() -> Void)?

    convenience init() {
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 110),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        isMovable = false
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        contentView?.wantsLayer = true
        contentView?.layer?.cornerRadius = PANEL_CORNER_RADIUS
        contentView?.layer?.masksToBounds = true
    }

    func show(command: String, below barWindow: NSPanel) {
        let h: CGFloat = 132
        let cardFrame = frame(below: barWindow, height: h)

        onRun = { [weak self] in
            self?.hide()
            self?.executeCommand(command)
        }
        onCancel = { [weak self] in
            self?.hide()
        }

        let view = NSHostingView(rootView: PreviewCardView(
            command: command,
            explanation: CommandNarrator.preview(for: command),
            onRun: { [weak self] in self?.runCommand() },
            onCancel: { [weak self] in self?.cancel() }
        ))
        view.frame = NSRect(origin: .zero, size: cardFrame.size)
        view.autoresizingMask = [.width, .height]
        contentView?.subviews.forEach { $0.removeFromSuperview() }
        contentView?.addSubview(view)

        setFrame(cardFrame, display: false)
        alphaValue = 0
        makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            animator().alphaValue = 1
        }
    }

    func hide() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
            self.alphaValue = 1
        })
    }

    func updatePosition(below barWindow: NSPanel) {
        guard isVisible else { return }
        setFrame(frame(below: barWindow, height: frame.height), display: true, animate: false)
    }

    private func frame(below barWindow: NSPanel, height: CGFloat) -> NSRect {
        let barFrame = barWindow.frame
        let screen = barWindow.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? barFrame
        let width = min(max(barFrame.width, 560), visible.width - 24)
        let x = min(max(barFrame.minX, visible.minX + 12), visible.maxX - width - 12)
        let preferredBelowY = barFrame.minY - height
        let y: CGFloat

        if preferredBelowY >= visible.minY + 12 {
            y = preferredBelowY
        } else {
            y = min(barFrame.maxY, visible.maxY - height - 12)
        }

        return NSRect(x: x, y: max(y, visible.minY + 12), width: width, height: height)
    }

    private func runCommand() {
        onRun?()
        onRun = nil
        onCancel = nil
    }

    private func cancel() {
        onCancel?()
        onRun = nil
        onCancel = nil
    }

    private func executeCommand(_ command: String) {
        CommandExecutor.execute(command: command)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76:
            runCommand()
        case 53:
            cancel()
        default:
            super.keyDown(with: event)
        }
    }

    override var canBecomeKey: Bool { true }
}

// MARK: - SwiftUI Preview Card

struct PreviewCardView: View {
    let command: String
    let explanation: String
    var onRun: () -> Void
    var onCancel: () -> Void

    private var isDestructive: Bool {
        let danger = ["rm ", "rmdir", "sudo", "mkfs", "> /dev"]
        return danger.contains { command.contains($0) }
    }

    var body: some View {
        ZStack {
            RoundedPanelBackground()

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: isDestructive ? "trash" : "sparkles")
                        .font(.system(size: 12))
                        .foregroundColor(isDestructive ? .orange : .blue)
                        .padding(.top, 1)

                    Text(explanation)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                // Command preview
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "terminal")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.top, 1)

                    Text(command)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(isDestructive ? .orange : .primary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if isDestructive {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 12))
                    }
                }
                .padding(.horizontal, 14)

                // Buttons
                HStack(spacing: 8) {
                    Spacer()

                    Button("Cancel") { onCancel() }
                        .buttonStyle(PreviewButtonStyle(isRun: false))

                    Button(isDestructive ? "Run ⚠️" : "Run ↵") { onRun() }
                        .buttonStyle(PreviewButtonStyle(isRun: true, destructive: isDestructive))
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
        .overlay(
            VStack {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
                Spacer()
            }
        )
    }
}

struct PreviewButtonStyle: ButtonStyle {
    var isRun: Bool
    var destructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(
                isRun
                    ? (destructive ? Color.orange : Color.blue).opacity(configuration.isPressed ? 0.7 : 1)
                    : Color.white.opacity(configuration.isPressed ? 0.2 : 0.1)
            )
            .foregroundColor(isRun ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
