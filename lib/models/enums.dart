import 'package:flutter/material.dart';
import 'package:tracker_sheet/l10n/app_localizations.dart';

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
  reminder,
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
      case ColumnType.reminder:
        return 'Reminder';
    }
  }

  /// Localized label (needs l10n from the UI layer).
  String labelL(AppLocalizations t) {
    switch (this) {
      case ColumnType.checkbox:
        return t.ctCheckbox;
      case ColumnType.status:
        return t.ctStatus;
      case ColumnType.number:
        return t.ctNumber;
      case ColumnType.date:
        return t.ctDate;
      case ColumnType.datetime:
        return t.ctDatetime;
      case ColumnType.tags:
        return t.ctTags;
      case ColumnType.text:
        return t.ctText;
      case ColumnType.timer:
        return t.ctTimer;
      case ColumnType.schedule:
        return t.ctSchedule;
      case ColumnType.reminder:
        return t.ctReminder;
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
      case ColumnType.reminder:
        return 'Dated message — email + app notification at that time';
    }
  }

  /// Localized description (needs l10n from the UI layer).
  String descL(AppLocalizations t) {
    switch (this) {
      case ColumnType.checkbox:
        return t.ctCheckboxDesc;
      case ColumnType.status:
        return t.ctStatusDesc;
      case ColumnType.number:
        return t.ctNumberDesc;
      case ColumnType.date:
        return t.ctDateDesc;
      case ColumnType.datetime:
        return t.ctDatetimeDesc;
      case ColumnType.tags:
        return t.ctTagsDesc;
      case ColumnType.text:
        return t.ctTextDesc;
      case ColumnType.timer:
        return t.ctTimerDesc;
      case ColumnType.schedule:
        return t.ctScheduleDesc;
      case ColumnType.reminder:
        return t.ctReminderDesc;
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
      case ColumnType.reminder:
        return Icons.notifications_outlined;
    }
  }

  static ColumnType fromString(String s) =>
      ColumnType.values.firstWhere((e) => e.name == s, orElse: () => ColumnType.text);
}
