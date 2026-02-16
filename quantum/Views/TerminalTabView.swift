import SwiftUI
import SwiftTerm

struct TerminalTabView: NSViewRepresentable {
    let tab: TerminalTab
    let isActive: Bool
    @Environment(\.fontZoom) private var zoom

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let container = NSView(frame: .zero)
        container.wantsLayer = true

        let termView = LocalProcessTerminalView(frame: .zero)

        let bgColor = NSColor(srgbRed: 0.059, green: 0.059, blue: 0.059, alpha: 1)
        let fgColor = NSColor(srgbRed: 0.847, green: 0.910, blue: 0.875, alpha: 1)

        termView.nativeBackgroundColor = bgColor
        termView.nativeForegroundColor = fgColor
        termView.optionAsMetaKey = false

        let fontSize = 11.0 * zoom
        termView.font = NSFont(name: "Menlo", size: fontSize) ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["TERM_PROGRAM"] = "Quantum"
        env["COLORTERM"] = "truecolor"
        env.removeValue(forKey: "CLAUDECODE")

        let cwd = tab.workingDirectory?.path ?? NSHomeDirectory()
        env["HOME"] = NSHomeDirectory()

        termView.startProcess(
            executable: shell,
            args: ["--login"],
            environment: env.map { "\($0.key)=\($0.value)" },
            execName: "-" + (shell as NSString).lastPathComponent,
            currentDirectory: cwd
        )

        if tab.workingDirectory != nil {
            termView.send(txt: "clear\n")
        }

        termView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(termView)

        // URL overlay sits on top of the terminal
        let overlay = TerminalURLOverlay(terminalView: termView)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(overlay)

        NSLayoutConstraint.activate([
            termView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            termView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            termView.topAnchor.constraint(equalTo: container.topAnchor),
            termView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: container.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        context.coordinator.termView = termView
        context.coordinator.overlay = overlay

        if isActive {
            DispatchQueue.main.async {
                termView.window?.makeFirstResponder(termView)
            }
        }

        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        guard let termView = context.coordinator.termView else { return }
        let fontSize = 11.0 * zoom
        termView.font = NSFont(name: "Menlo", size: fontSize) ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        if isActive {
            DispatchQueue.main.async {
                if termView.window?.firstResponder !== termView {
                    termView.window?.makeFirstResponder(termView)
                }
            }
        }
    }

    class Coordinator {
        var termView: LocalProcessTerminalView?
        var overlay: TerminalURLOverlay?
    }
}

// MARK: - Terminal URL Overlay

/// Transparent overlay that detects URLs under mouse when Cmd is held.
/// Passes all events through to the terminal except Cmd+click on URLs.
final class TerminalURLOverlay: NSView {

    private static let urlPattern: NSRegularExpression = {
        let pattern = #"https?://[^\s\]\)\>\"\'\`\,\;\|]+"#
        return try! NSRegularExpression(pattern: pattern, options: [])
    }()

    private weak var terminalView: LocalProcessTerminalView?
    private var underlineLayer: CALayer?
    private var detectedURL: String?
    private var cmdHeld = false
    private var trackingArea: NSTrackingArea?

    init(terminalView: LocalProcessTerminalView) {
        self.terminalView = terminalView
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        let ta = NSTrackingArea(
            rect: bounds,
            options: [.activeInActiveApp, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self
        )
        addTrackingArea(ta)
        trackingArea = ta
    }

    // MARK: - Hit test — pass through unless Cmd+hovering a URL

    override func hitTest(_ point: NSPoint) -> NSView? {
        if cmdHeld, let _ = detectedURL {
            return self
        }
        return nil  // Pass through to terminal
    }

    // MARK: - Flag changes (Cmd key)

    override func flagsChanged(with event: NSEvent) {
        let wasCmd = cmdHeld
        cmdHeld = event.modifierFlags.contains(.command)

        if cmdHeld && !wasCmd {
            checkForURL(at: event)
        } else if !cmdHeld && wasCmd {
            clearHighlight()
        }

        super.flagsChanged(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        if cmdHeld {
            checkForURL(at: event)
        }
        super.mouseMoved(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        if cmdHeld, let urlString = detectedURL, let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
            clearHighlight()
            return
        }
        super.mouseDown(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        clearHighlight()
        super.mouseExited(with: event)
    }

    // MARK: - URL detection

    private func checkForURL(at event: NSEvent) {
        guard let termView = terminalView else { return }

        let localPoint = termView.convert(event.locationInWindow, from: nil)
        let cellSize = computeCellSize(for: termView.font)
        guard cellSize.width > 0, cellSize.height > 0 else {
            clearHighlight()
            return
        }

        let col = Int(localPoint.x / cellSize.width)
        let row = Int((termView.frame.height - localPoint.y) / cellSize.height)

        guard row >= 0, row < termView.terminal.rows,
              let line = termView.terminal.getLine(row: row) else {
            clearHighlight()
            return
        }

        let lineText = line.translateToString(trimRight: true)

        let nsString = lineText as NSString
        let matches = Self.urlPattern.matches(in: lineText, range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            let range = match.range
            if col >= range.location && col < range.location + range.length {
                let url = nsString.substring(with: range)
                detectedURL = url
                NSCursor.pointingHand.push()
                drawUnderline(row: row, colStart: range.location, colEnd: range.location + range.length, cellSize: cellSize, in: termView)
                return
            }
        }

        clearHighlight()
    }

    private func drawUnderline(row: Int, colStart: Int, colEnd: Int, cellSize: CGSize, in termView: NSView) {
        underlineLayer?.removeFromSuperlayer()

        let layer = CALayer()
        // Position underline at the bottom of the character cell
        let y = termView.frame.height - CGFloat(row + 1) * cellSize.height + 1
        let termOrigin = termView.convert(CGPoint.zero, to: self)

        layer.frame = CGRect(
            x: termOrigin.x + CGFloat(colStart) * cellSize.width,
            y: termOrigin.y + y,
            width: CGFloat(colEnd - colStart) * cellSize.width,
            height: 1
        )
        layer.backgroundColor = NSColor(srgbRed: 0.4, green: 0.85, blue: 0.6, alpha: 0.8).cgColor
        self.layer?.addSublayer(layer)
        underlineLayer = layer
    }

    private func clearHighlight() {
        if underlineLayer != nil || detectedURL != nil {
            underlineLayer?.removeFromSuperlayer()
            underlineLayer = nil
            detectedURL = nil
            NSCursor.pop()
        }
    }

    private func computeCellSize(for font: NSFont) -> CGSize {
        let ctFont = font as CTFont
        let ascent = CTFontGetAscent(ctFont)
        let descent = CTFontGetDescent(ctFont)
        let leading = CTFontGetLeading(ctFont)
        let height = ceil(ascent + descent + leading)

        var glyph: CGGlyph = 0
        let chars: [UniChar] = [0x57] // 'W'
        CTFontGetGlyphsForCharacters(ctFont, chars, &glyph, 1)
        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(ctFont, .horizontal, [glyph], &advance, 1)
        let width = ceil(advance.width)

        return CGSize(width: max(1, width), height: max(1, height))
    }
}
