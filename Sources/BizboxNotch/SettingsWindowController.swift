import AppKit

final class SettingsWindowController: NSWindowController {
    private let settings: SettingsStore
    private let onSave: () -> Void

    private let siteURLField = NSTextField()
    private let usernameField = NSTextField()
    private let passwordField = NSSecureTextField()

    init(settings: SettingsStore, onSave: @escaping () -> Void) {
        self.settings = settings
        self.onSave = onSave

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Bizbox Notch 설정"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        buildUI()
        loadSettings()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func showWindow(_ sender: Any?) {
        loadSettings()
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
    }

    private func buildUI() {
        guard let contentView = window?.contentView else {
            return
        }

        let titleLabel = NSTextField(labelWithString: "Bizbox 로그인 설정")
        titleLabel.font = .boldSystemFont(ofSize: 17)

        let description = NSTextField(wrappingLabelWithString: "아이디와 비밀번호는 앱 안에 저장됩니다. 비밀번호는 macOS Keychain에 보관합니다.")
        description.textColor = .secondaryLabelColor

        siteURLField.placeholderString = "https://gw.forbiz.co.kr/gw/userMain.do"
        usernameField.placeholderString = "아이디"
        passwordField.placeholderString = "비밀번호"

        let form = NSGridView(views: [
            [label("사이트 URL"), siteURLField],
            [label("아이디"), usernameField],
            [label("비밀번호"), passwordField]
        ])
        form.column(at: 0).xPlacement = .trailing
        form.column(at: 1).width = 300
        form.rowSpacing = 12
        form.columnSpacing = 12

        let saveButton = NSButton(title: "저장", target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"

        let cancelButton = NSButton(title: "닫기", target: self, action: #selector(closeWindow))

        let buttons = NSStackView(views: [cancelButton, saveButton])
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.distribution = .fill
        buttons.spacing = 8

        let buttonRow = NSStackView(views: [NSView(), buttons])
        buttonRow.orientation = .horizontal
        buttonRow.distribution = .fill

        let stack = NSStackView(views: [titleLabel, description, form, buttonRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20),
            buttonRow.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func loadSettings() {
        siteURLField.stringValue = settings.siteURL
        usernameField.stringValue = settings.username
        passwordField.stringValue = settings.password
    }

    @objc private func save() {
        settings.siteURL = siteURLField.stringValue
        settings.username = usernameField.stringValue
        settings.password = passwordField.stringValue
        onSave()
        window?.close()
    }

    @objc private func closeWindow() {
        window?.close()
    }

    private func label(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.alignment = .right
        return label
    }
}
