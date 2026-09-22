class DayEntry {
  final String id;
  final String taskId;
  final String userId;
  final DateTime date; // normalized to midnight UTC date-only
  final bool checked; // the main checkbox (done today)
  final Map<String, dynamic> data; // columnId -> value

  const DayEntry({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.date,
    required this.checked,
    required this.data,
  });

  String get dateKey => DayEntry.dateToKey(date);
  static String dateToKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime keyToDate(String k) => DateTime.parse(k);

  DayEntry copyWith({bool? checked, Map<String, dynamic>? data}) => DayEntry(
        id: id,
        taskId: taskId,
        userId: userId,
        date: date,
        checked: checked ?? this.checked,
        data: data ?? this.data,
      );

  factory DayEntry.fromSupabase(Map<String, dynamic> j) => DayEntry(
        id: j['id'] as String,
        taskId: j['task_id'] as String,
        userId: j['user_id'] as String,
        date: DateTime.parse(j['entry_date'] as String),
        checked: j['checked'] is bool ? j['checked'] as bool : (j['checked'] == 1),
        data: j['data'] is Map ? Map<String, dynamic>.from(j['data']) : {},
      );

  Map<String, dynamic> toSupabase() => {
        'id': id,
        'task_id': taskId,
        'user_id': userId,
        'entry_date': dateKey,
        'checked': checked,
        'data': data,
      };

  dynamic valueFor(String columnId) => data[columnId];

  DayEntry withValue(String columnId, dynamic value) {
    final n = Map<String, dynamic>.from(data);
    if (value == null) {
      n.remove(columnId);
    } else {
      n[columnId] = value;
    }
    return copyWith(data: n);
  }
}
