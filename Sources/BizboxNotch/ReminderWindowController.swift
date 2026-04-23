import AppKit

@MainActor
final class ReminderWindowController: NSWindowController {
    private let action: AttendanceAction
    private let onAction: (AttendanceAction) -> Void
    private let onDismiss: () -> Void

    init(action: AttendanceAction, scheduledTime: String, onAction: @escaping (AttendanceAction) -> Void, onDismiss: @escaping () -> Void) {
        self.action = action
        self.onAction = onAction
        self.onDismiss = onDismiss

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 128),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Bizbox Notch"
        window.level = .modalPanel
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.isMovableByWindowBackground = true

        super.init(window: window)
        buildUI(scheduledTime: scheduledTime)
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func showWindow(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
    }

    override func close() {
        onDismiss()
        super.close()
    }

    private func buildUI(scheduledTime: String) {
        guard let contentView = window?.contentView else {
            return
        }

        let titleLabel = NSTextField(labelWithString: "\(action.title) 알림")
        titleLabel.font = .boldSystemFont(ofSize: 17)

        let message = "\(scheduledTime) \(action.title) 알림 시간입니다."
        let messageLabel = NSTextField(wrappingLabelWithString: message)
        messageLabel.textColor = .secondaryLabelColor

        let actionButton = NSButton(title: action.title, target: self, action: #selector(runAction))
        actionButton.keyEquivalent = "\r"

        let closeButton = NSButton(title: "닫기", target: self, action: #selector(closeWindow))

        let buttons = NSStackView(views: [closeButton, actionButton])
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 8

        let buttonRow = NSStackView(views: [NSView(), buttons])
        buttonRow.orientation = .horizontal

        let stack = NSStackView(views: [titleLabel, messageLabel, buttonRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),
            buttonRow.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    @objc private func runAction() {
        window?.close()
        onAction(action)
    }

    @objc private func closeWindow() {
        window?.close()
    }
}