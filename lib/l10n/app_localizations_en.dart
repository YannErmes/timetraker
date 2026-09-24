// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get weekly => 'Weekly';

  @override
  String get daily => 'Daily';

  @override
  String get monthly => 'Monthly';

  @override
  String get today => 'Today';

  @override
  String get filters => 'Filters';

  @override
  String get viewDensity => 'View density';

  @override
  String get manageColumns => 'Manage Columns';

  @override
  String get analytics => 'Analytics';

  @override
  String get more => 'More';

  @override
  String get account => 'Account';

  @override
  String get changeNameTitle => 'Change name?';

  @override
  String get changeNameBody => 'You will be signed out locally. Your data stays on the server under your current name and can be reclaimed by entering the exact same name again.';

  @override
  String get continueBtn => 'Continue';

  @override
  String get signOutChange => 'Sign out / change name';

  @override
  String signedInAs(String email) {
    return 'Signed in as \"$email\"';
  }

  @override
  String signedInAsChange(String email) {
    return 'Signed in as \"$email\" — change name';
  }

  @override
  String get tapToChangeName => 'Tap to change name';

  @override
  String get reloadCloud => 'Reload from cloud';

  @override
  String get suggestIdea => 'Suggest an idea';

  @override
  String get add => 'Add';

  @override
  String get cancel => 'Cancel';

  @override
  String get addTask => 'Add task';

  @override
  String get close => 'Close';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get rename => 'Rename';

  @override
  String get retry => 'Retry';

  @override
  String get create => 'Create';

  @override
  String get showAll => 'Show all';

  @override
  String get hideAll => 'Hide all';

  @override
  String get untitledLower => 'untitled';

  @override
  String get untitledCap => 'Untitled';

  @override
  String get taskFallback => 'Task';

  @override
  String get rowsLbl => 'Rows';

  @override
  String get daysLbl => 'Days';

  @override
  String get typeLbl => 'Type';

  @override
  String get prevBtn => 'Prev';

  @override
  String get nextBtn => 'Next';

  @override
  String get upNext => 'Up next';

  @override
  String get editTip => 'Edit';

  @override
  String get deleteTip => 'Delete';

  @override
  String get clearTip => 'Clear';

  @override
  String get searchLbl => 'Search';

  @override
  String get tasksHeader => 'Tasks';

  @override
  String get prevDaysTip => 'Prev days';

  @override
  String get nextDaysTip => 'Next days';

  @override
  String rowsRange(String from, String to, String total) {
    return 'Rows $from–$to of $total';
  }

  @override
  String showingTip(String shown, String all, String daysPart) {
    return 'Showing $shown of $all tasks$daysPart — adjust in view settings (tune icon). The Tasks column stays fixed while you scroll horizontally.';
  }

  @override
  String daysVisiblePart(String shown, String total) {
    return ' · $shown of $total days visible';
  }

  @override
  String openDaily(String date) {
    return 'Open $date in Daily view';
  }

  @override
  String get addTaskTitle => 'Add task';

  @override
  String get taskNameLbl => 'Task name';

  @override
  String get syncMonthlyTip => 'Sync monthly to Google';

  @override
  String syncedMsg(String count) {
    return 'Synced $count events to Google Calendar';
  }

  @override
  String syncFailedMsg(String error) {
    return 'Sync failed: $error. Connect Google first in View Settings (tune icon).';
  }

  @override
  String scheduledOf(String done, String total) {
    return '$done/$total scheduled';
  }

  @override
  String get todayChecklist => 'Today (Android checklist)';

  @override
  String get taskNameReq => 'Task name *';

  @override
  String get taskNameHint => 'e.g. Typing';

  @override
  String get scheduledDay => 'Scheduled day:';

  @override
  String get scheduleLbl => 'Schedule';

  @override
  String get setTimeBtn => 'Set time';

  @override
  String get timeDurationLbl => 'Time (duration)';

  @override
  String get timeHint => 'e.g. 3h5min, 4h, 30min';

  @override
  String get statusLbl => 'Status';

  @override
  String get noteLbl => 'Note';

  @override
  String get noteHint => 'Add a note for this task…';

  @override
  String get createsHint => 'Creates task and schedules it for the chosen day (checkbox = scheduled).';

  @override
  String statsFor(String day) {
    return 'Stats for $day';
  }

  @override
  String get totalChip => 'Total';

  @override
  String tasksCount(String n) {
    return '$n tasks';
  }

  @override
  String get doneChip => 'Done';

  @override
  String get progChip => 'In progress';

  @override
  String get totalTimeChip => 'Total time';

  @override
  String get doneTimeChip => 'Done time';

  @override
  String get leftChip => 'Left';

  @override
  String get elapsedChip => 'Elapsed';

  @override
  String pctDone(String pct) {
    return '$pct% done';
  }

  @override
  String get doneSection => 'Done';

  @override
  String moreSuffix(String n) {
    return '+$n more';
  }

  @override
  String get leftToDo => 'Left to do';

  @override
  String get noScheduled => 'No tasks scheduled for this day.';

  @override
  String get goWeeklyHint => 'Go to Weekly view and check the box for tasks you want on this date.';

  @override
  String scheduledLine(String a, String b, String day) {
    return '$a of $b tasks scheduled for $day';
  }

  @override
  String rowsScheduled(String from, String to, String total) {
    return 'Rows $from–$to of $total scheduled';
  }

  @override
  String get manageColsTitle => 'Manage Columns';

  @override
  String get introText => 'Add, rename, delete, reorder, and change type. Changing type keeps the column but clears or converts existing values (best-effort).';

  @override
  String get hiddenBadge => 'hidden';

  @override
  String get showCol => 'Show column';

  @override
  String get hideCol => 'Hide column';

  @override
  String get editTypeItem => 'Edit / Change type';

  @override
  String typeChangedWarn(String from, String to) {
    return 'Type will change from $from to $to. Existing values will be cleared or best-effort converted.';
  }

  @override
  String get insertPosition => 'Insert position';

  @override
  String get insertHelp => 'Choose where the new column appears. Works for any column type.';

  @override
  String get anchorLbl => 'Anchor column';

  @override
  String get atBeginning => 'At beginning (before all)';

  @override
  String get atEnd => 'At end (after all)';

  @override
  String get beforeBtn => 'Before';

  @override
  String get afterBtn => 'After';

  @override
  String willInsert(String pos, String total) {
    return 'Will be inserted at position $pos of $total';
  }

  @override
  String get unitLbl => 'Unit (h, min, etc)';

  @override
  String get unitHint => 'h';

  @override
  String get timerHelp => 'Time Length: cells store a duration (e.g. 4h) and a live countdown. Tap cell to set duration, then use timer controls.';

  @override
  String get statusOptsLbl => 'Status options (label + color):';

  @override
  String get addOptionLbl => 'Add option';

  @override
  String get labelFieldLbl => 'label';

  @override
  String get pickColorTitle => 'Pick color';

  @override
  String get deleteColTitle => 'Delete column?';

  @override
  String deleteColBody(String name) {
    return 'Delete \"$name\"? All values in this column will be removed.';
  }

  @override
  String get footerDragHelp => 'Drag handle to reorder. Columns appear as sub-columns per day in Weekly view. Type changes preserve the column ID.';

  @override
  String get addColTitle => 'Add column';

  @override
  String get editColTitle => 'Edit column';

  @override
  String get changeTypeTitle => 'Change column type?';

  @override
  String changeTypeBody(String name, String from, String to) {
    return 'Change \"$name\" from $from to $to? Existing cell values will be cleared or converted.';
  }

  @override
  String get changeBtn => 'Change';

  @override
  String get colNameLbl => 'Column name';

  @override
  String get visibleCols => 'Visible columns';

  @override
  String get visibleColsShort => 'Visible columns:';

  @override
  String get showShort => 'Show:';

  @override
  String get visibilityHelp => 'Tap to collapse/expand each per-day field. Hidden columns stay in your data but are not shown in Weekly/Daily.';

  @override
  String get ctCheckbox => 'Checkbox';

  @override
  String get ctCheckboxDesc => 'Single tickbox — done / not done';

  @override
  String get ctStatus => 'Status';

  @override
  String get ctStatusDesc => 'Colored dropdown (e.g. none / done / cancel)';

  @override
  String get ctNumber => 'Number / Duration';

  @override
  String get ctNumberDesc => 'Number with optional unit (h, min)';

  @override
  String get ctDate => 'Date';

  @override
  String get ctDateDesc => 'Calendar date picker';

  @override
  String get ctDatetime => 'DateTime';

  @override
  String get ctDatetimeDesc => 'Date + time picker';

  @override
  String get ctTags => 'Tags';

  @override
  String get ctTagsDesc => 'Multiple colored tags per cell';

  @override
  String get ctText => 'Text';

  @override
  String get ctTextDesc => 'Free-form notes';

  @override
  String get ctTimer => 'Time Length Selector';

  @override
  String get ctTimerDesc => 'Estimated duration + live countdown timer';

  @override
  String get ctSchedule => 'Schedule';

  @override
  String get ctScheduleDesc => 'Time-of-day for that day (e.g. 9:00 AM)';

  @override
  String get welcome => 'Welcome to 4cus';

  @override
  String get emailContinue => 'Enter your email to continue. We’ll create your workspace instantly — no password needed.';

  @override
  String get whyWorks => 'Why 4cus works';

  @override
  String get whyText => 'Motivation fades. Written plans don\'t.';

  @override
  String get studyQuote => '“A goal-setting study (Dominican University, 2015) shows people who wrote down a specific plan succeeded 70% of the time, versus 35% — literally double.”';

  @override
  String get studyRef => '— Gail Matthews, 2015';

  @override
  String get emailLbl => 'Email address *';

  @override
  String get emailHint => 'e.g. alex@example.com';

  @override
  String get vipLbl => 'VIP key (optional)';

  @override
  String get emailKeyNote => 'your email is your only key to your data — remember exactly how you typed it';

  @override
  String get cloudNotConfigured => 'Cloud is NOT configured in this build — data will stay on THIS device only and will not appear on your other devices.';

  @override
  String get worksLine => 'Works on web and Android. Your data syncs instantly via Supabase — if you’re offline, edits queue and retry.';

  @override
  String get suggestLink => 'Have an idea to improve 4cus? Tell us';

  @override
  String get errEmail => 'Please enter a valid email address.';

  @override
  String get errVip => 'Invalid VIP key';

  @override
  String get vipRequired => 'VIP required';

  @override
  String get vipRequiredText => 'Enter your VIP key to unlock Google Calendar sync.';

  @override
  String get vipKeyLbl => 'VIP key';

  @override
  String get vipKeyHint => 'paste your key';

  @override
  String get unlockBtn => 'Unlock';

  @override
  String get enterVipKey => 'Enter a VIP key';

  @override
  String get vipSaved => 'VIP key saved — Google sync unlocked!';

  @override
  String invalidVipKey(String error) {
    return 'Invalid VIP key: $error';
  }

  @override
  String get addLaterNote => 'You can add the VIP key later in Settings. Without it, the sync options stay grayed out.';

  @override
  String get cloudOkTip => 'Cloud sync: connected';

  @override
  String get cloudOfflineTip => 'Cloud sync: offline — showing saved data';

  @override
  String get demoTip => 'Demo mode: cloud not configured — data stays on this device';

  @override
  String get syncErrorTip => 'Cloud sync failed';

  @override
  String get connectingTip => 'Connecting to cloud…';

  @override
  String get reloadTapHint => 'Tap to reload from cloud.';

  @override
  String signedInWord(String email) {
    return 'Signed in as $email.';
  }

  @override
  String get demoBanner => 'Demo mode — cloud is not configured in this build, so data stays on THIS device only.';

  @override
  String recapTitle(String name) {
    return '$name — notes recap';
  }

  @override
  String get notesRecap => 'Notes recap';

  @override
  String notesRecapCount(String n) {
    return 'Notes recap ($n)';
  }

  @override
  String get noNoteCol => 'No note column yet — add one in Manage Columns to start collecting notes.';

  @override
  String noNotesYet(String name, String col) {
    return 'No notes for \"$name\" yet. Add one from any day cell under \"$col\".';
  }

  @override
  String get tapOpenStudio => 'Tap to open in sidebar studio';

  @override
  String get openTooltip => 'Open';

  @override
  String get tabEdit => 'Edit';

  @override
  String get tabPreview => 'Preview';

  @override
  String get writeHint => 'Write your note…';

  @override
  String get previewEmpty => 'Nothing to preview yet.';

  @override
  String autosavedAt(String time) {
    return 'Autosaved $time';
  }

  @override
  String get savingNow => 'Saving…';

  @override
  String get autosavesHint => 'Autosaves as you type';

  @override
  String get writeNoteEmpty => 'Tap to write note…';

  @override
  String editColLabel(String label) {
    return 'Edit $label';
  }

  @override
  String get shapeTitle => 'Shape 4cus with us';

  @override
  String get shapeMsg => 'The average person doesn’t fail for lack of ambition — they fail for lack of planning and structure. That’s why most goals quietly fade and plans get forgotten.\n\n4cus exists to fix that, and we’re building it in the open. Your suggestion directly shapes what we build next — thank you for helping us build it with you.';

  @override
  String get nameEmailLbl => 'Your name or email';

  @override
  String get suggLbl => 'Your suggestion…';

  @override
  String get suggHint => 'What would make 4cus better for you?';

  @override
  String get sendBtn => 'Send';

  @override
  String get thankTitle => 'Thank you!';

  @override
  String get thanksText => 'Your suggestion was received. We read every single one, and the best ideas go straight onto the roadmap.';

  @override
  String get errWriteFirst => 'Please write your suggestion first.';

  @override
  String get errNoCloud => 'Cloud is not configured in this build.';

  @override
  String get analyticsTitle => 'Analytics';

  @override
  String get scheduledChip => 'Scheduled';

  @override
  String get doneChipA => 'Done';

  @override
  String get timePlanned => 'Time planned';

  @override
  String get timeDone => 'Time done';

  @override
  String get weeklyProgress => 'Weekly progress (last 8 weeks)';

  @override
  String get statusBreakdown => 'Status breakdown';

  @override
  String get timePerTask => 'Time per task';

  @override
  String get completionPerTask => 'Completion per task';

  @override
  String get noTasksYet => 'No tasks yet';

  @override
  String get plannedLeg => 'planned';

  @override
  String get progLeg => 'in progress';

  @override
  String get cancelLeg => 'cancelled';

  @override
  String get doneLeg => 'done';

  @override
  String slotsDays(String slots, String days) {
    return '$slots slots · $days days';
  }

  @override
  String get searchTasks => 'Search tasks';

  @override
  String get searchHint => 'Search tasks…';

  @override
  String get statusFilterLbl => 'Status';

  @override
  String get allStatuses => 'All statuses';

  @override
  String get tagFilterLbl => 'Tag';

  @override
  String get allTags => 'All tags';

  @override
  String get hasNoteChip => 'Has note';

  @override
  String get hasNoteOnlyChip => 'Has note only';

  @override
  String get clearFiltersBtn => 'Clear';

  @override
  String get clearAllFilters => 'Clear all filters';

  @override
  String filtersActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filters active',
      one: '$count filter active',
    );
    return '$_temp0';
  }

  @override
  String activeShort(String count) {
    return '$count active';
  }

  @override
  String filtersFooter(String count) {
    return '$count active • Filters apply to Weekly, Daily and Monthly';
  }

  @override
  String tapFilterHint(String a, String b) {
    return '$a of $b tasks • tap filter icon for more';
  }

  @override
  String get todayTitle => 'Today';

  @override
  String ofTasksHint(String a, String b) {
    return '$a of $b tasks';
  }

  @override
  String get androidNote => 'Android simplified view — checkbox + status editing only. Structural edits (add/reorder columns) on Web. Synced via Supabase realtime. Offline queue enabled.';

  @override
  String get editsHint => 'Edits save immediately and update the Monthly heatmap.';

  @override
  String get noScheduledTitle => 'No tasks scheduled for this day.';

  @override
  String get checkHint => 'Check the box for a task in Weekly or Daily view to schedule it for this date.';

  @override
  String noneScheduledLine(String day, String total) {
    return '$day — $total total tasks, none scheduled.';
  }

  @override
  String get checkScheduledHint => 'Check the box for a task in Weekly or Daily view to schedule it for this date.';

  @override
  String get timerTitle => 'Timer';

  @override
  String get editDurationTip => 'Edit duration';

  @override
  String get editDurationTitle => 'Edit duration';

  @override
  String get durationLbl => 'Duration';

  @override
  String get setDurationBtn => 'Set duration';

  @override
  String get durationExample => 'e.g. 4h, 30min, 1h 20m';

  @override
  String get remainingLbl => 'remaining';

  @override
  String get completedLbl => 'completed';

  @override
  String get pausedLbl => 'paused';

  @override
  String elapsedOf(String eff, String total) {
    return '$eff elapsed / $total total';
  }

  @override
  String get startBtn => 'Start';

  @override
  String get resumeBtn => 'Resume';

  @override
  String get pauseBtn => 'Pause';

  @override
  String get stopBtn => 'Stop';

  @override
  String get restartBtn => 'Restart';

  @override
  String get completedBadge => 'Completed';

  @override
  String get tagsTitle => 'Tags';

  @override
  String get okBtn => 'OK';

  @override
  String get notifTitle => 'Notifications';

  @override
  String get notifHelp => 'Alerts for timer done, daily tasks, and timer reminders — works on Android and web (when tab is open).';

  @override
  String get timerDoneTitle => 'Timer done';

  @override
  String get timerDoneSub => 'When a time countdown finishes';

  @override
  String get dailyBriefTitle => 'Daily briefing';

  @override
  String get dailyBriefSub => 'Send next tasks for today';

  @override
  String get sendTestNow => 'Send test now';

  @override
  String atDaily(String time) {
    return 'at $time daily';
  }

  @override
  String get timerRemTitle => 'Timer reminders';

  @override
  String get timerRemSub => 'Before a timer ends';

  @override
  String minSuffix(String m) {
    return '$m min';
  }

  @override
  String get noTasksToday => 'No tasks scheduled for today — tap to open 4cus.';

  @override
  String get tapToSee => 'Tap to see what’s scheduled for today';

  @override
  String get gcalTitle => 'Google Calendar sync';

  @override
  String get gcalHelp => 'Sync monthly view (scheduled tasks) to your Google Calendar automatically. Put your Google email, accept the consent screen, and you’re done.';

  @override
  String get connectBtn => 'Connect Google Calendar';

  @override
  String get connectHelp => 'You’ll be asked to pick your Google account and Accept calendar access.';

  @override
  String get disconnectBtn => 'Disconnect';

  @override
  String get autoSyncLbl => 'Auto-sync monthly';

  @override
  String get autoSyncHelp => 'When on, every checkbox / schedule / time change for a scheduled day creates/updates a Google event within seconds.';

  @override
  String connectFailed(String error) {
    return 'Connect failed: $error';
  }

  @override
  String connectedAs(String email) {
    return 'Connected as $email';
  }

  @override
  String get rowsVisibleLbl => 'Rows visible at once';

  @override
  String get allRowsItem => 'All rows';

  @override
  String rowsCountItem(String n) {
    return '$n rows';
  }

  @override
  String get daysVisibleLbl => 'Day-columns visible at once (Weekly)';

  @override
  String get allDaysItem => 'All (7 days)';

  @override
  String daysCountItem(String n) {
    return '$n days';
  }

  @override
  String get cellStyleLbl => 'Cell style (timer & status)';

  @override
  String get fullBtn => 'Full';

  @override
  String get basicBtn => 'Basic';

  @override
  String get basicHelp => 'Basic shows icon-only timer/status cells — tap one to open the full editor.';

  @override
  String get appearanceLbl => 'Appearance';

  @override
  String get darkBtn => 'Dark';

  @override
  String get lightBtn => 'Light';

  @override
  String get columnVisibilityHelp => 'Column visibility is saved per user. Hide schedule/time/status/note to focus the table — e.g., show only status or only time.';

  @override
  String get switchDark => 'Switch to dark mode';

  @override
  String get switchLight => 'Switch to light mode';

  @override
  String get changeNameQ => 'Change name?';

  @override
  String get changeNameQBody => 'Your data stays under the current name. You can reclaim it later by entering the exact same name again.';
}
