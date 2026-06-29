import AppKit
import DisplayFocusCore

enum BlinkOverlay {
    static let duration: TimeInterval = 45
    static let message = "Blink time · Use your eye drops. Without your eyes, you can't look at this screen forever."
}

enum BlinkOverlayDismissReason {
    case timerElapsed
    case skipConfirmed
}

/// Full-screen **Blink time overlay** on every connected **Display**.
@MainActor
final class BlinkOverlayController {
    private var windows: [NSWindow] = []
    private var contentViews: [BlinkOverlayContentView] = []
    private var dismissTimer: Timer?
    private var dismissDeadline: Date?
    private var eventMonitor: Any?
    private var onComplete: ((BlinkOverlayDismissReason) -> Void)?
    private var isPresented = false
    private var confirmationVisible = false

    func present(onComplete: @escaping (BlinkOverlayDismissReason) -> Void) {
        guard !isPresented else { return }
        isPresented = true
        confirmationVisible = false
        self.onComplete = onComplete

        NSApp.activate(ignoringOtherApps: true)
        startEventMonitor()

        contentViews.removeAll()
        windows.removeAll()
        for screen in NSScreen.screens {
            let contentView = BlinkOverlayContentView(frame: NSRect(origin: .zero, size: screen.frame.size))
            contentView.onSkip = { [weak self] in self?.requestSkip() }
            contentView.onConfirmSkip = { [weak self] in self?.confirmSkip() }
            contentView.onCancelSkip = { [weak self] in self?.cancelSkip() }
            contentViews.append(contentView)

            let window = makeWindow(for: screen, contentView: contentView)
            windows.append(window)
            window.orderFrontRegardless()
        }

        windows.first?.makeKeyAndOrderFront(nil)
        Log.info("blink time: overlay shown")

        dismissDeadline = Date().addingTimeInterval(BlinkOverlay.duration)
        scheduleDismissTimer()
    }

    func dismiss(reason: BlinkOverlayDismissReason) {
        guard isPresented else { return }

        dismissTimer?.invalidate()
        dismissTimer = nil
        dismissDeadline = nil
        confirmationVisible = false
        stopEventMonitor()

        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        contentViews.removeAll()
        isPresented = false

        let callback = onComplete
        onComplete = nil
        callback?(reason)
    }

    private func requestSkip() {
        guard isPresented, !confirmationVisible else { return }
        confirmationVisible = true
        pauseDismissTimer()
        for contentView in contentViews {
            contentView.showConfirmation(true)
        }
        Log.info("blink time: skip confirmation shown")
    }

    private func cancelSkip() {
        guard isPresented, confirmationVisible else { return }
        confirmationVisible = false
        for contentView in contentViews {
            contentView.showConfirmation(false)
        }
        resumeDismissTimer()
        Log.info("blink time: skip cancelled — overlay timer resumed")
    }

    private func confirmSkip() {
        guard isPresented, confirmationVisible else { return }
        dismiss(reason: .skipConfirmed)
        Log.info("blink time: skip confirmed")
    }

    private func scheduleDismissTimer() {
        dismissTimer?.invalidate()
        guard let deadline = dismissDeadline else { return }
        let remaining = deadline.timeIntervalSinceNow
        guard remaining > 0 else {
            dismiss(reason: .timerElapsed)
            return
        }
        dismissTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.dismiss(reason: .timerElapsed) }
        }
    }

    private func pauseDismissTimer() {
        dismissTimer?.invalidate()
        dismissTimer = nil
    }

    private func resumeDismissTimer() {
        scheduleDismissTimer()
    }

    private func makeWindow(for screen: NSScreen, contentView: BlinkOverlayContentView) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.isOpaque = true
        window.backgroundColor = .black
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.contentView = contentView
        window.setFrame(screen.frame, display: true)
        return window
    }

    private func startEventMonitor() {
        guard eventMonitor == nil else { return }
        let mask: NSEvent.EventTypeMask = [
            .keyDown,
            .keyUp,
            .flagsChanged,
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown,
            .scrollWheel,
        ]
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { event in
            nil
        }
    }

    private func stopEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
}

// MARK: - Content view

@MainActor
private final class BlinkOverlayContentView: NSView {
    var onSkip: (() -> Void)?
    var onConfirmSkip: (() -> Void)?
    var onCancelSkip: (() -> Void)?

    private let skipButton = NSButton(title: "Skip", target: nil, action: nil)
    private let confirmationPanel = NSView()
    private let confirmButton = NSButton(title: "Confirm skip", target: nil, action: nil)
    private let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        setupMessage()
        setupSkipButton()
        setupConfirmationPanel()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showConfirmation(_ show: Bool) {
        skipButton.isHidden = show
        confirmationPanel.isHidden = !show
    }

    private func setupMessage() {
        let label = NSTextField(wrappingLabelWithString: BlinkOverlay.message)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.alignment = .center
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        label.drawsBackground = false
        label.font = .systemFont(ofSize: 22, weight: .medium)
        label.maximumNumberOfLines = 0

        addSubview(label)
        let maxWidth = min(600, bounds.width * 0.8)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40),
        ])
    }

    private func setupSkipButton() {
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        skipButton.bezelStyle = .rounded
        skipButton.target = self
        skipButton.action = #selector(skipPressed)
        addSubview(skipButton)

        NSLayoutConstraint.activate([
            skipButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            skipButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -48),
        ])
    }

    private func setupConfirmationPanel() {
        confirmationPanel.translatesAutoresizingMaskIntoConstraints = false
        confirmationPanel.isHidden = true
        addSubview(confirmationPanel)

        let prompt = NSTextField(wrappingLabelWithString: "Skip blink time? Active usage will reset.")
        prompt.translatesAutoresizingMaskIntoConstraints = false
        prompt.textColor = .white
        prompt.alignment = .center
        prompt.isBezeled = false
        prompt.isEditable = false
        prompt.isSelectable = false
        prompt.drawsBackground = false
        prompt.font = .systemFont(ofSize: 16, weight: .medium)
        prompt.maximumNumberOfLines = 0

        confirmButton.target = self
        confirmButton.action = #selector(confirmPressed)
        confirmButton.bezelStyle = .rounded
        confirmButton.keyEquivalent = "\r"

        cancelButton.target = self
        cancelButton.action = #selector(cancelPressed)
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"

        confirmationPanel.addSubview(prompt)

        let buttonStack = NSStackView(views: [cancelButton, confirmButton])
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 12
        confirmationPanel.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            confirmationPanel.centerXAnchor.constraint(equalTo: centerXAnchor),
            confirmationPanel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -48),
            confirmationPanel.widthAnchor.constraint(lessThanOrEqualToConstant: 420),

            prompt.topAnchor.constraint(equalTo: confirmationPanel.topAnchor),
            prompt.leadingAnchor.constraint(equalTo: confirmationPanel.leadingAnchor),
            prompt.trailingAnchor.constraint(equalTo: confirmationPanel.trailingAnchor),

            buttonStack.topAnchor.constraint(equalTo: prompt.bottomAnchor, constant: 16),
            buttonStack.centerXAnchor.constraint(equalTo: confirmationPanel.centerXAnchor),
            buttonStack.bottomAnchor.constraint(equalTo: confirmationPanel.bottomAnchor),
        ])
    }

    @objc private func skipPressed() {
        onSkip?()
    }

    @objc private func confirmPressed() {
        onConfirmSkip?()
    }

    @objc private func cancelPressed() {
        onCancelSkip?()
    }
}
