import 'package:flutter/material.dart';

enum ColumnType {
  checkbox,
  status,
  number,
  date,
  datetime,
  tags,
  text,
  timer,
  schedule,
}

extension ColumnTypeX on ColumnType {
  String get label {
    switch (this) {
      case ColumnType.checkbox:
        return 'Checkbox';
      case ColumnType.status:
        return 'Status';
      case ColumnType.number:
        return 'Number / Duration';
      case ColumnType.date:
        return 'Date';
      case ColumnType.datetime:
        return 'DateTime';
      case ColumnType.tags:
        return 'Tags';
      case ColumnType.text:
        return 'Text';
      case ColumnType.timer:
        return 'Time Length Selector';
      case ColumnType.schedule:
        return 'Schedule';
    }
  }

  String get description {
    switch (this) {
      case ColumnType.checkbox:
        return 'Single tickbox — done / not done';
      case ColumnType.status:
        return 'Colored dropdown (e.g. none / done / cancel)';
      case ColumnType.number:
        return 'Number with optional unit (h, min)';
      case ColumnType.date:
        return 'Calendar date picker';
      case ColumnType.datetime:
        return 'Date + time picker';
      case ColumnType.tags:
        return 'Multiple colored tags per cell';
      case ColumnType.text:
        return 'Free-form notes';
      case ColumnType.timer:
        return 'Estimated duration + live countdown timer';
      case ColumnType.schedule:
        return 'Time-of-day for that day (e.g. 9:00 AM)';
    }
  }

  IconData get icon {
    switch (this) {
      case ColumnType.checkbox:
        return Icons.check_box_outlined;
      case ColumnType.status:
        return Icons.flag_outlined;
      case ColumnType.number:
        return Icons.timer_outlined;
      case ColumnType.date:
        return Icons.calendar_today_outlined;
      case ColumnType.datetime:
        return Icons.schedule_outlined;
      case ColumnType.tags:
        return Icons.label_outlined;
      case ColumnType.text:
        return Icons.notes_outlined;
      case ColumnType.timer:
        return Icons.hourglass_bottom_rounded;
      case ColumnType.schedule:
        return Icons.access_time_rounded;
    }
  }

  static ColumnType fromString(String s) =>
      ColumnType.values.firstWhere((e) => e.name == s, orElse: () => ColumnType.text);
}
