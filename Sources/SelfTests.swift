import AppKit

func runSelfTests() {
    var checks = 0
    func check(_ condition: @autoclosure () -> Bool, _ name: String) {
        guard condition() else { print("FAIL: \(name)"); exit(1) }
        checks += 1
        print("PASS: \(name)")
    }
    let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ClipShelf-Tests-\(UUID().uuidString)")
    let board = NSPasteboard(name: .init("ClipShelf.Tests.\(UUID().uuidString)"))
    defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: root) }
    let store = HistoryStore(directory: root, pasteboard: board, startMonitoring: false)
    store.addText("你好，剪贴板 👋\n第二行", source: "Tests")
    check(store.clips.count == 1 && store.clips[0].text == "你好，剪贴板 👋\n第二行", "Unicode and multiline text")
    let originalID = store.clips[0].id
    store.togglePin(store.clips[0])
    store.addText("你好，剪贴板 👋\n第二行", source: "Tests")
    check(store.clips.count == 1 && store.clips[0].pinned && store.clips[0].id == originalID, "Deduplication preserves identity and favorites")
    store.addText("https://example.com/hello", source: "Safari")
    check(store.clips[0].kind == .link, "URL classification")
    check(store.matching(query: "EXAMPLE Safari", filter: 0).count == 1, "Case-insensitive multi-term search")
    check(store.matching(query: "你好", filter: 1).count == 1, "Favorite search")
    let restored = HistoryStore(directory: root, pasteboard: board, startMonitoring: false)
    check(restored.clips.count == 2 && restored.clips.last?.pinned == true, "History and favorites survive restart")
    check(store.copy(store.clips.last!), "Copy succeeds")
    check(board.string(forType: .string) == "你好，剪贴板 👋\n第二行", "Copy preserves exact text")
    store.poll(sourceOverride: "Tests")
    check(store.clips.count == 2, "Copying history does not recapture it")
    board.clearContents(); board.setString("captured", forType: .string)
    store.poll(sourceOverride: "Tests")
    check(store.clips.first?.text == "captured", "Pasteboard polling captures a new change")
    store.paused = true
    board.clearContents(); board.setString("private while paused", forType: .string)
    store.poll(sourceOverride: "Tests")
    store.paused = false
    store.poll(sourceOverride: "Tests")
    check(!store.clips.contains { $0.text == "private while paused" }, "Paused content is not captured on resume")
    board.clearContents(); board.setString("secret", forType: .string); board.setData(Data(), forType: .init("org.nspasteboard.ConcealedType"))
    store.poll(sourceOverride: "Tests")
    check(!store.clips.contains { $0.text == "secret" }, "Sensitive clipboard marker is skipped")
    store.updateSettings(limit: 100, retentionDays: 7, captureImages: false)
    check(HistoryStore(directory: root, pasteboard: board, startMonitoring: false).settings.captureImages == false, "Settings survive restart")
    for index in 0..<110 { store.addText("Item \(index)", source: "Tests") }
    check(store.clips.filter { !$0.pinned }.count == 100 && store.clips.contains { $0.pinned }, "Capacity eviction preserves favorites")
    store.addText("expired", source: "Tests", date: Date().addingTimeInterval(-86400 * 8))
    check(!store.clips.contains { $0.text == "expired" }, "Expired records are removed")
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 8, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 32, bitsPerPixel: 32)!
    memset(bitmap.bitmapData!, 128, 256)
    let png = bitmap.representation(using: .png, properties: [:])!
    store.addImage(png, source: "Tests")
    let imageClip = store.clips[0]
    let imageURL = store.imageURL(for: imageClip)!
    check(imageClip.kind == .image && FileManager.default.fileExists(atPath: imageURL.path), "Image persists to disk")
    check(store.image(for: imageClip) != nil && store.image(for: imageClip, thumbnail: false) != nil, "Thumbnail and full-size preview load")
    check(store.copy(imageClip) && board.data(forType: .png) != nil, "Image can be copied back")
    store.remove(imageClip)
    check(!FileManager.default.fileExists(atPath: imageURL.path), "Deleting image cleans its file")
    store.clearUnpinned()
    check(store.clips.count == 1 && store.clips[0].pinned, "Clear history preserves favorites")
    print("\(checks) checks passed. General clipboard was not accessed.")
}
