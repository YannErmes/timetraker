import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_colors.dart';
import '../providers/app_providers.dart';
import '../widgets/weekly_grid.dart';
import '../widgets/daily_view.dart';
import '../widgets/monthly_view.dart';
import '../widgets/column_settings_panel.dart';
import '../widgets/view_settings.dart';
import '../widgets/filter_sidebar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(viewModeProvider);
    final svc = ref.watch(supabaseServiceProvider);
    final identity = ref.watch(identityServiceProvider);
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.header,
        title: Row(children: [
          const Text('Tracker Sheet', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
          if (identity.name != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.person_rounded, size: 12, color: AppColors.accent),
                const SizedBox(width: 4),
                Text(identity.name!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
        ]),
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
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.filter_list_rounded, color: AppColors.textSecondary),
              tooltip: 'Filters',
              onPressed: () {
                showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => DraggableScrollableSheet(initialChildSize: 0.7, maxChildSize: 0.9, minChildSize: 0.4, builder: (_, c) => Container(decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(12))), child: const FilterSidebarContent(showClose: true))));
              },
            ),
          const ViewSettingsButton(),
          IconButton(icon: const Icon(Icons.view_column, color: AppColors.textSecondary), tooltip: 'Manage Columns', onPressed: () => Scaffold.of(context).openEndDrawer()),
          IconButton(icon: const Icon(Icons.analytics_outlined, color: AppColors.textSecondary), tooltip: 'Analytics', onPressed: () => _showAnalytics(context, ref)),
          PopupMenuButton<String>(
            icon: const Icon(Icons.person_rounded, color: AppColors.textSecondary),
            tooltip: identity.name ?? 'Account',
            onSelected: (v) async {
              if (v == 'change') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.border)),
                    title: const Text('Change name?', style: TextStyle(color: AppColors.textPrimary)),
                    content: const Text('You will be signed out locally. Your data stays on the server under your current name and can be reclaimed by entering the exact same name again.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue'))],
                  ),
                );
                if (ok == true) await svc.signOut();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'change', child: Text('Signed in as "${identity.name ?? ''}" — change name')),
              const PopupMenuItem(value: 'change', child: Text('Sign out / change name')),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      endDrawer: const ColumnSettingsPanel(),
      drawer: isMobile
          ? Drawer(
              backgroundColor: AppColors.surface,
              child: ListView(children: [
                DrawerHeader(
                  decoration: const BoxDecoration(color: AppColors.header),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Tracker Sheet', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (identity.name != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.person_rounded, size: 12, color: AppColors.accent),
                          const SizedBox(width: 4),
                          Text(identity.name!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                  ]),
                ),
                ListTile(title: const Text('Weekly', style: TextStyle(color: AppColors.textPrimary)), selected: view == ViewMode.weekly, selectedTileColor: AppColors.inputFill, onTap: () { ref.read(viewModeProvider.notifier).state = ViewMode.weekly; Navigator.pop(context); }),
                ListTile(title: const Text('Daily', style: TextStyle(color: AppColors.textPrimary)), selected: view == ViewMode.daily, selectedTileColor: AppColors.inputFill, onTap: () { ref.read(viewModeProvider.notifier).state = ViewMode.daily; Navigator.pop(context); }),
                ListTile(title: const Text('Monthly', style: TextStyle(color: AppColors.textPrimary)), selected: view == ViewMode.monthly, selectedTileColor: AppColors.inputFill, onTap: () { ref.read(viewModeProvider.notifier).state = ViewMode.monthly; Navigator.pop(context); }),
                const Divider(color: AppColors.border),
                ListTile(title: const Text('Today (Android checklist)', style: TextStyle(color: AppColors.textSecondary)), onTap: () { ref.read(viewModeProvider.notifier).state = ViewMode.daily; Navigator.pop(context); }),
                const Divider(color: AppColors.border),
                ListTile(
                  leading: const Icon(Icons.person_rounded, size: 16, color: AppColors.textSecondary),
                  title: Text('Signed in as "${identity.name ?? ''}"', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  subtitle: const Text('Tap to change name', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                  onTap: () async {
                    Navigator.pop(context);
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.border)),
                        title: const Text('Change name?', style: TextStyle(color: AppColors.textPrimary)),
                        content: const Text('Your data stays under the current name. You can reclaim it later by entering the exact same name again.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue'))],
                      ),
                    );
                    if (ok == true) await svc.signOut();
                  },
                ),
              ]),
            )
          : null,
      body: isMobile
          ? _mobileBody(view)
          : Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: ref.watch(isFilterSidebarCollapsedProvider) ? 0 : 280,
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(border: Border(right: BorderSide(color: AppColors.border))),
                child: ref.watch(isFilterSidebarCollapsedProvider) ? const SizedBox.shrink() : const FilterSidebarContent(),
              ),
              InkWell(
                onTap: () => ref.read(isFilterSidebarCollapsedProvider.notifier).state = !ref.read(isFilterSidebarCollapsedProvider),
                child: Container(
                  width: 12,
                  color: AppColors.header,
                  child: Center(
                    child: Icon(
                      ref.watch(isFilterSidebarCollapsedProvider) ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              Expanded(child: _desktopBody(view)),
            ]),
      floatingActionButton: isMobile
          ? FloatingActionButton(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              onPressed: () => _showAddTaskForCurrentView(context, ref),
              child: const Icon(Icons.add_rounded),
            )
          : null,
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

  Widget _mobileBody(ViewMode view) {
    // On phone, use the same desktop views but they are already responsive (Weekly has horizontal scroll + pagination, Daily has square grid, Monthly has grid)
    // Wrap in a SafeArea and add a bit of padding for thumb reach
    return _desktopBody(view);
  }

  void _showAddTaskForCurrentView(BuildContext context, WidgetRef ref) {
    final view = ref.read(viewModeProvider);
    final svc = ref.read(supabaseServiceProvider);
    if (view == ViewMode.monthly) {
      // Monthly has its own Add task dialog with date+params, trigger it via MonthlyView's method
      // For mobile, just show a simple add task dialog that will be scheduled for today
      final c = TextEditingController();
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
          title: const Text('Add task', style: TextStyle(color: AppColors.textPrimary)),
          content: TextField(controller: c, autofocus: true, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(labelText: 'Task name', hintText: 'e.g. Gym')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = c.text.trim();
                if (name.isEmpty) return;
                await svc.addTask(name);
                // auto-schedule for today so it appears immediately in Daily
                final today = ref.read(selectedDateProvider);
                await svc.toggleChecked(svc.tasks.lastWhere((t) => t.name == name).id, today, true);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      );
      return;
    }
    // Weekly/Daily: use same add as desktop
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.border)),
        title: const Text('Add task', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(controller: c, autofocus: true, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(labelText: 'Task name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () { if (c.text.trim().isNotEmpty) svc.addTask(c.text.trim()); Navigator.pop(context); }, child: const Text('Add')),
        ],
      ),
    );
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
