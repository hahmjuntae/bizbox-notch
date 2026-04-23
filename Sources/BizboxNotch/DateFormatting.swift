import Foundation

enum DateFormatting {
    static let menuFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    static let serverFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy.MM.dd HH:mm:ss"
        return formatter
    }()

    static let scheduleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static func menuTime(_ date: Date?) -> String {
        guard let date else {
            return "--:--:--"
        }

        return menuFormatter.string(from: date)
    }

    static func scheduleTime(_ date: Date) -> String {
        scheduleFormatter.string(from: date)
    }

    static func scheduleDate(_ time: String) -> Date {
        scheduleFormatter.date(from: time) ?? scheduleFormatter.date(from: "09:00") ?? Date()
    }
}