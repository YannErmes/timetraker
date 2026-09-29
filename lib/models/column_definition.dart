import 'enums.dart';

class StatusOption {
  final String id;
  final String label;

  /// The colour the customer picked for this status, e.g. `#22C55E`.
  ///
  /// Empty means "not chosen yet". There is no built-in colour per status: a
  /// customer who never opened the colour picker gets the neutral one from
  /// [neutralColor] rather than a colour the app made up. Rows written before
  /// this was optional are read as-is, so colours already picked are kept.
  final String colorHex;

  const StatusOption({required this.id, required this.label, this.colorHex = ''});

  /// Shown for a status with no colour of its own, so the pill still reads as
  /// a pill instead of borrowing another status's colour.
  static const neutralColor = '#64748B';

  bool get hasColor => colorHex.isNotEmpty;

  /// What to actually paint: the customer's choice, or the neutral one.
  String get effectiveColorHex => hasColor ? colorHex : neutralColor;

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'colorHex': colorHex};
  factory StatusOption.fromJson(Map<String, dynamic> j) => StatusOption(
        id: j['id'] as String,
        label: j['label'] as String,
        // A missing key (or a null written by an older build) means unchosen.
        colorHex: (j['colorHex'] as String?) ?? '',
      );
}

class TagOption {
  final String id;
  final String label;
  final String colorHex;
  const TagOption({required this.id, required this.label, required this.colorHex});
  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'colorHex': colorHex};
  factory TagOption.fromJson(Map<String, dynamic> j) =>
      TagOption(id: j['id'] as String, label: j['label'] as String, colorHex: j['colorHex'] as String);
}

class ColumnDefinition {
  final String id;
  final String label;
  final ColumnType type;
  final int position;
  /// Type-specific config stored as json. Examples:
  /// status: { options: [StatusOption] }
  /// tags: { options: [TagOption] }
  /// number: { unit: 'h' | 'min' | '' }
  final Map<String, dynamic> config;
  /// If non-empty, column only visible on those weekday names (mon..sun) or specific dates. null = all days.
  final List<String>? visibleDays;

  const ColumnDefinition({
    required this.id,
    required this.label,
    required this.type,
    required this.position,
    this.config = const {},
    this.visibleDays,
  });

  List<StatusOption> get statusOptions {
    final l = config['options'] as List?;
    if (l == null) return [];
    return l.map((e) => StatusOption.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  List<TagOption> get tagOptions {
    final l = config['options'] as List?;
    if (l == null) return [];
    return l.map((e) => TagOption.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  String get unit => config['unit'] as String? ?? '';

  ColumnDefinition copyWith({
    String? label,
    ColumnType? type,
    int? position,
    Map<String, dynamic>? config,
    List<String>? visibleDays,
  }) =>
      ColumnDefinition(
        id: id,
        label: label ?? this.label,
        type: type ?? this.type,
        position: position ?? this.position,
        config: config ?? this.config,
        visibleDays: visibleDays ?? this.visibleDays,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'type': type.name,
        'position': position,
        'config': config,
        'visible_days': visibleDays,
      };

  factory ColumnDefinition.fromJson(Map<String, dynamic> j) => ColumnDefinition(
        id: j['id'] as String,
        label: j['label'] as String,
        type: ColumnTypeX.fromString(j['type'] as String),
        position: (j['position'] as num).toInt(),
        config: j['config'] is Map ? Map<String, dynamic>.from(j['config']) : {},
        visibleDays: j['visible_days'] is List ? List<String>.from(j['visible_days']) : null,
      );

  /// Supabase row (snake_case)
  factory ColumnDefinition.fromSupabase(Map<String, dynamic> j) => ColumnDefinition(
        id: j['id'] as String,
        label: j['label'] as String,
        type: ColumnTypeX.fromString(j['type'] as String),
        position: (j['position'] as num).toInt(),
        config: j['config'] is Map ? Map<String, dynamic>.from(j['config']) : {},
        visibleDays: j['visible_days'] is List ? List<String>.from(j['visible_days']) : null,
      );

  Map<String, dynamic> toSupabase(String userId) => {
        'id': id,
        'user_id': userId,
        'label': label,
        'type': type.name,
        'position': position,
        'config': config,
        'visible_days': visibleDays,
      };

  /// First-install default: status column only (user adds more if wanted).
  static List<ColumnDefinition> defaultColumns() => [
        ColumnDefinition(
          id: 'col_status',
          label: 'status',
          type: ColumnType.status,
          position: 0,
          config: {
            // No colours: every status starts neutral and the customer picks
            // its own in the column settings. `none` used to ship purple and
            // `idle` gray, which is how a brand-new workspace ended up with
            // colours nobody chose.
            'options': [
              const StatusOption(id: 'idle', label: 'idle').toJson(),
              const StatusOption(id: 'none', label: 'none').toJson(),
              const StatusOption(id: 'done', label: 'done').toJson(),
              const StatusOption(id: 'cancel', label: 'cancel').toJson(),
              const StatusOption(id: 'in_progress', label: 'in progress').toJson(),
            ]
          },
        ),
      ];
}
