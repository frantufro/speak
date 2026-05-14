import AppKit
import SpeakKit

/// A borderless, transparent, non-activating window rendered above all other
/// content (including full-screen apps).
///
/// - Click-through: mouse events are *not* consumed by this window.
/// - Not in ⌘+Tab / Dock.
/// - Shown on every desktop Space.
final class OverlayWindow: NSWindow {
    private let pillView = OverlayPillView()

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 44),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        // Non-activating: the window never becomes key/main, so the
        // underlying app keeps focus.
        level = .floating
        ignoresMouseEvents = true
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,   // excluded from ⌘+Tab
            .fullScreenAuxiliary,
        ]
        isReleasedWhenClosed = false
        contentView = pillView
    }

    func update(state: CaptureCoordinator.State) {
        pillView.update(state: state)
        sizeToFit()
    }

    private func sizeToFit() {
        let size = pillView.intrinsicContentSize
        setContentSize(size)
        pillView.frame = NSRect(origin: .zero, size: size)
    }
}

// MARK: - Pill view

private final class OverlayPillView: NSView {
    private let label = NSTextField(labelWithString: "")
    private let dot = DotView()
    private let spinner: NSProgressIndicator = {
        let s = NSProgressIndicator()
        s.style = .spinning
        s.controlSize = .small
        s.isIndeterminate = true
        s.startAnimation(nil)
        return s
    }()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.masksToBounds = true

        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false

        addSubview(dot)
        addSubview(spinner)
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 160, height: 40)
    }

    func update(state: CaptureCoordinator.State) {
        switch state {
        case .recording:
            layer?.backgroundColor = NSColor(white: 0.12, alpha: 0.82).cgColor
            label.stringValue = "Recording…"
            dot.isHidden = false
            spinner.isHidden = true
            dot.startAnimating()
        case .transcribing:
            layer?.backgroundColor = NSColor(white: 0.12, alpha: 0.82).cgColor
            label.stringValue = "Transcribing…"
            dot.isHidden = true
            spinner.isHidden = false
        default:
            break
        }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let h = bounds.height
        let padding: CGFloat = 12
        let iconSize: CGFloat = 16

        // Icon (dot or spinner) at left, label to the right.
        let iconY = (h - iconSize) / 2
        dot.frame = NSRect(x: padding, y: iconY, width: iconSize, height: iconSize)
        spinner.frame = NSRect(x: padding, y: iconY, width: iconSize, height: iconSize)

        let labelX = padding + iconSize + 6
        let labelW = bounds.width - labelX - padding
        let labelH = label.intrinsicContentSize.height
        label.frame = NSRect(x: labelX, y: (h - labelH) / 2, width: labelW, height: labelH)
    }
}

// MARK: - Animated dot

@MainActor
private final class DotView: NSView {
    private var animTimer: Timer?
    private var bright = true

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.backgroundColor = NSColor.systemRed.cgColor
    }

    func startAnimating() {
        animTimer?.invalidate()
        bright = true
        updateColor()
        animTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.bright.toggle()
                self.updateColor()
            }
        }
    }

    func stopAnimating() {
        animTimer?.invalidate()
        animTimer = nil
    }

    private func updateColor() {
        layer?.backgroundColor = (bright ? NSColor.systemRed : NSColor.systemRed.withAlphaComponent(0.4)).cgColor
    }
}
