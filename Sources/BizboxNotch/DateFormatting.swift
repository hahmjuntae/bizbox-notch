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

    static func menuTime(_ date: Date?) -> String {
        guard let date else {
            return "--:--:--"
        }

        return menuFormatter.string(from: date)
    }
}
