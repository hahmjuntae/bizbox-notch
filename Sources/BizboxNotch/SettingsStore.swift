import Foundation

final class SettingsStore {
    private enum Keys {
        static let siteURL = "siteURL"
        static let username = "username"
        static let lastClockInAt = "lastClockInAt"
        static let lastClockOutAt = "lastClockOutAt"
        static let lastSiteUpdatedAt = "lastSiteUpdatedAt"
    }

    struct WorkdaySchedule {
        let weekday: Int
        let label: String
        var clockIn: String
        var clockOut: String
    }

    private let defaults: UserDefaults
    private let keychain: KeychainStore

    init(defaults: UserDefaults = .standard, keychain: KeychainStore = .shared) {
        self.defaults = defaults
        self.keychain = keychain
    }

    var siteURL: String {
        get {
            defaults.string(forKey: Keys.siteURL) ?? "https://gw.forbiz.co.kr/gw/userMain.do"
        }
        set {
            defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.siteURL)
        }
    }

    var username: String {
        get {
            defaults.string(forKey: Keys.username) ?? ""
        }
        set {
            defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.username)
        }
    }

    var password: String {
        get {
            keychain.read(account: "bizbox-password") ?? ""
        }
        set {
            keychain.save(newValue, account: "bizbox-password")
        }
    }

    var lastClockInAt: Date? {
        get {
            date(forKey: Keys.lastClockInAt)
        }
        set {
            setDate(newValue, forKey: Keys.lastClockInAt)
        }
    }

    var lastClockOutAt: Date? {
        get {
            date(forKey: Keys.lastClockOutAt)
        }
        set {
            setDate(newValue, forKey: Keys.lastClockOutAt)
        }
    }

    var lastSiteUpdatedAt: Date? {
        get {
            date(forKey: Keys.lastSiteUpdatedAt)
        }
        set {
            setDate(newValue, forKey: Keys.lastSiteUpdatedAt)
        }
    }

    var workdaySchedules: [WorkdaySchedule] {
        get {
            [
                schedule(for: 2, label: "월", defaultClockIn: "08:50", defaultClockOut: "18:10"),
                schedule(for: 3, label: "화", defaultClockIn: "08:20", defaultClockOut: "17:40"),
                schedule(for: 4, label: "수", defaultClockIn: "08:20", defaultClockOut: "17:40"),
                schedule(for: 5, label: "목", defaultClockIn: "08:20", defaultClockOut: "17:40"),
                schedule(for: 6, label: "금", defaultClockIn: "08:50", defaultClockOut: "18:10")
            ]
        }
        set {
            for schedule in newValue {
                defaults.set(schedule.clockIn, forKey: scheduleKey(weekday: schedule.weekday, action: "clockIn"))
                defaults.set(schedule.clockOut, forKey: scheduleKey(weekday: schedule.weekday, action: "clockOut"))
            }
        }
    }

    func lastDate(for action: AttendanceAction) -> Date? {
        switch action {
        case .clockIn:
            return lastClockInAt
        case .clockOut:
            return lastClockOutAt
        }
    }

    func setLastDate(_ date: Date, for action: AttendanceAction) {
        switch action {
        case .clockIn:
            lastClockInAt = date
        case .clockOut:
            lastClockOutAt = date
        }
    }

    func validate() throws {
        guard URL(string: siteURL)?.scheme?.hasPrefix("http") == true else {
            throw AttendanceError.configuration("사이트 URL을 확인하세요.")
        }

        guard !username.isEmpty else {
            throw AttendanceError.configuration("아이디를 설정하세요.")
        }

        guard !password.isEmpty else {
            throw AttendanceError.configuration("비밀번호를 설정하세요.")
        }

        try validateSchedules(workdaySchedules)
    }

    func validateSchedules(_ schedules: [WorkdaySchedule]) throws {
        for schedule in schedules {
            guard Self.minutes(from: schedule.clockIn) != nil else {
                throw AttendanceError.configuration("\(schedule.label)요일 출근 시간을 HH:mm 형식으로 입력하세요.")
            }

            guard Self.minutes(from: schedule.clockOut) != nil else {
                throw AttendanceError.configuration("\(schedule.label)요일 퇴근 시간을 HH:mm 형식으로 입력하세요.")
            }
        }
    }

    static func minutes(from time: String) -> Int? {
        let parts = time.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")

        guard
            parts.count == 2,
            let hour = Int(parts[0]),
            let minute = Int(parts[1]),
            (0...23).contains(hour),
            (0...59).contains(minute)
        else {
            return nil
        }

        return hour * 60 + minute
    }

    private func date(forKey key: String) -> Date? {
        let timestamp = defaults.double(forKey: key)
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }

    private func setDate(_ date: Date?, forKey key: String) {
        if let date {
            defaults.set(date.timeIntervalSince1970, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private func schedule(
        for weekday: Int,
        label: String,
        defaultClockIn: String,
        defaultClockOut: String
    ) -> WorkdaySchedule {
        WorkdaySchedule(
            weekday: weekday,
            label: label,
            clockIn: defaults.string(forKey: scheduleKey(weekday: weekday, action: "clockIn")) ?? defaultClockIn,
            clockOut: defaults.string(forKey: scheduleKey(weekday: weekday, action: "clockOut")) ?? defaultClockOut
        )
    }

    private func scheduleKey(weekday: Int, action: String) -> String {
        "workday.\(weekday).\(action)"
    }
}