import SwiftUI

struct ContentView: View {
    @State private var state = AppState()
    @State private var sidebarFraction: CGFloat = 0.15
    @State private var terminalFraction: CGFloat = 0.30
    @State private var showQuickOpen: Bool = false
    @Binding var showSettings: Bool
    @Binding var openFolderTrigger: Bool
    @Binding var saveTrigger: Bool
    @Binding var saveAsTrigger: Bool
    @Binding var zoomInTrigger: Bool
    @Binding var zoomOutTrigger: Bool
    @Binding var zoomResetTrigger: Bool
    @Binding var goToFileTrigger: Bool
    @Binding var findInFilesTrigger: Bool
    @Binding var toggleSidebarTrigger: Bool
    @Binding var toggleTerminalTrigger: Bool

    var body: some View {
        Group {
            if state.projectURL != nil {
                ZStack {
                    VStack(spacing: 0) {
                        GeometryReader { geo in
                            let totalWidth = geo.size.width
                            let sidebarWidth = state.showSidebar ? totalWidth * sidebarFraction : 0
                            let terminalWidth = state.showTerminal ? totalWidth * terminalFraction : 0
                            let editorWidth = totalWidth - sidebarWidth - terminalWidth

                            // Title bar aligned with panels
                            VStack(spacing: 0) {
                                ZStack {
                                    // Search bar — centered in window
                                    Button {
                                        showQuickOpen = true
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "magnifyingglass")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(Theme.textMuted)
                                            Text("Go to file...")
                                                .font(.system(size: 12))
                                                .foregroundStyle(Theme.textMuted)
                                            Spacer()
                                            Text("\u{2318}P")
                                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                                .foregroundStyle(Theme.textMuted.opacity(0.5))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(Color.white.opacity(0.04))
                                                .cornerRadius(3)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.white.opacity(0.04))
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .frame(width: totalWidth * 0.3)
                                    .help("Go to File (\u{2318}P)")

                                    // Action buttons — top right
                                    HStack {
                                        Spacer()
                                        HStack(spacing: 2) {
                                            ModelPickerButton()
                                            titleBarButton(icon: "sidebar.left", tooltip: "Toggle Sidebar (\u{2318}B)") {
                                                state.showSidebar.toggle()
                                            }
                                            titleBarButton(icon: "terminal", tooltip: "Toggle Terminal (\u{2318}`)") {
                                                state.showTerminal.toggle()
                                            }
                                            titleBarButton(icon: "gearshape", tooltip: "Settings (\u{2318},)") {
                                                showSettings = true
                                            }
                                        }
                                        .padding(.trailing, 12)
                                    }
                                }
                                .padding(.top, 6)
                                .padding(.bottom, 6)
                                .background(
                                    Color.clear
                                        .contentShape(Rectangle())
                                        .onTapGesture(count: 2) {
                                            NSApp.keyWindow?.zoom(nil)
                                        }
                                )

                                Rectangle()
                                    .fill(Theme.border)
                                    .frame(height: 1)

                                HStack(spacing: 0) {
                                    if state.showSidebar {
                                        SidebarView(state: state)
                                            .frame(width: sidebarWidth)

                                        PanelDivider { delta in
                                            let newFraction = sidebarFraction + delta / totalWidth
                                            sidebarFraction = newFraction.clamped(to: 0.08...0.40)
                                        }
                                    }

                                    FileContentView(state: state)
                                        .frame(width: editorWidth)

                                    if state.showTerminal {
                                        PanelDivider { delta in
                                            let newFraction = terminalFraction - delta / totalWidth
                                            terminalFraction = newFraction.clamped(to: 0.10...0.60)
                                        }

                                        TerminalPanelView(state: state)
                                            .frame(width: terminalWidth)
                                    }
                                }
                            } // VStack for title + panels
                        } // GeometryReader

                        StatusBarView(state: state)
                    }
                    .background(Theme.bg)

                    // Command Palette overlay
                    if showQuickOpen {
                        CommandPalette(state: state, isPresented: $showQuickOpen)
                            .transition(.opacity)
                    }
                }
                .animation(.easeOut(duration: 0.15), value: showQuickOpen)
                .ignoresSafeArea(.all, edges: .top)
            } else {
                WelcomeView(state: state, onOpenFolder: openFolder)
            }
        }
        .environment(\.fontZoom, state.zoomLevel)
        .frame(minWidth: 800, minHeight: 500)
        .background(Theme.bg)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            state.loadZoom()
            state.loadRecents()
            state.startObservingFileSaves()
            let args = ProcessInfo.processInfo.arguments
            if args.count > 1 {
                let path = args[args.count - 1]
                let url = URL(fileURLWithPath: path)
                if FileManager.default.fileExists(atPath: path) {
                    state.openProject(at: url)
                    return
                }
            }
            state.restoreLastProject()
        }
        .onDisappear {
            state.saveSession()
        }
        .onChange(of: openFolderTrigger) {
            openFolder()
        }
        .onChange(of: saveTrigger) {
            saveCurrentFile()
        }
        .onChange(of: saveAsTrigger) {
            saveCurrentFileAs()
        }
        .onChange(of: zoomInTrigger) {
            state.zoomIn()
        }
        .onChange(of: zoomOutTrigger) {
            state.zoomOut()
        }
        .onChange(of: zoomResetTrigger) {
            state.zoomReset()
        }
        .onChange(of: goToFileTrigger) {
            showQuickOpen = true
        }
        .onChange(of: findInFilesTrigger) {
            state.showSidebar = true
            state.sidebarTab = .search
        }
        .onChange(of: toggleSidebarTrigger) {
            state.showSidebar.toggle()
        }
        .onChange(of: toggleTerminalTrigger) {
            state.showTerminal.toggle()
        }
    }

    private func titleBarButton(icon: String, tooltip: String = "", action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 34, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    // MARK: - Model Picker Button

    private struct ModelPickerButton: View {
        @State private var settings = AppSettings.shared

        private var selectedModel: AIModel? {
            let id = settings.resolvedModelID
            return AIModel.allModels.first { $0.id == id }
        }

        var body: some View {
            Menu {
                let available = settings.availableModels
                if available.isEmpty {
                    Text("No models configured")
                } else {
                    ForEach(available) { model in
                        Button {
                            settings.lastSelectedModelID = model.id
                        } label: {
                            HStack {
                                Text(model.name)
                                if model.id == settings.resolvedModelID {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                        .font(.system(size: 12, weight: .medium))
                    if let model = selectedModel {
                        Text(model.name)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.04))
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Select AI Model")
        }
    }

    private func saveCurrentFile() {
        guard let tab = state.selectedEditorTab else { return }
        do {
            try tab.content.write(to: tab.file.url, atomically: true, encoding: .utf8)
            if let idx = state.openEditorTabs.firstIndex(where: { $0.id == tab.id }) {
                state.openEditorTabs[idx].isModified = false
            }
            NotificationCenter.default.post(name: .fileSaved, object: nil)
        } catch {
            print("Save failed: \(error)")
        }
    }

    private func saveCurrentFileAs() {
        guard let tab = state.selectedEditorTab else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = tab.file.name
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try tab.content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            print("Save As failed: \(error)")
        }
    }

    private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Select a project folder"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        state.openProject(at: url)
    }
}

// MARK: - Command Palette

private struct CommandPalette: View {
    @Bindable var state: AppState
    @Binding var isPresented: Bool
    @State private var query = ""
    @State private var results: [PaletteMatch] = []
    @State private var selectedIndex = 0
    @State private var appeared = false
    @FocusState private var isFocused: Bool

    private var recentFiles: [PaletteMatch] {
        state.openEditorTabs.reversed().prefix(8).map { tab in
            PaletteMatch(url: tab.file.url, name: tab.file.name, matchIndices: [])
        }
    }

    private var displayItems: [PaletteMatch] {
        query.isEmpty ? recentFiles : results
    }

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(appeared ? 0.45 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Palette card
            VStack(spacing: 0) {
                // Search input
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.accent)

                    TextField("Go to file...", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textPrimary)
                        .focused($isFocused)
                        .onSubmit { openSelected() }

                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textMuted)
                        }
                        .buttonStyle(.plain)
                        .help("Clear Search")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // Divider
                Rectangle().fill(Theme.border).frame(height: 1)

                // Section header
                if !displayItems.isEmpty {
                    HStack {
                        Text(query.isEmpty ? "RECENT FILES" : "\(results.count) FILE\(results.count == 1 ? "" : "S") FOUND")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textMuted)
                            .tracking(0.5)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }

                // Results list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(displayItems.enumerated()), id: \.offset) { index, match in
                                PaletteRow(
                                    match: match,
                                    isSelected: index == selectedIndex,
                                    rootPath: state.projectURL?.path ?? "",
                                    query: query
                                )
                                .id(index)
                                .contentShape(Rectangle())
                                .onHover { hovering in
                                    if hovering { selectedIndex = index }
                                }
                                .onTapGesture {
                                    selectedIndex = index
                                    openSelected()
                                }
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: min(CGFloat(displayItems.count) * 40 + 16, 380))
                    .onChange(of: selectedIndex) {
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(selectedIndex, anchor: .center)
                        }
                    }
                }

                if displayItems.isEmpty && !query.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.questionmark")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.textMuted.opacity(0.5))
                        Text("No matching files")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }

                if displayItems.isEmpty && query.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.textMuted.opacity(0.5))
                        Text("No recent files")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }

                // Footer hints
                Rectangle().fill(Theme.border).frame(height: 1)
                HStack(spacing: 16) {
                    footerHint(keys: ["↑", "↓"], label: "navigate")
                    footerHint(keys: ["↵"], label: "open")
                    footerHint(keys: ["esc"], label: "close")
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.bg.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.6), radius: 40, y: 12)
            .frame(width: 560)
            .offset(y: appeared ? -40 : -20)
            .scaleEffect(appeared ? 1 : 0.97)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isFocused = true
            }
        }
        .onChange(of: query) { updateResults() }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 { selectedIndex -= 1 }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < displayItems.count - 1 { selectedIndex += 1 }
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }

    private func footerHint(keys: [String], label: String) -> some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(3)
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textMuted.opacity(0.7))
        }
    }

    private func updateResults() {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { results = []; selectedIndex = 0; return }

        let files = SearchIndex.shared.getFiles()
        var matches: [PaletteMatch] = []

        for file in files {
            let name = file.name.lowercased()
            if let (score, indices) = fuzzyMatch(query: q, target: name) {
                matches.append(PaletteMatch(
                    url: file.url,
                    name: file.name,
                    matchIndices: indices,
                    score: score
                ))
            }
            if matches.count >= 500 { break }
        }

        matches.sort { $0.score > $1.score }
        results = Array(matches.prefix(50))
        selectedIndex = 0
    }

    private func fuzzyMatch(query: String, target: String) -> (score: Int, indices: [Int])? {
        var qi = query.startIndex
        var ti = target.startIndex
        var score = 0
        var consecutive = 0
        var indices: [Int] = []
        var tIdx = 0

        while qi < query.endIndex, ti < target.endIndex {
            if query[qi] == target[ti] {
                score += 1 + consecutive * 3
                // Word boundary bonus
                if tIdx == 0 {
                    score += 10
                } else {
                    let prev = target[target.index(before: ti)]
                    if prev == "/" || prev == "." || prev == "_" || prev == "-" || prev == " " {
                        score += 8
                    }
                }
                consecutive += 1
                indices.append(tIdx)
                qi = query.index(after: qi)
            } else {
                consecutive = 0
            }
            ti = target.index(after: ti)
            tIdx += 1
        }
        return qi == query.endIndex ? (score, indices) : nil
    }

    private func openSelected() {
        guard selectedIndex < displayItems.count else { return }
        let match = displayItems[selectedIndex]
        let file = FileItem(name: match.name, url: match.url, isDirectory: false, children: nil)
        state.openFile(file)
        dismiss()
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.1)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isPresented = false
        }
    }
}

// MARK: - Palette Data

private struct PaletteMatch {
    let url: URL
    let name: String
    let matchIndices: [Int]
    var score: Int = 0
}

// MARK: - Palette Row

private struct PaletteRow: View {
    let match: PaletteMatch
    let isSelected: Bool
    let rootPath: String
    let query: String

    var body: some View {
        HStack(spacing: 10) {
            // File icon
            let item = FileItem(name: match.name, url: match.url, isDirectory: false, children: nil)
            Image(nsImage: FileIconResolver.icon(for: item))
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)

            // File name with highlighted matches
            highlightedName
                .lineLimit(1)

            Spacer()

            // Relative path
            let rel = relativePath(match.url.deletingLastPathComponent().path)
            if !rel.isEmpty {
                Text(rel)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.textMuted.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.head)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Theme.accent.opacity(0.18) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Theme.accent.opacity(0.3) : .clear, lineWidth: 1)
        )
    }

    private var highlightedName: some View {
        let name = match.name
        var attr = AttributedString(name)
        attr.foregroundColor = Color(nsColor: .init(srgbRed: 0.65, green: 0.67, blue: 0.71, alpha: 1))
        attr.font = .system(size: 13)

        // Highlight matched characters
        let chars = Array(name)
        for idx in match.matchIndices {
            guard idx < chars.count else { continue }
            let start = name.index(name.startIndex, offsetBy: idx)
            let end = name.index(start, offsetBy: 1)
            if let range = Range(start..<end, in: attr) {
                attr[range].foregroundColor = Theme.accent
                attr[range].font = .system(size: 13, weight: .bold)
            }
        }

        return Text(attr)
    }

    private func relativePath(_ path: String) -> String {
        let root = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        if path.hasPrefix(root) {
            return String(path.dropFirst(root.count))
        }
        return path
    }
}

// MARK: - Draggable Divider

private struct PanelDivider: View {
    let onDrag: (CGFloat) -> Void

    var body: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(width: 1.5)
            .contentShape(Rectangle().inset(by: -3))
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        onDrag(value.translation.width)
                    }
            )
    }
}

// MARK: - Helpers

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    ContentView(showSettings: .constant(false), openFolderTrigger: .constant(false), saveTrigger: .constant(false), saveAsTrigger: .constant(false), zoomInTrigger: .constant(false), zoomOutTrigger: .constant(false), zoomResetTrigger: .constant(false), goToFileTrigger: .constant(false), findInFilesTrigger: .constant(false), toggleSidebarTrigger: .constant(false), toggleTerminalTrigger: .constant(false))
}
