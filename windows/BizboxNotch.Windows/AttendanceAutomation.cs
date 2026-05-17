using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

namespace BizboxNotch.Windows;

internal sealed class AttendanceAutomation : IDisposable
{
    private readonly SettingsStore settings;
    private readonly Action<string>? onProgress;
    private Form? hiddenForm;
    private WebView2? webView;
    private string? lastAlertMessage;
    private string? lastConfirmMessage;
    private bool disposed;

    public AttendanceAutomation(SettingsStore settings, Action<string>? onProgress = null)
    {
        this.settings = settings;
        this.onProgress = onProgress;
    }

    public async Task<AttendanceResult> RunAsync(AttendanceAction action)
    {
        settings.Validate();
        lastAlertMessage = null;
        lastConfirmMessage = null;

        var url = new Uri(settings.SiteUrl);
        ReportProgress("세션 초기화 중...");
        await PrepareWebViewAsync();
        await webView!.CoreWebView2.Profile.ClearBrowsingDataAsync();

        ReportProgress("접속 중...");
        await NavigateAsync(FreshUrl(url));
        await LoginIfNeededAsync();

        ReportProgress("확인 중...");
        await WaitForAttendanceTabsAsync();
        return await ClickAttendanceAsync(action);
    }

    public async Task<AttendanceSnapshot> FetchCurrentTimesAsync()
    {
        settings.Validate();
        lastAlertMessage = null;
        lastConfirmMessage = null;

        var url = new Uri(settings.SiteUrl);
        ReportProgress("세션 초기화 중...");
        await PrepareWebViewAsync();
        await webView!.CoreWebView2.Profile.ClearBrowsingDataAsync();

        ReportProgress("접속 중...");
        await NavigateAsync(FreshUrl(url));
        await LoginIfNeededAsync();

        ReportProgress("확인 중...");
        await WaitForAttendanceTabsAsync();

        ReportProgress("시간 반영 중...");
        return await DisplayedAttendanceSnapshotAsync();
    }

    public void Dispose()
    {
        if (disposed)
        {
            return;
        }

        disposed = true;
        webView?.Dispose();
        hiddenForm?.Dispose();
    }

    private async Task PrepareWebViewAsync()
    {
        if (webView is not null)
        {
            webView.Stop();
            return;
        }

        hiddenForm = new Form
        {
            ShowInTaskbar = false,
            StartPosition = FormStartPosition.Manual,
            Location = new Point(-10000, -10000),
            Size = new Size(1200, 900),
            FormBorderStyle = FormBorderStyle.None
        };

        webView = new WebView2
        {
            Dock = DockStyle.Fill,
            Visible = true
        };
        hiddenForm.Controls.Add(webView);
        hiddenForm.Show();

        await webView.EnsureCoreWebView2Async();
        webView.CoreWebView2.ScriptDialogOpening += (_, args) =>
        {
            if (args.Kind == CoreWebView2ScriptDialogKind.Confirm)
            {
                lastConfirmMessage = args.Message;
                args.Accept();
            }
            else
            {
                lastAlertMessage = args.Message;
                args.Accept();
            }
        };
    }

    private async Task NavigateAsync(Uri url)
    {
        await PrepareWebViewAsync();
        var completion = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);

        void Handler(object? sender, CoreWebView2NavigationCompletedEventArgs args)
        {
            webView!.NavigationCompleted -= Handler;
            if (args.IsSuccess)
            {
                completion.TrySetResult();
            }
            else
            {
                completion.TrySetException(new AttendanceException($"사이트 로딩에 실패했습니다. ({args.WebErrorStatus})"));
            }
        }

        webView!.NavigationCompleted += Handler;
        webView.CoreWebView2.Navigate(url.ToString());

        var finished = await Task.WhenAny(completion.Task, Task.Delay(TimeSpan.FromSeconds(30)));
        if (finished != completion.Task)
        {
            webView.NavigationCompleted -= Handler;
            throw new AttendanceException("사이트 로딩 시간이 초과되었습니다.");
        }

        await completion.Task;
    }

    private async Task LoginIfNeededAsync()
    {
        ReportProgress("로그인 확인 중...");
        var isLoginPage = await BoolJsAsync($$"""
        (function() {
            {{DeepQueryHelper()}}
            return Boolean(bizboxNotchQuery("#userId") && bizboxNotchQuery("#userPw"));
        })();
        """);

        if (!isLoginPage)
        {
            return;
        }

        ReportProgress("로그인 중...");
        var username = JsLiteral(settings.Username);
        var password = JsLiteral(settings.Password);

        try
        {
            await BoolJsAsync($$"""
            (function() {
                {{DeepQueryHelper()}}
                const userId = bizboxNotchQuery("#userId");
                const userPw = bizboxNotchQuery("#userPw");
                if (!userId || !userPw) return false;

                userId.value = {{username}};
                userPw.value = {{password}};

                const win = userId.ownerDocument.defaultView || window;
                if (typeof win.actionLogin === "function") {
                    win.actionLogin();
                } else {
                    bizboxNotchQuery(".log_btn")?.click();
                }
                return true;
            })();
            """);
        }
        catch
        {
            if (!string.IsNullOrWhiteSpace(lastAlertMessage))
            {
                throw new AttendanceException(lastAlertMessage);
            }
        }

        await WaitForConditionAsync(
            AttendanceTabsReadyScript(),
            TimeSpan.FromSeconds(30),
            lastAlertMessage ?? "로그인 후 근태 영역을 찾지 못했습니다."
        );
    }

    private async Task WaitForAttendanceTabsAsync()
    {
        await WaitForConditionAsync(
            AttendanceTabsReadyScript(),
            TimeSpan.FromSeconds(20),
            "출근/퇴근 탭을 찾지 못했습니다."
        );
    }

    private async Task<AttendanceResult> ClickAttendanceAsync(AttendanceAction action)
    {
        var tabSelector = JsLiteral(action.TabSelector());

        ReportProgress($"{action.Title()} 선택 중...");
        var tabClicked = await BoolJsAsync($$"""
        (function() {
            {{DeepQueryHelper()}}
            const tab = bizboxNotchQuery({{tabSelector}});
            if (!tab) return false;
            tab.click();
            return true;
        })();
        """);

        if (!tabClicked)
        {
            throw new AttendanceException($"{action.Title()} 탭을 찾지 못했습니다.");
        }

        await WaitForConditionAsync(
            $$"""
            (function() {
                {{DeepQueryHelper()}}
                return Boolean(bizboxNotchQuery({{tabSelector}})?.classList.contains("active"));
            })();
            """,
            TimeSpan.FromSeconds(5),
            $"{action.Title()} 탭을 활성화하지 못했습니다."
        );

        var previousTime = await DisplayedServerTimeAsync(action);
        lastAlertMessage = null;
        lastConfirmMessage = null;

        ReportProgress($"{action.Title()} 버튼 확인 중...");
        await WaitForConditionAsync(
            SubmitReadyScript(action),
            TimeSpan.FromSeconds(5),
            $"{action.Title()} 처리 버튼이 활성화되지 않았습니다."
        );

        ReportProgress($"{action.Title()} 처리 중...");
        var submitted = await BoolJsAsync($$"""
        (function() {
            {{DeepQueryHelper()}}
            const submit = bizboxNotchQuery({{JsLiteral(action.SubmitSelector())}});
            if (submit) {
                submit.click();
                return true;
            }

            const tab = bizboxNotchQuery({{tabSelector}});
            const win = tab?.ownerDocument?.defaultView || window;
            if (typeof win.fnAttendCheck !== "function") return false;
            win.fnAttendCheck({{action.Code()}});
            return true;
        })();
        """);

        if (!submitted)
        {
            throw new AttendanceException($"{action.Title()} 처리 버튼을 찾지 못했습니다.");
        }

        ReportProgress("결과 확인 중...");
        return await WaitForAttendanceResultAsync(action, previousTime);
    }

    private async Task<AttendanceResult> WaitForAttendanceResultAsync(AttendanceAction action, DateTime? previousTime)
    {
        var deadline = DateTime.Now.AddSeconds(20);
        DateTime? alertSeenAt = null;
        DateTime? lastObservedTime = null;

        while (DateTime.Now < deadline)
        {
            var currentTime = await DisplayedServerTimeAsync(action);
            if (currentTime is not null)
            {
                lastObservedTime = currentTime.Value;
                if (IsNewTime(currentTime.Value, previousTime))
                {
                    ReportProgress("시간 반영 중...");
                    var snapshot = await DisplayedAttendanceSnapshotAsync();
                    return new AttendanceResult(
                        currentTime.Value,
                        snapshot.FetchedAt,
                        snapshot.ClockInAt,
                        snapshot.ClockOutAt,
                        lastAlertMessage ?? $"{action.Title()} 처리 시간이 기록되었습니다."
                    );
                }
            }

            if (!string.IsNullOrWhiteSpace(lastAlertMessage))
            {
                if (IsFailureMessage(lastAlertMessage))
                {
                    throw new AttendanceException(lastAlertMessage);
                }

                alertSeenAt ??= DateTime.Now;
                if (DateTime.Now - alertSeenAt.Value >= TimeSpan.FromSeconds(3))
                {
                    if (lastObservedTime is not null)
                    {
                        throw new AttendanceException($"{lastAlertMessage} 기존 {action.Title()} 시간과 동일해서 새 처리 여부를 확인하지 못했습니다.");
                    }

                    throw new AttendanceException(lastAlertMessage);
                }
            }

            await Task.Delay(250);
        }

        if (!string.IsNullOrWhiteSpace(lastAlertMessage))
        {
            throw new AttendanceException(lastAlertMessage);
        }

        if (!string.IsNullOrWhiteSpace(lastConfirmMessage))
        {
            throw new AttendanceException($"{lastConfirmMessage} 이후 사이트 처리 결과를 확인하지 못했습니다.");
        }

        throw new AttendanceException($"{action.Title()} 처리 후 Bizbox 화면에서 새 시간을 확인하지 못했습니다.");
    }

    private async Task<AttendanceSnapshot> DisplayedAttendanceSnapshotAsync()
    {
        var dto = await JsonJsAsync<SnapshotTextDto>("""
        (function() {
            __DEEP_QUERY_HELPER__
            const textFor = (selector) => {
                const element = bizboxNotchQuery(selector);
                return element ? (element.innerText || element.textContent || "").trim().replace(/\s+/g, " ") : "";
            };
            return {
                clockIn: textFor("#tab1"),
                clockOut: textFor("#tab2")
            };
        })();
        """.Replace("__DEEP_QUERY_HELPER__", DeepQueryHelper()));

        DateFormatting.TryParseServerTime(dto.ClockIn ?? "", out var clockIn);
        DateFormatting.TryParseServerTime(dto.ClockOut ?? "", out var clockOut);

        return new AttendanceSnapshot(
            DateTime.Now,
            clockIn == default ? null : clockIn,
            clockOut == default ? null : clockOut,
            dto.ClockIn ?? "",
            dto.ClockOut ?? ""
        );
    }

    private async Task<DateTime?> DisplayedServerTimeAsync(AttendanceAction action)
    {
        var selector = JsLiteral(action.ResultSelector());
        var text = await StringJsAsync($$"""
        (function() {
            {{DeepQueryHelper()}}
            const element = bizboxNotchQuery({{selector}});
            return element ? (element.innerText || element.textContent || "").trim().replace(/\s+/g, " ") : "";
        })();
        """);

        return DateFormatting.TryParseServerTime(text, out var parsed) ? parsed : null;
    }

    private async Task WaitForConditionAsync(string script, TimeSpan timeout, string failureMessage)
    {
        var deadline = DateTime.Now + timeout;
        while (DateTime.Now < deadline)
        {
            if (!string.IsNullOrWhiteSpace(lastAlertMessage))
            {
                throw new AttendanceException(lastAlertMessage);
            }

            try
            {
                if (await BoolJsAsync(script))
                {
                    return;
                }
            }
            catch
            {
                if (!string.IsNullOrWhiteSpace(lastAlertMessage))
                {
                    throw new AttendanceException(lastAlertMessage);
                }
            }

            await Task.Delay(250);
        }

        throw new AttendanceException(failureMessage);
    }

    private async Task<bool> BoolJsAsync(string script) =>
        await JsonJsAsync<bool>(script);

    private async Task<string> StringJsAsync(string script) =>
        await JsonJsAsync<string>(script) ?? string.Empty;

    private async Task<T> JsonJsAsync<T>(string script)
    {
        await PrepareWebViewAsync();
        var result = await webView!.CoreWebView2.ExecuteScriptAsync(script);
        return JsonSerializer.Deserialize<T>(result) ?? throw new AttendanceException("사이트 응답을 해석하지 못했습니다.");
    }

    private static Uri FreshUrl(Uri url)
    {
        var builder = new UriBuilder(url);
        var separator = string.IsNullOrWhiteSpace(builder.Query) ? "" : builder.Query.TrimStart('&', '?') + "&";
        builder.Query = $"{separator}_bizboxNotchRefresh={DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()}";
        return builder.Uri;
    }

    private static string SubmitReadyScript(AttendanceAction action)
    {
        var selector = JsLiteral(action.SubmitSelector());
        return $$"""
        (function() {
            {{DeepQueryHelper()}}
            const element = bizboxNotchQuery({{selector}});
            if (!element) return false;
            const win = element.ownerDocument.defaultView || window;
            const style = win.getComputedStyle(element);
            const rect = element.getBoundingClientRect();
            const onclick = element.getAttribute("onclick") || "";
            return style.display !== "none"
                && style.visibility !== "hidden"
                && rect.width > 0
                && rect.height > 0
                && onclick.includes("fnAttendCheck({{action.Code()}})");
        })();
        """;
    }

    private static string AttendanceTabsReadyScript() =>
        $$"""
        (function() {
            {{DeepQueryHelper()}}
            return Boolean(
                bizboxNotchQuery('li[onclick*="fnSetAttOption(1)"]')
                    && bizboxNotchQuery('li[onclick*="fnSetAttOption(4)"]')
            );
        })();
        """;

    private static string DeepQueryHelper() =>
        """
        function bizboxNotchDocuments(root) {
            const documents = [root];
            for (const frame of root.querySelectorAll("iframe, frame")) {
                try {
                    const childDocument = frame.contentDocument || frame.contentWindow?.document;
                    if (childDocument) {
                        documents.push(...bizboxNotchDocuments(childDocument));
                    }
                } catch (_) {
                }
            }
            return documents;
        }

        function bizboxNotchQuery(selector) {
            for (const candidateDocument of bizboxNotchDocuments(document)) {
                const element = candidateDocument.querySelector(selector);
                if (element) return element;
            }
            return null;
        }
        """;

    private static bool IsNewTime(DateTime currentTime, DateTime? previousTime)
    {
        if (previousTime is null)
        {
            return true;
        }

        return Math.Abs((currentTime - previousTime.Value).TotalSeconds) > 1;
    }

    private static bool IsFailureMessage(string message) =>
        message.Contains("실패", StringComparison.Ordinal)
            || message.Contains("아닙니다", StringComparison.Ordinal)
            || message.Contains("이미", StringComparison.Ordinal)
            || message.Contains("오류", StringComparison.Ordinal);

    private static string JsLiteral(string value) =>
        JsonSerializer.Serialize(value, new JsonSerializerOptions
        {
            Encoder = JavaScriptEncoder.Default
        });

    private void ReportProgress(string message) => onProgress?.Invoke(message);

    private sealed class SnapshotTextDto
    {
        [JsonPropertyName("clockIn")]
        public string? ClockIn { get; set; }

        [JsonPropertyName("clockOut")]
        public string? ClockOut { get; set; }
    }
}
