import 'package:get/get.dart';

import '../constants/app_strings.dart';

/// QA5 #3: the Global League leaderboard's period label ("Week 37",
/// "September 2026") used to come pre-formatted in English from the
/// backend and could never be translated. The backend now sends raw
/// week_number/month_number/year; these build the FR/EN display string
/// client-side, the same way every other date/time label in the app is
/// localised (see formatLocalClockTime above) rather than trusting a
/// server-formatted string.
String formatWeekLabel(int weekNumber) => '${AppString.week.tr} $weekNumber';

String formatMonthLabel(int monthNumber, int year) {
  const monthKeys = [
    AppString.january, AppString.february, AppString.march, AppString.april,
    AppString.may, AppString.june, AppString.july, AppString.august,
    AppString.september, AppString.october, AppString.november, AppString.december,
  ];
  if (monthNumber < 1 || monthNumber > 12) return '$monthNumber $year';
  return '${monthKeys[monthNumber - 1].tr} $year';
}

/// Formats a UTC instant as a device-local clock time, per the app's
/// locale-specific convention (matches the Home screen's lock-time display):
/// French uses 24h with no colon ("8h36"), English uses 12h AM/PM ("8:36 AM").
String formatLocalClockTime(DateTime utcTime) {
  final local = utcTime.toLocal();
  final minute = local.minute.toString().padLeft(2, '0');
  if (Get.locale?.languageCode == 'fr') {
    return '${local.hour}h$minute';
  }
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '$hour12:$minute $period';
}

/// Parses a game's `datetimeUtc` ISO string and returns the local clock
/// time, or `null` if the string is missing/unparseable (caller should
/// fall back to the raw `gameTime` string in that case).
///
/// The backend sends a naive (no offset/`Z`) isoformat() string that is
/// already UTC, so `DateTime.parse` must be told to treat it as UTC
/// explicitly rather than trusting `DateTime.tryParse`'s own guess (which
/// would otherwise interpret it as local device time and convert wrong).
String? formatGameLocalTime(String datetimeUtc) {
  if (datetimeUtc.isEmpty) return null;
  final parsed = DateTime.tryParse(datetimeUtc);
  if (parsed == null) return null;
  final asUtc = DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
  );
  return formatLocalClockTime(asUtc);
}

/// Formats a backend `YYYY-MM-DD` match date for display: French
/// "08/09/2026", English "Sep 8, 2026" (QA 15/09/2026 item 5). Returns the
/// input unchanged if it isn't a parseable date.
String formatMatchDate(String isoDate) {
  final d = DateTime.tryParse(isoDate);
  if (d == null) return isoDate;
  if (Get.locale?.languageCode == 'fr') {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

/// "Matchday 16" / "Journée 16".
String formatMatchdayLabel(int matchDay) =>
    AppString.matchdayNumberTemplate.trParams({'n': '$matchDay'});

/// Precise time-to-tip-off, e.g. "4 h 12 min" (QA 15/09/2026 item 6). Under
/// an hour it's just "12 min"; never rounds up to a whole hour.
String formatCountdown(int seconds) {
  final totalMinutes = (seconds / 60).floor();
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  if (h <= 0) {
    return AppString.minutesTemplate.trParams({'m': '$m'});
  }
  return AppString.hoursMinutesTemplate.trParams({'h': '$h', 'm': '$m'});
}
