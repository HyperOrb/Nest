import AppKit

class MenubarController {
    private var statusItem: NSStatusItem!
    var onToggle: () -> Void
    var onSettings: () -> Void
    var onWelcome: () -> Void
    var onQuit: () -> Void

    init(onToggle: @escaping () -> Void, onSettings: @escaping () -> Void, onWelcome: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onToggle = onToggle
        self.onSettings = onSettings
        self.onWelcome = onWelcome
        self.onQuit = onQuit
        setup()
    }

    private func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "shippingbox", accessibilityDescription: "Nest")
            btn.image?.isTemplate = true
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "Toggle Bar  ⌃Space", action: #selector(toggle), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(settings), keyEquivalent: ",")
            .target = self
        menu.addItem(withTitle: "Welcome to Nest…", action: #selector(welcome), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Nest", action: #selector(quit), keyEquivalent: "q")
            .target = self
        statusItem.menu = menu
    }

    @objc func toggle() { onToggle() }
    @objc func settings() { onSettings() }
    @objc func welcome() { onWelcome() }
    @objc func quit() { onQuit() }
}
