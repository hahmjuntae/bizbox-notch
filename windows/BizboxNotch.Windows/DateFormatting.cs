using System.Globalization;

namespace BizboxNotch.Windows;

internal static class DateFormatting
{
    private static readonly CultureInfo KoreanCulture = CultureInfo.GetCultureInfo("ko-KR");

    public static string MenuTime(DateTime? value) => value?.ToString("HH:mm:ss", KoreanCulture) ?? "--:--:--";

    public static string ReminderTime(string value)
    {
        if (!DateTime.TryParseExact(value, "HH:mm", CultureInfo.InvariantCulture, DateTimeStyles.None, out var parsed))
        {
            return value;
        }

        return parsed.ToString("tt h:mm", KoreanCulture);
    }

    public static bool TryParseServerTime(string text, out DateTime value)
    {
        var match = System.Text.RegularExpressions.Regex.Match(
            text,
            @"\d{4}\.\d{2}\.\d{2}\s+\d{2}:\d{2}:\d{2}"
        );

        if (match.Success
            && DateTime.TryParseExact(
                match.Value,
                "yyyy.MM.dd HH:mm:ss",
                CultureInfo.InvariantCulture,
                DateTimeStyles.AssumeLocal,
                out value
            ))
        {
            return true;
        }

        value = default;
        return false;
    }
}
