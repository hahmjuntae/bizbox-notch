import AppKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private lazy var automation = AttendanceAutomation(settings: settings) { [weak self] message in
        self?.showProgress(message)
    }
    private lazy var settingsWindowController = SettingsWindowController(settings: settings) { [weak self] in
        self?.refreshMenu()
    }

    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private let clockInItem = NSMenuItem(title: "출근", action: #selector(clockIn), keyEquivalent: "")
    private let clockOutItem = NSMenuItem(title: "퇴근", action: #selector(clockOut), keyEquivalent: "")
    private let clockInTimeItem = NSMenuItem(title: "출근시간: --:--:--", action: nil, keyEquivalent: "")
    private let clockOutTimeItem = NSMenuItem(title: "퇴근시간: --:--:--", action: nil, keyEquivalent: "")
    private let refreshTimesItem = NSMenuItem(title: "새로고침", action: #selector(refreshTimesFromMenu), keyEquivalent: "")
    private let statusTextItem = NSMenuItem(title: "대기 중", action: nil, keyEquivalent: "")
    private var automationRunning = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        configureStatusItem()
        refreshMenu()
        refreshTimesSilentlyIfConfigured()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = makeStatusIcon()
        item.button?.title = "근태"
        item.button?.imagePosition = .imageLeading
        item.button?.imageScaling = .scaleProportionallyDown
        item.button?.toolTip = "Bizbox Notch 근태"
        statusItem = item

        menu.showsStateColumn = false
        clockInItem.target = self
        clockOutItem.target = self
        refreshTimesItem.target = self
        clockInTimeItem.isEnabled = false
        clockOutTimeItem.isEnabled = false
        statusTextItem.isEnabled = false

        menu.addItem(clockInItem)
        menu.addItem(clockOutItem)
        menu.addItem(.separator())
        menu.addItem(clockInTimeItem)
        menu.addItem(clockOutTimeItem)
        menu.addItem(.separator())
        menu.addItem(refreshTimesItem)
        menu.addItem(.separator())
        menu.addItem(statusTextItem)
        menu.addItem(.separator())
        menu.addItem(makePlainActionItem(title: "설정...", action: #selector(openSettings)))
        menu.addItem(makePlainActionItem(title: "종료", action: #selector(quit)))

        menu.items.forEach { $0.target = $0.target ?? self }
        menu.items.forEach { $0.image = nil }
        menu.items.forEach { $0.state = .off }
        item.menu = menu
    }

    private func makePlainActionItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 180, height: 24))
        let button = NSButton(title: title, target: self, action: action)
        button.alignment = .left
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.image = nil
        button.font = .menuFont(ofSize: NSFont.systemFontSize)
        button.frame = NSRect(x: 18, y: 0, width: 150, height: 24)
        container.addSubview(button)
        item.view = container
        return item
    }

    private func refreshMenu() {
        clockInTimeItem.title = "출근시간: \(DateFormatting.menuTime(settings.lastClockInAt))"
        clockOutTimeItem.title = "퇴근시간: \(DateFormatting.menuTime(settings.lastClockOutAt))"

        if settings.username.isEmpty {
            statusTextItem.title = "설정 필요"
        } else if let lastSiteUpdatedAt = settings.lastSiteUpdatedAt {
            statusTextItem.title = "최근 업데이트: \(DateFormatting.menuTime(lastSiteUpdatedAt))"
        } else {
            statusTextItem.title = "\(settings.username) / 대기 중"
        }
    }

    @objc private func clockIn() {
        run(.clockIn)
    }

    @objc private func clockOut() {
        run(.clockOut)
    }

    private func run(_ action: AttendanceAction) {
        guard !automationRunning else {
            return
        }

        do {
            try settings.validate()
        } catch {
            showNotification(title: "\(action.title) 실패", body: error.localizedDescription)
            openSettings()
            return
        }

        automationRunning = true
        let startedAt = Date()
        setRunning(true, action: action)

        Task { @MainActor in
            var notificationTitle: String?
            var notificationBody: String?
            var failed = false

            do {
                let result = try await automation.run(action)
                if let clockInAt = result.clockInAt {
                    settings.lastClockInAt = clockInAt
                }

                if let clockOutAt = result.clockOutAt {
                    settings.lastClockOutAt = clockOutAt
                }

                settings.lastSiteUpdatedAt = result.fetchedAt

                if result.clockInAt == nil && result.clockOutAt == nil {
                    settings.setLastDate(result.recordedAt, for: action)
                }

                refreshMenu()
                notificationTitle = "\(action.title) 완료"
                notificationBody = result.message
            } catch {
                failed = true
                showFailure(error.localizedDescription)
                notificationTitle = "\(action.title) 실패"
                notificationBody = error.localizedDescription
            }

            await keepBusyIndicatorVisible(since: startedAt)
            if failed {
                await keepFailureVisible()
            }
            setRunning(false, action: action)
            automationRunning = false

            if let notificationTitle, let notificationBody {
                showNotification(title: notificationTitle, body: notificationBody)
            }
        }
    }

    private func setRunning(_ running: Bool, action: AttendanceAction) {
        clockInItem.isEnabled = !running
        clockOutItem.isEnabled = !running
        refreshTimesItem.isEnabled = !running
        statusItem?.button?.image = running ? makeRunningStatusIcon() : makeStatusIcon()

        if running {
            showProgress("\(action.title) 준비 중...")
        } else {
            statusItem?.button?.title = "근태"
            refreshTimesItem.title = "새로고침"
            refreshMenu()
        }
    }

    @objc private func refreshTimesFromMenu() {
        refreshTimes(silent: false)
    }

    private func refreshTimesSilentlyIfConfigured() {
        guard (try? settings.validate()) != nil else {
            return
        }

        refreshTimes(silent: true)
    }

    private func refreshTimes(silent: Bool) {
        guard !automationRunning else {
            return
        }

        automationRunning = true
        let startedAt = Date()
        clockInItem.isEnabled = false
        clockOutItem.isEnabled = false
        refreshTimesItem.isEnabled = false
        statusItem?.button?.image = makeRunningStatusIcon()
        showProgress("접속 준비 중...")

        Task { @MainActor in
            var notificationTitle: String?
            var notificationBody: String?
            var failed = false

            do {
                let snapshot = try await automation.fetchCurrentTimes()
                apply(snapshot)
                refreshMenu()

                if !silent {
                    notificationTitle = "새로고침 완료"
                    notificationBody = refreshNotificationBody(for: snapshot)
                }
            } catch {
                if !silent {
                    failed = true
                    showFailure(error.localizedDescription)
                    notificationTitle = "새로고침 실패"
                    notificationBody = error.localizedDescription
                } else {
                    refreshMenu()
                }
            }

            await keepBusyIndicatorVisible(since: startedAt)
            if failed {
                await keepFailureVisible()
            }
            automationRunning = false
            clockInItem.isEnabled = true
            clockOutItem.isEnabled = true
            refreshTimesItem.isEnabled = true
            refreshTimesItem.title = "새로고침"
            statusItem?.button?.image = makeStatusIcon()
            statusItem?.button?.title = "근태"
            menu.update()

            if let notificationTitle, let notificationBody {
                showNotification(title: notificationTitle, body: notificationBody)
            }
        }
    }

    private func showProgress(_ message: String) {
        statusItem?.button?.image = makeRunningStatusIcon()
        statusItem?.button?.title = message
        statusTextItem.title = message
        refreshTimesItem.title = message
        menu.update()
    }

    private func showFailure(_ message: String) {
        statusItem?.button?.image = makeStatusIcon()
        statusItem?.button?.title = "실패"
        statusTextItem.title = message
        refreshTimesItem.title = "실패"
        menu.update()
    }

    private func keepBusyIndicatorVisible(since startedAt: Date) async {
        let minimumDuration: TimeInterval = 0.0
        let remaining = minimumDuration - Date().timeIntervalSince(startedAt)

        if remaining > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }
    }

    private func keepFailureVisible() async {
        try? await Task.sleep(nanoseconds: 3_000_000_000)
    }

    private func apply(_ snapshot: AttendanceSnapshot) {
        settings.lastClockInAt = snapshot.clockInAt
        settings.lastClockOutAt = snapshot.clockOutAt
        settings.lastSiteUpdatedAt = snapshot.fetchedAt
    }

    private func refreshNotificationBody(for snapshot: AttendanceSnapshot) -> String {
        let clockIn = DateFormatting.menuTime(snapshot.clockInAt)
        let clockOut = DateFormatting.menuTime(snapshot.clockOutAt)
        return "출근 \(clockIn) / 퇴근 \(clockOut)"
    }

    private func makeStatusIcon() -> NSImage {
        if let image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "근태") {
            image.isTemplate = true
            return image
        }

        return drawFallbackIcon(strokeOnly: false)
    }

    private func makeRunningStatusIcon() -> NSImage {
        if let image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath.circle", accessibilityDescription: "근태 처리 중") {
            image.isTemplate = true
            return image
        }

        return drawFallbackIcon(strokeOnly: true)
    }

    private func drawFallbackIcon(strokeOnly: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()

        NSColor.labelColor.setStroke()
        NSColor.labelColor.setFill()

        let circle = NSBezierPath(ovalIn: NSRect(x: 2.5, y: 2.5, width: 13, height: 13))
        circle.lineWidth = 1.8
        circle.stroke()

        let check = NSBezierPath()
        check.move(to: NSPoint(x: 5.2, y: 9.0))
        check.line(to: NSPoint(x: 8.0, y: 6.2))
        check.line(to: NSPoint(x: 13.0, y: 11.5))
        check.lineWidth = strokeOnly ? 1.5 : 2.0
        check.lineCapStyle = .round
        check.lineJoinStyle = .round
        check.stroke()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    @objc private func openSettings() {
        menu.cancelTracking()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController.showWindow(nil)
    }

    @objc private func quit() {
        menu.cancelTracking()
        NSApp.terminate(nil)
    }

    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}