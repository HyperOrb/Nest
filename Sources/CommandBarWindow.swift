import AppKit
import SwiftUI

let BAR_HEIGHT: CGFloat = 52
let PANEL_CORNER_RADIUS: CGFloat = 14

class CommandBarWindow: NSPanel {

    private var hostingView: NSView?
    private var userHidden = false

    convenience init() {
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: BAR_HEIGHT),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        configure()
    }

    private func configure() {
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isMovable = false
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        contentView?.wantsLayer = true
        contentView?.layer?.cornerRadius = PANEL_CORNER_RADIUS
        contentView?.layer?.masksToBounds = true

        let view = NSHostingView(rootView: CommandBarView())
        view.frame = contentView?.bounds ?? .zero
        view.autoresizingMask = [.width, .height]
        contentView?.addSubview(view)
        hostingView = view
    }

    func updatePosition(finderFrame: NSRect) {
        guard isVisible else { return }
        let barFrame = frameBelow(finderFrame: finderFrame)
        setFrame(barFrame, display: true, animate: false)
    }

    func show(finderFrame: NSRect) {
        userHidden = false
        showFromTracker(finderFrame: finderFrame)
    }

    func showFromTracker(finderFrame: NSRect) {
        guard !userHidden else { return }
        let barFrame = frameBelow(finderFrame: finderFrame)
        setFrame(barFrame, display: false)
        alphaValue = 0
        makeKeyAndOrderFront(nil)
        focusCommandField()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            animator().alphaValue = 1
        }
    }

    func hide() {
        hide(markUserHidden: false)
    }

    func hideFromUser() {
        hide(markUserHidden: true)
    }

    private func hide(markUserHidden: Bool) {
        if markUserHidden {
            userHidden = true
        }
        guard isVisible else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.14
            animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
            self.alphaValue = 1
        })
    }

    func toggle() {
        if isVisible {
            hideFromUser()
        } else {
            userHidden = false
            // Pull latest frame from tracker
            if let finder = NSWorkspace.shared.runningApplications
                .first(where: { $0.bundleIdentifier == "com.apple.finder" }),
               let frame = FinderTracker.finderWindowFrame(pid: finder.processIdentifier) {
                show(finderFrame: frame)
            }
        }
    }

    private func frameBelow(finderFrame: NSRect) -> NSRect {
        NSRect(x: finderFrame.minX,
               y: finderFrame.minY - BAR_HEIGHT,
               width: finderFrame.width,
               height: BAR_HEIGHT)
    }

    private func focusCommandField() {
        DispatchQueue.main.async {
            guard let textField = self.contentView?.firstSubview(ofType: InterceptTextField.self) else { return }
            self.makeFirstResponder(textField)
            textField.selectText(nil)
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private extension NSView {
    func firstSubview<T: NSView>(ofType type: T.Type) -> T? {
        if let view = self as? T { return view }
        for subview in subviews {
            if let found = subview.firstSubview(ofType: type) {
                return found
            }
        }
        return nil
    }
}
