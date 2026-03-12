//
//  KyozoAppTopBar.swift
//  Kyozo
//
//  Top bar with dynamic toolbar items for KyozoApp-inspired interface
//

import SwiftUI

// NOTE: Moved from CodeAppTopBar.swift to KyozoAppTopBar.swift per naming cleanup
// The implementation mirrors the previous file and hooks buttons to actual actions.

struct KyozoAppTopBar: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var settings: SettingsState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @SceneStorage("selectedActivityItem") private var selectedActivityItem: String = "explorer"
    @SceneStorage("sidebarVisible") private var isSidebarVisible: Bool = true
    @SceneStorage("panelVisible") private var isPanelVisible: Bool = true

    @State private var notebooks: [Notebook] = []
    @State private var activeNotebook: Notebook.ID? = nil
    @State private var searchText: String = ""
    @State private var showingSearch: Bool = false
    @State private var showWorkspacePicker = false

    private let store = NotebookStore()

    var body: some View {
        HStack(spacing: 8) {
            leadingSection
            Spacer()
//            if horizontalSizeClass == .regular { centerSection }
            Spacer()
            trailingSection
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Rectangle())
        .task { await loadNotebooks() }
        #if os(iOS)
        .background(workspacePickerSheet())
        #endif
    }

    private var leadingSection: some View {
        HStack(spacing: 12) {
            if horizontalSizeClass == .compact {
                Button(action: { withAnimation(.easeInOut(duration: 0.3)) { isSidebarVisible.toggle() } }) {
                    Image(systemName: "sidebar.left").font(.system(size: 16, weight: .medium)).foregroundStyle(.primary)
                }.buttonStyle(.plain)
            }
            if let active = notebooks.first(where: { $0.id == activeNotebook }) {
                HStack(spacing: 8) {
                    Image(systemName: "book.closed").font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary)
                    Text(active.name).font(.headline).fontWeight(.medium).lineLimit(1)
                }
            } else {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4).fill(.blue.gradient).frame(width: 20, height: 20).overlay { Text("K").font(.caption).fontWeight(.bold).foregroundStyle(.white) }
                    Text("Kyozo").font(.headline).fontWeight(.semibold)
                }
            }
        }
    }

//    @ViewBuilder private var centerSection: some View { showingSearch ? searchBar : editorTabs }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary)
            TextField("Search notebooks and content...", text: $searchText)
                .textFieldStyle(.plain)
//                .onSubmit { performSearch() }
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) { Image(systemName: "xmark.circle.fill").font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary) }.buttonStyle(.plain)
            }
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showingSearch = false } }) { Image(systemName: "escape").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary) }.buttonStyle(.plain).keyboardShortcut(.escape)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: 400)
    }

    private var editorTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
//                ForEach(notebooks.prefix(6)) { nb in
//                    EditorTab(title: nb.name, isActive: activeNotebook == nb.id, hasChanges: false, onActivate: { activeNotebook = nb.id }, onClose: { closeNotebook(nb.id) })
//                }
            }.padding(.horizontal, 8)
        }.frame(maxWidth: 500)
    }

    private var trailingSection: some View {
        HStack(spacing: 8) {
            dynamicToolbarItems
            Menu { globalMenuItems } label: {
                Image(systemName: "ellipsis").font(.system(size: 16, weight: .medium)).foregroundStyle(.primary)
            }.buttonStyle(.plain)
        }
    }

    @ViewBuilder private var dynamicToolbarItems: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showingSearch.toggle() } }) {
            Image(systemName: "magnifyingglass").font(.system(size: 16, weight: .medium)).foregroundStyle(showingSearch ? .blue : .secondary)
        }.buttonStyle(.plain).keyboardShortcut("f", modifiers: .command)

        switch selectedActivityItem {
        case "explorer", "notebooks":
            Button(action: { createNewNotebook() }) { Image(systemName: "doc.badge.plus").font(.system(size: 16, weight: .medium)).foregroundStyle(.secondary) }.buttonStyle(.plain).help("New Notebook")
        case "git":
            Button(action: { selectedActivityItem = "git"; NotificationCenter.default.post(name: .kyozoGitRefresh, object: nil) }) { Image(systemName: "arrow.clockwise").font(.system(size: 16, weight: .medium)).foregroundStyle(.secondary) }.buttonStyle(.plain).help("Sync Repository")
        default:
            EmptyView()
        }

        Button(action: { withAnimation(.easeInOut(duration: 0.3)) { isPanelVisible.toggle() } }) {
            Image(systemName: isPanelVisible ? "rectangle.split.3x1.fill" : "rectangle.split.3x1").font(.system(size: 16, weight: .medium)).foregroundStyle(.secondary)
        }.buttonStyle(.plain).keyboardShortcut("j", modifiers: .command)
    }

    @ViewBuilder private var globalMenuItems: some View {
        Section("File") {
            Button("New Notebook", systemImage: "doc.badge.plus") { createNewNotebook() }.keyboardShortcut("n", modifiers: .command)
//            Button("Open Workspace", systemImage: "folder.badge.plus") { openWorkspace() }.keyboardShortcut("o", modifiers: .command)
//            if activeNotebook != nil { Button("Close Notebook", systemImage: "xmark") { closeActiveNotebook() }.keyboardShortcut("w", modifiers: .command) }
        }
        Section("View") {
            Button(isSidebarVisible ? "Hide Sidebar" : "Show Sidebar", systemImage: "sidebar.left") { withAnimation(.easeInOut(duration: 0.3)) { isSidebarVisible.toggle() } }.keyboardShortcut("s", modifiers: [.command, .control])
            Button(isPanelVisible ? "Hide Panel" : "Show Panel", systemImage: "rectangle.split.3x1") { withAnimation(.easeInOut(duration: 0.3)) { isPanelVisible.toggle() } }.keyboardShortcut("j", modifiers: .command)
            Button("Toggle Search", systemImage: "magnifyingglass") { withAnimation(.easeInOut(duration: 0.2)) { showingSearch.toggle() } }.keyboardShortcut("f", modifiers: .command)
        }
        Section("Interface") {
            Menu("Interface Style") {
                Button("Modern") { settings.interfaceStyle = "modern" }
                Button("Enhanced") { settings.interfaceStyle = "enhanced" }
                Button("Classic") { settings.interfaceStyle = "classic" }
            }
            Button("Settings", systemImage: "gearshape") { selectedActivityItem = "settings" }.keyboardShortcut(",", modifiers: .command)
        }
        Section("Help") {
            Button("Welcome", systemImage: "hand.wave") { NotificationCenter.default.post(name: .kyozoShowWelcome, object: nil) }
            Button("Keyboard Shortcuts", systemImage: "keyboard") { NotificationCenter.default.post(name: .kyozoShowShortcuts, object: nil) }
            Button("About Kyozo", systemImage: "info.circle") { NotificationCenter.default.post(name: .kyozoShowAbout, object: nil) }
        }
    }

    private func loadNotebooks() async {
        let loaded = await store.load()
        await MainActor.run { self.notebooks = loaded; if self.activeNotebook == nil { self.activeNotebook = self.notebooks.first?.id } }
    }

    private func createNewNotebook() {
        let newNotebook = Notebook(name: "Untitled Notebook", cells: [NotebookCell(kind: .markup, value: "# New Notebook\n\nStart writing your content here..."), NotebookCell(kind: .code, role: .user, languageId: "javascript", value: "// Your code here")])
        notebooks.append(newNotebook); activeNotebook = newNotebook.id; Task { await store.save(notebooks) }
    }

//    private func openWorkspace() { #if os(iOS) showWorkspacePicker = true #endif }
    private func closeNotebook(_ id: Notebook.ID) { notebooks.removeAll { $0.id == id }; if activeNotebook == id { activeNotebook = notebooks.first?.id }; Task { await store.save(notebooks) } }
    private func closeActiveNotebook() { if let id = activeNotebook { closeNotebook(id) } }

    #if os(iOS)
    func workspacePickerSheet() -> some View {
        EmptyView().sheet(isPresented: $showWorkspacePicker) { FolderPicker { url in showWorkspacePicker = false; guard let url else { return }; NotificationCenter.default.post(name: .kyozoWorkspaceOpened, object: nil, userInfo: ["url": url]) } }
    }
    #endif
}

