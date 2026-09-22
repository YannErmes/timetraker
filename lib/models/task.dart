class Task {
  final String id;
  final String name;
  final int position;
  final DateTime createdAt;
  final String userId;

  const Task({
    required this.id,
    required this.name,
    required this.position,
    required this.createdAt,
    required this.userId,
  });

  Task copyWith({String? name, int? position}) => Task(
        id: id,
        name: name ?? this.name,
        position: position ?? this.position,
        createdAt: createdAt,
        userId: userId,
      );

  factory Task.fromSupabase(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        name: j['name'] as String,
        position: (j['position'] as num).toInt(),
        createdAt: DateTime.parse(j['created_at'] as String),
        userId: j['user_id'] as String,
      );

  Map<String, dynamic> toSupabase() => {
        'id': id,
        'name': name,
        'position': position,
        'user_id': userId,
      };
}
