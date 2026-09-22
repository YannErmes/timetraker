import 'package:intl/intl.dart';

DateTime normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

String formatDayHeader(DateTime d) => DateFormat('M/d/yyyy').format(d);
String formatWeekday(DateTime d) => DateFormat('EEEE').format(d).toLowerCase(); // tuesday
String formatShort(DateTime d) => DateFormat('MMM d').format(d);

List<DateTime> weekDates(DateTime anchor) {
  // anchor within week, return Mon..Sun or Tue..Fri? Default Mon-Sun, but allow any 7-day window.
  // For spreadsheet mirror, show Tue-Fri style - we show 7 days starting Monday.
  final n = normalizeDate(anchor);
  final monday = n.subtract(Duration(days: n.weekday - 1));
  return List.generate(7, (i) => monday.add(Duration(days: i)));
}

List<DateTime> monthDates(DateTime anchor) {
  final first = DateTime(anchor.year, anchor.month, 1);
  final start = first.subtract(Duration(days: first.weekday - 1));
  // 6 weeks grid
  return List.generate(42, (i) => start.add(Duration(days: i)));
}
