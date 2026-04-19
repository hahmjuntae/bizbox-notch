import Foundation

enum AttendanceError: LocalizedError {
    case configuration(String)
    case automation(String)

    var errorDescription: String? {
        switch self {
        case .configuration(let message), .automation(let message):
            return message
        }
    }
}
