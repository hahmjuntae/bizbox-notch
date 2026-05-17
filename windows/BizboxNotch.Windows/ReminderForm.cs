namespace BizboxNotch.Windows;

internal sealed class ReminderForm : Form
{
    private readonly AttendanceAction action;
    private readonly Func<AttendanceAction, Task> onAction;
    private readonly Action onDismiss;

    public ReminderForm(
        AttendanceAction action,
        string scheduledTime,
        Func<AttendanceAction, Task> onAction,
        Action onDismiss
    )
    {
        this.action = action;
        this.onAction = onAction;
        this.onDismiss = onDismiss;

        Text = "Bizbox Notch";
        StartPosition = FormStartPosition.Manual;
        Size = new Size(360, 170);
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = false;
        ShowInTaskbar = true;
        TopMost = true;
        BuildUi(scheduledTime);
        PositionNearBottomRight();
    }

    protected override void OnFormClosed(FormClosedEventArgs e)
    {
        onDismiss();
        base.OnFormClosed(e);
    }

    private void BuildUi(string scheduledTime)
    {
        var layout = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            Padding = new Padding(22, 18, 22, 18),
            ColumnCount = 1,
            RowCount = 3
        };
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));

        var title = new Label
        {
            AutoSize = true,
            Text = $"{action.Title()} 알림",
            Font = new Font(FontFamily.GenericSansSerif, 15, FontStyle.Bold)
        };
        var message = new Label
        {
            AutoSize = true,
            Margin = new Padding(0, 10, 0, 0),
            Text = $"{scheduledTime} {action.Title()} 알림 시간입니다.",
            ForeColor = SystemColors.GrayText
        };
        var buttons = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill,
            FlowDirection = FlowDirection.RightToLeft,
            Padding = new Padding(0, 14, 0, 0)
        };

        var actionButton = new Button { Text = action.Title(), AutoSize = true };
        actionButton.Click += async (_, _) =>
        {
            Close();
            await onAction(action);
        };

        var closeButton = new Button { Text = "닫기", AutoSize = true };
        closeButton.Click += (_, _) => Close();

        buttons.Controls.Add(actionButton);
        buttons.Controls.Add(closeButton);

        layout.Controls.Add(title, 0, 0);
        layout.Controls.Add(message, 0, 1);
        layout.Controls.Add(buttons, 0, 2);
        Controls.Add(layout);
    }

    private void PositionNearBottomRight()
    {
        var area = Screen.PrimaryScreen?.WorkingArea ?? new Rectangle(0, 0, 1280, 720);
        Location = new Point(area.Right - Width - 24, area.Bottom - Height - 24);
    }
}
