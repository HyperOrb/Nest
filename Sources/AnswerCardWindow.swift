import AppKit
import SwiftUI

struct CommandResultPayload {
    let command: String
    let summary: String
    let output: String
    let succeeded: Bool
}

class AnswerCardWindow: NSPanel {
    convenience init() {
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 150),
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

    func show(answer: String, below barWindow: NSPanel) {
        showContent(answer: answer, isLoading: false, below: barWindow)
    }

    func showResult(_ result: CommandResultPayload, below barWindow: NSPanel) {
        let h: CGFloat = result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 190 : 300
        let cardFrame = frame(below: barWindow, height: h)

        let view = NSHostingView(rootView: CommandResultCardView(result: result) { [weak self] in
            self?.hide()
        })
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

    func showLoading(below barWindow: NSPanel) {
        showContent(answer: "Thinking...", isLoading: true, below: barWindow)
    }

    private func showContent(answer: String, isLoading: Bool, below barWindow: NSPanel) {
        let h: CGFloat = isLoading ? 150 : 260
        let cardFrame = frame(below: barWindow, height: h)

        let view = NSHostingView(rootView: AnswerCardView(answer: answer, isLoading: isLoading) { [weak self] in
            self?.hide()
        })
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

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 53, 76:
            hide()
        default:
            super.keyDown(with: event)
        }
    }

    override var canBecomeKey: Bool { true }
}

struct AnswerCardView: View {
    let answer: String
    var isLoading = false
    let onClose: () -> Void

    var body: some View {
        ZStack {
            RoundedPanelBackground()

            VStack(alignment: .leading, spacing: 12) {
                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.55)
                            .frame(width: 14, height: 14)

                        Text("Nest")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(answer)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                        Text("Asking your AI provider...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                } else {
                    ScrollView {
                        Text(answer)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }

                HStack {
                    Spacer()
                    Button("Close") { onClose() }
                        .buttonStyle(PreviewButtonStyle(isRun: false))
                        .disabled(isLoading)
                }
            }
            .padding(14)
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

struct CommandResultCardView: View {
    let result: CommandResultPayload
    let onClose: () -> Void

    private var trimmedOutput: String {
        result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            RoundedPanelBackground()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: result.succeeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(result.succeeded ? .green : .orange)

                    Text(result.succeeded ? "Result" : "Command failed")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                }

                Text(result.summary)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(result.command)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                if !trimmedOutput.isEmpty {
                    ScrollView {
                        Text(trimmedOutput)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(result.succeeded ? .secondary : .orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    Spacer(minLength: 0)
                }

                HStack {
                    Spacer()
                    Button("Close") { onClose() }
                        .buttonStyle(PreviewButtonStyle(isRun: false))
                }
            }
            .padding(14)
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
