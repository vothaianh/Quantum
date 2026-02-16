import Foundation
import AppKit
import CoreServices

extension Notification.Name {
    static let fileSaved = Notification.Name("fileSaved")
}

@Observable
final class AppState {
    var rootFileItem: FileItem?
    var openEditorTabs: [EditorTab] = []
    var selectedEditorTabID: UUID?
    var terminalTabs: [TerminalTab] = []
    var selectedTerminalTabID: UUID?
    var showSidebar: Bool = true
    var showTerminal: Bool = true
    var projectURL: URL?
    var zoomLevel: Double = 1.0
    var sidebarTab: SidebarTab = .files
    var expandedFolders: Set<String> = []
    var searchQuery: String = ""
    var searchResults: [SearchResult] = []
    var isSearching: Bool = false
    var gitRepos: [GitRepoStatus] = []
    var gitBranch: String = ""
    var isLoadingGit: Bool = false
    var commitMessage: String = ""
    var isGeneratingCommitMsg: Bool = false
    var isCommitting: Bool = false
    var isPushing: Bool = false
    var isPulling: Bool = false
    var commitError: String?
    var showGitErrorPopup: Bool = false
    var gitErrorDetail: String = ""
    var gitCommits: [GitCommitLog] = []
    var isLoadingGitLog: Bool = false
    var activeGitRoot: URL?
    var activeGitBranch: String = ""
    var unpulledCommits: [GitCommitLog] = []

    // MARK: - File System Watcher

    private var fsEventStream: FSEventStreamRef?
    private var fileTreeRefreshWork: DispatchWorkItem?

    func startFileWatcher() {
        stopFileWatcher()
        guard let projectURL else { return }
        let path = projectURL.path as CFString
        let paths = [path] as CFArray

        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let state = Unmanaged<AppState>.fromOpaque(info).takeUnretainedValue()
            DispatchQueue.main.async { state.scheduleFileTreeRefresh() }
        }

        let stream = FSEventStreamCreate(
            nil, callback, &context, paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,  // 1 second latency to batch events
            UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        )

        if let stream {
            FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            FSEventStreamStart(stream)
            fsEventStream = stream
        }
    }

    func stopFileWatcher() {
        if let stream = fsEventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            fsEventStream = nil
        }
        fileTreeRefreshWork?.cancel()
    }

    private func scheduleFileTreeRefresh() {
        fileTreeRefreshWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.refreshFileTree()
        }
        fileTreeRefreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func refreshFileTree() {
        guard let projectURL else { return }
        Task.detached {
            let root = FileService.loadDirectory(at: projectURL)
            await MainActor.run {
                self.rootFileItem = root
            }
        }
    }

    // MARK: - File Save Observer

    private var gitRefreshTimer: Timer?
    private var gitFetchTimer: Timer?

    func startObservingFileSaves() {
        NotificationCenter.default.addObserver(
            forName: .fileSaved, object: nil, queue: .main
        ) { [weak self] _ in
            self?.scheduleGitRefresh()
        }
    }

    func startAutoFetch() {
        gitFetchTimer?.invalidate()
        gitFetchTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.backgroundFetch()
        }
        // Initial fetch after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.backgroundFetch()
        }
    }

    func stopAutoFetch() {
        gitFetchTimer?.invalidate()
        gitFetchTimer = nil
    }

    private func backgroundFetch() {
        let root = activeGitRoot ?? projectURL
        guard let root else { return }
        Task.detached {
            GitService.fetch(at: root)
            let unpulled = GitService.unpulledCommits(at: root)
            await MainActor.run {
                self.unpulledCommits = unpulled
            }
        }
    }

    private func scheduleGitRefresh() {
        guard sidebarTab == .git else { return }
        gitRefreshTimer?.invalidate()
        gitRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.refreshGit()
        }
    }

    // MARK: - Search

    func performSearch() {
        guard !searchQuery.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        // Search whatever is indexed so far — synchronous, Data.range(of:) is C-fast
        let files = SearchIndex.shared.getFiles()
        searchResults = SearchService.search(query: searchQuery, files: files)
        isSearching = false
    }

    // MARK: - Git

    func refreshGit() {
        guard let projectURL else { return }
        isLoadingGit = true
        let root = projectURL
        Task.detached {
            let repos = GitService.statusAllRepos(at: root)
            let branch = repos.first?.branch ?? GitService.currentBranch(at: root)
            await MainActor.run {
                self.gitRepos = repos
                self.gitBranch = branch
                self.isLoadingGit = false
            }
        }
        refreshGitLog()
    }

    func refreshGitLog() {
        let root = activeGitRoot ?? projectURL
        guard let root else { return }
        isLoadingGitLog = true
        Task.detached {
            let commits = GitService.log(at: root, count: 50)
            let unpulled = GitService.unpulledCommits(at: root)
            await MainActor.run {
                self.gitCommits = commits
                self.unpulledCommits = unpulled
                self.isLoadingGitLog = false
            }
        }
    }

    func updateActiveGitContext() {
        guard let fileURL = selectedFile?.url else {
            // No file open — fall back to project root
            activeGitRoot = projectURL.flatMap { GitService.findGitRoot(from: $0) }
            activeGitBranch = gitBranch
            refreshGitLog()
            return
        }
        let dir = fileURL.deletingLastPathComponent()
        Task.detached {
            let root = GitService.findGitRoot(from: dir)
            let branch = root.map { GitService.currentBranch(at: $0) } ?? ""
            await MainActor.run {
                let changed = self.activeGitRoot?.path != root?.path
                self.activeGitRoot = root
                self.activeGitBranch = branch
                self.gitBranch = branch
                if changed {
                    self.refreshGitLog()
                }
            }
        }
    }

    func refreshGitBranchForCurrentFile() {
        guard let fileURL = selectedFile?.url else {
            gitBranch = ""
            return
        }
        let dir = fileURL.deletingLastPathComponent()
        Task.detached {
            let root = GitService.findGitRoot(from: dir)
            let branch = root.map { GitService.currentBranch(at: $0) } ?? ""
            await MainActor.run {
                self.gitBranch = branch
                let changed = self.activeGitRoot?.path != root?.path
                self.activeGitRoot = root
                self.activeGitBranch = branch
                if changed {
                    self.refreshGitLog()
                }
            }
        }
    }

    func generateCommitMessage() {
        guard !gitRepos.isEmpty else { return }
        let modelID = AppSettings.shared.resolvedModelID
        guard !modelID.isEmpty else {
            commitError = "No AI model configured. Add an API key in Settings."
            return
        }
        isGeneratingCommitMsg = true
        commitError = nil
        let roots = gitRepos.map(\.gitRoot)
        Task.detached {
            do {
                var allDiffs = ""
                for root in roots {
                    let diff = GitService.diff(at: root)
                    if !diff.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        allDiffs += "[\(root.lastPathComponent)]\n\(diff)\n"
                    }
                }
                guard !allDiffs.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    await MainActor.run {
                        self.commitError = "No changes to describe"
                        self.isGeneratingCommitMsg = false
                    }
                    return
                }
                let message = try await AIService.generateCommitMessage(diff: allDiffs, modelID: modelID)
                await MainActor.run {
                    self.commitMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.isGeneratingCommitMsg = false
                }
            } catch {
                await MainActor.run {
                    self.commitError = error.localizedDescription
                    self.isGeneratingCommitMsg = false
                }
            }
        }
    }

    func commitChanges() {
        guard !gitRepos.isEmpty else { return }
        let message = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else {
            commitError = "Commit message cannot be empty"
            return
        }
        isCommitting = true
        commitError = nil
        let roots = gitRepos.map(\.gitRoot)
        Task.detached {
            var allSuccess = true
            var allOutput = ""
            for root in roots {
                let result = GitService.commitAll(message: message, at: root)
                if !result.success {
                    allSuccess = false
                    if !result.output.isEmpty {
                        allOutput += "[\(root.lastPathComponent)] \(result.output)\n"
                    }
                }
            }
            // Push after successful commit
            if allSuccess {
                await MainActor.run {
                    self.isCommitting = false
                    self.isPushing = true
                }
                for root in roots {
                    let pushResult = GitService.push(at: root)
                    if !pushResult.success {
                        allSuccess = false
                        if !pushResult.output.isEmpty {
                            allOutput += "[\(root.lastPathComponent)] Push: \(pushResult.output)\n"
                        }
                    }
                }
            }
            await MainActor.run {
                self.isCommitting = false
                self.isPushing = false
                if allSuccess {
                    self.commitMessage = ""
                    self.commitError = nil
                    self.refreshGit()
                } else {
                    let detail = allOutput.isEmpty ? "Failed" : allOutput
                    self.commitError = detail.components(separatedBy: "\n").first ?? "Failed"
                    self.gitErrorDetail = detail
                    self.showGitErrorPopup = true
                }
            }
        }
    }

    func discardFile(_ file: GitFileStatus) {
        guard let repo = gitRepos.first(where: { repo in
            repo.files.contains(where: { $0.id == file.id })
        }) else { return }
        let root = repo.gitRoot
        let fileURL = file.fullURL
        Task.detached {
            GitService.discardFile(file, at: root)
            await MainActor.run {
                self.reloadOpenTab(for: fileURL)
                self.refreshGit()
            }
        }
    }

    func discardAllChanges() {
        let roots = gitRepos.map(\.gitRoot)
        let affectedURLs = gitRepos.flatMap { $0.files.map(\.fullURL) }
        Task.detached {
            for root in roots {
                GitService.discardAll(at: root)
            }
            await MainActor.run {
                for url in affectedURLs {
                    self.reloadOpenTab(for: url)
                }
                self.refreshGit()
            }
        }
    }

    private func reloadOpenTab(for fileURL: URL) {
        for i in openEditorTabs.indices {
            guard openEditorTabs[i].file.url == fileURL else { continue }
            let freshContent = FileService.readFile(at: fileURL)
            if openEditorTabs[i].isDiff {
                // Close diff tab — file is restored, diff no longer relevant
                let tabID = openEditorTabs[i].id
                openEditorTabs.remove(at: i)
                if selectedEditorTabID == tabID {
                    selectedEditorTabID = openEditorTabs.last?.id
                }
            } else {
                openEditorTabs[i].content = freshContent
                openEditorTabs[i].isModified = false
            }
            return
        }
    }

    func pushChanges() {
        let root = activeGitRoot ?? gitRepos.first?.gitRoot
        guard let root else { return }
        isPushing = true
        commitError = nil
        Task.detached {
            let result = GitService.push(at: root)
            await MainActor.run {
                self.isPushing = false
                if result.success {
                    self.commitError = nil
                    self.refreshGitLog()
                } else {
                    self.commitError = "Push failed"
                    self.gitErrorDetail = result.output.isEmpty ? "Push failed" : result.output
                    self.showGitErrorPopup = true
                }
            }
        }
    }

    func pullChanges() {
        let root = activeGitRoot ?? gitRepos.first?.gitRoot
        guard let root else { return }
        isPulling = true
        commitError = nil
        Task.detached {
            let result = GitService.pull(at: root)
            await MainActor.run {
                self.isPulling = false
                if result.success {
                    self.commitError = nil
                    self.refreshGit()
                } else {
                    self.commitError = "Pull failed"
                    self.gitErrorDetail = result.output.isEmpty ? "Pull failed" : result.output
                    self.showGitErrorPopup = true
                }
            }
        }
    }

    private static let zoomKey = "zoomLevel"
    private static let zoomStep = 0.1
    private static let zoomMin = 0.5
    private static let zoomMax = 2.0

    func zoomIn() {
        zoomLevel = min(zoomLevel + Self.zoomStep, Self.zoomMax)
        UserDefaults.standard.set(zoomLevel, forKey: Self.zoomKey)
    }

    func zoomOut() {
        zoomLevel = max(zoomLevel - Self.zoomStep, Self.zoomMin)
        UserDefaults.standard.set(zoomLevel, forKey: Self.zoomKey)
    }

    func zoomReset() {
        zoomLevel = 1.0
        UserDefaults.standard.set(zoomLevel, forKey: Self.zoomKey)
    }

    func loadZoom() {
        let saved = UserDefaults.standard.double(forKey: Self.zoomKey)
        if saved >= Self.zoomMin && saved <= Self.zoomMax {
            zoomLevel = saved
        }
    }

    // MARK: - Editor Tabs

    var selectedEditorTab: EditorTab? {
        guard let id = selectedEditorTabID else { return openEditorTabs.first }
        return openEditorTabs.first { $0.id == id }
    }

    var selectedFile: FileItem? { selectedEditorTab?.file }
    var fileContent: String { selectedEditorTab?.content ?? "" }

    func openFile(_ file: FileItem) {
        // If already open, just select it
        if let existing = openEditorTabs.first(where: { $0.file.url == file.url }) {
            selectedEditorTabID = existing.id
            refreshGitBranchForCurrentFile()
            saveSession()
            return
        }
        let content = FileService.readFile(at: file.url)
        let tab = EditorTab(file: file, content: content)
        openEditorTabs.append(tab)
        selectedEditorTabID = tab.id
        refreshGitBranchForCurrentFile()
        saveSession()
    }

    func openFileAtLine(_ file: FileItem, line: Int, query: String?) {
        // If already open, select it and set pending go-to
        if let idx = openEditorTabs.firstIndex(where: { $0.file.url == file.url && !$0.isDiff }) {
            selectedEditorTabID = openEditorTabs[idx].id
            openEditorTabs[idx].pendingGoToLine = line
            openEditorTabs[idx].pendingSearchQuery = query
            refreshGitBranchForCurrentFile()
            return
        }
        let content = FileService.readFile(at: file.url)
        var tab = EditorTab(file: file, content: content)
        tab.pendingGoToLine = line
        tab.pendingSearchQuery = query
        openEditorTabs.append(tab)
        selectedEditorTabID = tab.id
        refreshGitBranchForCurrentFile()
    }

    func openDiffFile(_ gitFile: GitFileStatus) {
        let fileURL = gitFile.fullURL

        // Untracked/added files have no HEAD version — open normally
        guard gitFile.status == .modified || gitFile.status == .renamed else {
            let name = fileURL.lastPathComponent
            let item = FileItem(name: name, url: fileURL, isDirectory: false, children: nil)
            openFile(item)
            return
        }

        // If a diff tab for this file is already open, select it
        if let existing = openEditorTabs.first(where: { $0.file.url == fileURL && $0.isDiff }) {
            selectedEditorTabID = existing.id
            return
        }

        // Close any non-diff tab for the same file
        openEditorTabs.removeAll { $0.file.url == fileURL && !$0.isDiff }

        let currentContent = FileService.readFile(at: fileURL)

        // Find git root and relative path
        let dir = fileURL.deletingLastPathComponent()
        guard let gitRoot = GitService.findGitRoot(from: dir) else {
            let item = FileItem(name: fileURL.lastPathComponent, url: fileURL, isDirectory: false, children: nil)
            openFile(item)
            return
        }

        let rootPath = gitRoot.path.hasSuffix("/") ? gitRoot.path : gitRoot.path + "/"
        let filePath = fileURL.path
        guard filePath.hasPrefix(rootPath) else {
            let item = FileItem(name: fileURL.lastPathComponent, url: fileURL, isDirectory: false, children: nil)
            openFile(item)
            return
        }
        let relativePath = String(filePath.dropFirst(rootPath.count))

        let original = GitService.showHEAD(relativePath: relativePath, at: gitRoot)
        guard let original else {
            let item = FileItem(name: fileURL.lastPathComponent, url: fileURL, isDirectory: false, children: nil)
            openFile(item)
            return
        }

        let file = FileItem(name: fileURL.lastPathComponent, url: fileURL, isDirectory: false, children: nil)
        let tab = EditorTab(file: file, content: currentContent, diffOriginalContent: original)
        openEditorTabs.append(tab)
        selectedEditorTabID = tab.id
    }

    func closeEditorTab(_ tab: EditorTab) {
        openEditorTabs.removeAll { $0.id == tab.id }
        if selectedEditorTabID == tab.id {
            selectedEditorTabID = openEditorTabs.last?.id
        }
        saveSession()
    }

    // MARK: - Terminal Tabs

    var selectedTerminalTab: TerminalTab? {
        guard let id = selectedTerminalTabID else { return terminalTabs.first }
        return terminalTabs.first { $0.id == id }
    }

    // MARK: - Recent Projects

    private static let recentProjectsKey = "recentProjects"
    private static let lastOpenedProjectKey = "lastOpenedProject"
    private static let maxRecents = 10

    var recentProjects: [URL] = []

    func loadRecents() {
        guard let bookmarks = UserDefaults.standard.array(forKey: Self.recentProjectsKey) as? [Data] else {
            recentProjects = []
            return
        }
        recentProjects = bookmarks.compactMap { data in
            var stale = false
            return try? URL(resolvingBookmarkData: data, options: .withSecurityScope, bookmarkDataIsStale: &stale)
        }
    }

    private func saveRecents() {
        let bookmarks = recentProjects.prefix(Self.maxRecents).compactMap { url in
            try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        UserDefaults.standard.set(Array(bookmarks), forKey: Self.recentProjectsKey)
    }

    func addToRecents(_ url: URL) {
        // If already in list, keep its position
        if recentProjects.contains(where: { $0.path == url.path }) { return }
        recentProjects.append(url)
        if recentProjects.count > Self.maxRecents {
            recentProjects = Array(recentProjects.prefix(Self.maxRecents))
        }
        saveRecents()
    }

    func removeFromRecents(_ url: URL) {
        recentProjects.removeAll { $0.path == url.path }
        saveRecents()
        // Also remove custom name
        var names = Self.projectNames
        names.removeValue(forKey: url.path)
        Self.projectNames = names
    }

    // MARK: - Project Names

    private static let projectNamesKey = "projectCustomNames"

    static var projectNames: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: projectNamesKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: projectNamesKey) }
    }

    func displayName(for url: URL) -> String {
        Self.projectNames[url.path] ?? url.lastPathComponent
    }

    func renameProject(_ url: URL, to name: String) {
        var names = Self.projectNames
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == url.lastPathComponent {
            names.removeValue(forKey: url.path)
        } else {
            names[url.path] = trimmed
        }
        Self.projectNames = names
    }

    func openProjectInNewWindow(_ url: URL) {
        // Launch a new instance of the app with the project path as argument
        guard let appURL = Bundle.main.bundleURL as URL? else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        config.arguments = [url.path]
        NSWorkspace.shared.openApplication(at: appURL, configuration: config)
    }

    func restoreLastProject() {
        guard projectURL == nil else { return }
        if let url = loadLastOpenedProject(), FileManager.default.fileExists(atPath: url.path) {
            openProject(at: url)
            return
        }
        // Fallback to first recent project
        if let last = recentProjects.first {
            let didAccess = last.startAccessingSecurityScopedResource()
            defer { if didAccess { last.stopAccessingSecurityScopedResource() } }
            guard FileManager.default.fileExists(atPath: last.path) else { return }
            openProject(at: last)
        }
    }

    private func saveLastOpenedProject(_ url: URL) {
        if let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(bookmark, forKey: Self.lastOpenedProjectKey)
        }
    }

    private func loadLastOpenedProject() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: Self.lastOpenedProjectKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, bookmarkDataIsStale: &stale) else { return nil }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        return url
    }

    func openProject(at url: URL) {
        saveSession() // Save current project state before switching
        stopFileWatcher()
        terminalTabs.removeAll()
        openEditorTabs.removeAll()
        selectedEditorTabID = nil

        projectURL = url
        rootFileItem = nil
        addToRecents(url)
        saveLastOpenedProject(url)

        // Spawn default terminal
        let tab = TerminalTab(workingDirectory: url)
        terminalTabs.append(tab)
        selectedTerminalTabID = tab.id

        // Build search index in background
        SearchIndex.shared.invalidate()
        Task.detached { SearchIndex.shared.buildIndex(for: url) }

        // Load directory tree off main thread
        Task.detached {
            let root = FileService.loadDirectory(at: url)
            await MainActor.run {
                self.rootFileItem = root
            }
        }

        refreshGit()
        startAutoFetch()
        startFileWatcher()

        // Restore saved session state after tree loads
        restoreSession()
    }

    // MARK: - Session Persistence

    private var sessionKey: String {
        "session_\(projectURL?.path ?? "")"
    }

    func saveSession() {
        guard let projectURL else { return }
        let key = sessionKey

        // Editor tabs — save file paths and selected
        let tabPaths = openEditorTabs.compactMap { tab -> String? in
            guard !tab.isDiff else { return nil }
            return tab.file.url.path
        }
        let selectedPath = selectedEditorTab?.file.url.path ?? ""
        UserDefaults.standard.set(tabPaths, forKey: "\(key)_editorTabs")
        UserDefaults.standard.set(selectedPath, forKey: "\(key)_selectedTab")

        // Terminal tabs — save working directories
        let termPaths = terminalTabs.compactMap { $0.workingDirectory?.path }
        UserDefaults.standard.set(termPaths, forKey: "\(key)_terminalTabs")

        // Expanded folders
        UserDefaults.standard.set(Array(expandedFolders), forKey: "\(key)_expandedFolders")

        // Panel visibility
        UserDefaults.standard.set(showSidebar, forKey: "\(key)_showSidebar")
        UserDefaults.standard.set(showTerminal, forKey: "\(key)_showTerminal")
    }

    private func restoreSession() {
        guard let projectURL else { return }
        let key = sessionKey

        // Expanded folders
        if let saved = UserDefaults.standard.stringArray(forKey: "\(key)_expandedFolders") {
            expandedFolders = Set(saved)
        }

        // Panel visibility
        if UserDefaults.standard.object(forKey: "\(key)_showSidebar") != nil {
            showSidebar = UserDefaults.standard.bool(forKey: "\(key)_showSidebar")
        }
        if UserDefaults.standard.object(forKey: "\(key)_showTerminal") != nil {
            showTerminal = UserDefaults.standard.bool(forKey: "\(key)_showTerminal")
        }

        // Terminal tabs
        if let termPaths = UserDefaults.standard.stringArray(forKey: "\(key)_terminalTabs"), !termPaths.isEmpty {
            terminalTabs.removeAll()
            for path in termPaths {
                let url = URL(fileURLWithPath: path)
                if FileManager.default.fileExists(atPath: path) {
                    terminalTabs.append(TerminalTab(workingDirectory: url))
                }
            }
            if terminalTabs.isEmpty {
                terminalTabs.append(TerminalTab(workingDirectory: projectURL))
            }
            selectedTerminalTabID = terminalTabs.first?.id
        }

        // Editor tabs — restore after a short delay so file tree is ready
        if let tabPaths = UserDefaults.standard.stringArray(forKey: "\(key)_editorTabs"), !tabPaths.isEmpty {
            let selectedPath = UserDefaults.standard.string(forKey: "\(key)_selectedTab") ?? ""
            Task { @MainActor in
                // Wait for file tree to load
                try? await Task.sleep(for: .milliseconds(300))
                for path in tabPaths {
                    let url = URL(fileURLWithPath: path)
                    guard FileManager.default.fileExists(atPath: path) else { continue }
                    let name = url.lastPathComponent
                    let file = FileItem(name: name, url: url, isDirectory: false, children: nil)
                    self.openFile(file)
                }
                // Select the previously selected tab
                if !selectedPath.isEmpty {
                    if let tab = self.openEditorTabs.first(where: { $0.file.url.path == selectedPath }) {
                        self.selectedEditorTabID = tab.id
                    }
                }
            }
        }
    }

    func toggleFolder(_ relativePath: String) {
        if expandedFolders.contains(relativePath) {
            expandedFolders.remove(relativePath)
        } else {
            expandedFolders.insert(relativePath)
        }
        saveSession()
    }

    func isFolderExpanded(_ relativePath: String) -> Bool {
        expandedFolders.contains(relativePath)
    }
}
