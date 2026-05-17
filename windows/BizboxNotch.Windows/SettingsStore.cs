using System.Globalization;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.Win32;

namespace BizboxNotch.Windows;

internal sealed class SettingsStore
{
    public const string DefaultSiteUrl = "https://gw.forbiz.co.kr/gw/userMain.do";

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true
    };

    private readonly string directory;
    private readonly string settingsPath;

    public SettingsStore()
    {
        directory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "Bizbox Notch"
        );
        settingsPath = Path.Combine(directory, "settings.json");
        State = Load();
    }

    public SettingsState State { get; private set; }

    public string SiteUrl
    {
        get => NormalizeSiteUrl(State.SiteUrl);
        set => State.SiteUrl = NormalizeSiteUrl(value);
    }

    public string Username
    {
        get => State.Username.Trim();
        set => State.Username = value.Trim();
    }

    public string Password
    {
        get => Unprotect(State.EncryptedPassword);
        set => State.EncryptedPassword = Protect(value);
    }

    public bool LaunchAtLogin
    {
        get => LoginItemManager.IsEnabled();
        set => LoginItemManager.SetEnabled(value);
    }

    public IReadOnlyList<WorkdaySchedule> WorkdaySchedules
    {
        get => DefaultSchedules.Select(schedule =>
        {
            var key = KeyFor(schedule.Day);
            return State.Schedules.TryGetValue(key, out var saved)
                ? schedule with
                {
                    Enabled = saved.Enabled ?? schedule.Enabled,
                    ClockIn = IsValidTime(saved.ClockIn) ? saved.ClockIn : schedule.ClockIn,
                    ClockOut = IsValidTime(saved.ClockOut) ? saved.ClockOut : schedule.ClockOut
                }
                : schedule;
        }).ToList();
    }

    public DateTime? LastClockInAt
    {
        get => State.LastClockInAt;
        set => State.LastClockInAt = value;
    }

    public DateTime? LastClockOutAt
    {
        get => State.LastClockOutAt;
        set => State.LastClockOutAt = value;
    }

    public DateTime? LastSiteUpdatedAt
    {
        get => State.LastSiteUpdatedAt;
        set => State.LastSiteUpdatedAt = value;
    }

    public void SetSchedules(IEnumerable<WorkdaySchedule> schedules)
    {
        State.Schedules = schedules.ToDictionary(
            schedule => KeyFor(schedule.Day),
            schedule => new ScheduleState
            {
                Enabled = schedule.Enabled,
                ClockIn = schedule.ClockIn,
                ClockOut = schedule.ClockOut
            }
        );
    }

    public void Save()
    {
        Directory.CreateDirectory(directory);
        var json = JsonSerializer.Serialize(State, JsonOptions);
        File.WriteAllText(settingsPath, json);
    }

    public void Validate()
    {
        Validate(SiteUrl, Username, Password, WorkdaySchedules);
    }

    public static void Validate(
        string siteUrl,
        string username,
        string password,
        IEnumerable<WorkdaySchedule> schedules
    )
    {
        ValidateSiteUrl(siteUrl);

        if (string.IsNullOrWhiteSpace(username))
        {
            throw new AttendanceException("아이디를 설정하세요.");
        }

        if (string.IsNullOrEmpty(password))
        {
            throw new AttendanceException("비밀번호를 설정하세요.");
        }

        foreach (var schedule in schedules)
        {
            if (!schedule.Enabled)
            {
                continue;
            }

            if (!IsValidTime(schedule.ClockIn))
            {
                throw new AttendanceException($"{schedule.Label}요일 출근 시간을 확인하세요.");
            }

            if (!IsValidTime(schedule.ClockOut))
            {
                throw new AttendanceException($"{schedule.Label}요일 퇴근 시간을 확인하세요.");
            }
        }
    }

    public static string NormalizeSiteUrl(string value)
    {
        var trimmed = value.Trim();
        return string.IsNullOrWhiteSpace(trimmed) ? DefaultSiteUrl : trimmed;
    }

    public static void ValidateSiteUrl(string value)
    {
        var normalized = NormalizeSiteUrl(value);
        if (!Uri.TryCreate(normalized, UriKind.Absolute, out var uri)
            || uri.Scheme != Uri.UriSchemeHttps
            || uri.Host != "gw.forbiz.co.kr"
            || !uri.AbsolutePath.StartsWith("/gw/", StringComparison.Ordinal))
        {
            throw new AttendanceException("사이트 URL은 https://gw.forbiz.co.kr/gw/... 주소여야 합니다.");
        }
    }

    public static bool IsValidTime(string value) =>
        DateTime.TryParseExact(
            value,
            "HH:mm",
            CultureInfo.InvariantCulture,
            DateTimeStyles.None,
            out _
        );

    public static int MinuteOfDay(string value)
    {
        var parsed = DateTime.ParseExact(value, "HH:mm", CultureInfo.InvariantCulture);
        return parsed.Hour * 60 + parsed.Minute;
    }

    private SettingsState Load()
    {
        if (!File.Exists(settingsPath))
        {
            return new SettingsState();
        }

        try
        {
            return JsonSerializer.Deserialize<SettingsState>(File.ReadAllText(settingsPath)) ?? new SettingsState();
        }
        catch
        {
            return new SettingsState();
        }
    }

    private static string Protect(string value)
    {
        if (string.IsNullOrEmpty(value))
        {
            return string.Empty;
        }

        var bytes = System.Text.Encoding.UTF8.GetBytes(value);
        var protectedBytes = ProtectedData.Protect(bytes, null, DataProtectionScope.CurrentUser);
        return Convert.ToBase64String(protectedBytes);
    }

    private static string Unprotect(string value)
    {
        if (string.IsNullOrEmpty(value))
        {
            return string.Empty;
        }

        try
        {
            var protectedBytes = Convert.FromBase64String(value);
            var bytes = ProtectedData.Unprotect(protectedBytes, null, DataProtectionScope.CurrentUser);
            return System.Text.Encoding.UTF8.GetString(bytes);
        }
        catch
        {
            return string.Empty;
        }
    }

    private static string KeyFor(DayOfWeek day) => day.ToString();

    private static readonly WorkdaySchedule[] DefaultSchedules =
    [
        new(DayOfWeek.Sunday, "일", false, "08:50", "18:10"),
        new(DayOfWeek.Monday, "월", true, "08:50", "18:10"),
        new(DayOfWeek.Tuesday, "화", true, "08:20", "17:40"),
        new(DayOfWeek.Wednesday, "수", true, "08:20", "17:40"),
        new(DayOfWeek.Thursday, "목", true, "08:20", "17:40"),
        new(DayOfWeek.Friday, "금", true, "08:50", "18:10"),
        new(DayOfWeek.Saturday, "토", false, "08:50", "18:10")
    ];
}

internal sealed class SettingsState
{
    public string SiteUrl { get; set; } = SettingsStore.DefaultSiteUrl;

    public string Username { get; set; } = string.Empty;

    public string EncryptedPassword { get; set; } = string.Empty;

    public Dictionary<string, ScheduleState> Schedules { get; set; } = [];

    public DateTime? LastClockInAt { get; set; }

    public DateTime? LastClockOutAt { get; set; }

    public DateTime? LastSiteUpdatedAt { get; set; }
}

internal sealed class ScheduleState
{
    public bool? Enabled { get; set; }

    public string ClockIn { get; set; } = string.Empty;

    public string ClockOut { get; set; } = string.Empty;
}

internal static class LoginItemManager
{
    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "Bizbox Notch";

    public static bool IsEnabled()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, false);
        return key?.GetValue(ValueName) is string value
            && string.Equals(value, ExecutableCommand(), StringComparison.OrdinalIgnoreCase);
    }

    public static void SetEnabled(bool enabled)
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, true)
            ?? Registry.CurrentUser.CreateSubKey(RunKeyPath);

        if (enabled)
        {
            key.SetValue(ValueName, ExecutableCommand());
        }
        else
        {
            key.DeleteValue(ValueName, false);
        }
    }

    private static string ExecutableCommand() => $"\"{System.Windows.Forms.Application.ExecutablePath}\"";
}
