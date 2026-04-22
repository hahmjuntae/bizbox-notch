import Foundation

enum LoginItemError: LocalizedError {
    case missingApplicationBundle
    case propertyListEncodingFailed

    var errorDescription: String? {
        switch self {
        case .missingApplicationBundle:
            return "앱 번들 경로를 찾지 못했습니다."
        case .propertyListEncodingFailed:
            return "로그인 항목 설정 파일을 만들지 못했습니다."
        }
    }
}

@MainActor
final class LoginItemManager {
    static let shared = LoginItemManager()

    private let label = "com.hahmjuntae.bizbox-notch.login"
    private let fileManager = FileManager.default

    var isEnabled: Bool {
        fileManager.fileExists(atPath: launchAgentURL.path)
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try installLaunchAgent()
        } else {
            removeLaunchAgent()
        }
    }

    private func installLaunchAgent() throws {
        try fileManager.createDirectory(
            at: launchAgentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/usr/bin/open", applicationPath],
            "RunAtLoad": true
        ]

        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: launchAgentURL, options: .atomic)
    }

    private func removeLaunchAgent() {
        try? fileManager.removeItem(at: launchAgentURL)
    }

    private var launchAgentURL: URL {
        let libraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return libraryURL
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist")
    }

    private var applicationPath: String {
        let bundleURL = Bundle.main.bundleURL

        if bundleURL.pathExtension == "app" {
            return bundleURL.path
        }

        return "/Applications/Bizbox Notch.app"
    }
}