namespace BizboxNotch.Windows;

internal sealed record WorkdaySchedule(DayOfWeek Day, string Label, bool Enabled, string ClockIn, string ClockOut)
{
    public WorkdaySchedule WithEnabled(bool value) => this with { Enabled = value };

    public WorkdaySchedule WithClockIn(string value) => this with { ClockIn = value };

    public WorkdaySchedule WithClockOut(string value) => this with { ClockOut = value };
}
