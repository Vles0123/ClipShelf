import SwiftUI
import AppKit

enum Palette {
    static let bg = Color(red: 0.065, green: 0.074, blue: 0.094)
    static let card = Color(red: 0.105, green: 0.116, blue: 0.145)
    static let accent = Color(red: 0.72, green: 0.67, blue: 1.0)
    static let muted = Color(red: 0.53, green: 0.56, blue: 0.64)
}

final class PanelState: ObservableObject {
    @Published var query = ""
    @Published var filter = 0
    @Published var selected: UUID?
    @Published var showSettings = false
    @Published var focusToken = UUID()
    @Published var preview: Clip?
    @Published var hotkeyAvailable = true
}

struct PanelView: View {
    @ObservedObject var store: HistoryStore
    @ObservedObject var state: PanelState
    var onCopy: (Clip) -> Void
    var onClose: () -> Void
    @FocusState private var searchFocused: Bool
    @State private var confirmClear = false

    var results: [Clip] { store.matching(query: state.query, filter: state.filter) }

    var body: some View {
        VStack(spacing: 0) {
            header
            if state.showSettings {
                settingsPanel
            } else if let clip = state.preview {
                previewPanel(clip)
            } else {
                searchBar
                filters
                if let notice = store.notice {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                        Text(notice).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Button { store.notice = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                    }.foregroundStyle(Palette.accent).padding(12).background(Palette.accent.opacity(0.07)).padding(.horizontal, 20).padding(.bottom, 8)
                }
                if results.isEmpty { emptyState } else { historyList }
            }
            footer
        }
        .frame(width: 448, height: 626)
        .background(Palette.bg)
        .foregroundStyle(Color.white.opacity(0.91))
        .preferredColorScheme(.dark)
        .onChange(of: state.focusToken) { _ in searchFocused = true }
        .onChange(of: state.query) { _ in state.selected = results.first?.id }
        .onChange(of: state.filter) { _ in state.selected = results.first?.id }
        .onAppear { searchFocused = true }
    }

    private var header: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Palette.accent.opacity(0.15)).frame(width: 42, height: 42)
                Image(systemName: "doc.on.clipboard").font(.system(size: 22, weight: .medium)).foregroundStyle(Palette.accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("拾贴").font(.system(size: 21, weight: .semibold))
                    Text("CLIPSHELF").font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1.5).foregroundStyle(Palette.muted)
                }
                Text(state.showSettings ? "让剪贴板更合你的习惯" : "复制过的，都在手边。")
                    .font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
            Spacer()
            Button {
                store.paused.toggle()
            } label: {
                HStack(spacing: 5) {
                    Circle().fill(store.paused ? Color.orange : Color(red: 0.45, green: 0.85, blue: 0.68)).frame(width: 5, height: 5)
                    Text(store.paused ? "已暂停" : "记录中").font(.system(size: 10, weight: .medium))
                }.padding(.horizontal, 9).padding(.vertical, 6).background(Color.white.opacity(0.04), in: Capsule())
            }.buttonStyle(.plain).help(store.paused ? "继续记录剪贴板" : "暂停记录剪贴板").accessibilityLabel(store.paused ? "继续记录" : "暂停记录")
        }.padding(.horizontal, 22).padding(.top, 22).padding(.bottom, 22)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundStyle(Palette.muted)
            TextField("搜索内容或来源应用…", text: $state.query)
                .textFieldStyle(.plain).font(.system(size: 13)).focused($searchFocused)
                .accessibilityLabel("搜索剪贴板历史")
            if !state.query.isEmpty {
                Button { state.query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.muted) }.buttonStyle(.plain).accessibilityLabel("清除搜索")
            } else {
                Text("⌘ F").font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted).padding(.horizontal, 5).padding(.vertical, 3).background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.horizontal, 13).frame(height: 42)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(searchFocused ? 0.14 : 0.06), lineWidth: 1))
        .padding(.horizontal, 22)
    }

    private var filters: some View {
        HStack(spacing: 5) {
            filterButton("全部", index: 0, count: store.clips.count)
            filterButton("收藏", index: 1, count: store.clips.filter(\.pinned).count)
            filterButton("图片", index: 2, count: store.clips.filter { $0.kind == .image }.count)
            Spacer()
            Text("最近复制").font(.system(size: 10)).foregroundStyle(Palette.muted)
        }.padding(.horizontal, 22).padding(.top, 17).padding(.bottom, 13)
    }

    private func filterButton(_ title: String, index: Int, count: Int) -> some View {
        Button { state.filter = index } label: {
            HStack(spacing: 5) {
                Text(title).font(.system(size: 11, weight: state.filter == index ? .semibold : .regular))
                Text("\(count)").font(.system(size: 9, weight: .medium, design: .monospaced)).opacity(0.65)
            }.padding(.horizontal, 10).padding(.vertical, 7)
                .foregroundStyle(state.filter == index ? Palette.accent : Palette.muted)
                .background(state.filter == index ? Palette.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 7))
        }.buttonStyle(.plain).accessibilityLabel("\(title)，\(count) 条")
    }

    private var historyList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 7) {
                    ForEach(results) { clip in
                        ClipRow(clip: clip, image: clip.kind == .image ? store.image(for: clip) : nil,
                                selected: state.selected == clip.id,
                                onCopy: { onCopy(clip) }, onPin: { store.togglePin(clip) })
                            .id(clip.id)
                            .contextMenu {
                                Button("复制", action: { onCopy(clip) })
                                Button("查看完整内容", action: { state.preview = clip })
                                Button(clip.pinned ? "取消收藏" : "收藏", action: { store.togglePin(clip) })
                                Divider()
                                Button("删除记录", role: .destructive, action: { store.remove(clip) })
                            }
                    }
                }.padding(.horizontal, 16).padding(.bottom, 12)
            }
            .onChange(of: state.selected) { id in if let id { withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(id, anchor: .center) } } }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().stroke(Palette.accent.opacity(0.07), lineWidth: 1).frame(width: 118, height: 118)
                Circle().fill(Palette.accent.opacity(0.045)).frame(width: 92, height: 92)
                Image(systemName: emptySymbol).font(.system(size: 34, weight: .light)).foregroundStyle(Palette.accent)
            }.padding(.bottom, 24)
            Text(emptyTitle).font(.system(size: 17, weight: .medium)).padding(.bottom, 9)
            Text(emptyDescription).font(.system(size: 12)).lineSpacing(5).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
            if state.query.isEmpty && state.filter == 0 {
                HStack(spacing: 7) {
                    key("⌘ C")
                    Image(systemName: "arrow.right").font(.system(size: 9)).foregroundStyle(Palette.muted)
                    Text("拾贴自动记住").font(.system(size: 10)).foregroundStyle(Palette.muted)
                }.padding(.top, 24)
            }
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "internaldrive").font(.system(size: 10))
                Text("只保存在这台 Mac 上").font(.system(size: 10))
            }.foregroundStyle(Palette.muted.opacity(0.75)).padding(.bottom, 24)
        }.frame(maxWidth: .infinity)
    }

    private var emptySymbol: String { !state.query.isEmpty ? "magnifyingglass" : state.filter == 1 ? "star" : state.filter == 2 ? "photo.on.rectangle" : "doc.on.clipboard" }
    private var emptyTitle: String { !state.query.isEmpty ? "没有找到这条内容" : state.filter == 1 ? "把常用的，留在这里" : state.filter == 2 ? "图片，也能记住" : "从下一次复制开始" }
    private var emptyDescription: String {
        if !state.query.isEmpty { return "换个关键词，或试试来源应用的名称。" }
        if state.filter == 1 { return "点击记录旁的星标收藏。\n收藏内容会一直保留，直到你手动删除。" }
        if state.filter == 2 { return "复制截图或图片后，就能在这里找到。" }
        return store.paused ? "记录已暂停，点击右上角继续。" : "复制一段文字、链接或图片。\n下次需要时，来这里找。"
    }

    private var footer: some View {
        HStack(spacing: 6) {
            if state.showSettings || state.preview != nil {
                Button { state.showSettings = false; state.preview = nil; state.focusToken = UUID() } label: {
                    Label("返回历史", systemImage: "arrow.left").font(.system(size: 11))
                }.buttonStyle(.plain).foregroundStyle(Palette.accent)
            } else {
                key("↑ ↓")
                Text("选择").font(.system(size: 10)).foregroundStyle(Palette.muted)
                key("↵").padding(.leading, 5)
                Text("复制，再 ⌘V 粘贴").font(.system(size: 10)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 4)
            Text(state.hotkeyAvailable ? "⌃⌥V" : "菜单栏呼出").font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.muted)
            Button { state.showSettings.toggle(); state.preview = nil } label: {
                Image(systemName: "slider.horizontal.3").font(.system(size: 14)).foregroundStyle(state.showSettings ? Palette.accent : Palette.muted).frame(width: 26, height: 28)
            }.buttonStyle(.plain).help("设置").accessibilityLabel("设置")
        }.padding(.horizontal, 22).frame(height: 51)
            .background(Color.white.opacity(0.018))
            .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.055)).frame(height: 1) }
    }

    private func key(_ value: String) -> some View {
        Text(value).font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted).padding(.horizontal, 5).padding(.vertical, 3)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("偏好设置").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.accent)
            VStack(spacing: 18) {
                settingRow("历史记录上限") {
                    Picker("历史记录上限", selection: Binding(get: { store.settings.limit }, set: { store.updateSettings(limit: $0) })) {
                        Text("100 条").tag(100); Text("200 条").tag(200); Text("500 条").tag(500); Text("1000 条").tag(1000)
                    }.labelsHidden().frame(width: 112)
                }
                settingRow("保留时间") {
                    Picker("保留时间", selection: Binding(get: { store.settings.retentionDays }, set: { store.updateSettings(retentionDays: $0) })) {
                        Text("7 天").tag(7); Text("30 天").tag(30); Text("90 天").tag(90); Text("永久").tag(0)
                    }.labelsHidden().frame(width: 112)
                }
                settingRow("记录图片") {
                    Toggle("记录图片", isOn: Binding(get: { store.settings.captureImages }, set: { store.updateSettings(captureImages: $0) })).labelsHidden().toggleStyle(.switch).controlSize(.small).tint(Palette.accent)
                }
            }.padding(16).background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 10) {
                Label("收藏记录不受数量和时间限制", systemImage: "star").font(.system(size: 11))
                Label("自动跳过标记为敏感内容的剪贴板", systemImage: "lock").font(.system(size: 11))
                Label("快捷键：Control + Option + V", systemImage: "keyboard").font(.system(size: 11))
            }.foregroundStyle(Palette.muted)
            HStack {
                Button("打开存储文件夹") { NSWorkspace.shared.open(store.directory) }.buttonStyle(.plain).foregroundStyle(Palette.accent)
                Spacer()
                Button("清空未收藏") { confirmClear = true }.buttonStyle(.plain).foregroundStyle(Color(red: 1, green: 0.58, blue: 0.57))
            }.font(.system(size: 11))
            if confirmClear {
                HStack {
                    Text("删除所有未收藏记录？").font(.system(size: 11))
                    Spacer()
                    Button("取消") { confirmClear = false }
                    Button("删除") { store.clearUnpinned(); confirmClear = false }.tint(.red)
                }.padding(12).background(Palette.card, in: RoundedRectangle(cornerRadius: 8))
            }
            Spacer(minLength: 0)
            HStack {
                Text("拾贴 1.0 · 本地存储 · 无需联网").font(.system(size: 10)).foregroundStyle(Palette.muted)
                Spacer()
                Button("退出拾贴") { NSApp.terminate(nil) }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
        }.padding(.horizontal, 22).padding(.bottom, 22).frame(maxHeight: .infinity, alignment: .top)
    }

    private func settingRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack { Text(title).font(.system(size: 12)); Spacer(); content() }
    }

    private func previewPanel(_ clip: Clip) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(clip.label, systemImage: clip.symbol).font(.system(size: 12)).foregroundStyle(Palette.accent)
                Spacer()
                Text(clip.source).font(.system(size: 11)).foregroundStyle(Palette.muted)
                Button("复制") { onCopy(clip) }.tint(Palette.accent)
            }
            ScrollView {
                if clip.kind == .image, let image = store.image(for: clip, thumbnail: false) {
                    Image(nsImage: image).resizable().scaledToFit()
                } else {
                    Text(clip.text ?? "").font(.system(size: 13, design: clip.kind == .code ? .monospaced : .default)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
            }.padding(14).background(Palette.card, in: RoundedRectangle(cornerRadius: 10))
        }.padding(.horizontal, 22).padding(.bottom, 18)
    }
}

struct ClipRow: View {
    let clip: Clip
    let image: NSImage?
    let selected: Bool
    var onCopy: () -> Void
    var onPin: () -> Void
    @State private var hovered = false

    private var tint: Color {
        switch clip.kind {
        case .link: return Color(red: 0.46, green: 0.73, blue: 0.98)
        case .code: return Color(red: 0.94, green: 0.74, blue: 0.47)
        case .image: return Color(red: 0.56, green: 0.83, blue: 0.70)
        case .text: return Palette.accent
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Button(action: onCopy) {
                HStack(alignment: .top, spacing: 11) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.09)).frame(width: 34, height: 34)
                        if let image {
                            Image(nsImage: image).resizable().scaledToFill().frame(width: 34, height: 34).clipped().clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Image(systemName: clip.symbol).font(.system(size: 14)).foregroundStyle(tint)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(clip.title).font(.system(size: 12, weight: .medium, design: clip.kind == .code ? .monospaced : .default)).lineLimit(1).foregroundStyle(.white.opacity(0.89))
                        if let text = clip.text {
                            let detail = text.split(whereSeparator: \.isNewline).dropFirst().joined(separator: " ")
                            if !detail.isEmpty { Text(detail).font(.system(size: 11, design: clip.kind == .code ? .monospaced : .default)).foregroundStyle(Palette.muted).lineLimit(1) }
                        }
                        HStack(spacing: 5) {
                            Text(clip.label).foregroundStyle(tint.opacity(0.8))
                            Text("·")
                            Text(clip.source).lineLimit(1)
                            Spacer(minLength: 4)
                            TimelineView(.periodic(from: .now, by: 60)) { _ in Text(age(clip.date)) }
                        }.font(.system(size: 9)).foregroundStyle(Palette.muted.opacity(0.8))
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).help("复制这条记录").accessibilityLabel("复制：\(clip.title)")
            Button(action: onPin) {
                Image(systemName: clip.pinned ? "star.fill" : "star").font(.system(size: 12)).foregroundStyle(clip.pinned ? Palette.accent : Palette.muted.opacity(hovered ? 0.9 : 0.45)).frame(width: 22, height: 28)
            }.buttonStyle(.plain).help(clip.pinned ? "取消收藏" : "收藏").accessibilityLabel(clip.pinned ? "取消收藏" : "收藏")
        }
        .padding(12)
        .background(selected || hovered ? Palette.accent.opacity(0.085) : Palette.card.opacity(0.66), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Palette.accent.opacity(0.35) : Color.white.opacity(0.025), lineWidth: 1))
        .onHover { hovered = $0 }
    }

    private func age(_ date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 60 { return "刚刚" }
        if seconds < 3600 { return "\(seconds / 60) 分钟前" }
        if seconds < 86400 { return "\(seconds / 3600) 小时前" }
        return "\(seconds / 86400) 天前"
    }
}
