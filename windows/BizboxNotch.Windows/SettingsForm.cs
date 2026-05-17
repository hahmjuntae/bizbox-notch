using System.Globalization;

namespace BizboxNotch.Windows;

internal sealed class SettingsForm : Form
{
    private readonly SettingsStore settings;
    private readonly Action onSaved;
    private readonly TextBox siteUrlBox = new();
    private readonly TextBox usernameBox = new();
    private readonly TextBox passwordBox = new();
    private readonly CheckBox launchAtLoginBox = new();
    private readonly Dictionary<DayOfWeek, (CheckBox Enabled, DateTimePicker ClockIn, DateTimePicker ClockOut)> schedulePickers = [];

    public SettingsForm(SettingsStore settings, Action onSaved)
    {
        this.settings = settings;
        this.onSaved = onSaved;

        Text = "Bizbox Notch 설정";
        StartPosition = FormStartPosition.CenterScreen;
        Size = new Size(560, 640);
        MinimumSize = new Size(560, 640);
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;

        BuildUi();
        LoadSettings();
    }

    private void BuildUi()
    {
        var root = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            Padding = new Padding(24),
            ColumnCount = 1,
            RowCount = 7
        };
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));

        var title = new Label
        {
            AutoSize = true,
            Text = "Bizbox 로그인 설정",
            Font = new Font(FontFamily.GenericSansSerif, 14, FontStyle.Bold)
        };
        var description = new Label
        {
            AutoSize = true,
            Margin = new Padding(0, 8, 0, 18),
            Text = "비밀번호는 Windows 사용자 계정 범위로 암호화해 저장합니다.",
            ForeColor = SystemColors.GrayText
        };

        var formGrid = new TableLayoutPanel
        {
            Dock = DockStyle.Top,
            ColumnCount = 2,
            AutoSize = true
        };
        formGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 90));
        formGrid.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));

        siteUrlBox.Width = 340;
        usernameBox.Width = 340;
        passwordBox.Width = 340;
        passwordBox.UseSystemPasswordChar = true;

        AddInputRow(formGrid, "사이트 URL", siteUrlBox);
        AddInputRow(formGrid, "아이디", usernameBox);
        AddInputRow(formGrid, "비밀번호", passwordBox);

        launchAtLoginBox.Text = "로그인 시 실행";
        launchAtLoginBox.Margin = new Padding(92, 12, 0, 18);
        launchAtLoginBox.AutoSize = true;

        var scheduleTitle = new Label
        {
            AutoSize = true,
            Text = "알림 발생 시간",
            Font = new Font(FontFamily.GenericSansSerif, 10, FontStyle.Bold),
            Margin = new Padding(0, 0, 0, 8)
        };

        var scheduleGrid = BuildScheduleGrid();
        var buttons = BuildButtonRow();

        root.Controls.Add(title, 0, 0);
        root.Controls.Add(description, 0, 1);
        root.Controls.Add(formGrid, 0, 2);
        root.Controls.Add(launchAtLoginBox, 0, 3);
        root.Controls.Add(scheduleTitle, 0, 4);
        root.Controls.Add(scheduleGrid, 0, 5);
        root.Controls.Add(buttons, 0, 6);
        Controls.Add(root);
    }

    private TableLayoutPanel BuildScheduleGrid()
    {
        var grid = new TableLayoutPanel
        {
            Dock = DockStyle.Top,
            AutoSize = true,
            ColumnCount = 4,
            RowCount = 8,
            Margin = new Padding(0, 0, 0, 18)
        };
        grid.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 44));
        grid.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 62));
        grid.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 145));
        grid.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 145));

        grid.Controls.Add(new Label(), 0, 0);
        grid.Controls.Add(HeaderLabel("활성"), 1, 0);
        grid.Controls.Add(HeaderLabel("출근"), 2, 0);
        grid.Controls.Add(HeaderLabel("퇴근"), 3, 0);

        var row = 1;
        foreach (var schedule in settings.WorkdaySchedules)
        {
            var enabledBox = new CheckBox
            {
                Checked = schedule.Enabled,
                Dock = DockStyle.Fill,
                AutoSize = true,
                Margin = new Padding(0, 6, 16, 0)
            };
            var clockInPicker = TimePicker(schedule.ClockIn);
            var clockOutPicker = TimePicker(schedule.ClockOut);
            clockInPicker.Enabled = schedule.Enabled;
            clockOutPicker.Enabled = schedule.Enabled;
            enabledBox.CheckedChanged += (_, _) => ApplyScheduleEnabledState(schedule.Day);
            schedulePickers[schedule.Day] = (enabledBox, clockInPicker, clockOutPicker);

            grid.Controls.Add(new Label
            {
                Text = schedule.Label,
                TextAlign = ContentAlignment.MiddleLeft,
                Dock = DockStyle.Fill,
                AutoSize = true,
                Margin = new Padding(0, 6, 8, 0)
            }, 0, row);
            grid.Controls.Add(enabledBox, 1, row);
            grid.Controls.Add(clockInPicker, 2, row);
            grid.Controls.Add(clockOutPicker, 3, row);
            row += 1;
        }

        return grid;
    }

    private FlowLayoutPanel BuildButtonRow()
    {
        var row = new FlowLayoutPanel
        {
            Dock = DockStyle.Bottom,
            FlowDirection = FlowDirection.RightToLeft,
            AutoSize = true
        };

        var saveButton = new Button { Text = "저장", AutoSize = true };
        saveButton.Click += (_, _) => SaveSettings();
        AcceptButton = saveButton;

        var closeButton = new Button { Text = "닫기", AutoSize = true };
        closeButton.Click += (_, _) => Close();

        row.Controls.Add(saveButton);
        row.Controls.Add(closeButton);
        return row;
    }

    private void LoadSettings()
    {
        siteUrlBox.Text = settings.SiteUrl;
        usernameBox.Text = settings.Username;
        passwordBox.Text = settings.Password;
        launchAtLoginBox.Checked = settings.LaunchAtLogin;

        foreach (var schedule in settings.WorkdaySchedules)
        {
            if (schedulePickers.TryGetValue(schedule.Day, out var pickers))
            {
                pickers.Enabled.Checked = schedule.Enabled;
                pickers.ClockIn.Value = PickerDate(schedule.ClockIn);
                pickers.ClockOut.Value = PickerDate(schedule.ClockOut);
                ApplyScheduleEnabledState(schedule.Day);
            }
        }
    }

    private void SaveSettings()
    {
        var schedules = settings.WorkdaySchedules.Select(schedule =>
        {
            var pickers = schedulePickers[schedule.Day];
            return schedule with
            {
                Enabled = pickers.Enabled.Checked,
                ClockIn = FormatPickerTime(pickers.ClockIn),
                ClockOut = FormatPickerTime(pickers.ClockOut)
            };
        }).ToList();

        var siteUrl = SettingsStore.NormalizeSiteUrl(siteUrlBox.Text);
        var username = usernameBox.Text.Trim();
        var password = passwordBox.Text;

        try
        {
            SettingsStore.Validate(siteUrl, username, password, schedules);
            settings.SiteUrl = siteUrl;
            settings.Username = username;
            settings.Password = password;
            settings.SetSchedules(schedules);
            settings.LaunchAtLogin = launchAtLoginBox.Checked;
            settings.Save();
        }
        catch (Exception error)
        {
            MessageBox.Show(this, error.Message, "설정 저장 실패", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        onSaved();
        Close();
    }

    private static void AddInputRow(TableLayoutPanel grid, string title, Control input)
    {
        var row = grid.RowCount++;
        grid.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        grid.Controls.Add(new Label
        {
            Text = title,
            AutoSize = true,
            TextAlign = ContentAlignment.MiddleRight,
            Dock = DockStyle.Fill,
            Margin = new Padding(0, 6, 8, 0)
        }, 0, row);
        input.Margin = new Padding(0, 3, 0, 6);
        input.Dock = DockStyle.Fill;
        grid.Controls.Add(input, 1, row);
    }

    private static Label HeaderLabel(string text) => new()
    {
        Text = text,
        AutoSize = true,
        Font = new Font(FontFamily.GenericSansSerif, 9, FontStyle.Bold),
        Margin = new Padding(0, 0, 0, 4)
    };

    private void ApplyScheduleEnabledState(DayOfWeek day)
    {
        if (!schedulePickers.TryGetValue(day, out var pickers))
        {
            return;
        }

        pickers.ClockIn.Enabled = pickers.Enabled.Checked;
        pickers.ClockOut.Enabled = pickers.Enabled.Checked;
    }

    private static DateTimePicker TimePicker(string value) => new()
    {
        Format = DateTimePickerFormat.Custom,
        CustomFormat = "tt h:mm",
        ShowUpDown = true,
        Width = 120,
        Value = PickerDate(value),
        Margin = new Padding(0, 3, 16, 6)
    };

    private static DateTime PickerDate(string value)
    {
        if (!DateTime.TryParseExact(value, "HH:mm", CultureInfo.InvariantCulture, DateTimeStyles.None, out var parsed))
        {
            parsed = DateTime.Today.AddHours(9);
        }

        return DateTime.Today.AddHours(parsed.Hour).AddMinutes(parsed.Minute);
    }

    private static string FormatPickerTime(DateTimePicker picker) => picker.Value.ToString("HH:mm", CultureInfo.InvariantCulture);
}
