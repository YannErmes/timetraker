class Task {
  final String id;
  final String name;
  final int position;
  final DateTime createdAt;
  final String userId;
  /// Reminder shorthand (e.g. 10MI, 2H, 1D, 1W, 1M) — null/empty = none.
  final String? reminder;

  /// Tag ids attached to the task itself, as opposed to the tags column that
  /// tags a task on one particular day. A task tagged "project" stays tagged
  /// "project" on every day, including days it was never scheduled on.
  final List<String> tags;

  const Task({
    required this.id,
    required this.name,
    required this.position,
    required this.createdAt,
    required this.userId,
    this.reminder,
    this.tags = const [],
  });

  Task copyWith({String? name, int? position, String? Function()? reminder, List<String>? tags}) => Task(
        id: id,
        name: name ?? this.name,
        position: position ?? this.position,
        createdAt: createdAt,
        userId: userId,
        reminder: reminder != null ? reminder() : this.reminder,
        tags: tags ?? this.tags,
      );

  factory Task.fromSupabase(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        name: j['name'] as String,
        position: (j['position'] as num).toInt(),
        createdAt: DateTime.parse(j['created_at'] as String),
        userId: j['user_id'] as String,
        reminder: (j['reminder'] as String?)?.trim().isEmpty == true ? null : j['reminder'] as String?,
        // Written as jsonb, but a missing column (older schema) or a text value
        // must not break the whole task list.
        tags: _tagIds(j['tags']),
      );

  Map<String, dynamic> toSupabase() => {
        'id': id,
        'name': name,
        'position': position,
        'user_id': userId,
        'reminder': reminder,
        'tags': tags,
      };

  /// Reads the tag id list from whatever the database handed back: a jsonb
  /// array, a Postgres text array, or nothing at all.
  static List<String> _tagIds(dynamic raw) {
    if (raw is List) return raw.map((e) => '$e').where((e) => e.isNotEmpty).toList();
    if (raw is String && raw.trim().isNotEmpty) {
      // A string that is really a json array, e.g. ["a","b"].
      final s = raw.trim();
      if (s.startsWith('[') && s.endsWith(']')) {
        return s
            .substring(1, s.length - 1)
            .split(',')
            .map((e) => e.trim().replaceAll('"', '').replaceAll("'", '').trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }
    return const [];
  }

  /// Parse a reminder shorthand into a Duration.
  /// Units (case-insensitive): MI = minutes, H = hours, D = days,
  /// W = weeks, M = months (30 days). e.g. 10MI, 2H, 3D, 1W, 1M.
  /// Returns null when invalid.
  static Duration? parseReminder(String? raw) {
    if (raw == null) return null;
    final m = RegExp(r'^\s*(\d+)\s*(MI|M|H|D|W)\s*$', caseSensitive: false).firstMatch(raw);
    if (m == null) return null;
    final n = int.tryParse(m.group(1)!);
    if (n == null || n <= 0) return null;
    switch (m.group(2)!.toUpperCase()) {
      case 'MI':
        return Duration(minutes: n);
      case 'H':
        return Duration(hours: n);
      case 'D':
        return Duration(days: n);
      case 'W':
        return Duration(days: 7 * n);
      case 'M':
        return Duration(days: 30 * n);
    }
    return null;
  }
}
