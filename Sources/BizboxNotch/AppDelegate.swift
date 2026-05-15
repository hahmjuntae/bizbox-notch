import AppKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private lazy var automation = AttendanceAutomation(settings: settings) { [weak self] message in
        self?.showProgress(message)
    }
    private lazy var settingsWindowController = SettingsWindowController(settings: settings) { [weak self] in
        self?.applySettingsChanges()
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
    private var scheduleTimer: Timer?
    private var reminderWindowController: ReminderWindowController?
    private var triggeredReminderKeys = Set<String>()
    private var lastFailureMessage: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if supportsUserNotifications {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] _, _ in
                Task { @MainActor in
                    self?.scheduleWorkdayNotifications()
                }
            }
        }
        configureStatusItem()
        refreshMenu()
        startScheduleTimer()
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
        menu.addItem(NSMenuItem(title: "설정\u{200B}", action: #selector(showSettingsWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "종료", action: #selector(quit), keyEquivalent: ""))

        menu.items.forEach { $0.target = $0.target ?? self }
        menu.items.forEach { $0.image = nil }
        menu.items.forEach { $0.state = .off }
        item.menu = menu
    }

    private func refreshMenu() {
        clockInTimeItem.title = "출근시간: \(DateFormatting.menuTime(settings.lastClockInAt))"
        clockOutTimeItem.title = "퇴근시간: \(DateFormatting.menuTime(settings.lastClockOutAt))"

        if settings.username.isEmpty {
            statusTextItem.title = "설정 필요"
        } else if let lastFailureMessage {
            statusTextItem.title = "실패: \(lastFailureMessage)"
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
            lastFailureMessage = error.localizedDescription
            refreshMenu()
            showNotification(title: "\(action.title) 실패", body: error.localizedDescription)
            return
        }

        lastFailureMessage = nil
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
                lastFailureMessage = error.localizedDescription
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

        lastFailureMessage = nil
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
                    lastFailureMessage = error.localizedDescription
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
            refreshMenu()
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

    private func startScheduleTimer() {
        scheduleTimer?.invalidate()
        let timer = Timer(timeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkScheduleReminder()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        scheduleTimer = timer
        checkScheduleReminder()
    }

    private func checkScheduleReminder(now: Date = Date()) {
        guard reminderWindowController == nil else {
            return
        }

        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        guard let schedule = settings.workdaySchedules.first(where: { $0.weekday == weekday }) else {
            return
        }

        let currentMinute = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)

        if let reminder = dueReminder(
            schedule: schedule,
            currentMinute: currentMinute,
            date: now
        ) {
            showScheduleReminder(reminder.action, scheduledTime: reminder.scheduledTime, date: now)
        }
    }

    private func dueReminder(
        schedule: SettingsStore.WorkdaySchedule,
        currentMinute: Int,
        date: Date
    ) -> (action: AttendanceAction, scheduledTime: String)? {
        [
            (action: AttendanceAction.clockIn, scheduledTime: schedule.clockIn),
            (action: AttendanceAction.clockOut, scheduledTime: schedule.clockOut)
        ]
            .compactMap { reminder -> (action: AttendanceAction, scheduledTime: String, minute: Int)? in
                guard let minute = SettingsStore.minutes(from: reminder.scheduledTime) else {
                    return nil
                }

                return (reminder.action, reminder.scheduledTime, minute)
            }
            .filter { reminder in
                currentMinute == reminder.minute
                    && !triggeredReminderKeys.contains(
                        reminderKey(
                            action: reminder.action,
                            scheduledTime: reminder.scheduledTime,
                            date: date
                        )
                    )
            }
            .max { left, right in
                left.minute < right.minute
            }
            .map { reminder in
                (reminder.action, reminder.scheduledTime)
            }
    }

    private func showScheduleReminder(_ action: AttendanceAction, scheduledTime: String, date: Date) {
        let key = reminderKey(action: action, scheduledTime: scheduledTime, date: date)
        guard !triggeredReminderKeys.contains(key) else {
            return
        }

        triggeredReminderKeys.insert(key)

        let controller = ReminderWindowController(
            action: action,
            scheduledTime: scheduledTime,
            onAction: { [weak self] action in
                self?.run(action)
            },
            onDismiss: { [weak self] in
                self?.reminderWindowController = nil
            }
        )
        reminderWindowController = controller
        controller.showWindow(nil)
    }

    private func reminderKey(action: AttendanceAction, scheduledTime: String, date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)-\(action.title)-\(scheduledTime)"
    }

    private func scheduleWorkdayNotifications() {
        guard supportsUserNotifications else {
            return
        }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: workdayNotificationIdentifiers())

        for schedule in settings.workdaySchedules {
            addWorkdayNotification(center: center, schedule: schedule, action: .clockIn, time: schedule.clockIn)
            addWorkdayNotification(center: center, schedule: schedule, action: .clockOut, time: schedule.clockOut)
        }
    }

    private func addWorkdayNotification(center: UNUserNotificationCenter, schedule: SettingsStore.WorkdaySchedule, action: AttendanceAction, time: String) {
        guard let dateComponents = notificationDateComponents(weekday: schedule.weekday, time: time) else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "\(action.title) 알림"
        content.body = "\(time) \(action.title) 알림 시간입니다."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: workdayNotificationIdentifier(weekday: schedule.weekday, action: action),
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    private func notificationDateComponents(weekday: Int, time: String) -> DateComponents? {
        guard let minuteOfDay = SettingsStore.minutes(from: time) else {
            return nil
        }

        var components = DateComponents()
        components.weekday = weekday
        components.hour = minuteOfDay / 60
        components.minute = minuteOfDay % 60
        return components
    }

    private func workdayNotificationIdentifiers() -> [String] {
        settings.workdaySchedules.flatMap { schedule in
            [
                workdayNotificationIdentifier(weekday: schedule.weekday, action: .clockIn),
                workdayNotificationIdentifier(weekday: schedule.weekday, action: .clockOut)
            ]
        }
    }

    private func workdayNotificationIdentifier(weekday: Int, action: AttendanceAction) -> String {
        "workday-reminder-\(weekday)-\(action.code)"
    }

    private var supportsUserNotifications: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    private func applySettingsChanges() {
        refreshMenu()
        resetScheduleReminders()
        startScheduleTimer()
        scheduleWorkdayNotifications()
    }

    private func resetScheduleReminders() {
        triggeredReminderKeys.removeAll()
        reminderWindowController?.close()
        reminderWindowController = nil
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

    @objc private func showSettingsWindow() {
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
