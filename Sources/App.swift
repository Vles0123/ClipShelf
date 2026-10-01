import AppKit
import SwiftUI
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var store: HistoryStore!
    let state = PanelState()
    var statusItem: NSStatusItem!
    let popover = NSPopover()
    var previewWindow: NSWindow?
    var hotkey: EventHotKeyRef?
    var handler: EventHandlerRef?
    var keyMonitor: Any?
    var previousApp: NSRunningApplication?
    let demo = CommandLine.arguments.contains("--demo")

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if demo {
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ClipShelf-Demo-\(UUID().uuidString)")
            store = HistoryStore(directory: url, pasteboard: NSPasteboard(name: .init("ClipShelf.Demo")))
            seedDemo()
        } else {
            store = HistoryStore()
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "拾贴剪贴板历史")
            button.image?.isTemplate = true
            button.toolTip = "拾贴 · 剪贴板历史（⌃⌥V）"
            button.target = self
            button.action = #selector(statusClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        let view = PanelView(store: store, state: state, onCopy: { [weak self] in self?.copyAndClose($0) }, onClose: { [weak self] in self?.close() })
        let controller = NSHostingController(rootView: view)
        popover.contentViewController = controller
        popover.contentSize = NSSize(width: 448, height: 626)
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        registerHotkey()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.popover.isShown || self.previewWindow?.isVisible == true else { return event }
            return self.handleKey(event)
        }
        if CommandLine.arguments.contains("--preview") {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 448, height: 626), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "拾贴 · ClipShelf"
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(red: 0.065, green: 0.074, blue: 0.094, alpha: 1)
            window.appearance = NSAppearance(named: .darkAqua)
            window.contentViewController = controller
            window.center()
            window.makeKeyAndOrderFront(nil)
            previewWindow = window
            NSApp.activate(ignoringOtherApps: true)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.show() }
        }
    }

    @objc func statusClicked(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "打开拾贴", action: #selector(toggle), keyEquivalent: "")
            menu.addItem(withTitle: store.paused ? "继续记录" : "暂停记录", action: #selector(togglePaused), keyEquivalent: "")
            menu.addItem(.separator())
            menu.addItem(withTitle: "退出拾贴", action: #selector(quit), keyEquivalent: "q")
            for item in menu.items { item.target = self }
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else { toggle() }
    }

    @objc func toggle() { popover.isShown ? close() : show() }
    @objc func togglePaused() { store.paused.toggle() }
    @objc func quit() { NSApp.terminate(nil) }

    func show() {
        guard let button = statusItem.button else { return }
        if let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != ProcessInfo.processInfo.processIdentifier { previousApp = app }
        state.query = ""
        state.showSettings = false
        state.preview = nil
        state.selected = store.matching(query: "", filter: state.filter).first?.id
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        state.focusToken = UUID()
    }

    func close() { popover.performClose(nil) }

    func copyAndClose(_ clip: Clip) {
        guard store.copy(clip) else { return }
        close()
        previousApp?.activate(options: [])
    }

    func handleKey(_ event: NSEvent) -> NSEvent? {
        if event.keyCode == 53 {
            if state.preview != nil { state.preview = nil }
            else if state.showSettings { state.showSettings = false }
            else { close(); previousApp?.activate(options: []) }
            return nil
        }
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "f" {
            state.showSettings = false
            state.preview = nil
            state.focusToken = UUID()
            return nil
        }
        guard !state.showSettings, state.preview == nil else { return event }
        // Let the input method handle arrows and Return while Chinese text is being composed.
        if let input = event.window?.firstResponder as? NSTextView, input.hasMarkedText() { return event }
        let clips = store.matching(query: state.query, filter: state.filter)
        if event.keyCode == 125 || event.keyCode == 126 {
            guard !clips.isEmpty else { return nil }
            let current = clips.firstIndex { $0.id == state.selected } ?? (event.keyCode == 125 ? -1 : clips.count)
            let next = min(max(current + (event.keyCode == 125 ? 1 : -1), 0), clips.count - 1)
            state.selected = clips[next].id
            return nil
        }
        if event.keyCode == 36, let clip = clips.first(where: { $0.id == state.selected }) ?? clips.first {
            copyAndClose(clip)
            return nil
        }
        return event
    }

    func registerHotkey() {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, _, data in
            guard let data else { return OSStatus(eventNotHandledErr) }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(data).takeUnretainedValue()
            delegate.toggle()
            return noErr
        }, 1, &event, context, &handler)
        let id = EventHotKeyID(signature: 0x43534846, id: 1)
        let registered = RegisterEventHotKey(UInt32(kVK_ANSI_V), UInt32(controlKey | optionKey), id, GetApplicationEventTarget(), 0, &hotkey)
        state.hotkeyAvailable = installed == noErr && registered == noErr
        if !state.hotkeyAvailable { store.notice = "⌃⌥V 被其他应用占用，可点击菜单栏图标打开拾贴。" }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store?.save()
        if let hotkey { UnregisterEventHotKey(hotkey) }
        if let handler { RemoveEventHandler(handler) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if demo, let directory = store?.directory { try? FileManager.default.removeItem(at: directory) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { show(); return true }

    private func seedDemo() {
        let samples = [
            ("每一个好想法，都值得被留下。\n把零散的灵感，慢慢拼成自己的作品。", "备忘录", 5800.0),
            ("周末清单\n去书店 · 整理照片 · 把那个小工具做出来", "备忘录", 3500.0),
            ("const ideas = clipboard.history\n  .filter(item => item.favorite)\n  .map(item => item.content)", "Visual Studio Code", 1300.0),
            ("https://developer.apple.com/design/", "Safari", 420.0),
            ("设计不只是看起来如何，而是用起来如何。\n让常用的东西更近一点，让重复的操作更少一点。", "Safari", 30.0)
        ]
        for (text, source, seconds) in samples { store.addText(text, source: source, date: Date().addingTimeInterval(-seconds)) }
        if let clip = store.clips.last { store.togglePin(clip) }
        state.selected = store.clips.first?.id
    }
}

@main struct ClipShelfMain {
    static func main() {
        if CommandLine.arguments.contains("--self-test") { runSelfTests(); return }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
        withExtendedLifetime(delegate) {}
    }
}
