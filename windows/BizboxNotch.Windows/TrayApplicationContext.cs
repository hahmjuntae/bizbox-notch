namespace BizboxNotch.Windows;

internal sealed class TrayApplicationContext : ApplicationContext
{
    private readonly SettingsStore settings = new();
    private readonly AttendanceAutomation automation;
    private readonly NotifyIcon notifyIcon;
    private readonly ContextMenuStrip menu = new();
    private readonly System.Windows.Forms.Timer reminderTimer = new();
    private readonly HashSet<string> triggeredReminderKeys = [];

    private ToolStripMenuItem clockInItem = null!;
    private ToolStripMenuItem clockOutItem = null!;
    private ToolStripMenuItem clockInTimeItem = null!;
    private ToolStripMenuItem clockOutTimeItem = null!;
    private ToolStripMenuItem refreshItem = null!;
    private ToolStripMenuItem statusItem = null!;
    private ReminderForm? reminderForm;
    private SettingsForm? settingsForm;
    private bool automationRunning;
    private string? lastFailureMessage;

    public TrayApplicationContext()
    {
        automation = new AttendanceAutomation(settings, ShowProgress);
        notifyIcon = new NotifyIcon
        {
            Icon = LoadAppIcon(),
            Text = "Bizbox Notch",
            Visible = true,
            ContextMenuStrip = menu
        };

        BuildMenu();
        UpdateMenu();
        StartReminderTimer();
        _ = RefreshTimesAsync(silent: true);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            reminderTimer.Dispose();
            notifyIcon.Visible = false;
            notifyIcon.Dispose();
            automation.Dispose();
        }

        base.Dispose(disposing);
    }

    private void BuildMenu()
    {
        clockInItem = new ToolStripMenuItem("출근", null, async (_, _) => await RunAsync(AttendanceAction.ClockIn));
        clockOutItem = new ToolStripMenuItem("퇴근", null, async (_, _) => await RunAsync(AttendanceAction.ClockOut));
        clockInTimeItem = new ToolStripMenuItem("출근시간: --:--:--") { Enabled = false };
        clockOutTimeItem = new ToolStripMenuItem("퇴근시간: --:--:--") { Enabled = false };
        refreshItem = new ToolStripMenuItem("새로고침", null, async (_, _) => await RefreshTimesAsync(silent: false));
        statusItem = new ToolStripMenuItem("대기 중") { Enabled = false };

        menu.Items.Add(clockInItem);
        menu.Items.Add(clockOutItem);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(clockInTimeItem);
        menu.Items.Add(clockOutTimeItem);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(refreshItem);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(statusItem);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(new ToolStripMenuItem("설정", null, (_, _) => ShowSettings()));
        menu.Items.Add(new ToolStripMenuItem("종료", null, (_, _) => ExitThread()));
    }

    private async Task RunAsync(AttendanceAction action)
    {
        if (automationRunning)
        {
            return;
        }

        try
        {
            settings.Validate();
        }
        catch (Exception error)
        {
            lastFailureMessage = error.Message;
            UpdateMenu();
            ShowBalloon($"{action.Title()} 실패", error.Message);
            ShowResultAlert($"{action.Title()} 실패", error.Message, MessageBoxIcon.Error);
            return;
        }

        lastFailureMessage = null;
        SetRunning(true, $"{action.Title()} 준비 중...");

        try
        {
            var result = await automation.RunAsync(action);
            Apply(result);
            settings.Save();
            UpdateMenu();
            ShowBalloon($"{action.Title()} 완료", result.Message);
            ShowResultAlert($"{action.Title()} 완료", result.Message, MessageBoxIcon.Information);
        }
        catch (Exception error)
        {
            lastFailureMessage = error.Message;
            ShowFailure(error.Message);
            ShowBalloon($"{action.Title()} 실패", error.Message);
            ShowResultAlert($"{action.Title()} 실패", error.Message, MessageBoxIcon.Error);
        }
        finally
        {
            SetRunning(false);
        }
    }

    private async Task RefreshTimesAsync(bool silent)
    {
        if (automationRunning)
        {
            return;
        }

        try
        {
            settings.Validate();
        }
        catch
        {
            if (!silent)
            {
                lastFailureMessage = "설정을 확인하세요.";
                UpdateMenu();
            }

            return;
        }

        lastFailureMessage = null;
        SetRunning(true, "접속 준비 중...");

        try
        {
            var snapshot = await automation.FetchCurrentTimesAsync();
            Apply(snapshot);
            settings.Save();
            UpdateMenu();

            if (!silent)
            {
                ShowBalloon("새로고침 완료", $"출근 {DateFormatting.MenuTime(snapshot.ClockInAt)} / 퇴근 {DateFormatting.MenuTime(snapshot.ClockOutAt)}");
            }
        }
        catch (Exception error)
        {
            if (!silent)
            {
                lastFailureMessage = error.Message;
                ShowFailure(error.Message);
                ShowBalloon("새로고침 실패", error.Message);
            }
            else
            {
                UpdateMenu();
            }
        }
        finally
        {
            SetRunning(false);
        }
    }

    private void Apply(AttendanceResult result)
    {
        if (result.ClockInAt is not null)
        {
            settings.LastClockInAt = result.ClockInAt;
        }

        if (result.ClockOutAt is not null)
        {
            settings.LastClockOutAt = result.ClockOutAt;
        }

        settings.LastSiteUpdatedAt = result.FetchedAt;
    }

    private void Apply(AttendanceSnapshot snapshot)
    {
        settings.LastClockInAt = snapshot.ClockInAt;
        settings.LastClockOutAt = snapshot.ClockOutAt;
        settings.LastSiteUpdatedAt = snapshot.FetchedAt;
    }

    private void SetRunning(bool running, string? message = null)
    {
        automationRunning = running;
        clockInItem.Enabled = !running;
        clockOutItem.Enabled = !running;
        refreshItem.Enabled = !running;

        if (running && message is not null)
        {
            ShowProgress(message);
        }
        else if (!running)
        {
            refreshItem.Text = "새로고침";
            UpdateMenu();
        }
    }

    private void ShowProgress(string message)
    {
        statusItem.Text = message;
        refreshItem.Text = message;
        notifyIcon.Text = TrimTooltip(message);
    }

    private void ShowFailure(string message)
    {
        statusItem.Text = $"실패: {message}";
        refreshItem.Text = "실패";
        notifyIcon.Text = "Bizbox Notch - 실패";
    }

    private void UpdateMenu()
    {
        clockInTimeItem.Text = $"출근시간: {DateFormatting.MenuTime(settings.LastClockInAt)}";
        clockOutTimeItem.Text = $"퇴근시간: {DateFormatting.MenuTime(settings.LastClockOutAt)}";

        statusItem.Text = string.IsNullOrWhiteSpace(settings.Username)
            ? "설정 필요"
            : lastFailureMessage is not null
                ? $"실패: {lastFailureMessage}"
                : settings.LastSiteUpdatedAt is not null
                    ? $"최근 업데이트: {DateFormatting.MenuTime(settings.LastSiteUpdatedAt)}"
                    : $"{settings.Username} / 대기 중";

        notifyIcon.Text = "Bizbox Notch";
    }

    private void ShowSettings()
    {
        if (settingsForm is { IsDisposed: false })
        {
            settingsForm.Activate();
            return;
        }

        settingsForm = new SettingsForm(settings, ApplySettingsChanges);
        settingsForm.Show();
    }

    private void ApplySettingsChanges()
    {
        lastFailureMessage = null;
        triggeredReminderKeys.Clear();
        reminderForm?.Close();
        reminderForm = null;
        UpdateMenu();
        ScheduleReminderNotifications();
        CheckScheduleReminder();
    }

    private void StartReminderTimer()
    {
        reminderTimer.Interval = 10_000;
        reminderTimer.Tick += (_, _) => CheckScheduleReminder();
        reminderTimer.Start();
        CheckScheduleReminder();
    }

    private void CheckScheduleReminder()
    {
        if (reminderForm is not null)
        {
            return;
        }

        var now = DateTime.Now;
        var schedule = settings.WorkdaySchedules.FirstOrDefault(item => item.Day == now.DayOfWeek && item.Enabled);
        if (schedule is null)
        {
            return;
        }

        var currentMinute = now.Hour * 60 + now.Minute;
        var dueReminder = DueReminder(schedule, currentMinute, now);
        if (dueReminder is null)
        {
            return;
        }

        ShowReminder(dueReminder.Value.Action, dueReminder.Value.ScheduledTime, now);
    }

    private (AttendanceAction Action, string ScheduledTime)? DueReminder(
        WorkdaySchedule schedule,
        int currentMinute,
        DateTime date
    )
    {
        var reminders = new[]
        {
            (Action: AttendanceAction.ClockIn, ScheduledTime: schedule.ClockIn),
            (Action: AttendanceAction.ClockOut, ScheduledTime: schedule.ClockOut)
        };

        foreach (var reminder in reminders.Reverse())
        {
            if (SettingsStore.MinuteOfDay(reminder.ScheduledTime) == currentMinute
                && !triggeredReminderKeys.Contains(ReminderKey(reminder.Action, reminder.ScheduledTime, date)))
            {
                return reminder;
            }
        }

        return null;
    }

    private void ShowReminder(AttendanceAction action, string scheduledTime, DateTime date)
    {
        var key = ReminderKey(action, scheduledTime, date);
        if (!triggeredReminderKeys.Add(key))
        {
            return;
        }

        reminderForm = new ReminderForm(
            action,
            scheduledTime,
            async selectedAction => await RunAsync(selectedAction),
            () => reminderForm = null
        );
        reminderForm.Show();
    }

    private static string ReminderKey(AttendanceAction action, string scheduledTime, DateTime date) =>
        $"{date:yyyy-MM-dd}-{action}-{scheduledTime}";

    private void ScheduleReminderNotifications()
    {
        // The persistent form is the primary reminder UI on Windows.
    }

    private void ShowBalloon(string title, string body)
    {
        notifyIcon.BalloonTipTitle = title;
        notifyIcon.BalloonTipText = body;
        notifyIcon.ShowBalloonTip(3000);
    }

    private static Icon LoadAppIcon() =>
        Icon.ExtractAssociatedIcon(Application.ExecutablePath) ?? SystemIcons.Application;

    private static void ShowResultAlert(string title, string body, MessageBoxIcon icon)
    {
        using var owner = new Form
        {
            ShowInTaskbar = false,
            StartPosition = FormStartPosition.Manual,
            Location = new Point(-10000, -10000),
            Size = new Size(1, 1),
            TopMost = true
        };

        owner.Show();
        owner.Activate();
        MessageBox.Show(owner, body, title, MessageBoxButtons.OK, icon);
    }

    private static string TrimTooltip(string text) =>
        text.Length <= 63 ? text : text[..63];
}
