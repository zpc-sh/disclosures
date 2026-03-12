//
//  ExplorerView.swift
//  Kyozo
//
//  Main view combining all Explorer components
//  Provides VS Code-like interface with responsive design (renamed from CodeApp)
//

import SwiftUI

struct ExplorerView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var settings: SettingsState
    @EnvironmentObject private var settingsManager: SettingsManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @SceneStorage("selectedActivityItem") private var selectedActivityItem: String = "explorer"
    @SceneStorage("sidebarVisible") private var isSidebarVisible: Bool = true
    // Use a new key to reset default to hidden, avoiding stale values
    @SceneStorage("panelVisibleV2") private var isPanelVisible: Bool = false
    @SceneStorage("sidebarWidth") private var sidebarWidth: Double = 300
    
    @State private var notebooks: [Notebook] = []
    @State private var activeNotebook: Notebook.ID? = nil
    @State private var cellSelection: UUID? = nil
    @StateObject private var workspaceStore = EnhancedWorkspaceStore(apiClient: EnhancedKyozoAPIClient())
    @StateObject private var iCloud = iCloudSyncManager()
    @StateObject private var serverHolder = ServerHolder()
    @StateObject private var fsManagerHolder = FSHolder()
    @StateObject private var s3 = S3SyncService()
    @State private var workspaceURL: URL? = nil
    @State private var selectedFileURL: URL? = nil
    @State private var fileMap: [UUID: URL] = [:]
    // Debug counters for PM event flow
    @State private var pmStateEvents: Int = 0
    @State private var pmMarkdownEvents: Int = 0
    // Dev controls to ensure a working path quickly
    @State private var forceWebEditor: Bool = true
    @State private var webMarkdown: String = ""
    
    @State private var showWelcome = false
    @State private var showShortcuts = false
    @State private var showAbout = false
    
    private let store = NotebookStore()
    // Base layout composing sidebar, editor, optional bottom panel, and status bar
    private var baseLayout: some View {
        VStack(spacing: 0) {
            // Main content area with optional sidebar
            HStack(spacing: 0) {
                if isSidebarVisible {
                    sidebarContent
                        .frame(width: sidebarWidth)
                        .frame(maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }

                if isSidebarVisible {
                    Divider()
                }

                // Editor / main content
                editorContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Optional bottom panel (e.g., terminal/output)
            if isPanelVisible {
                Divider()
                bottomPanel
                    .frame(height: 260)
            }

            // Status bar at the very bottom
            Divider()
            statusBar
        }
    }
    
    var body: some View {
        applyRootModifiers(to: AnyView(baseLayout))
    }
    
    @ViewBuilder
    private func applyRootModifiers(to view: AnyView) -> some View {
        view
            .task {
                await loadNotebooks()
                await workspaceStore.loadWorkspaces()
                if notebooks.isEmpty {
                    createNewNotebook()
                } else if activeNotebook == nil {
                    activeNotebook = notebooks.first?.id
                }
                if let id = activeNotebook, let idx = notebooks.firstIndex(where: { $0.id == id }) {
                    webMarkdown = MarkdownLPParser.toMarkdown(notebooks[idx].cells)
                }
            }
            .erased()
            .onChange(of: activeNotebook) { _, newValue in
                if let id = newValue, let idx = notebooks.firstIndex(where: { $0.id == id }) {
                    webMarkdown = MarkdownLPParser.toMarkdown(notebooks[idx].cells)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .kyozoOpenFileURL)) { notif in
                guard let url = notif.userInfo?["url"] as? URL else { return }
                handleOpenFile(url)
            }
            .onReceive(NotificationCenter.default.publisher(for: .pmMarkdownChanged)) { notif in
                guard let md = notif.userInfo?["markdown"] as? String else { return }
                pmMarkdownEvents += 1
                // Update the first markup cell in the active notebook to keep model in sync
                if let activeNotebook = activeNotebook, let idx = notebooks.firstIndex(where: { $0.id == activeNotebook }) {
                    if let cellIdx = notebooks[idx].cells.firstIndex(where: { $0.kind == .markup }) {
                        notebooks[idx].cells[cellIdx].value = md
                    } else if !notebooks[idx].cells.isEmpty {
                        notebooks[idx].cells[0].value = md
                    } else {
                        notebooks[idx].cells.append(NotebookCell(kind: .markup, value: md))
                    }
                    Task { await store.save(notebooks) }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .pmStateUpdated)) { _ in
                pmStateEvents += 1
            }
            .onReceive(NotificationCenter.default.publisher(for: .kyozoSelectFileURL)) { notif in
                if let url = notif.userInfo?["url"] as? URL { selectedFileURL = url; activeNotebook = nil }
            }
            .onReceive(NotificationCenter.default.publisher(for: .kyozoSelectNotebook)) { notif in
                if let id = notif.userInfo?["id"] as? UUID {
                    activeNotebook = id
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .kyozoCreateNotebook)) { _ in
                createNewNotebook()
            }
            .onReceive(NotificationCenter.default.publisher(for: .kyozoRefreshFiles)) { _ in
                if let url = workspaceURL {
                    Task { @MainActor in
                        try? await fsManager.scanDirectory(url)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .kyozoRenameNotebook)) { notif in
                guard let id = notif.userInfo?["id"] as? UUID, let name = notif.userInfo?["name"] as? String else { return }
                if let idx = notebooks.firstIndex(where: { $0.id == id }) {
                    notebooks[idx].name = name
                    Task { await store.save(notebooks) }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .kyozoDeleteNotebook)) { notif in
                guard let id = notif.userInfo?["id"] as? UUID else { return }
                notebooks.removeAll { $0.id == id }
                if activeNotebook == id { activeNotebook = notebooks.first?.id }
                Task { await store.save(notebooks) }
            }
            .erased()
            // Global modal listeners
            .onReceive(NotificationCenter.default.publisher(for: .kyozoShowWelcome)) { _ in showWelcome = true }
            .onReceive(NotificationCenter.default.publisher(for: .kyozoShowShortcuts)) { _ in showShortcuts = true }
            .onReceive(NotificationCenter.default.publisher(for: .kyozoShowAbout)) { _ in showAbout = true }
            // Global sheets
            .sheet(isPresented: $showWelcome) { WelcomeModal() }
            .sheet(isPresented: $showShortcuts) { ShortcutsModal() }
            .sheet(isPresented: $showAbout) { AboutModal() }
            .onReceive(NotificationCenter.default.publisher(for: .kyozoWorkspaceOpened)) { notif in
                guard let url = notif.userInfo?["url"] as? URL else { return }
                workspaceURL = url
                Task { @MainActor in
                    // Configure S3 from settings when needed
                    if settings.workspaceSyncProvider == "s3" {
                        s3.configure(accessKey: settings.s3AccessKey, secretKey: settings.s3SecretKey, region: settings.s3Region, bucket: settings.s3Bucket, endpoint: settings.s3Endpoint)
                        await s3.syncFolder(url)
                    } else if settings.workspaceSyncProvider == "server" {
                        try? await fsManager.scanDirectory(url)
                        await fsManager.syncAllData()
                    } else if settings.workspaceSyncProvider == "icloud" {
                        await iCloud.syncFolder(at: url)
                    }
                }
            }
    }
    
    @ViewBuilder
    private var sidebarContent: some View {
        #if os(iOS)
        // On iOS, always use the compact sidebar (regular variant is macOS-only)
        ExplorerCompactSidebar()
        #else
        ExplorerRegularSidebar()
        #endif
    }
    
    private var editorContent: some View {
        Group {
            if let activeNotebook = activeNotebook,
               let notebookIndex = notebooks.firstIndex(where: { $0.id == activeNotebook }) {
                
                // Main Editor View
                VStack(spacing: 0) {
                    // Editor Header (optional breadcrumb/file info)
                    editorHeader(for: notebooks[notebookIndex])
                    
                    // Editor Content
                    if forceWebEditor {
                        ProseMirrorEditorView(
                            markdown: $webMarkdown,
                            onChange: { md in
                                if let ni = notebooks.firstIndex(where: { $0.id == activeNotebook }) {
                                    if let ci = notebooks[ni].cells.firstIndex(where: { $0.kind == .markup }) {
                                        notebooks[ni].cells[ci].value = md
                                    } else if !notebooks[ni].cells.isEmpty {
                                        notebooks[ni].cells[0].value = md
                                    } else {
                                        notebooks[ni].cells.append(NotebookCell(kind: .markup, value: md))
                                    }
                                    Task { await store.save(notebooks) }
                                }
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if settingsManager.useLegacyTextRenderer {
                        LegacyEditorPlaceholderView(
                            notebook: $notebooks[notebookIndex],
                            selection: $cellSelection
                        )
                    } else if settings.useEnhancedUI ?? true {
                        // Use enhanced Metal editor for performance
                        ZStack(alignment: .top) {
                            EnhancedMetalEditor(
                                notebook: $notebooks[notebookIndex],
                                selection: $cellSelection
                            )
                            if settings.enableProseMirrorEditor {
                                RichTextToolbar(
                                    onBold: { EditorCommandCenter.post(.pmToggleBold) },
                                    onItalic: { EditorCommandCenter.post(.pmToggleItalic) },
                                    onH1: { EditorCommandCenter.post(.pmToggleH1) },
                                    onH2: { EditorCommandCenter.post(.pmToggleH2) },
                                    onCode: { EditorCommandCenter.post(.pmToggleCodeBlock) },
                                    onBulletList: { EditorCommandCenter.post(.pmToggleBulletList) },
                                    onOrderedList: { EditorCommandCenter.post(.pmToggleOrderedList) },
                                    onQuote: { EditorCommandCenter.post(.pmToggleBlockquote) },
                                    onLink: { NotificationCenter.default.post(name: .pmInsertLink, object: nil, userInfo: ["href":"https://example.com","title":"example"]) },
                                    onImage: { NotificationCenter.default.post(name: .pmInsertImage, object: nil, userInfo: ["src":"https://picsum.photos/200","alt":"image"]) },
                                    onTable: { NotificationCenter.default.post(name: .pmInsertTable, object: nil, userInfo: ["rows":3,"cols":3]) },
                                    onUndo: { EditorCommandCenter.post(.pmUndo) },
                                    onRedo: { EditorCommandCenter.post(.pmRedo) }
                                )
                                .padding(.top, 8)
                                .padding(.leading, 8)
                                .zIndex(1000)
                                .allowsHitTesting(true)
                                .contentShape(Rectangle())
                            }
                            // Debug overlay chip (top-right)
                            VStack(alignment: .trailing, spacing: 4) {
                                HStack(spacing: 6) {
                                    Circle().fill(settings.enableProseMirrorEditor ? .green : .red).frame(width: 6, height: 6)
                                    Text("PM \(settings.enableProseMirrorEditor ? "on" : "off")").font(.caption2)
                                }
                                HStack(spacing: 6) {
                                    Circle().fill(settings.enableMarkdownMetalEditor ? .green : .red).frame(width: 6, height: 6)
                                    Text("MetalMD \(settings.enableMarkdownMetalEditor ? "on" : "off")").font(.caption2)
                                }
                                Text("state: \(pmStateEvents)").font(.caption2)
                                Text("md: \(pmMarkdownEvents)").font(.caption2)
                                if activeNotebook != nil {
                                    Text("notebook ✓").font(.caption2)
                                } else {
                                    Text("no notebook").font(.caption2)
                                }
                                Toggle(isOn: $forceWebEditor) { Text("Web editor") }
                                    .font(.caption2)
                                    .toggleStyle(.switch)
                            }
                            .padding(8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .padding([.top, .trailing], 8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .zIndex(1001)
                        }
                        .overlay(alignment: .topTrailing) {
                            if settingsManager.showPerformanceOverlay {
                                KyozoPerformanceIndicator(fps: 120, memoryUsage: 15, gpuUsage: 20)
                                    .padding(8)
                            }
                        }
                    } else {
                        // Fallback to regular outline view
                        NotebookOutlineView(
                            notebook: $notebooks[notebookIndex],
                            selection: $cellSelection
                        )
                    }
                }
                
            } else if let url = selectedFileURL {
                FilePreviewPane(url: url)
            } else {
                welcomeView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func editorHeader(for notebook: Notebook) -> some View {
        HStack {
            // File Path/Breadcrumb
            HStack(spacing: 4) {
                Image(systemName: "book.closed")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Text(notebook.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Experimental pipeline badge
            if settings.enableMarkdownMetalEditor {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill").font(.system(size: 10, weight: .semibold))
                    Text("Markdown+Metal")
                        .font(.caption2).fontWeight(.semibold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.12), in: Capsule())
                .foregroundStyle(.blue)
                .help("Experimental Markdown + Metal pipeline")
            }

            // Workspace indicators + actions
            if let wurl = workspaceURL {
                HStack(spacing: 10) {
                    // Git repo indicator
                    if FileManager.default.fileExists(atPath: wurl.appendingPathComponent(".git").path) {
                        Image(systemName: "point.3.connected.trianglepath.dotted").foregroundStyle(.secondary).help("Git Repository")
                    }
                    // Sync provider indicator
                    Group {
                        switch settings.workspaceSyncProvider {
                        case "icloud": Image(systemName: "icloud").foregroundStyle(.secondary).help("iCloud Sync")
                        case "server": Image(systemName: "server.rack").foregroundStyle(.secondary).help("Server Sync")
                        case "s3": Image(systemName: "externaldrive.connected.to.line.below").foregroundStyle(.secondary).help("S3 Sync")
                        default: EmptyView()
                        }
                    }
                    // Sync Now
                    Button {
                        Task { await syncNow() }
                    } label: {
                        Image(systemName: "arrow.clockwise").font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .help("Sync Now")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial.opacity(0.5), in: Rectangle())
    }

    private func syncNow() async {
        guard let url = workspaceURL else { return }
        switch settings.workspaceSyncProvider {
        case "icloud":
            await iCloud.syncFolder(at: url)
        case "server":
            try? await fsManager.scanDirectory(url)
            await fsManager.syncAllData()
        case "s3":
            s3.configure(accessKey: settings.s3AccessKey, secretKey: settings.s3SecretKey, region: settings.s3Region, bucket: settings.s3Bucket, endpoint: settings.s3Endpoint)
            await s3.syncFolder(url)
        default:
            break
        }
    }
    
    private var welcomeView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                // Kyozo Logo
                RoundedRectangle(cornerRadius: 16)
                    .fill(.blue.gradient)
                    .frame(width: 80, height: 80)
                    .overlay {
                        Text("K")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.white)
                    }
                
                VStack(spacing: 8) {
                    Text("Welcome to Kyozo Explorer")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("High-performance collaborative notebook environment with Explorer interface")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Quick Actions
            VStack(spacing: 12) {
                WelcomeActionCard(
                    icon: "doc.badge.plus",
                    iconColor: .blue,
                    title: "Create New Notebook",
                    subtitle: "Start with a blank notebook or choose from templates",
                    action: createNewNotebook
                )
                
                WelcomeActionCard(
                    icon: "folder.badge.plus",
                    iconColor: .green,
                    title: "Open Workspace",
                    subtitle: "Open an existing workspace or project folder",
                    action: openWorkspace
                )
                
                WelcomeActionCard(
                    icon: "icloud.and.arrow.down",
                    iconColor: .purple,
                    title: "Clone from Repository",
                    subtitle: "Clone a Git repository to start collaborating",
                    action: cloneRepository
                )
            }
            .frame(maxWidth: 400)
            
            // Recent Files
            if !notebooks.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    
                    VStack(spacing: 8) {
                        ForEach(notebooks.prefix(5)) { notebook in
                            WelcomeRecentItem(
                                icon: "doc.text",
                                title: notebook.name,
                                subtitle: "\(notebook.cells.count) cells",
                                action: {
                                    activeNotebook = notebook.id
                                }
                            )
                        }
                    }
                }
                .frame(maxWidth: 400)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var bottomPanel: some View {
        VStack(spacing: 0) {
            // Use the integrated TerminalPanelView
            // TerminalView()
            //     .frame(height: 250)
            
            // Close button overlay
            HStack {
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPanelVisible = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(8)
            }
            .background(.regularMaterial.opacity(0.3))
        }
    }
    
    
    private var statusBar: some View {
        HStack {
            // Left Status Items
            HStack(spacing: 16) {
                // Git Status
                if let activeNotebook = activeNotebook {
                    HStack(spacing: 4) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("main")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Problems
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.orange)
                    Text("0")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Right Status Items
            HStack(spacing: 16) {
                // Sync Provider Indicator (configurable)
                if settings.showSyncIndicator, let url = workspaceURL {
                    HStack(spacing: 6) {
                        Group {
                            switch settings.workspaceSyncProvider {
                            case "icloud": Image(systemName: "icloud").foregroundStyle(.secondary)
                            case "server": Image(systemName: "server.rack").foregroundStyle(.secondary)
                            case "s3": Image(systemName: "externaldrive.connected.to.line.below").foregroundStyle(.secondary)
                            default: EmptyView()
                            }
                        }
                        // Tiny spinner when progress is in-flight
                        if isSyncing() {
                            ProgressView().progressViewStyle(.circular)
                                .scaleEffect(0.6)
                        }
                        if settings.showSyncPercent {
                            Text(syncPercentString())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .help(syncProviderHelp(url: url))
                }
                // Line/Column Info
                if activeNotebook != nil {
                    Text("Ln 1, Col 1")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Language Mode
                if activeNotebook != nil {
                    Text("Markdown")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Performance Indicator
                HStack(spacing: 4) {
                    Text("⚡")
                        .font(.caption)
                    Text("120 FPS")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.regularMaterial.opacity(0.8), in: Rectangle())
    }

    private func syncPercentString() -> String {
        switch settings.workspaceSyncProvider {
        case "icloud":
            let pct = Int((iCloud.syncProgress * 100).rounded())
            return "\(pct)%"
        case "server":
            let pct = Int((fsManager.syncProgress * 100).rounded())
            return "\(pct)%"
        case "s3":
            let pct = Int((s3.progress * 100).rounded())
            return "\(pct)%"
        default:
            return ""
        }
    }

    private func isSyncing() -> Bool {
        switch settings.workspaceSyncProvider {
        case "icloud":
            return iCloud.globalSyncStatus == .downloading || iCloud.globalSyncStatus == .uploading || (iCloud.syncProgress > 0 && iCloud.syncProgress < 1)
        case "server":
            return fsManager.isAutoSyncing || (fsManager.syncProgress > 0 && fsManager.syncProgress < 1)
        case "s3":
            return s3.progress > 0 && s3.progress < 1
        default:
            return false
        }
    }

    private func syncProviderHelp(url: URL) -> String {
        switch settings.workspaceSyncProvider {
        case "icloud": return "iCloud syncing: \(url.lastPathComponent)"
        case "server": return "Server: \(settings.apiBaseURL)"
        case "s3": return "S3 bucket: \(settings.s3Bucket)"
        default: return ""
        }
    }
    
    // MARK: - Actions
    
    private func loadNotebooks() async {
        let loaded = await store.load()
        await MainActor.run {
            if loaded.isEmpty {
                self.notebooks = [
                    Notebook(name: "Welcome Notebook", cells: [
                        NotebookCell(kind: .markup, value: "# Welcome to Kyozo Explorer\n\nThis is your notebook with the Explorer interface featuring:\n\n- VS Code-like sidebar navigation\n- Resizable panels and sidebar\n- High-performance Metal rendering at 120fps\n- Collaborative editing capabilities\n\nStart creating amazing content!"),
                        NotebookCell(kind: .code, role: .user, languageId: "javascript", value: "// Welcome to the enhanced Kyozo Explorer experience!\nconsole.log('Hello, Explorer-style Kyozo!');\n\n// Try executing this cell\nconst greeting = 'Welcome to high-performance notebook editing!';\nconsole.log(greeting);")
                    ])
                ]
            } else {
                self.notebooks = loaded
            }
            
            if self.activeNotebook == nil {
                self.activeNotebook = self.notebooks.first?.id
            }
        }
    }

    private func handleOpenFile(_ url: URL) {
        let ext = url.pathExtension.lowercased()
        if ext == "md" || ext == "markdown" {
            if let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) {
                let nb = Notebook(name: url.deletingPathExtension().lastPathComponent, cells: [NotebookCell(kind: .markup, value: text)])
                notebooks.append(nb)
                activeNotebook = nb.id
                fileMap[nb.id] = url
                Task { await store.save(notebooks) }
            }
        }
    }
    
    private func createNewNotebook() {
        let newNotebook = Notebook(
            name: "Untitled Notebook",
            cells: [
                NotebookCell(kind: .markup, value: "# New Notebook\n\nStart writing your content here..."),
                NotebookCell(kind: .code, role: .user, languageId: "javascript", value: "// Your code here\nconsole.log('Hello, world!');")
            ]
        )
        notebooks.append(newNotebook)
        activeNotebook = newNotebook.id
        Task { await store.save(notebooks) }
    }
    
    private func openWorkspace() {
        // TODO: Implement workspace opening
    }
    
    private func cloneRepository() {
        // TODO: Implement repository cloning
    }
}

// Local holder to lazily construct FileSystemDataManager with environment services
private final class FSHolder: ObservableObject {
    @Published var manager: FileSystemDataManager?
}

extension ExplorerView {
    private var fsManager: FileSystemDataManager {
        if let m = fsManagerHolder.manager { return m }
        let m = FileSystemDataManager(iCloudManager: iCloud, serverSyncCoordinator: serverSync)
        fsManagerHolder.manager = m
        return m
    }
}

// Hold ServerSyncCoordinator and build from settings on demand
private final class ServerHolder: ObservableObject { @Published var coordinator: ServerSyncCoordinator? }

extension ExplorerView {
    private var serverSync: ServerSyncCoordinator {
        if let c = serverHolder.coordinator { return c }
        // Build from settings.apiBaseURL
        let baseURL = URL(string: settings.apiBaseURL) ?? URL(string: "http://localhost:4000")!
        let cfg = ServerSyncCoordinator.EndpointConfig(
            health: settings.serverHealthPath,
            sync: settings.serverSyncPath,
            filesList: settings.serverFilesListPath,
            s3Presign: settings.serverS3PresignPath
        )
        let c = ServerSyncCoordinator(baseURL: baseURL, authService: AuthService.shared, endpoints: cfg)
        serverHolder.coordinator = c
        return c
    }
}

private extension View {
    func erased() -> AnyView { AnyView(self) }
}

#Preview {
    ExplorerView()
        .environmentObject(AppState())
        .environmentObject(SettingsState())
        .environmentObject(SettingsManager())
        .frame(width: 1200, height: 800)
}

