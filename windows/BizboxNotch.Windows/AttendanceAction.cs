namespace BizboxNotch.Windows;

internal enum AttendanceAction
{
    ClockIn,
    ClockOut
}

internal static class AttendanceActionExtensions
{
    public static string Title(this AttendanceAction action) =>
        action == AttendanceAction.ClockIn ? "출근" : "퇴근";

    public static int Code(this AttendanceAction action) =>
        action == AttendanceAction.ClockIn ? 1 : 4;

    public static string TabSelector(this AttendanceAction action) =>
        action == AttendanceAction.ClockIn
            ? "li[onclick*=\"fnSetAttOption(1)\"]"
            : "li[onclick*=\"fnSetAttOption(4)\"]";

    public static string SubmitSelector(this AttendanceAction action) =>
        action == AttendanceAction.ClockIn ? "#attHref1" : "#attHref2";

    public static string ResultSelector(this AttendanceAction action) =>
        action == AttendanceAction.ClockIn ? "#tab1" : "#tab2";
}
