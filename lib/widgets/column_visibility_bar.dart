import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_colors.dart';
import '../providers/app_providers.dart';
import '../providers/column_visibility.dart';
import '../models/enums.dart';

class ColumnVisibilityBar extends ConsumerWidget {
  final bool compact;
  const ColumnVisibilityBar({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.watch(supabaseServiceProvider);
    ref.watch(columnsProvider);
    final cols = List.of(svc.columns)..sort((a, b) => a.position.compareTo(b.position));
    final hidden = ref.watch(columnVisibilityProvider);
    if (cols.isEmpty) return const SizedBox.shrink();

    return Container(
      color: AppColors.header,
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: 6),
      child: Row(children: [
        const Icon(Icons.visibility_outlined, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(compact ? 'Show:' : 'Visible columns:', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final col in cols)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(col.type.icon, size: 12, color: hidden.contains(col.id) ? AppColors.textSecondary : AppColors.accent),
                      const SizedBox(width: 4),
                      Text(col.label, style: const TextStyle(fontSize: 11)),
                    ]),
                    selected: !hidden.contains(col.id),
                    onSelected: (_) => ref.read(columnVisibilityProvider.notifier).toggle(col.id),
                    backgroundColor: AppColors.inputFill,
                    selectedColor: AppColors.accent.withValues(alpha: 0.22),
                    side: BorderSide(color: hidden.contains(col.id) ? AppColors.border : AppColors.accent.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    showCheckmark: false,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () => ref.read(columnVisibilityProvider.notifier).showAll(cols),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: const Text('Show all', style: TextStyle(fontSize: 10)),
        ),
        TextButton(
          onPressed: () => ref.read(columnVisibilityProvider.notifier).hideAll(cols),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: const Text('Hide all', style: TextStyle(fontSize: 10)),
        ),
      ]),
    );
  }
}

class ColumnVisibilitySection extends ConsumerWidget {
  const ColumnVisibilitySection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.watch(supabaseServiceProvider);
    ref.watch(columnsProvider);
    final cols = List.of(svc.columns)..sort((a, b) => a.position.compareTo(b.position));
    final hidden = ref.watch(columnVisibilityProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Visible columns', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
      const SizedBox(height: 4),
      const Text('Tap to collapse/expand each per-day field. Hidden columns stay in your data but are not shown in Weekly/Daily.', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final col in cols)
          FilterChip(
            label: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(col.type.icon, size: 14, color: hidden.contains(col.id) ? AppColors.textSecondary : AppColors.accent),
              const SizedBox(width: 6),
              Text(col.label),
            ]),
            selected: !hidden.contains(col.id),
            onSelected: (_) => ref.read(columnVisibilityProvider.notifier).toggle(col.id),
            backgroundColor: AppColors.inputFill,
            selectedColor: AppColors.accent.withValues(alpha: 0.22),
            side: BorderSide(color: hidden.contains(col.id) ? AppColors.border : AppColors.accent),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        OutlinedButton(onPressed: () => ref.read(columnVisibilityProvider.notifier).showAll(cols), child: const Text('Show all')),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: () => ref.read(columnVisibilityProvider.notifier).hideAll(cols), child: const Text('Hide all')),
      ]),
    ]);
  }
}
