import AppKit

struct TimeSelection {
    var isPM: Bool
    var hour: Int
    var minute: Int

    init(time24: String) {
        let totalMinutes = SettingsStore.minutes(from: time24) ?? 9 * 60
        let hour24 = totalMinutes / 60
        minute = totalMinutes % 60
        isPM = hour24 >= 12

        let hour12 = hour24 % 12
        hour = hour12 == 0 ? 12 : hour12
    }

    var time24: String {
        var hour24 = hour % 12
        if isPM {
            hour24 += 12
        }
        return String(format: "%02d:%02d", hour24, minute)
    }

    var displayText: String {
        "\(isPM ? "오후" : "오전") \(hour):\(String(format: "%02d", minute))"
    }
}

@MainActor
final class TimeSelectionPopoverController: NSViewController {
    private var selection: TimeSelection
    private let onApply: (String) -> Void
    private let popover: NSPopover

    private let periodControl = NSSegmentedControl(labels: ["오전", "오후"], trackingMode: .selectOne, target: nil, action: nil)
    private let hourLabel = NSTextField(labelWithString: "")
    private let minuteLabel = NSTextField(labelWithString: "")

    init(time24: String, popover: NSPopover, onApply: @escaping (String) -> Void) {
        self.selection = TimeSelection(time24: time24)
        self.popover = popover
        self.onApply = onApply
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 230, height: 176))
        buildUI()
        refreshLabels()
    }

    private func buildUI() {
        periodControl.target = self
        periodControl.action = #selector(periodChanged)

        hourLabel.alignment = .center
        hourLabel.font = .monospacedDigitSystemFont(ofSize: 32, weight: .semibold)
        minuteLabel.alignment = .center
        minuteLabel.font = .monospacedDigitSystemFont(ofSize: 32, weight: .semibold)

        let colon = NSTextField(labelWithString: ":")
        colon.font = .monospacedDigitSystemFont(ofSize: 30, weight: .medium)
        colon.alignment = .center

        let hourUp = arrowButton("▲", action: #selector(incrementHour))
        let hourDown = arrowButton("▼", action: #selector(decrementHour))
        let minuteUp = arrowButton("▲", action: #selector(incrementMinute))
        let minuteDown = arrowButton("▼", action: #selector(decrementMinute))

        let timeGrid = NSGridView(views: [
            [hourUp, NSView(), minuteUp],
            [hourLabel, colon, minuteLabel],
            [hourDown, NSView(), minuteDown]
        ])
        timeGrid.column(at: 0).width = 76
        timeGrid.column(at: 1).width = 22
        timeGrid.column(at: 2).width = 76
        timeGrid.rowSpacing = 2
        timeGrid.columnSpacing = 6

        let cancelButton = NSButton(title: "취소", target: self, action: #selector(cancel))
        let applyButton = NSButton(title: "적용", target: self, action: #selector(apply))
        applyButton.keyEquivalent = "\r"

        let buttonRow = NSStackView(views: [NSView(), cancelButton, applyButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8

        let stack = NSStackView(views: [periodControl, timeGrid, buttonRow])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -14),
            buttonRow.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func arrowButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.font = .systemFont(ofSize: 15, weight: .medium)
        return button
    }

    private func refreshLabels() {
        periodControl.selectedSegment = selection.isPM ? 1 : 0
        hourLabel.stringValue = "\(selection.hour)"
        minuteLabel.stringValue = String(format: "%02d", selection.minute)
    }

    @objc private func periodChanged() {
        selection.isPM = periodControl.selectedSegment == 1
        refreshLabels()
    }

    @objc private func incrementHour() {
        selection.hour = selection.hour == 12 ? 1 : selection.hour + 1
        refreshLabels()
    }

    @objc private func decrementHour() {
        selection.hour = selection.hour == 1 ? 12 : selection.hour - 1
        refreshLabels()
    }

    @objc private func incrementMinute() {
        selection.minute = selection.minute == 59 ? 0 : selection.minute + 1
        refreshLabels()
    }

    @objc private func decrementMinute() {
        selection.minute = selection.minute == 0 ? 59 : selection.minute - 1
        refreshLabels()
    }

    @objc private func cancel() {
        popover.close()
    }

    @objc private func apply() {
        onApply(selection.time24)
        popover.close()
    }
}

final class TimePickerButton: NSButton {
    var time24: String {
        didSet {
            title = TimeSelection(time24: time24).displayText
        }
    }

    init(time24: String) {
        self.time24 = time24
        super.init(frame: NSRect(x: 0, y: 0, width: 120, height: 28))
        title = TimeSelection(time24: time24).displayText
        bezelStyle = .rounded
        target = self
        action = #selector(showPopover)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    @objc private func showPopover() {
        let popover = NSPopover()
        popover.behavior = .transient
        let controller = TimeSelectionPopoverController(time24: time24, popover: popover) { [weak self] newTime in
            self?.time24 = newTime
        }
        popover.contentViewController = controller
        popover.show(relativeTo: bounds, of: self, preferredEdge: .maxY)
    }
}