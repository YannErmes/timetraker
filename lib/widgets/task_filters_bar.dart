import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_colors.dart';
import '../providers/task_filters.dart';
import '../providers/app_providers.dart';

class TaskFiltersBar extends ConsumerWidget {
  const TaskFiltersBar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(taskFiltersProvider);
    final cols = ref.watch(supabaseServiceProvider).columns;
    // find status options for dropdown
    final statusCol = cols.where((c) => c.type.name == 'status').firstOrNull;
    final statusOpts = statusCol != null ? (statusCol.config['options'] as List? ?? []) : [];
    final tagCols = cols.where((c) => c.type.name == 'tags').toList();
    final allTags = <String, String>{};
    for (final c in tagCols) {
      final opts = c.config['options'] as List? ?? [];
      for (final o in opts) {
        final m = Map<String, dynamic>.from(o);
        allTags[m['id'] as String] = m['label'] as String;
      }
    }

    return Container(
      color: AppColors.header,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 200,
          child: TextField(
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Search tasks…',
              hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.textSecondary),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            onChanged: (v) => ref.read(taskFiltersProvider.notifier).setSearch(v),
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String?>(
            value: filters.status,
            isExpanded: true,
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            decoration: const InputDecoration(labelText: 'Status', isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('All statuses', overflow: TextOverflow.ellipsis)),
              ...statusOpts.map((o) {
                final m = Map<String, dynamic>.from(o);
                return DropdownMenuItem(value: m['id'] as String, child: Text(m['label'] as String, overflow: TextOverflow.ellipsis));
              }),
            ],
            onChanged: (v) => ref.read(taskFiltersProvider.notifier).setStatus(v),
          ),
        ),
        if (allTags.isNotEmpty)
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String?>(
              value: filters.tag,
              isExpanded: true,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
              decoration: const InputDecoration(labelText: 'Tag', isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('All tags', overflow: TextOverflow.ellipsis)),
                ...allTags.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => ref.read(taskFiltersProvider.notifier).setTag(v),
            ),
          ),
        FilterChip(
          label: const Text('Has note', style: TextStyle(fontSize: 11)),
          selected: filters.hasNoteOnly,
          onSelected: (v) => ref.read(taskFiltersProvider.notifier).setHasNoteOnly(v),
          backgroundColor: AppColors.inputFill,
          selectedColor: AppColors.accent.withValues(alpha: 0.25),
          side: BorderSide(color: filters.hasNoteOnly ? AppColors.accent : AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        if (filters.search.isNotEmpty || filters.status != null || filters.hasNoteOnly || filters.tag != null)
          TextButton.icon(onPressed: () => ref.read(taskFiltersProvider.notifier).clear(), icon: const Icon(Icons.clear, size: 14), label: const Text('Clear')),
        const SizedBox(width: 4),
        Text('${_activeCount(filters)} filter${_activeCount(filters)==1?'':'s'} active', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ]),
    );
  }
  int _activeCount(TaskFilters f) {
    int c = 0;
    if (f.search.isNotEmpty) c++;
    if (f.status != null) c++;
    if (f.hasNoteOnly) c++;
    if (f.tag != null) c++;
    return c;
  }
}
