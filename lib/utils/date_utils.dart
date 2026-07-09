/// Formats a [DateTime] as a zero-padded "YYYY-MM-DD" calendar-day key.
///
/// Used throughout the app to compare/group events by local calendar day
/// (streak tracking, notification rotation, metrics buckets) independent
/// of time-of-day.
String dateOnly(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
