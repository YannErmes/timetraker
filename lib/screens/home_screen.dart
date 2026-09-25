import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_sheet/l10n/app_localizations.dart';
import '../config/app_colors.dart';
import '../config/ui_style.dart';
import '../providers/app_providers.dart';
import '../providers/display_prefs.dart';
import '../services/supabase_service.dart';
import '../widgets/weekly_grid.dart';
import '../widgets/daily_view.dart';
import '../widgets/monthly_view.dart';
import '../widgets/column_settings_panel.dart';
import '../widgets/note_editor_panel.dart';
import '../widgets/analytics_panel.dart';
import '../widgets/suggestion_dialog.dart';
import '../widgets/view_settings.dart';
import '../widgets/filter_sidebar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openColumnManager() {
    // Clear any note request so the drawer shows columns, not the editor.
    ref.read(noteEditorRequestProvider.notifier).state = null;
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _openNoteEditor() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    // Whenever any note cell requests the editor, swap the drawer and open it.
    ref.listen<NoteEditorRequest?>(noteEditorRequestProvider, (_, req) {
      if (req != null) _openNoteEditor();
    });
    final view = ref.watch(viewModeProvider);
    final svc = ref.watch(supabaseServiceProvider);
    final identity = ref.watch(identityServiceProvider);
    final isMobile = MediaQuery.of(context).size.width < 700;
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.header,
        automaticallyImplyLeading: isMobile,
        titleSpacing: isMobile ? 4 : 16,
        title: LayoutBuilder(builder: (ctx, c) {
          final narrow = c.maxWidth < 380;
          return Row(children: [
            Flexible(child: Text('4cus', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16), overflow: TextOverflow.ellipsis)),
            if (!isMobile && identity.name != null && !narrow) ...[
              const SizedBox(width: 10),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.person_rounded, size: 12, color: AppColors.accent),
                    const SizedBox(width: 4),
                    Flexible(child: Text(identity.name!, style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              ),
            ],
          ]);
        }),
        actions: [
          Builder(builder: (ctx) {
            final light = ref.watch(displayPrefsProvider).lightMode;
            return IconButton(
              icon: Icon(light ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: AppColors.textSecondary),
              tooltip: light ? t.switchDark : t.switchLight,
              onPressed: () => ref.read(displayPrefsProvider.notifier).setLightMode(!light),
            );
          }),
          _SyncStatusButton(svc: svc, email: identity.name),
          if (!isMobile) ...[
            SegmentedButton<ViewMode>(
              segments: [
                ButtonSegment(value: ViewMode.weekly, label: Text(t.weekly), icon: Icon(Icons.view_week, size: 16)),
                ButtonSegment(value: ViewMode.daily, label: Text(t.daily), icon: Icon(Icons.view_day, size: 16)),
                ButtonSegment(value: ViewMode.monthly, label: Text(t.monthly), icon: Icon(Icons.calendar_month, size: 16)),
                ButtonSegment(value: ViewMode.analytics, label: Text(t.analytics), icon: Icon(Icons.analytics_outlined, size: 16)),
              ],
              selected: {view},
              onSelectionChanged: (s) => ref.read(viewModeProvider.notifier).state = s.first,
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: Icon(Icons.filter_list_rounded, color: AppColors.textSecondary),
            tooltip: t.filters,
            onPressed: () {
              if (isMobile) {
                showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => DraggableScrollableSheet(initialChildSize: 0.7, maxChildSize: 0.9, minChildSize: 0.4, builder: (_, c) => Container(decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(12))), child: FilterSidebarContent(showClose: true))));
              } else {
                // desktop: toggle collapsible sidebar
                ref.read(isFilterSidebarCollapsedProvider.notifier).state = !ref.read(isFilterSidebarCollapsedProvider);
              }
            },
          ),
          const ViewSettingsButton(),
          if (!isMobile) ...[
            IconButton(icon: Icon(Icons.view_column, color: AppColors.textSecondary), tooltip: t.manageColumns, onPressed: _openColumnManager),
            const SuggestionButton(),
          ] else ...[
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz, color: AppColors.textSecondary),
              tooltip: t.more,
              onSelected: (v) async {
                if (v == 'columns') _openColumnManager();
                if (v == 'analytics') ref.read(viewModeProvider.notifier).state = ViewMode.analytics;
                if (v == 'suggest') {
                  if (context.mounted) showDialog(context: context, builder: (_) => const SuggestionDialog());
                  return;
                }
                if (v == 'reload') {
                  await svc.reloadFromCloud();
                  return;
                }
                if (v == 'change') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border)),
                      title: Text(t.changeNameTitle, style: TextStyle(color: AppColors.textPrimary)),
                      content: Text(t.changeNameBody, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)), FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t.continueBtn))],
                    ),
                  );
                  if (ok == true) await svc.signOut();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'columns', child: Text(t.manageColumns)),
                PopupMenuItem(value: 'analytics', child: Text(t.analytics)),
                PopupMenuItem(value: 'suggest', child: Text(t.suggestIdea)),
                PopupMenuItem(value: 'reload', child: Text(t.reloadCloud)),
                PopupMenuItem(value: 'change', child: Text(t.signedInAs(identity.name ?? ''))),
                PopupMenuItem(value: 'change', child: Text(t.signOutChange)),
              ],
            ),
          ],
          if (!isMobile)
            PopupMenuButton<String>(
              icon: Icon(Icons.person_rounded, color: AppColors.textSecondary),
              tooltip: identity.name ?? t.account,
              onSelected: (v) async {
                if (v == 'reload') {
                  await svc.reloadFromCloud();
                  return;
                }
                if (v == 'change') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border)),
                      title: Text(t.changeNameTitle, style: TextStyle(color: AppColors.textPrimary)),
                      content: Text(t.changeNameBody, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)), FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t.continueBtn))],
                    ),
                  );
                  if (ok == true) await svc.signOut();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'change', child: Text(t.signedInAsChange(identity.name ?? ''))),
                PopupMenuItem(value: 'reload', child: Text(t.reloadCloud)),
                PopupMenuItem(value: 'change', child: Text(t.signOutChange)),
              ],
            ),
          const SizedBox(width: 4),
        ],
      ),
      endDrawer: ref.watch(noteEditorRequestProvider) != null ? const NoteEditorPanel() : const ColumnSettingsPanel(),
      onEndDrawerChanged: (opened) {
        // Tidy up when the drawer is dismissed (save already flushed).
        if (!opened) ref.read(noteEditorRequestProvider.notifier).state = null;
      },
      drawer: isMobile
          ? Drawer(
              backgroundColor: AppColors.surface,
              child: ListView(children: [
                DrawerHeader(
                  decoration: BoxDecoration(color: AppColors.header),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('4cus', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (identity.name != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.person_rounded, size: 12, color: AppColors.accent),
                          const SizedBox(width: 4),
                          Text(identity.name!, style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                  ]),
                ),
                ListTile(title: Text(t.weekly, style: TextStyle(color: AppColors.textPrimary)), selected: view == ViewMode.weekly, selectedTileColor: AppColors.inputFill, onTap: () { ref.read(viewModeProvider.notifier).state = ViewMode.weekly; Navigator.pop(context); }),
                ListTile(title: Text(t.daily, style: TextStyle(color: AppColors.textPrimary)), selected: view == ViewMode.daily, selectedTileColor: AppColors.inputFill, onTap: () { ref.read(viewModeProvider.notifier).state = ViewMode.daily; Navigator.pop(context); }),
                ListTile(title: Text(t.monthly, style: TextStyle(color: AppColors.textPrimary)), selected: view == ViewMode.monthly, selectedTileColor: AppColors.inputFill, onTap: () { ref.read(viewModeProvider.notifier).state = ViewMode.monthly; Navigator.pop(context); }),
                ListTile(title: Text(t.analytics, style: TextStyle(color: AppColors.textPrimary)), selected: view == ViewMode.analytics, selectedTileColor: AppColors.inputFill, onTap: () { ref.read(viewModeProvider.notifier).state = ViewMode.analytics; Navigator.pop(context); }),
                Divider(color: AppColors.border),
                ListTile(title: Text(t.todayChecklist, style: TextStyle(color: AppColors.textSecondary)), onTap: () { ref.read(viewModeProvider.notifier).state = ViewMode.daily; Navigator.pop(context); }),
                Divider(color: AppColors.border),
                ListTile(
                  leading: Icon(Icons.person_rounded, size: 16, color: AppColors.textSecondary),
                  title: Text(t.signedInAs(identity.name ?? ''), style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  subtitle: Text(t.tapToChangeName, style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                  onTap: () async {
                    Navigator.pop(context);
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border)),
                        title: Text(t.changeNameQ, style: TextStyle(color: AppColors.textPrimary)),
                        content: Text(t.changeNameQBody, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)), FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t.continueBtn))],
                      ),
                    );
                    if (ok == true) await svc.signOut();
                  },
                ),
              ]),
            )
          : null,
      body: Column(children: [
        _SyncBanner(svc: svc),
        Expanded(
          // iOS-smooth crossfade/scale whenever the view changes.
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: UiStyle.iosSwitchTransition,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, if (current != null) current],
            ),
            child: KeyedSubtree(
              key: ValueKey('${isMobile ? 'm' : 'd'}-$view'),
              child: isMobile
                  ? _mobileBody(view)
                  : Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: ref.watch(isFilterSidebarCollapsedProvider) ? 0 : 280,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(border: Border(right: BorderSide(color: AppColors.border))),
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
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: isMobile && view != ViewMode.analytics
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
              selectedIndex: [ViewMode.weekly, ViewMode.daily, ViewMode.monthly, ViewMode.analytics].indexOf(view),
              onDestinationSelected: (i) => ref.read(viewModeProvider.notifier).state = [ViewMode.weekly, ViewMode.daily, ViewMode.monthly, ViewMode.analytics][i],
              destinations: [
                NavigationDestination(icon: Icon(Icons.view_week, color: AppColors.textSecondary), selectedIcon: Icon(Icons.view_week, color: Colors.white), label: t.weekly),
                NavigationDestination(icon: Icon(Icons.view_day, color: AppColors.textSecondary), selectedIcon: Icon(Icons.view_day, color: Colors.white), label: t.daily),
                NavigationDestination(icon: Icon(Icons.calendar_month, color: AppColors.textSecondary), selectedIcon: Icon(Icons.calendar_month, color: Colors.white), label: t.monthly),
                NavigationDestination(icon: Icon(Icons.analytics_outlined, color: AppColors.textSecondary), selectedIcon: Icon(Icons.analytics_outlined, color: Colors.white), label: t.analytics),
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
      case ViewMode.analytics:
        return const AnalyticsPage();
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
    final t = AppLocalizations.of(context)!;
    if (view == ViewMode.monthly) {
      // Monthly has its own Add task dialog with date+params, trigger it via MonthlyView's method
      // For mobile, just show a simple add task dialog that will be scheduled for today
      final c = TextEditingController();
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.border)),
          title: Text(t.addTask, style: TextStyle(color: AppColors.textPrimary)),
          content: TextField(controller: c, autofocus: true, style: TextStyle(color: AppColors.textPrimary), decoration: InputDecoration(labelText: t.taskNameLbl, hintText: 'e.g. Gym')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
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
              child: Text(t.add),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border)),
          title: Text(t.addTask, style: TextStyle(color: AppColors.textPrimary)),
          content: TextField(controller: c, autofocus: true, style: TextStyle(color: AppColors.textPrimary), decoration: InputDecoration(labelText: t.taskNameLbl)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
            FilledButton(onPressed: () { if (c.text.trim().isNotEmpty) svc.addTask(c.text.trim()); Navigator.pop(context); }, child: Text(t.add)),
          ],
      ),
    );
  }
}

/// AppBar cloud-sync indicator. Green = live cloud data, amber = offline
/// cache, red = failed, grey = demo/loading. Tap to reload from cloud.
class _SyncStatusButton extends StatelessWidget {
  final SupabaseService svc;
  final String? email;
  const _SyncStatusButton({required this.svc, required this.email});
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: svc.syncStatus,
      builder: (_, status, _) {
        IconData icon;
        Color color;
        String label;
        switch (status) {
          case SyncStatus.cloud:
            icon = Icons.cloud_done_outlined;
            color = const Color(0xFF22C55E);
            label = loc.cloudOkTip;
            break;
          case SyncStatus.offlineCache:
            icon = Icons.cloud_off_outlined;
            color = const Color(0xFFF59E0B);
            label = loc.cloudOfflineTip;
            break;
          case SyncStatus.demo:
            icon = Icons.cloud_off_outlined;
            color = AppColors.textSecondary;
            label = loc.demoTip;
            break;
          case SyncStatus.error:
            icon = Icons.error_outline;
            color = const Color(0xFFF43F5E);
            label = loc.syncErrorTip;
            break;
          case SyncStatus.loading:
            icon = Icons.cloud_sync_outlined;
            color = AppColors.textSecondary;
            label = loc.connectingTip;
            break;
        }
        final detail = svc.syncError;
        return IconButton(
          icon: Icon(icon, color: color, size: 20),
          tooltip: '$label\n${loc.signedInWord(email ?? '?')}${detail != null ? '\n$detail' : ''}\n${loc.reloadTapHint}',
          onPressed: () => svc.reloadFromCloud(),
        );
      },
    );
  }
}

/// Full-width banner shown only when NOT on live cloud data, so a wrong
/// state (demo build, offline, failed fetch) is impossible to miss.
class _SyncBanner extends StatelessWidget {
  final SupabaseService svc;
  const _SyncBanner({required this.svc});
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: svc.syncStatus,
      builder: (_, status, _) {
        if (status == SyncStatus.cloud || status == SyncStatus.loading) {
          return const SizedBox.shrink();
        }
        final isDemo = status == SyncStatus.demo;
        final bg = isDemo ? AppColors.inputFill : const Color(0xFFF43F5E).withValues(alpha: 0.12);
        final border = isDemo ? AppColors.border : const Color(0xFFF43F5E).withValues(alpha: 0.5);
        final text = isDemo ? loc.demoBanner : (svc.syncError ?? 'Could not reach the cloud.');
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: bg, border: Border(bottom: BorderSide(color: border))),
          child: Row(children: [
            Icon(isDemo ? Icons.cloud_off_outlined : Icons.error_outline, size: 16, color: isDemo ? AppColors.textSecondary : const Color(0xFFF43F5E)),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(fontSize: 11, color: AppColors.textPrimary))),
            TextButton(
              onPressed: () => svc.reloadFromCloud(),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text(loc.retry, style: const TextStyle(fontSize: 11)),
            ),
          ]),
        );
      },
    );
  }
}
