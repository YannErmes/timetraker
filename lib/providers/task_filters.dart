import 'package:flutter_riverpod/flutter_riverpod.dart';

class TaskFilters {
  final String search;
  final String? status; // null = all, else id like 'done','in_progress','cancel','none'
  final bool hasNoteOnly;
  final String? tag; // filter by tag id
  const TaskFilters({this.search = '', this.status, this.hasNoteOnly = false, this.tag});
  TaskFilters copyWith({String? search, String? status, bool? hasNoteOnly, String? tag, bool clearStatus = false, bool clearTag = false}) =>
      TaskFilters(
        search: search ?? this.search,
        status: clearStatus ? null : (status ?? this.status),
        hasNoteOnly: hasNoteOnly ?? this.hasNoteOnly,
        tag: clearTag ? null : (tag ?? this.tag),
      );
}

class TaskFiltersNotifier extends StateNotifier<TaskFilters> {
  TaskFiltersNotifier() : super(const TaskFilters());
  void setSearch(String v) => state = state.copyWith(search: v);
  void setStatus(String? v) => state = v == null ? state.copyWith(clearStatus: true) : state.copyWith(status: v);
  void setHasNoteOnly(bool v) => state = state.copyWith(hasNoteOnly: v);
  void setTag(String? v) => state = v == null ? state.copyWith(clearTag: true) : state.copyWith(tag: v);
  void clear() => state = const TaskFilters();
}

final taskFiltersProvider = StateNotifierProvider<TaskFiltersNotifier, TaskFilters>((ref) => TaskFiltersNotifier());
