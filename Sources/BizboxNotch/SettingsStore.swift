import Foundation

final class SettingsStore {
    private enum Keys {
        static let siteURL = "siteURL"
        static let username = "username"
        static let lastClockInAt = "lastClockInAt"
        static let lastClockOutAt = "lastClockOutAt"
        static let lastSiteUpdatedAt = "lastSiteUpdatedAt"
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
}
