import AppKit

struct FinderContext: Equatable {
    var selectedFiles: [String]
    var currentFolder: String?

    var hasSelection: Bool {
        !selectedFiles.isEmpty
    }
}

class FinderTracker {
    private var timer: Timer?
    private var finderPID: pid_t?
    private var observer: AXObserver?
    private var observedWindow: AXUIElement?
    private var lastFrame: NSRect = .zero
    private var lastIsActive = false
    private var fallbackTick = 0

    var onChange: ((NSRect, Bool) -> Void)?

    init(onChange: @escaping (NSRect, Bool) -> Void) {
        self.onChange = onChange
        start()
    }

    deinit {
        timer?.invalidate()
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
    }

    func start() {
        // Keep frame tracking fast and AX-first so Nest can follow Finder during drags.
        timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
        timer?.tolerance = 0
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func poll() {
        if finderPID == nil {
            finderPID = NSWorkspace.shared.runningApplications
                .first(where: { $0.bundleIdentifier == "com.apple.finder" })?
                .processIdentifier
            if let finderPID {
                installObserver(pid: finderPID)
            }
        }
        guard let finderPID else { return }
        updateObservedWindow(pid: finderPID)

        let isActive = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder"

        let frame: NSRect
        if let axFrame = Self.finderWindowFrameAX(pid: finderPID) {
            frame = axFrame
        } else if fallbackTick % 15 == 0, let asFrame = Self.finderWindowFrameAppleScript() {
            frame = asFrame
        } else {
            fallbackTick += 1
            return
        }
        fallbackTick += 1

        if !Self.rectsNearlyEqual(frame, lastFrame) || isActive != lastIsActive {
            lastFrame = frame
            lastIsActive = isActive
            onChange?(frame, isActive)
        }
    }

    private func installObserver(pid: pid_t) {
        guard observer == nil else { return }

        var newObserver: AXObserver?
        let result = AXObserverCreate(pid, { _, _, _, refcon in
            guard let refcon else { return }
            let tracker = Unmanaged<FinderTracker>.fromOpaque(refcon).takeUnretainedValue()
            tracker.poll()
        }, &newObserver)

        guard result == .success, let newObserver else { return }
        observer = newObserver
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(newObserver), .commonModes)
        updateObservedWindow(pid: pid)
    }

    private func updateObservedWindow(pid: pid_t) {
        guard let observer else { return }
        let axApp = AXUIElementCreateApplication(pid)
        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let windowRef = windowRef,
              CFGetTypeID(windowRef) == AXUIElementGetTypeID() else { return }

        let window = windowRef as! AXUIElement
        if let observedWindow, CFEqual(observedWindow, window) {
            return
        }

        observedWindow = window
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(observer, window, kAXMovedNotification as CFString, refcon)
        AXObserverAddNotification(observer, window, kAXResizedNotification as CFString, refcon)
    }

    private static func rectsNearlyEqual(_ a: NSRect, _ b: NSRect) -> Bool {
        abs(a.minX - b.minX) < 0.5 &&
        abs(a.minY - b.minY) < 0.5 &&
        abs(a.width - b.width) < 0.5 &&
        abs(a.height - b.height) < 0.5
    }

    // MARK: - Accessibility API (requires permission in System Settings)

    static func finderWindowFrameAX(pid: pid_t) -> NSRect? {
        let axApp = AXUIElementCreateApplication(pid)
        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let windowRef = windowRef else { return nil }
        let axWindow = windowRef as! AXUIElement

        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posRef = posRef, let sizeRef = sizeRef else { return nil }

        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)

        guard size.width > 0, size.height > 0 else { return nil }
        return Self.convertToNSWindowCoords(axX: position.x, axY: position.y,
                                            width: size.width, height: size.height)
    }

    // MARK: - AppleScript fallback (works without Accessibility permission)

    static func finderWindowFrameAppleScript() -> NSRect? {
        // AppleScript returns bounds as {left, top, right, bottom} in screen points, top-left origin
        let src = """
        tell application "Finder"
            if (count windows) = 0 then return ""
            get bounds of window 1
        end tell
        """
        var err: NSDictionary?
        guard let result = NSAppleScript(source: src)?.executeAndReturnError(&err),
              err == nil,
              result.numberOfItems == 4 else { return nil }

        let left   = CGFloat(result.atIndex(1)?.int32Value ?? 0)
        let top    = CGFloat(result.atIndex(2)?.int32Value ?? 0)
        let right  = CGFloat(result.atIndex(3)?.int32Value ?? 0)
        let bottom = CGFloat(result.atIndex(4)?.int32Value ?? 0)

        let width = right - left
        let height = bottom - top
        guard width > 0, height > 0 else { return nil }

        // Convert from top-left origin to NSWindow bottom-left origin
        return Self.convertToNSWindowCoords(axX: left, axY: top, width: width, height: height)
    }

    // MARK: - Coordinate conversion

    /// Converts from screen coordinates (top-left origin, as used by AX and AppleScript)
    /// to NSWindow coordinates (bottom-left origin).
    static func convertToNSWindowCoords(axX: CGFloat, axY: CGFloat,
                                        width: CGFloat, height: CGFloat) -> NSRect? {
        guard let screen = NSScreen.main else { return nil }
        let screenH = screen.frame.height
        // axY is distance from top of screen; NSWindow y is distance from bottom
        let nsY = screenH - axY - height
        return NSRect(x: axX, y: nsY, width: width, height: height)
    }

    // MARK: - finderWindowFrame (public convenience, tries both methods)

    static func finderWindowFrame(pid: pid_t) -> NSRect? {
        if let frame = finderWindowFrameAX(pid: pid) { return frame }
        return finderWindowFrameAppleScript()
    }

    // MARK: - Read currently selected files from Finder

    static func context() -> FinderContext {
        FinderContext(
            selectedFiles: selectedFiles(),
            currentFolder: currentFolder()
        )
    }

    static func selectedFiles() -> [String] {
        if let files = selectedFilesAppleScript(), !files.isEmpty {
            return files
        }

        if let finder = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == "com.apple.finder" }) {
            return selectedFilesAX(pid: finder.processIdentifier)
        }

        return []
    }

    static func currentFolder() -> String? {
        let src = """
        tell application "Finder"
            if (count windows) > 0 then
                return POSIX path of (target of front window as alias)
            else
                return POSIX path of (desktop as alias)
            end if
        end tell
        """
        var err: NSDictionary?
        guard let result = NSAppleScript(source: src)?.executeAndReturnError(&err),
              err == nil,
              let path = result.stringValue,
              !path.isEmpty else { return nil }
        return path
    }

    private static func selectedFilesAppleScript() -> [String]? {
        let src = """
        tell application "Finder"
            set sel to selection as alias list
            set paths to {}
            repeat with f in sel
                set end of paths to POSIX path of f
            end repeat
            return paths
        end tell
        """
        var err: NSDictionary?
        let result = NSAppleScript(source: src)?.executeAndReturnError(&err)
        guard err == nil, let desc = result else { return nil }
        var paths: [String] = []
        let count = desc.numberOfItems
        guard count > 0 else { return [] }
        for i in 1...count {
            if let item = desc.atIndex(i), let s = item.stringValue, !s.isEmpty {
                paths.append(s)
            }
        }
        return paths
    }

    private static func selectedFilesAX(pid: pid_t) -> [String] {
        let axApp = AXUIElementCreateApplication(pid)
        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let windowRef = windowRef,
              CFGetTypeID(windowRef) == AXUIElementGetTypeID() else { return [] }
        let window = windowRef as! AXUIElement

        var paths: [String] = []
        for attr in ["AXSelectedChildren", "AXSelectedRows", "AXSelectedCells"] {
            var selectedRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window, attr as CFString, &selectedRef) == .success,
                  let selected = selectedRef else { continue }

            if let elements = selected as? [AXUIElement] {
                for element in elements {
                    paths.append(contentsOf: filePaths(in: element, depth: 0))
                }
            } else if CFGetTypeID(selected) == AXUIElementGetTypeID() {
                paths.append(contentsOf: filePaths(in: selected as! AXUIElement, depth: 0))
            }
        }

        return Array(NSOrderedSet(array: paths)) as? [String] ?? paths
    }

    private static func filePaths(in element: AXUIElement, depth: Int) -> [String] {
        guard depth < 6 else { return [] }

        if let path = filePath(from: element) {
            return [path]
        }

        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return [] }

        return children.flatMap { filePaths(in: $0, depth: depth + 1) }
    }

    private static func filePath(from element: AXUIElement) -> String? {
        var urlRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXURLAttribute as CFString, &urlRef) == .success,
              let url = urlRef as? URL,
              url.isFileURL else { return nil }
        return url.path
    }
}
