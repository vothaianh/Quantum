import SwiftUI

struct SidebarView: View {
    @Bindable var state: AppState
    @Environment(\.fontZoom) private var zoom

    var body: some View {
        VStack(spacing: 0) {
            // Icon tab bar — horizontal at top
            HStack(spacing: 6) {
                Spacer()
                SidebarTabIcon(icon: "doc.on.doc", tab: .files, selected: state.sidebarTab)
                    .onTapGesture { state.sidebarTab = .files }
                    .help("Explorer")
                SidebarTabIcon(icon: "magnifyingglass", tab: .search, selected: state.sidebarTab)
                    .onTapGesture { state.sidebarTab = .search }
                    .help("Search (\u{2318}F)")
                SidebarTabIcon(icon: "arrow.triangle.branch", tab: .git, selected: state.sidebarTab)
                    .onTapGesture {
                        state.sidebarTab = .git
                        state.updateActiveGitContext()
                        state.refreshGit()
                    }
                    .help("Source Control")
                SidebarTabIcon(icon: "square.grid.2x2", tab: .projects, selected: state.sidebarTab)
                    .onTapGesture { state.sidebarTab = .projects }
                    .help("Projects")
                Spacer()
            }
            .padding(.vertical, 10)
            .background(Theme.bgHeader)

            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)

            // Content
            switch state.sidebarTab {
            case .projects:
                ProjectsPanel(state: state)
            case .files:
                FileTreePanel(state: state)
            case .search:
                SearchPanel(state: state)
            case .git:
                GitPanel(state: state)
            }
        }
        .background(Theme.bgSidebar)
    }
}

// MARK: - Tab Icon

private struct SidebarTabIcon: View {
    let icon: String
    let tab: SidebarTab
    let selected: SidebarTab
    @State private var isHovered = false

    private var isActive: Bool { tab == selected }

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(isActive ? Theme.accent : Theme.textMuted)
            .frame(width: 32, height: 32)
            .background(isActive ? Theme.bgSelected : isHovered ? Theme.bgHover : .clear)
            .cornerRadius(6)
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
    }
}

// MARK: - Projects Panel

private struct ProjectsPanel: View {
    @Bindable var state: AppState
    @Environment(\.fontZoom) private var zoom
    @State private var renamingURL: URL?
    @State private var renameText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Text("PROJECTS")
                    .font(.zoomed(size: 10, zoom: zoom, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                Spacer()
                Button { addProject() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Theme.accent)
                        .clipShape(Circle())
                }
                .buttonStyle(.borderless)
                .help("Add project")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)

            if state.recentProjects.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 32))
                        .foregroundStyle(Theme.textMuted)
                    Text("No projects yet")
                        .font(.zoomed(size: 12, zoom: zoom))
                        .foregroundStyle(Theme.textSecondary)
                    Button { addProject() } label: {
                        Text("Add Project")
                            .font(.zoomed(size: 11, zoom: zoom, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Theme.accent)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.borderless)
                    .help("Add a project folder")
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(state.recentProjects, id: \.path) { url in
                            ProjectRow(
                                url: url,
                                state: state,
                                isRenaming: renamingURL?.path == url.path,
                                renameText: renamingURL?.path == url.path ? $renameText : .constant(""),
                                onStartRename: {
                                    renameText = state.displayName(for: url)
                                    renamingURL = url
                                },
                                onCommitRename: {
                                    state.renameProject(url, to: renameText)
                                    renamingURL = nil
                                },
                                onCancelRename: { renamingURL = nil }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func addProject() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Select a project folder"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        state.addToRecents(url)
    }
}

private struct ProjectRow: View {
    let url: URL
    @Bindable var state: AppState
    let isRenaming: Bool
    @Binding var renameText: String
    let onStartRename: () -> Void
    let onCommitRename: () -> Void
    let onCancelRename: () -> Void

    @Environment(\.fontZoom) private var zoom
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    private var isCurrent: Bool {
        state.projectURL?.path == url.path
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .font(.zoomed(size: 13, zoom: zoom))
                .foregroundStyle(Theme.folderBlue)

            VStack(alignment: .leading, spacing: 1) {
                if isRenaming {
                    HStack(spacing: 4) {
                        TextField("Name", text: $renameText)
                            .textFieldStyle(.plain)
                            .font(.zoomed(size: 11, zoom: zoom, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                            .focused($isFocused)
                            .onSubmit { onCommitRename() }
                            .onExitCommand { onCancelRename() }
                        Button {
                            onCancelRename()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Theme.textMuted)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.bg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Theme.accent, lineWidth: 1.5)
                    )
                    .cornerRadius(4)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isFocused = true
                        }
                    }
                } else {
                    Text(state.displayName(for: url))
                        .font(.zoomed(size: 11, zoom: zoom, weight: .medium))
                        .foregroundStyle(isCurrent ? Theme.accent : Theme.textPrimary)
                        .lineLimit(1)
                }
                Text(url.path)
                    .font(.zoomed(size: 9, zoom: zoom))
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
                    .truncationMode(.head)
            }

            Spacer()

            if isHovered && !isRenaming {
                // Open in new window
                Button { state.openProjectInNewWindow(url) } label: {
                    Image(systemName: "macwindow.badge.plus")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 26, height: 26)
                        .background(Theme.bgHover)
                        .cornerRadius(5)
                }
                .buttonStyle(.borderless)
                .help("Open in new window")

                // Rename
                Button { onStartRename() } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 26, height: 26)
                        .background(Theme.bgHover)
                        .cornerRadius(5)
                }
                .buttonStyle(.borderless)
                .help("Rename")

                // Remove
                Button {
                    state.removeFromRecents(url)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.danger.opacity(0.7))
                        .frame(width: 26, height: 26)
                        .background(Theme.danger.opacity(0.1))
                        .cornerRadius(5)
                }
                .buttonStyle(.borderless)
                .help("Remove from list")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            isCurrent ? Theme.accent.opacity(0.15) :
            isHovered ? Theme.bgHover : .clear
        )
        .cornerRadius(4)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            guard !isRenaming else { return }
            state.openProject(at: url)
        }
    }
}

// MARK: - File Tree Panel

private struct FileTreePanel: View {
    @Bindable var state: AppState
    @Environment(\.fontZoom) private var zoom
    @State private var isCreatingFile = false
    @State private var isCreatingFolder = false
    @State private var newItemName = ""
    @FocusState private var newItemFocused: Bool

    var body: some View {
        if let root = state.rootFileItem {
            HStack(spacing: 6) {
                Text(root.name)
                    .font(.zoomed(size: 12, zoom: zoom, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Spacer()
                Button {
                    newItemName = ""
                    isCreatingFile = true
                    isCreatingFolder = false
                } label: {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Theme.accent)
                        .clipShape(Circle())
                }
                .buttonStyle(.borderless)
                .help("New File")
                Button {
                    newItemName = ""
                    isCreatingFolder = true
                    isCreatingFile = false
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Theme.accent)
                        .clipShape(Circle())
                }
                .buttonStyle(.borderless)
                .help("New Folder")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.bgHeader)

            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if isCreatingFile || isCreatingFolder {
                        HStack(spacing: 4) {
                            Image(systemName: isCreatingFolder ? "folder.fill" : "doc")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16 * zoom, height: 16 * zoom)
                                .foregroundStyle(isCreatingFolder ? Theme.folderBlue : Theme.textMuted)
                            HStack(spacing: 2) {
                                TextField(isCreatingFolder ? "Folder name" : "File name", text: $newItemName)
                                    .textFieldStyle(.plain)
                                    .font(.zoomed(size: 12, zoom: zoom))
                                    .foregroundStyle(Theme.textPrimary)
                                    .focused($newItemFocused)
                                    .onSubmit { commitNewItem() }
                                    .onExitCommand { cancelNewItem() }
                                Button { cancelNewItem() } label: {
                                    Image(systemName: "xmark")
                                        .font(.zoomed(size: 8, zoom: zoom, weight: .bold))
                                        .foregroundStyle(Theme.textMuted)
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.bg)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Theme.accent, lineWidth: 1.5)
                            )
                            .cornerRadius(5)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    newItemFocused = true
                                }
                            }
                        }
                        .padding(.leading, 8)
                        .padding(.vertical, 6)
                        .padding(.trailing, 8)
                    }

                    if let children = root.children {
                        ForEach(children) { item in
                            FileTreeRow(item: item, state: state, depth: 0)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .contentShape(Rectangle())
            .contextMenu {
                Button {
                    newItemName = ""
                    isCreatingFile = true
                    isCreatingFolder = false
                } label: {
                    Label("New File", systemImage: "doc.badge.plus")
                }
                Button {
                    newItemName = ""
                    isCreatingFolder = true
                    isCreatingFile = false
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
            }
        } else {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 36))
                    .foregroundStyle(Theme.textMuted)
                Text("Open a folder to begin")
                    .font(.zoomed(size: 12, zoom: zoom))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func commitNewItem() {
        let name = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let root = state.rootFileItem else { cancelNewItem(); return }
        let newURL = root.url.appendingPathComponent(name)
        do {
            if isCreatingFolder {
                try FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: false)
            } else {
                FileManager.default.createFile(atPath: newURL.path, contents: nil)
            }
            if let projectURL = state.projectURL {
                Task.detached {
                    let tree = FileService.loadDirectory(at: projectURL)
                    await MainActor.run { state.rootFileItem = tree }
                }
            }
            if !isCreatingFolder {
                let file = FileItem(name: name, url: newURL, isDirectory: false, children: nil)
                state.openFile(file)
            }
        } catch {}
        cancelNewItem()
    }

    private func cancelNewItem() {
        isCreatingFile = false
        isCreatingFolder = false
        newItemName = ""
    }
}

// MARK: - Search Panel

private struct SearchPanel: View {
    @Bindable var state: AppState
    @Environment(\.fontZoom) private var zoom
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search header
            HStack(spacing: 6) {
                Text("SEARCH")
                    .font(.zoomed(size: 10, zoom: zoom, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Search input
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textMuted)
                TextField("Search", text: $state.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.zoomed(size: 12, zoom: zoom))
                    .foregroundStyle(Theme.textPrimary)
                    .focused($isFocused)
                    .onSubmit { state.performSearch() }
                if !state.searchQuery.isEmpty {
                    Button {
                        state.searchQuery = ""
                        state.searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .buttonStyle(.borderless)
                    .help("Clear Search")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Theme.bg)
            .cornerRadius(6)
            .padding(.horizontal, 8)

            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
                .padding(.top, 8)

            // Results
            if state.isSearching {
                VStack(spacing: 8) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Searching...")
                        .font(.zoomed(size: 11, zoom: zoom))
                        .foregroundStyle(Theme.textMuted)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if state.searchResults.isEmpty && !state.searchQuery.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text("No results found")
                        .font(.zoomed(size: 12, zoom: zoom))
                        .foregroundStyle(Theme.textMuted)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if state.searchQuery.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(Theme.textMuted.opacity(0.4))
                    Text("Press \u{2318}F to search across your files")
                        .font(.zoomed(size: 14, zoom: zoom))
                        .foregroundStyle(Theme.textMuted)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                // Group results by file
                let grouped = Dictionary(grouping: state.searchResults, by: \.fileURL)
                let sortedFiles = grouped.keys.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Result count
                        HStack {
                            Text("\(state.searchResults.count) result\(state.searchResults.count == 1 ? "" : "s") in \(sortedFiles.count) file\(sortedFiles.count == 1 ? "" : "s")")
                                .font(.zoomed(size: 10, zoom: zoom))
                                .foregroundStyle(Theme.textMuted)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)

                        ForEach(sortedFiles, id: \.self) { fileURL in
                            if let results = grouped[fileURL] {
                                SearchFileGroup(
                                    fileURL: fileURL,
                                    results: results,
                                    state: state,
                                    query: state.searchQuery
                                )
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isFocused = true
            }
        }
        .onChange(of: state.searchQuery) {
            state.performSearch()
        }
    }
}

// MARK: - Search File Group

private struct SearchFileGroup: View {
    let fileURL: URL
    let results: [SearchResult]
    @Bindable var state: AppState
    let query: String
    @Environment(\.fontZoom) private var zoom
    @State private var isExpanded = true
    @State private var isHovered = false

    private var relativePath: String {
        guard let root = state.projectURL else { return "" }
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        let dir = fileURL.deletingLastPathComponent().path
        if dir.hasPrefix(rootPath) {
            let rel = String(dir.dropFirst(rootPath.count))
            return rel.isEmpty ? "" : rel
        }
        return ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // File header
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Theme.textMuted)
                    .frame(width: 10)

                let item = FileItem(name: fileURL.lastPathComponent, url: fileURL, isDirectory: false, children: nil)
                Image(nsImage: FileIconResolver.icon(for: item))
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14 * zoom, height: 14 * zoom)

                Text(fileURL.lastPathComponent)
                    .font(.zoomed(size: 11, zoom: zoom, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                if !relativePath.isEmpty {
                    Text(relativePath)
                        .font(.zoomed(size: 10, zoom: zoom))
                        .foregroundStyle(Theme.textMuted)
                        .lineLimit(1)
                        .truncationMode(.head)
                }

                Spacer()

                Text("\(results.count)")
                    .font(.zoomed(size: 9, zoom: zoom, weight: .medium))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isHovered ? Theme.bgHover : .clear)
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            }

            // Match lines
            if isExpanded {
                ForEach(results) { result in
                    SearchMatchRow(result: result, query: query, state: state)
                }
            }
        }
    }
}

// MARK: - Search Match Row

private struct SearchMatchRow: View {
    let result: SearchResult
    let query: String
    @Bindable var state: AppState
    @Environment(\.fontZoom) private var zoom
    @State private var isHovered = false

    private var highlightedLine: AttributedString {
        let trimmed = result.lineContent.trimmingCharacters(in: .whitespaces)
        let q = query.lowercased()
        var attributed = AttributedString(trimmed)
        attributed.font = .system(size: 11 * state.zoomLevel, design: .monospaced)
        attributed.foregroundColor = Color(nsColor: .init(srgbRed: 0.467, green: 0.467, blue: 0.467, alpha: 1))

        let lower = trimmed.lowercased()
        var searchStart = lower.startIndex
        while let range = lower.range(of: q, range: searchStart..<lower.endIndex) {
            if let attrRange = Range(range, in: attributed) {
                attributed[attrRange].foregroundColor = Color(nsColor: .init(srgbRed: 0.0, green: 0.863, blue: 0.510, alpha: 1))
                attributed[attrRange].backgroundColor = Color(nsColor: .init(srgbRed: 0.0, green: 0.863, blue: 0.510, alpha: 0.15))
                attributed[attrRange].font = .system(size: 11 * state.zoomLevel, weight: .bold, design: .monospaced)
            }
            searchStart = range.upperBound
        }
        return attributed
    }

    var body: some View {
        HStack(spacing: 0) {
            // Line number gutter
            Text("\(result.lineNumber)")
                .font(.zoomed(size: 10, zoom: state.zoomLevel, design: .monospaced))
                .foregroundStyle(Theme.textMuted.opacity(0.6))
                .frame(width: 36, alignment: .trailing)
                .padding(.trailing, 8)

            // Code line with highlighted keyword
            Text(highlightedLine)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.leading, 24)
        .padding(.trailing, 8)
        .padding(.vertical, 3)
        .background(isHovered ? Theme.accent.opacity(0.08) : .clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            let file = FileItem(name: result.fileName, url: result.fileURL, isDirectory: false, children: nil)
            state.openFileAtLine(file, line: result.lineNumber, query: query)
        }
    }
}

// MARK: - Git Panel

private struct GitPanel: View {
    @Bindable var state: AppState
    @Environment(\.fontZoom) private var zoom
    @State private var showChanges = true
    @State private var showLog = true

    var body: some View {
        VStack(spacing: 0) {
            // Git header
            HStack(spacing: 6) {
                Text("SOURCE CONTROL")
                    .font(.zoomed(size: 10, zoom: zoom, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                Spacer()

                Button {
                    state.refreshGit()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textMuted)
                }
                .buttonStyle(.borderless)
                .help("Refresh")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .onChange(of: state.selectedEditorTabID) {
                state.updateActiveGitContext()
            }
            .onAppear {
                state.updateActiveGitContext()
            }

            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)

            // Commit input
            if !state.gitRepos.isEmpty {
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        TextField("Commit message", text: $state.commitMessage, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.zoomed(size: 11, zoom: zoom))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1...4)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Theme.bg)
                            .cornerRadius(6)

                        Button {
                            state.generateCommitMessage()
                        } label: {
                            if state.isGeneratingCommitMsg {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 16, height: 16)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .buttonStyle(.borderless)
                        .frame(width: 28, height: 28)
                        .background(Theme.bgHover)
                        .cornerRadius(6)
                        .disabled(state.isGeneratingCommitMsg)
                        .help("Generate commit message with AI")
                    }

                    Button {
                        state.commitChanges()
                    } label: {
                        HStack(spacing: 6) {
                            if state.isCommitting || state.isPushing {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                            }
                            Text(state.isCommitting ? "Committing..." : state.isPushing ? "Pushing..." : "Commit & Push")
                                .font(.zoomed(size: 11, zoom: zoom, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            state.commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state.isCommitting || state.isPushing
                                ? Theme.accent.opacity(0.4)
                                : Theme.accent
                        )
                        .cornerRadius(6)
                    }
                    .buttonStyle(.borderless)
                    .disabled(state.commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state.isCommitting || state.isPushing)
                    .help("Commit all changes and push to remote")

                    if let error = state.commitError {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.danger)
                            Text(error)
                                .font(.zoomed(size: 10, zoom: zoom))
                                .foregroundStyle(Theme.danger)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer()
                            Button {
                                state.showGitErrorPopup = true
                            } label: {
                                Text("Details")
                                    .font(.zoomed(size: 10, zoom: zoom, weight: .medium))
                                    .foregroundStyle(Theme.accent)
                            }
                            .buttonStyle(.borderless)
                            .help("Show full error details")
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .alert("Git Error", isPresented: $state.showGitErrorPopup) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(state.gitErrorDetail)
                }

                Rectangle()
                    .fill(Theme.border)
                    .frame(height: 1)
            }

            // Scrollable content: changes (top) + log (bottom 50%)
            GeometryReader { geo in
                VStack(spacing: 0) {
                    // MARK: Changes section
                    VStack(spacing: 0) {
                        GitSectionHeader(
                            title: "CHANGES",
                            count: state.gitRepos.reduce(0) { $0 + $1.files.count },
                            isExpanded: $showChanges
                        )

                        if showChanges {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 0) {
                                    if state.isLoadingGit {
                                        HStack {
                                            Spacer()
                                            ProgressView()
                                                .scaleEffect(0.6)
                                                .padding(.vertical, 12)
                                            Spacer()
                                        }
                                    } else if state.gitRepos.isEmpty {
                                        HStack(spacing: 6) {
                                            Image(systemName: "checkmark.circle")
                                                .font(.system(size: 11))
                                                .foregroundStyle(Theme.termGreen)
                                            Text("No changes")
                                                .font(.zoomed(size: 11, zoom: zoom))
                                                .foregroundStyle(Theme.textMuted)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                    } else {
                                        ForEach(state.gitRepos) { repo in
                                            GitRepoSection(repo: repo, state: state)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: showLog ? geo.size.height * 0.5 : .infinity)

                    Rectangle()
                        .fill(Theme.border)
                        .frame(height: 1)

                    // MARK: Git Log section
                    VStack(spacing: 0) {
                        GitLogSectionHeader(
                            title: "COMMIT LOG",
                            isExpanded: $showLog,
                            state: state
                        )

                        if showLog {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 0) {
                                    if state.isLoadingGitLog {
                                        HStack {
                                            Spacer()
                                            ProgressView()
                                                .scaleEffect(0.6)
                                                .padding(.vertical, 12)
                                            Spacer()
                                        }
                                    } else if state.gitCommits.isEmpty && state.unpulledCommits.isEmpty {
                                        HStack(spacing: 6) {
                                            Image(systemName: "clock")
                                                .font(.system(size: 11))
                                                .foregroundStyle(Theme.textMuted)
                                            Text("No commits")
                                                .font(.zoomed(size: 11, zoom: zoom))
                                                .foregroundStyle(Theme.textMuted)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                    } else {
                                        // Unpulled commits from remote
                                        if !state.unpulledCommits.isEmpty {
                                            HStack(spacing: 5) {
                                                Image(systemName: "arrow.down.circle.fill")
                                                    .font(.system(size: 9))
                                                    .foregroundStyle(Theme.accent)
                                                Text("\(state.unpulledCommits.count) incoming")
                                                    .font(.zoomed(size: 9, zoom: zoom, weight: .semibold))
                                                    .foregroundStyle(Theme.accent)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 4)

                                            ForEach(state.unpulledCommits) { commit in
                                                GitCommitRow(commit: commit)
                                            }

                                            Rectangle()
                                                .fill(Theme.border)
                                                .frame(height: 1)
                                                .padding(.vertical, 2)
                                        }

                                        // Local commits
                                        ForEach(state.gitCommits) { commit in
                                            GitCommitRow(commit: commit)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: showChanges ? geo.size.height * 0.5 : .infinity)
                }
            }
        }
    }
}

// MARK: - Section Headers

private struct GitSectionHeader: View {
    let title: String
    let count: Int
    @Binding var isExpanded: Bool
    @Environment(\.fontZoom) private var zoom
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Theme.textMuted)
                .frame(width: 10)

            Text(title)
                .font(.zoomed(size: 10, zoom: zoom, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)

            if count > 0 {
                Text("\(count)")
                    .font(.zoomed(size: 9, zoom: zoom, weight: .medium))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered ? Theme.bgHover : Theme.bgHeader)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                isExpanded.toggle()
            }
        }
    }
}

private struct GitLogSectionHeader: View {
    let title: String
    @Binding var isExpanded: Bool
    @Bindable var state: AppState
    @Environment(\.fontZoom) private var zoom
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Theme.textMuted)
                .frame(width: 10)

            Text(title)
                .font(.zoomed(size: 10, zoom: zoom, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)

            if !state.activeGitBranch.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 8))
                    Text(state.activeGitBranch)
                        .font(.zoomed(size: 9, zoom: zoom))
                        .lineLimit(1)
                }
                .foregroundStyle(Theme.textMuted)
            }

            Spacer()

            // Pull button with badge
            Button {
                state.pullChanges()
            } label: {
                if state.isPulling {
                    ProgressView()
                        .scaleEffect(0.4)
                        .frame(width: 9, height: 9)
                } else {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 9, weight: .semibold))
                }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(Theme.accent)
            .clipShape(Circle())
            .disabled(state.isPulling)
            .help(state.unpulledCommits.isEmpty ? "Pull (Rebase)" : "Pull \(state.unpulledCommits.count) commit\(state.unpulledCommits.count == 1 ? "" : "s")")
            .overlay(alignment: .topTrailing) {
                if !state.unpulledCommits.isEmpty {
                    Text("\(state.unpulledCommits.count)")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color(nsColor: .init(srgbRed: 0.510, green: 0.667, blue: 1.0, alpha: 1)))
                        .clipShape(Capsule())
                        .offset(x: 5, y: -5)
                }
            }

            // Push button
            Button {
                state.pushChanges()
            } label: {
                if state.isPushing {
                    ProgressView()
                        .scaleEffect(0.4)
                        .frame(width: 9, height: 9)
                } else {
                    Image(systemName: "arrow.up.to.line")
                        .font(.system(size: 9, weight: .semibold))
                }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(Theme.accent)
            .clipShape(Circle())
            .disabled(state.isPushing)
            .help("Push")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered ? Theme.bgHover : Theme.bgHeader)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                isExpanded.toggle()
            }
        }
    }
}

// MARK: - Git Commit Row

private struct GitCommitRow: View {
    let commit: GitCommitLog
    @Environment(\.fontZoom) private var zoom
    @State private var isHovered = false

    private var hashColor: Color {
        commit.isRemoteOnly ? Color(nsColor: .init(srgbRed: 0.510, green: 0.667, blue: 1.0, alpha: 1)) : Theme.accent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Commit message
            HStack(spacing: 5) {
                if commit.isRemoteOnly {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(hashColor)
                }
                Text(commit.message)
                    .font(.zoomed(size: 11, zoom: zoom))
                    .foregroundStyle(commit.isRemoteOnly ? Theme.textSecondary : Theme.textPrimary)
                    .lineLimit(1)
            }

            // Author and date
            HStack(spacing: 4) {
                // Hash badge
                Text(commit.id)
                    .font(.zoomed(size: 9, zoom: zoom, weight: .medium, design: .monospaced))
                    .foregroundStyle(hashColor)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(hashColor.opacity(0.1))
                    .cornerRadius(3)

                Text(commit.author)
                    .font(.zoomed(size: 10, zoom: zoom))
                    .foregroundStyle(commit.isRemoteOnly ? Theme.textMuted : Theme.textSecondary)
                    .lineLimit(1)

                Spacer()

                Text(commit.relativeDate)
                    .font(.zoomed(size: 10, zoom: zoom))
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            commit.isRemoteOnly
                ? (isHovered ? hashColor.opacity(0.08) : hashColor.opacity(0.03))
                : (isHovered ? Theme.bgHover : .clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

private struct GitRepoSection: View {
    let repo: GitRepoStatus
    @Bindable var state: AppState
    @Environment(\.fontZoom) private var zoom
    @State private var isExpanded = true
    @State private var showDiscardAllConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Repo header
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.zoomed(size: 9, zoom: zoom, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 10)

                Image(systemName: "folder.fill")
                    .font(.zoomed(size: 11, zoom: zoom))
                    .foregroundStyle(Theme.folderBlue)

                Text(repo.name)
                    .font(.zoomed(size: 11, zoom: zoom, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                Text("\(repo.files.count)")
                    .font(.zoomed(size: 10, zoom: zoom))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Theme.bgHover)
                    .cornerRadius(4)

                Spacer()

                Button {
                    showDiscardAllConfirm = true
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Theme.accent)
                        .clipShape(Circle())
                }
                .buttonStyle(.borderless)
                .help("Discard All Changes")
                .confirmationDialog("Discard all changes?", isPresented: $showDiscardAllConfirm) {
                    Button("Discard All", role: .destructive) {
                        state.discardAllChanges()
                    }
                }

                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.textMuted)
                Text(repo.branch)
                    .font(.zoomed(size: 10, zoom: zoom))
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.bgHeader)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            }

            if isExpanded {
                ForEach(repo.files) { file in
                    GitFileRow(file: file, state: state)
                }
            }
        }
    }
}

private struct GitFileRow: View {
    let file: GitFileStatus
    @Bindable var state: AppState
    @Environment(\.fontZoom) private var zoom
    @State private var isHovered = false
    @State private var showDiscardConfirm = false

    private var statusColor: Color {
        switch file.status {
        case .modified: return Theme.textPrimary
        case .added, .untracked: return Theme.accent
        case .deleted: return Theme.danger
        case .renamed: return Theme.textSecondary
        case .conflicted: return Theme.danger
        }
    }

    private var fileItem: FileItem {
        FileItem(name: file.fullURL.lastPathComponent, url: file.fullURL, isDirectory: false, children: nil)
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(nsImage: FileIconResolver.icon(for: fileItem))
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 16 * zoom, height: 16 * zoom)
            Text(file.path)
                .font(.zoomed(size: 11, zoom: zoom))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.head)
            Spacer()

            if isHovered || showDiscardConfirm {
                Button {
                    showDiscardConfirm = true
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Theme.accent)
                        .clipShape(Circle())
                }
                .buttonStyle(.borderless)
                .help("Discard Changes")
            }

            Text(file.status.label)
                .font(.zoomed(size: 10, zoom: zoom, weight: .bold, design: .monospaced))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered ? Theme.bgHover : .clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            state.openDiffFile(file)
        }
        .confirmationDialog("Discard changes to \(file.path)?", isPresented: $showDiscardConfirm) {
            Button("Discard", role: .destructive) {
                state.discardFile(file)
            }
        }
    }
}

// MARK: - File Tree Row

private struct FileTreeRow: View {
    let item: FileItem
    @Bindable var state: AppState
    let depth: Int

    @Environment(\.fontZoom) private var zoom
    @State private var isHovered = false

    private var isExpanded: Bool {
        state.isFolderExpanded(item.url.path)
    }

    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var showDeleteConfirm = false
    @State private var isCreatingFile = false
    @State private var isCreatingFolder = false
    @State private var newItemName = ""
    @FocusState private var renameFocused: Bool
    @FocusState private var newItemFocused: Bool

    private var isSelected: Bool {
        state.selectedFile?.id == item.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                if item.isDirectory {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.zoomed(size: 9, zoom: zoom, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 12)
                } else {
                    Spacer().frame(width: 12)
                }

                Image(nsImage: FileIconResolver.icon(for: item, expanded: isExpanded))
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16 * zoom, height: 16 * zoom)

                if isRenaming {
                    HStack(spacing: 2) {
                        TextField("Name", text: $renameText)
                            .textFieldStyle(.plain)
                            .font(.zoomed(size: 12, zoom: zoom))
                            .foregroundStyle(Theme.textPrimary)
                            .focused($renameFocused)
                            .onSubmit { commitRename() }
                            .onExitCommand { cancelRename() }
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    renameFocused = true
                                }
                            }
                        Button { cancelRename() } label: {
                            Image(systemName: "xmark")
                                .font(.zoomed(size: 8, zoom: zoom, weight: .bold))
                                .foregroundStyle(Theme.textMuted)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.bg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Theme.accent, lineWidth: 1.5)
                    )
                    .cornerRadius(5)
                } else {
                    Text(item.name)
                        .font(.zoomed(size: 12, zoom: zoom))
                        .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textPrimary.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()
            }
            .padding(.leading, CGFloat(depth) * 16 + 8)
            .padding(.vertical, 3)
            .padding(.trailing, 8)
            .contentShape(Rectangle())
            .background(
                isSelected ? Theme.accent.opacity(0.2) :
                isHovered ? Theme.bgHover : Color.clear
            )
            .cornerRadius(3)
            .onHover { isHovered = $0 }
            .onTapGesture {
                guard !isRenaming else { return }
                if item.isDirectory {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        state.toggleFolder(item.url.path)
                    }
                } else {
                    state.openFile(item)
                }
            }
            .contextMenu {
                Button {
                    startNewFile()
                } label: {
                    Label("New File", systemImage: "doc.badge.plus")
                }
                Button {
                    startNewFolder()
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                Divider()
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([item.url])
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
                Divider()
                Button {
                    startRename()
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .alert("Delete \"\(item.name)\"?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { deleteItem() }
            } message: {
                Text(item.isDirectory
                     ? "This folder and all its contents will be moved to Trash."
                     : "This file will be moved to Trash.")
            }

            if isCreatingFile || isCreatingFolder {
                HStack(spacing: 4) {
                    Image(systemName: isCreatingFolder ? "folder.fill" : "doc")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16 * zoom, height: 16 * zoom)
                        .foregroundStyle(isCreatingFolder ? Theme.folderBlue : Theme.textMuted)
                    HStack(spacing: 2) {
                        TextField(isCreatingFolder ? "Folder name" : "File name", text: $newItemName)
                            .textFieldStyle(.plain)
                            .font(.zoomed(size: 12, zoom: zoom))
                            .foregroundStyle(Theme.textPrimary)
                            .focused($newItemFocused)
                            .onSubmit { commitNewItem() }
                            .onExitCommand { cancelNewItem() }
                        Button { cancelNewItem() } label: {
                            Image(systemName: "xmark")
                                .font(.zoomed(size: 8, zoom: zoom, weight: .bold))
                                .foregroundStyle(Theme.textMuted)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.bg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Theme.accent, lineWidth: 1.5)
                    )
                    .cornerRadius(5)
                    .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                newItemFocused = true
                            }
                        }
                }
                .padding(.leading, CGFloat(item.isDirectory ? depth + 1 : depth) * 16 + 8)
                .padding(.vertical, 6)
                .padding(.trailing, 8)
            }

            if item.isDirectory && isExpanded, let children = item.children {
                ForEach(children) { child in
                    FileTreeRow(item: child, state: state, depth: depth + 1)
                }
            }
        }
    }

    private func startRename() {
        // Pre-select name without extension for files
        let name = item.name
        if !item.isDirectory, let dotIdx = name.lastIndex(of: "."), dotIdx != name.startIndex {
            renameText = String(name[..<dotIdx])
        } else {
            renameText = name
        }
        // Actually use full name so user sees extension
        renameText = name
        isRenaming = true
    }

    private func commitRename() {
        let newName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        isRenaming = false
        guard !newName.isEmpty, newName != item.name else { return }
        let newURL = item.url.deletingLastPathComponent().appendingPathComponent(newName)
        do {
            try FileManager.default.moveItem(at: item.url, to: newURL)
            // Reload the file tree
            if let root = state.projectURL {
                Task.detached {
                    let tree = FileService.loadDirectory(at: root)
                    await MainActor.run { state.rootFileItem = tree }
                }
            }
        } catch {
            // Rename failed — ignore silently
        }
    }

    private func cancelRename() {
        isRenaming = false
    }

    private var parentDir: URL {
        item.isDirectory ? item.url : item.url.deletingLastPathComponent()
    }

    private func startNewFile() {
        if item.isDirectory && !isExpanded { state.toggleFolder(item.url.path) }
        newItemName = ""
        isCreatingFile = true
        isCreatingFolder = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { newItemFocused = true }
    }

    private func startNewFolder() {
        if item.isDirectory && !isExpanded { state.toggleFolder(item.url.path) }
        newItemName = ""
        isCreatingFolder = true
        isCreatingFile = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { newItemFocused = true }
    }

    private func commitNewItem() {
        let name = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { cancelNewItem(); return }
        let newURL = parentDir.appendingPathComponent(name)
        do {
            if isCreatingFolder {
                try FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: false)
            } else {
                FileManager.default.createFile(atPath: newURL.path, contents: nil)
            }
            // Reload file tree
            if let root = state.projectURL {
                Task.detached {
                    let tree = FileService.loadDirectory(at: root)
                    await MainActor.run { state.rootFileItem = tree }
                }
            }
            // Open the new file
            if !isCreatingFolder {
                let file = FileItem(name: name, url: newURL, isDirectory: false, children: nil)
                state.openFile(file)
            }
        } catch {
            // Creation failed
        }
        cancelNewItem()
    }

    private func cancelNewItem() {
        isCreatingFile = false
        isCreatingFolder = false
        newItemName = ""
    }

    private func deleteItem() {
        do {
            try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
            // Close any open tab for this file
            state.openEditorTabs.removeAll { $0.file.url == item.url }
            // Reload file tree
            if let root = state.projectURL {
                Task.detached {
                    let tree = FileService.loadDirectory(at: root)
                    await MainActor.run { state.rootFileItem = tree }
                }
            }
        } catch {
            // Delete failed — ignore silently
        }
    }
}
