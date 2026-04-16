import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var menubarController: MenubarController!
    var finderTracker: FinderTracker!
    var commandBarWindow: CommandBarWindow!
    var previewWindow: PreviewCardWindow!
    var answerWindow: AnswerCardWindow!
    var settingsWindow: SettingsWindow?
    var activityLogWindow: ActivityLogWindow?
    var onboardingWindow: OnboardingWindow?
    private var hotKeyManager: HotKeyManager?
    private var globalHotkeyMonitor: Any?
    private var localHotkeyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        commandBarWindow = CommandBarWindow()
        previewWindow = PreviewCardWindow()
        answerWindow = AnswerCardWindow()

        finderTracker = FinderTracker { [weak self] frame, isFinderActive in
            guard let self = self else { return }
            if isFinderActive {
                // Finder is front — update position and show bar if not visible
                self.commandBarWindow.updatePosition(finderFrame: frame)
                self.previewWindow.updatePosition(below: self.commandBarWindow)
                self.answerWindow.updatePosition(below: self.commandBarWindow)
                if !self.commandBarWindow.isVisible {
                    self.commandBarWindow.showFromTracker(finderFrame: frame)
                }
            } else {
                // Only hide if the app in front is neither Finder nor Nest itself.
                let frontBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
                let ours = Bundle.main.bundleIdentifier ?? "com.nest.finder.agent"
                let isSelf = frontBundleID == ours || frontBundleID.isEmpty
                let isFinder = frontBundleID == "com.apple.finder"

                if !isSelf && !isFinder {
                    self.commandBarWindow.hide()
                    self.previewWindow.hide()
                    self.answerWindow.hide()
                } else {
                    // Still update position in case Finder window moved
                    self.commandBarWindow.updatePosition(finderFrame: frame)
                    self.previewWindow.updatePosition(below: self.commandBarWindow)
                    self.answerWindow.updatePosition(below: self.commandBarWindow)
                }
            }
        }

        menubarController = MenubarController(
            onToggle: { [weak self] in self?.commandBarWindow.toggle() },
            onSettings: { [weak self] in self?.openSettings() },
            onWelcome: { [weak self] in self?.openOnboarding(resetCompletion: true) },
            onQuit: { NSApp.terminate(nil) }
        )

        setupHotkeyMonitors()

        NotificationCenter.default.addObserver(self, selector: #selector(showPreview(_:)), name: .showCommandPreview, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(showAnswerLoading), name: .showAnswerLoading, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(showAnswer(_:)), name: .showAnswer, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(showCommandResult(_:)), name: .showCommandResult, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(openSettingsNotif), name: .openSettings, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(openActivityNotif), name: .openActivity, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(openOnboardingNotif), name: .openOnboarding, object: nil)

        // Enable Copy/Paste/Undo shortcuts
        setupEditMenu()

        requestAccessibilityPermissionIfNeeded()
        showOnboardingIfNeeded()

        // Try to show the bar immediately if Finder is already running
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let finder = NSWorkspace.shared.runningApplications
                .first(where: { $0.bundleIdentifier == "com.apple.finder" }),
               let frame = FinderTracker.finderWindowFrame(pid: finder.processIdentifier) {
                self.commandBarWindow.showFromTracker(finderFrame: frame)
            }
        }
    }

    private func setupHotkeyMonitors() {
        hotKeyManager = HotKeyManager { [weak self] in
            self?.commandBarWindow.toggle()
        }

        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if Self.isToggleHotkey(event) {
                DispatchQueue.main.async { self?.commandBarWindow.toggle() }
            }
        }

        localHotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if Self.isToggleHotkey(event) {
                self?.commandBarWindow.toggle()
                return nil
            }
            return event
        }
    }

    private static func isToggleHotkey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return flags.contains(.control) && event.keyCode == 49
    }

    /// Creates a standard Edit menu so that Copy/Paste/Undo shortcuts work.
    /// This is required even for menubar apps to handle keyboard shortcuts correctly.
    private func setupEditMenu() {
        let mainMenu = NSMenu()
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: #selector(UndoManager.undo), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: #selector(UndoManager.redo), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        
        editMenuItem.submenu = editMenu
        NSApp.mainMenu = mainMenu
    }

    @objc func showPreview(_ notif: Notification) {
        guard let command = notif.object as? String else { return }
        answerWindow.hide()
        previewWindow.show(command: command, below: commandBarWindow)
    }

    @objc func showAnswerLoading() {
        previewWindow.hide()
        answerWindow.hide()
    }

    @objc func showAnswer(_ notif: Notification) {
        previewWindow.hide()
        answerWindow.hide()
    }

    @objc func showCommandResult(_ notif: Notification) {
        previewWindow.hide()
        answerWindow.hide()
    }

    @objc func openSettingsNotif() { openSettings() }
    @objc func openActivityNotif() { openActivity() }
    @objc func openOnboardingNotif() { openOnboarding(resetCompletion: true) }

    func openSettings() {
        if settingsWindow == nil { settingsWindow = SettingsWindow() }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func openActivity() {
        if activityLogWindow == nil { activityLogWindow = ActivityLogWindow() }
        activityLogWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showOnboardingIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: "didCompleteOnboarding") else { return }
        openOnboarding(resetCompletion: false)
    }

    func openOnboarding(resetCompletion: Bool) {
        if resetCompletion {
            UserDefaults.standard.set(false, forKey: "didCompleteOnboarding")
        }
        onboardingWindow = OnboardingWindow { [weak self] in
            self?.openSettings()
        }
        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func requestAccessibilityPermissionIfNeeded() {
        guard !AXIsProcessTrusted() else { return }

        let key = "didRequestAccessibilityPermission"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
        UserDefaults.standard.set(true, forKey: key)
    }
}
