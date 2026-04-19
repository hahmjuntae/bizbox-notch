import AppKit
import Foundation
import WebKit

struct AttendanceResult {
    let recordedAt: Date
    let fetchedAt: Date
    let clockInAt: Date?
    let clockOutAt: Date?
    let message: String
}

struct AttendanceSnapshot {
    let fetchedAt: Date
    let clockInAt: Date?
    let clockOutAt: Date?
    let sourceURL: String
    let rawClockInText: String
    let rawClockOutText: String

    func date(for action: AttendanceAction) -> Date? {
        switch action {
        case .clockIn:
            return clockInAt
        case .clockOut:
            return clockOutAt
        }
    }
}

@MainActor
final class AttendanceAutomation: NSObject, WKNavigationDelegate, WKUIDelegate {
    typealias ProgressHandler = @MainActor (String) -> Void

    private let settings: SettingsStore
    private let onProgress: ProgressHandler?
    private var webView: WKWebView?
    private var hiddenWindow: NSWindow?
    private var navigationContinuation: CheckedContinuation<Void, Error>?
    private var navigationTimeoutTask: Task<Void, Never>?
    private var lastAlertMessage: String?
    private var lastConfirmMessage: String?

    init(settings: SettingsStore, onProgress: ProgressHandler? = nil) {
        self.settings = settings
        self.onProgress = onProgress
    }

    func run(_ action: AttendanceAction) async throws -> AttendanceResult {
        try settings.validate()
        lastAlertMessage = nil
        lastConfirmMessage = nil

        let url = URL(string: settings.siteURL)!
        reportProgress("세션 초기화 중...")
        await clearBrowserSession()
        prepareWebView().stopLoading()

        reportProgress("접속 중...")
        try await load(freshURL(from: url))
        try await loginIfNeeded()

        reportProgress("확인 중...")
        try await waitForAttendanceTabs()
        return try await clickAttendance(action)
    }

    func fetchCurrentTimes() async throws -> AttendanceSnapshot {
        try settings.validate()
        lastAlertMessage = nil
        lastConfirmMessage = nil

        let url = URL(string: settings.siteURL)!
        reportProgress("세션 초기화 중...")
        await clearBrowserSession()
        prepareWebView().stopLoading()

        reportProgress("접속 중...")
        try await load(freshURL(from: url))
        try await loginIfNeeded()

        reportProgress("확인 중...")
        try await waitForAttendanceTabs()

        reportProgress("시간 반영 중...")
        return try await displayedAttendanceSnapshot()
    }

    @discardableResult
    private func prepareWebView() -> WKWebView {
        if let webView {
            return webView
        }

        let webView = makeWebView()
        self.webView = webView
        self.hiddenWindow = makeHiddenWindow(webView: webView)
        return webView
    }

    private func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1200, height: 900), configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        return webView
    }

    private func makeHiddenWindow(webView: WKWebView) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: 1200, height: 900),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = webView
        return window
    }

    private func resetNavigationState() {
        navigationContinuation = nil
        navigationTimeoutTask?.cancel()
        navigationTimeoutTask = nil
    }

    private func clearBrowserSession() async {
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()

        await withCheckedContinuation { continuation in
            dataStore.removeData(ofTypes: dataTypes, modifiedSince: .distantPast) {
                continuation.resume()
            }
        }
    }

    private func load(_ url: URL) async throws {
        resetNavigationState()

        guard let webView else {
            throw AttendanceError.automation("자동화 브라우저를 시작하지 못했습니다.")
        }

        try await withCheckedThrowingContinuation { continuation in
            navigationContinuation = continuation
            navigationTimeoutTask?.cancel()
            navigationTimeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 30_000_000_000)

                guard let self, !Task.isCancelled, let continuation = self.navigationContinuation else {
                    return
                }

                self.navigationContinuation = nil
                continuation.resume(throwing: AttendanceError.automation("사이트 로딩 시간이 초과되었습니다."))
            }

            webView.load(URLRequest(
                url: url,
                cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                timeoutInterval: 30
            ))
        }
    }

    private func loginIfNeeded() async throws {
        reportProgress("로그인 확인 중...")
        let isLoginPage = try await boolJS("Boolean(document.querySelector('#userId') && document.querySelector('#userPw'))")

        if !isLoginPage {
            return
        }

        reportProgress("로그인 중...")
        let username = try jsLiteral(settings.username)
        let password = try jsLiteral(settings.password)

        do {
            _ = try await boolJS("""
        (function() {
            document.querySelector("#userId").value = \(username);
            document.querySelector("#userPw").value = \(password);
            if (typeof actionLogin === "function") {
                actionLogin();
            } else {
                document.querySelector(".log_btn")?.click();
            }
            return true;
        })();
        """)
        } catch {
            if lastAlertMessage == nil {
                // Submitting the login form can interrupt the JavaScript callback while navigation starts.
            } else {
                throw error
            }
        }

        try await waitForCondition(
            #"Boolean(document.querySelector('li[onclick="fnSetAttOption(1)"]') && document.querySelector('li[onclick="fnSetAttOption(4)"]'))"#,
            timeout: 30,
            failureMessage: lastAlertMessage ?? "로그인 후 근태 영역을 찾지 못했습니다."
        )
    }

    private func waitForAttendanceTabs() async throws {
        try await waitForCondition(
            #"Boolean(document.querySelector('li[onclick="fnSetAttOption(1)"]') && document.querySelector('li[onclick="fnSetAttOption(4)"]'))"#,
            timeout: 20,
            failureMessage: "출근/퇴근 탭을 찾지 못했습니다."
        )
    }

    private func clickAttendance(_ action: AttendanceAction) async throws -> AttendanceResult {
        let tabSelector = try jsLiteral(action.tabSelector)
        let submitSelector = try jsLiteral(action.submitSelector)

        reportProgress("\(action.title) 선택 중...")
        let tabClicked = try await boolJS("""
        (function() {
            const tab = document.querySelector(\(tabSelector));
            if (!tab) return false;
            tab.click();
            return true;
        })();
        """)

        guard tabClicked else {
            throw AttendanceError.automation("\(action.title) 탭을 찾지 못했습니다.")
        }

        try await waitForCondition(
            "Boolean(document.querySelector(\(tabSelector))?.classList.contains('active'))",
            timeout: 5,
            failureMessage: "\(action.title) 탭을 활성화하지 못했습니다."
        )

        let previousTime = try await displayedServerTime(for: action)
        lastAlertMessage = nil
        lastConfirmMessage = nil

        reportProgress("\(action.title) 처리 중...")
        let submitted = try await boolJS("""
        (function() {
            const submit = document.querySelector(\(submitSelector));
            if (!submit || typeof submit.click !== "function") return false;
            submit.click();
            return true;
        })();
        """)

        guard submitted else {
            throw AttendanceError.automation("\(action.title) 처리 버튼을 찾지 못했습니다.")
        }

        reportProgress("결과 확인 중...")
        return try await waitForAttendanceResult(action, previousTime: previousTime)
    }

    private func waitForAttendanceResult(_ action: AttendanceAction, previousTime: Date?) async throws -> AttendanceResult {
        let deadline = Date().addingTimeInterval(20)
        var alertSeenAt: Date?
        var lastObservedTime: Date?

        while Date() < deadline {
            if let currentTime = try await displayedServerTime(for: action) {
                lastObservedTime = currentTime

                if isNewTime(currentTime, comparedTo: previousTime) {
                    reportProgress("시간 반영 중...")
                    let snapshot = try await displayedAttendanceSnapshot()
                    return AttendanceResult(
                        recordedAt: currentTime,
                        fetchedAt: snapshot.fetchedAt,
                        clockInAt: snapshot.clockInAt,
                        clockOutAt: snapshot.clockOutAt,
                        message: lastAlertMessage ?? "\(action.title) 처리 시간이 기록되었습니다."
                    )
                }
            }

            if let alertMessage = lastAlertMessage {
                if isFailureMessage(alertMessage) {
                    throw AttendanceError.automation(alertMessage)
                }

                if alertSeenAt == nil {
                    alertSeenAt = Date()
                }

                if let alertSeenAt, Date().timeIntervalSince(alertSeenAt) >= 3 {
                    if lastObservedTime != nil {
                        throw AttendanceError.automation(
                            "\(alertMessage) 기존 \(action.title) 시간과 동일해서 새 처리 여부를 확인하지 못했습니다."
                        )
                    }

                    throw AttendanceError.automation(alertMessage)
                }
            }

            try await Task.sleep(nanoseconds: 250_000_000)
        }

        if let lastAlertMessage {
            throw AttendanceError.automation(lastAlertMessage)
        }

        if let lastConfirmMessage {
            throw AttendanceError.automation("\(lastConfirmMessage) 이후 사이트 처리 결과를 확인하지 못했습니다.")
        }

        throw AttendanceError.automation("\(action.title) 처리 후 Bizbox 화면에서 새 시간을 확인하지 못했습니다.")
    }

    private func displayedServerTime(for action: AttendanceAction) async throws -> Date? {
        try await displayedAttendanceSnapshot().date(for: action)
    }

    private func displayedAttendanceSnapshot() async throws -> AttendanceSnapshot {
        let sourceURL = try await stringJS("window.location.href")
        let rawClockInText = try await tabText(selector: "#tab1")
        let rawClockOutText = try await tabText(selector: "#tab2")

        return AttendanceSnapshot(
            fetchedAt: Date(),
            clockInAt: parseServerTime(from: rawClockInText),
            clockOutAt: parseServerTime(from: rawClockOutText),
            sourceURL: sourceURL,
            rawClockInText: rawClockInText,
            rawClockOutText: rawClockOutText
        )
    }

    private func tabText(selector: String) async throws -> String {
        let selector = try jsLiteral(selector)
        return try await stringJS("""
        (function() {
            const element = document.querySelector(\(selector));
            return (element?.innerText || element?.textContent || "").trim().replace(/\\s+/g, " ");
        })();
        """)
    }

    private func parseServerTime(from text: String) -> Date? {
        guard
            let match = text.range(
                of: #"\d{4}\.\d{2}\.\d{2}\s+\d{2}:\d{2}:\d{2}"#,
                options: .regularExpression
            )
        else {
            return nil
        }

        return DateFormatting.serverFormatter.date(from: String(text[match]))
    }

    private func freshURL(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        var queryItems = components.queryItems ?? []
        queryItems.removeAll { $0.name == "_bizboxNotchRefresh" }
        queryItems.append(URLQueryItem(
            name: "_bizboxNotchRefresh",
            value: String(Int(Date().timeIntervalSince1970 * 1000))
        ))
        components.queryItems = queryItems

        return components.url ?? url
    }

    private func isNewTime(_ currentTime: Date, comparedTo previousTime: Date?) -> Bool {
        guard let previousTime else {
            return true
        }

        return abs(currentTime.timeIntervalSince(previousTime)) >= 1
    }

    private func isFailureMessage(_ message: String) -> Bool {
        let lowered = message.lowercased()
        let failureMarkers = ["실패", "오류", "에러", "불가", "이미", "중복", "권한", "허용", "error", "fail"]
        return failureMarkers.contains { lowered.contains($0) }
    }

    private func waitForCondition(_ script: String, timeout: TimeInterval, failureMessage: String) async throws {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if try await boolJS(script) {
                return
            }

            if lastAlertMessage != nil {
                return
            }

            try await Task.sleep(nanoseconds: 250_000_000)
        }

        throw AttendanceError.automation(failureMessage)
    }

    private func reportProgress(_ message: String) {
        onProgress?(message)
    }

    private func boolJS(_ script: String) async throws -> Bool {
        guard let webView else {
            throw AttendanceError.automation("자동화 브라우저가 종료되었습니다.")
        }

        return try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result as? Bool ?? false)
                }
            }
        }
    }

    private func stringJS(_ script: String) async throws -> String {
        guard let webView else {
            throw AttendanceError.automation("자동화 브라우저가 종료되었습니다.")
        }

        return try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result as? String ?? "")
                }
            }
        }
    }

    private func jsLiteral(_ value: String) throws -> String {
        let data = try JSONEncoder().encode(value)
        return String(data: data, encoding: .utf8) ?? "\"\""
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationTimeoutTask?.cancel()
        navigationTimeoutTask = nil
        navigationContinuation?.resume()
        navigationContinuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        navigationTimeoutTask?.cancel()
        navigationTimeoutTask = nil
        navigationContinuation?.resume(throwing: error)
        navigationContinuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        navigationTimeoutTask?.cancel()
        navigationTimeoutTask = nil
        navigationContinuation?.resume(throwing: error)
        navigationContinuation = nil
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor @Sendable () -> Void
    ) {
        lastAlertMessage = message
        completionHandler()
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor @Sendable (Bool) -> Void
    ) {
        lastConfirmMessage = message
        completionHandler(true)
    }
}