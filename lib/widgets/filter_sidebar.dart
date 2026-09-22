import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_colors.dart';
import '../providers/task_filters.dart';
import '../providers/app_providers.dart';

class FilterSidebar extends ConsumerWidget {
  const FilterSidebar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: AppColors.surface,
      width: 300,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: AppColors.border)),
      child: const SafeArea(child: FilterSidebarContent(showClose: true)),
    );
  }
}

class FilterSidebarContent extends ConsumerWidget {
  final bool showClose;
  const FilterSidebarContent({super.key, this.showClose = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(taskFiltersProvider);
    final cols = ref.watch(supabaseServiceProvider).columns;
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
    return Column(children: [
      Container(
        color: AppColors.header,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          const Icon(Icons.filter_list_rounded, size: 18, color: AppColors.textPrimary),
          const SizedBox(width: 8),
          const Text('Filters', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('${_activeCount(filters)} active', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          if (showClose) IconButton(icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary), onPressed: () => Navigator.pop(context)),
        ]),
      ),
      const Divider(height: 1, color: AppColors.border),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(12), children: [
          TextField(
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            decoration: InputDecoration(
              labelText: 'Search tasks',
              hintText: 'Search tasks…',
              hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.textSecondary),
              isDense: true,
            ),
            onChanged: (v) => ref.read(taskFiltersProvider.notifier).setSearch(v),
            controller: TextEditingController(text: filters.search)..selection = TextSelection.collapsed(offset: filters.search.length),
          ),
          const SizedBox(height: 16),
          const Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String?>(
            value: filters.status,
            isExpanded: true,
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            decoration: const InputDecoration(isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('All statuses')),
              ...statusOpts.map((o) {
                final m = Map<String, dynamic>.from(o);
                return DropdownMenuItem(value: m['id'] as String, child: Text(m['label'] as String));
              }),
            ],
            onChanged: (v) => ref.read(taskFiltersProvider.notifier).setStatus(v),
          ),
          if (allTags.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Tag', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String?>(
              value: filters.tag,
              isExpanded: true,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
              decoration: const InputDecoration(isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('All tags')),
                ...allTags.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
              ],
              onChanged: (v) => ref.read(taskFiltersProvider.notifier).setTag(v),
            ),
          ],
          const SizedBox(height: 16),
          FilterChip(
            label: const Text('Has note only', style: TextStyle(fontSize: 12)),
            selected: filters.hasNoteOnly,
            onSelected: (v) => ref.read(taskFiltersProvider.notifier).setHasNoteOnly(v),
            backgroundColor: AppColors.inputFill,
            selectedColor: AppColors.accent.withValues(alpha: 0.25),
            side: BorderSide(color: filters.hasNoteOnly ? AppColors.accent : AppColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          const SizedBox(height: 24),
          if (filters.search.isNotEmpty || filters.status != null || filters.hasNoteOnly || filters.tag != null)
            FilledButton.icon(
              onPressed: () => ref.read(taskFiltersProvider.notifier).clear(),
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear all filters'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.inputFill, foregroundColor: AppColors.textPrimary, side: const BorderSide(color: AppColors.border)),
            ),
        ]),
      ),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
        child: Text('${_activeCount(filters)} filter${_activeCount(filters)==1?'':'s'} active • Filters apply to Weekly, Daily and Monthly', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ),
    ]);
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
