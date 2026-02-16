<p align="center">
  <img src="app-icon-preview.png" alt="Quantum" width="128" height="128">
</p>

<h1 align="center">Quantum</h1>

<p align="center">
  <strong>The AI IDE that thinks different. Because you do.</strong>
</p>

<p align="center">
  Built native. Built fast. Built for Mac lovers who refuse to settle.
</p>

---

> *"Every other IDE was ported to your Mac.*
> *This one was born here."*

---

<p align="center">
  <img src="app-screenshot.png" alt="Quantum IDE" width="800">
</p>

---

## What is Quantum?

Quantum is a **native AI-powered IDE for macOS** built from the ground up with **SwiftUI** and **Apple's own frameworks** — no Electron, no web views wrapping the entire app, no compromises.

While other editors pretend to be Mac apps, Quantum breathes the same air as Finder, Xcode, and the Dock. It respects your RAM. It respects your battery. It respects *you*.

## Philosophy

```
if editor.isWrappedInChromium {
    throw IdeError.notOnMyMac
}
```

We believe your code editor should be as refined as the machine it runs on. Every pixel, every animation, every interaction — designed for macOS and nothing else.

**One platform. Zero apologies.**

## Features

### Code Editor
- **Syntax highlighting** for 40+ languages powered by CodeMirror 5 — Swift, TypeScript, Python, Rust, Go, and many more
- **JetBrains Mono** embedded font with global zoom (50%–200%)
- Auto-closing brackets, bracket matching, active line highlighting, auto-indentation
- **Auto-save** with 1.5s delay + manual save (`Cmd+S`, `Cmd+Shift+S` for Save As)
- Multi-cursor selection (`Cmd+D` to select all occurrences)

### AI-Powered Editing
- **Inline AI editing** — select code, press `Cmd+K`, describe the change
- Support for **Anthropic** (Claude Opus 4.6, Sonnet 4.5, Haiku 4.5) and **Google** (Gemini 2.5 Pro, 2.5 Flash, 2.0 Flash)
- AI-generated commit messages from your staged diff
- Accept/revert AI changes with visual highlighting
- Model picker in the toolbar — switch models on the fly

### Git Integration
- **Full source control panel** — status, commit, push, pull, discard
- **Multi-repo detection** — scans project root and subdirectories
- **Side-by-side diff viewer** — Myers diff algorithm, synchronized scrolling, syntax-highlighted
- **Git log** — 50 most recent commits with hash, author, and relative timestamps
- **Auto-fetch every 30s** — see incoming (unpulled) commits before you pull
- **Incoming commit badge** on the pull button with count
- **AI commit messages** — one-click generation from your diff via Claude or Gemini
- Discard changes per file or all at once, with confirmation dialogs
- Context-aware — git log and pull follow the currently viewed file's repo

### Integrated Terminal
- **SwiftTerm**-powered terminal with multi-tab support
- Login shell (`~/.zshrc` sourced), 256-color, custom dark theme
- Per-tab working directories inherited from the project
- Session persistence — terminal tabs restored on reopen

### File Explorer
- Hierarchical file tree with expand/collapse
- **200+ file type icons** — custom SVGs for languages, configs, build files, and more
- Create, rename, delete files and folders — context menus and inline editing
- Reveal in Finder
- Smart filtering — skips `node_modules`, `.git`, `build`, `DerivedData`, etc.

### Search
- **Full-text search** across the entire project (`Cmd+F`)
- Incremental background indexing (utility QoS, 50 files per batch)
- Results grouped by file with line numbers and keyword highlighting
- Click any result to jump directly to that line

### Command Palette
- **Fuzzy file search** (`Cmd+P`) with score-based ranking
- Recent files list, keyboard navigation, file icons
- Character-level match highlighting

### Project Management
- **Recent projects** with bookmark persistence (security-scoped URLs)
- Custom project names, open in new window
- Per-project session state — open tabs, expanded folders, panel visibility, terminal tabs
- Auto-restore last project on launch
- Command-line support (`open Quantum.app --args /path/to/project`)

### Welcome Screen
- Animated wave background (12 layers, Canvas-rendered)
- Recent projects quick access with hover actions
- Keyboard shortcut hints

### UI & Layout
- **Three-column layout** — sidebar | editor | terminal
- Resizable panels with drag dividers
- Toggle sidebar (`Cmd+B`) and terminal (`` Cmd+` ``)
- Custom dark theme — emerald green accent, layered depth, custom scrollbars
- **Status bar** — git branch, file name, file type, line count, zoom level
- Tooltips on every button
- Full-size content view with hidden titlebar

### Settings
- API key management for Anthropic and Google
- Enable/disable individual AI models
- Show/hide password fields with validation indicators

## Built With

| | |
|---|---|
| **Language** | Swift — fast, safe, expressive |
| **UI Framework** | SwiftUI — declarative, native, beautiful |
| **Platform** | macOS (Apple Silicon optimized) |
| **Code Editor** | WKWebView + CodeMirror 5 |
| **Terminal** | SwiftTerm |
| **AI Providers** | Anthropic API, Google Gemini API |
| **Source Control** | Git CLI integration |
| **Architecture** | @Observable + async/await with MainActor isolation |
| **Icons** | 200+ custom SVG file icons |
| **Font** | JetBrains Mono (embedded) |

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `Cmd+O` | Open folder |
| `Cmd+S` | Save file |
| `Cmd+Shift+S` | Save As |
| `Cmd+P` | Go to file (command palette) |
| `Cmd+F` | Find in files |
| `Cmd+K` | AI edit selection |
| `Cmd+D` | Select all occurrences |
| `Cmd+B` | Toggle sidebar |
| `` Cmd+` `` | Toggle terminal |
| `Cmd++` | Zoom in |
| `Cmd+-` | Zoom out |
| `Cmd+0` | Reset zoom |
| `Cmd+,` | Settings |

## Why Quantum?

#### It's not a cross-platform afterthought
Every feature is designed for macOS first (and only). Native menus, native shortcuts, native *everything*.

#### It launches before your coffee gets cold
No garbage collector. No JavaScript runtime warming up. Just compiled Swift hitting bare metal.

#### It plays nice with your Mac
Proper window management. Proper dark mode. Proper trackpad gestures. Your Mac, your rules.

#### Your battery will thank you
While Electron editors drain 4GB of RAM rendering a `<textarea>`, Quantum sips resources like fine whiskey.

## AI-Native IDE

Quantum isn't an editor with AI bolted on as an afterthought. It's an **AI IDE** — intelligence is a first-class citizen, not a plugin.

### What works today

- **Inline AI editing** (`Cmd+K`) — select code, describe the change, accept or revert
- **AI commit messages** — one-click generation from your git diff
- **Multi-provider support** — Claude (Opus, Sonnet, Haiku) and Gemini (2.5 Pro, 2.5 Flash, 2.0 Flash)
- **Model picker** in the toolbar — switch between models without leaving your code
- **Terminal-based agents** — Claude Code, Codex CLI, Gemini CLI, Aider all work in the integrated terminal

### Coming next

- Inline AI suggestions as you type
- Agent-aware diff viewer — see what your AI changed at a glance
- Conversation history tied to your project
- Multi-agent orchestration
- Voice-to-code with Whisper + local models
- On-device inference with Apple Neural Engine

## Roadmap

- [x] Native SwiftUI foundation
- [x] Apple Silicon optimized builds
- [x] Code editor with syntax highlighting (40+ languages)
- [x] Integrated terminal (SwiftTerm, multi-tab)
- [x] File explorer with 200+ file type icons
- [x] Full-text search across project
- [x] Command palette with fuzzy search
- [x] Git integration (status, commit, push, pull, discard)
- [x] Side-by-side diff viewer
- [x] Git log with auto-fetch and incoming commits
- [x] AI-powered editing (Cmd+K)
- [x] AI commit message generation
- [x] Multi-provider AI support (Anthropic + Google)
- [x] Multi-tab editor with session persistence
- [x] Project management with recent projects
- [x] Custom dark theme with emerald accent
- [x] Global font zoom (50%–200%)
- [x] Status bar with git branch, file info, zoom
- [x] Settings panel with API key management
- [x] About dialog with tech stack
- [ ] Inline AI suggestions
- [ ] Agent-aware diff viewer
- [ ] Theme engine (light mode, custom themes)
- [ ] Plugin architecture
- [ ] Multi-agent orchestration
- [ ] On-device AI with Apple Neural Engine

## Getting Started

```bash
# Clone the repo
git clone https://github.com/vothaianh/Quantum.git

# Open in Xcode
open quantum.xcodeproj

# Build & Run (Cmd + R)
# That's it. No npm install. No node_modules black hole.
```

**Requirements:**
- macOS 26+
- Xcode 26+
- A deep appreciation for native software

## The Name

**Quantum** — because great code exists in a superposition of possibilities until you run it. And because, like quantum mechanics, the best software is elegant, powerful, and slightly magical.

## Contributing

Quantum is a passion project. If you love macOS and believe native apps still matter, you're already one of us.

---

<p align="center">
  <sub>Made with SwiftUI on a Mac, for a Mac, by someone who actually likes their Mac.</sub>
</p>

<p align="center">
  <strong>Quantum — Write code, not config files.</strong>
</p>
