enum AttendanceAction {
    case clockIn
    case clockOut

    var title: String {
        switch self {
        case .clockIn:
            return "출근"
        case .clockOut:
            return "퇴근"
        }
    }

    var code: Int {
        switch self {
        case .clockIn:
            return 1
        case .clockOut:
            return 4
        }
    }

    var tabSelector: String {
        switch self {
        case .clockIn:
            return #"li[onclick="fnSetAttOption(1)"]"#
        case .clockOut:
            return #"li[onclick="fnSetAttOption(4)"]"#
        }
    }

    var submitSelector: String {
        switch self {
        case .clockIn:
            return "#attHref1"
        case .clockOut:
            return "#attHref2"
        }
    }

    var resultSelector: String {
        switch self {
        case .clockIn:
            return "#tab1"
        case .clockOut:
            return "#tab2"
        }
    }
}
