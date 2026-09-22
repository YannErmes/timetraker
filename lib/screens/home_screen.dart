import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_colors.dart';
import '../providers/app_providers.dart';
import '../widgets/weekly_grid.dart';
import '../widgets/daily_view.dart';
import '../widgets/monthly_view.dart';
import '../widgets/column_settings_panel.dart';
import '../widgets/android_checklist.dart';
import '../widgets/view_settings.dart';
import '../widgets/task_filters_bar.dart';
import '../widgets/column_visibility_bar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(viewModeProvider);
    final svc = ref.watch(supabaseServiceProvider);
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.header,
        title: const Text('Tracker Sheet', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [
          if (!isMobile) ...[
            SegmentedButton<ViewMode>(
              segments: const [
                ButtonSegment(value: ViewMode.weekly, label: Text('Weekly'), icon: Icon(Icons.view_week, size: 16)),
                ButtonSegment(value: ViewMode.daily, label: Text('Daily'), icon: Icon(Icons.view_day, size: 16)),
                ButtonSegment(value: ViewMode.monthly, label: Text('Monthly'), icon: Icon(Icons.calendar_month, size: 16)),
              ],
              selected: {view},
              onSelectionChanged: (s) => ref.read(viewModeProvider.notifier).state = s.first,
            ),
            const SizedBox(width: 12),
          ],
          const ViewSettingsButton(),
          IconButton(icon: const Icon(Icons.view_column, color: AppColors.textSecondary), tooltip: 'Manage Columns', onPressed: () => Scaffold.of(context).openEndDrawer()),
          IconButton(icon: const Icon(Icons.analytics_outlined, color: AppColors.textSecondary), tooltip: 'Analytics', onPressed: () => _showAnalytics(context, ref)),
          IconButton(icon: const Icon(Icons.logout, color: AppColors.textSecondary), onPressed: () => svc.signOut()),
          const SizedBox(width: 4),
        ],
      ),
      endDrawer: const ColumnSettingsPanel(),
      drawer: isMobile
          ? Drawer(
              backgroundColor: AppColors.surface,
              child: ListView(children: [
                const DrawerHeader(
                  decoration: BoxDecoration(color: AppColors.header),
                  child: Text('Tracker Sheet', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                ),
                ListTile(title: const Text('Weekly', style: TextStyle(color: AppColors.textPrimary)), selected: view == ViewMode.weekly, selectedTileColor: AppColors.inputFill, onTap: () { ref.read(viewModeProvider.notifier).state = ViewMode.weekly; Navigator.pop(context); }),
                ListTile(title: const Text('Daily', style: TextStyle(color: AppColors.textPrimary)), selected: view == ViewMode.daily, selectedTileColor: AppColors.inputFill, onTap: () { ref.read(viewModeProvider.notifier).state = ViewMode.daily; Navigator.pop(context); }),
                ListTile(title: const Text('Monthly', style: TextStyle(color: AppColors.textPrimary)), selected: view == ViewMode.monthly, selectedTileColor: AppColors.inputFill, onTap: () { ref.read(viewModeProvider.notifier).state = ViewMode.monthly; Navigator.pop(context); }),
                const Divider(color: AppColors.border),
                ListTile(title: const Text('Today (Android checklist)', style: TextStyle(color: AppColors.textSecondary)), onTap: () { ref.read(viewModeProvider.notifier).state = ViewMode.daily; Navigator.pop(context); }),
              ]),
            )
          : null,
      body: Column(children: [
        const TaskFiltersBar(),
        const Divider(height: 1, color: AppColors.border),
        const ColumnVisibilityBar(compact: false),
        const Divider(height: 1, color: AppColors.border),
        Expanded(child: isMobile ? const AndroidChecklist() : _desktopBody(view)),
      ]),
      bottomNavigationBar: isMobile
          ? NavigationBar(
              backgroundColor: AppColors.header,
              indicatorColor: AppColors.accent,
              selectedIndex: [ViewMode.weekly, ViewMode.daily, ViewMode.monthly].indexOf(view),
              onDestinationSelected: (i) => ref.read(viewModeProvider.notifier).state = [ViewMode.weekly, ViewMode.daily, ViewMode.monthly][i],
              destinations: const [
                NavigationDestination(icon: Icon(Icons.view_week, color: AppColors.textSecondary), selectedIcon: Icon(Icons.view_week, color: Colors.white), label: 'Weekly'),
                NavigationDestination(icon: Icon(Icons.view_day, color: AppColors.textSecondary), selectedIcon: Icon(Icons.view_day, color: Colors.white), label: 'Daily'),
                NavigationDestination(icon: Icon(Icons.calendar_month, color: AppColors.textSecondary), selectedIcon: Icon(Icons.calendar_month, color: Colors.white), label: 'Monthly'),
              ],
            )
          : null,
    );
  }

  Widget _desktopBody(ViewMode view) {
    switch (view) {
      case ViewMode.weekly:
        return const WeeklyGrid();
      case ViewMode.daily:
        return const DailyView();
      case ViewMode.monthly:
        return const MonthlyView();
    }
  }

  void _showAnalytics(BuildContext context, WidgetRef ref) {
    final svc = ref.read(supabaseServiceProvider);
    final tasks = List.of(svc.tasks)..sort((a, b) => a.position.compareTo(b.position));
    final entries = svc.entries;
    final cols = svc.columns;
    // find status column (first type==status) — default col_status
    final statusCol = cols.where((c) => c.type.name == 'status').firstOrNull;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.border)),
        title: const Text('Analytics', style: TextStyle(color: AppColors.textPrimary)),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final t in tasks)
              Builder(builder: (_) {
                // scheduled = days where checkbox is checked (task should be performed)
                final scheduled = entries.where((e) => e.taskId == t.id && e.checked).toList()
                  ..sort((a, b) => a.date.compareTo(b.date));
                final total = scheduled.length;
                int done = 0;
                String? mostRecentStatus;
                if (statusCol != null && total > 0) {
                  done = scheduled.where((e) => (e.data[statusCol.id] as String?) == 'done').length;
                  // most recent scheduled entry by date
                  final mostRecent = scheduled.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
                  mostRecentStatus = mostRecent.data[statusCol.id] as String?;
                } else if (statusCol == null) {
                  // fallback: no status column -> treat checked as done (legacy)
                  done = total;
                }
                final pct = total == 0 ? 0.0 : done / total;
                // color based on most recent status
                Color barColor;
                switch (mostRecentStatus) {
                  case 'in_progress':
                  case 'in progress':
                    barColor = const Color(0xFFF59E0B); // amber
                    break;
                  case 'cancel':
                  case 'cancelled':
                    barColor = const Color(0xFFF43F5E); // red
                    break;
                  case 'done':
                    barColor = const Color(0xFF22C55E); // green
                    break;
                  case 'none':
                  case null:
                    barColor = total == 0 ? const Color(0xFF475569) : AppColors.accent;
                    break;
                  default:
                    barColor = AppColors.accent;
                }
                // if no scheduled days, keep gray
                if (total == 0) barColor = const Color(0xFF475569);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(child: Text(t.name.isEmpty ? 'untitled' : t.name, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary))),
                    SizedBox(width: 120, child: LinearProgressIndicator(value: pct, backgroundColor: AppColors.inputFill, valueColor: AlwaysStoppedAnimation(barColor), borderRadius: BorderRadius.circular(8), minHeight: 6)),
                    const SizedBox(width: 8),
                    Text('${(pct * 100).toStringAsFixed(0)}% ($done/$total)', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ]),
                );
              }),
            if (tasks.isEmpty) const Text('No tasks yet', style: TextStyle(color: AppColors.textSecondary)),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }
}
