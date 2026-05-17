namespace BizboxNotch.Windows;

internal sealed record AttendanceSnapshot(
    DateTime FetchedAt,
    DateTime? ClockInAt,
    DateTime? ClockOutAt,
    string RawClockInText,
    string RawClockOutText
);

internal sealed record AttendanceResult(
    DateTime RecordedAt,
    DateTime FetchedAt,
    DateTime? ClockInAt,
    DateTime? ClockOutAt,
    string Message
);

internal sealed class AttendanceException(string message) : Exception(message);
