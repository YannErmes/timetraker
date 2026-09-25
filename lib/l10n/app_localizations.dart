import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @viewDensity.
  ///
  /// In en, this message translates to:
  /// **'View density'**
  String get viewDensity;

  /// No description provided for @manageColumns.
  ///
  /// In en, this message translates to:
  /// **'Manage Columns'**
  String get manageColumns;

  /// No description provided for @analytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analytics;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @changeNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Change name?'**
  String get changeNameTitle;

  /// No description provided for @changeNameBody.
  ///
  /// In en, this message translates to:
  /// **'You will be signed out locally. Your data stays on the server under your current name and can be reclaimed by entering the exact same name again.'**
  String get changeNameBody;

  /// No description provided for @continueBtn.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueBtn;

  /// No description provided for @signOutChange.
  ///
  /// In en, this message translates to:
  /// **'Sign out / change name'**
  String get signOutChange;

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as \"{email}\"'**
  String signedInAs(String email);

  /// No description provided for @signedInAsChange.
  ///
  /// In en, this message translates to:
  /// **'Signed in as \"{email}\" — change name'**
  String signedInAsChange(String email);

  /// No description provided for @tapToChangeName.
  ///
  /// In en, this message translates to:
  /// **'Tap to change name'**
  String get tapToChangeName;

  /// No description provided for @reloadCloud.
  ///
  /// In en, this message translates to:
  /// **'Reload from cloud'**
  String get reloadCloud;

  /// No description provided for @suggestIdea.
  ///
  /// In en, this message translates to:
  /// **'Suggest an idea'**
  String get suggestIdea;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @addTask.
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get addTask;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @showAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get showAll;

  /// No description provided for @hideAll.
  ///
  /// In en, this message translates to:
  /// **'Hide all'**
  String get hideAll;

  /// No description provided for @untitledLower.
  ///
  /// In en, this message translates to:
  /// **'untitled'**
  String get untitledLower;

  /// No description provided for @untitledCap.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitledCap;

  /// No description provided for @taskFallback.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get taskFallback;

  /// No description provided for @rowsLbl.
  ///
  /// In en, this message translates to:
  /// **'Rows'**
  String get rowsLbl;

  /// No description provided for @daysLbl.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get daysLbl;

  /// No description provided for @typeLbl.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get typeLbl;

  /// No description provided for @prevBtn.
  ///
  /// In en, this message translates to:
  /// **'Prev'**
  String get prevBtn;

  /// No description provided for @nextBtn.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextBtn;

  /// No description provided for @upNext.
  ///
  /// In en, this message translates to:
  /// **'Up next'**
  String get upNext;

  /// No description provided for @editTip.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editTip;

  /// No description provided for @deleteTip.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteTip;

  /// No description provided for @clearTip.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearTip;

  /// No description provided for @searchLbl.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchLbl;

  /// No description provided for @tasksHeader.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasksHeader;

  /// No description provided for @prevDaysTip.
  ///
  /// In en, this message translates to:
  /// **'Prev days'**
  String get prevDaysTip;

  /// No description provided for @nextDaysTip.
  ///
  /// In en, this message translates to:
  /// **'Next days'**
  String get nextDaysTip;

  /// No description provided for @rowsRange.
  ///
  /// In en, this message translates to:
  /// **'Rows {from}–{to} of {total}'**
  String rowsRange(String from, String to, String total);

  /// No description provided for @showingTip.
  ///
  /// In en, this message translates to:
  /// **'Showing {shown} of {all} tasks{daysPart} — adjust in view settings (tune icon). The Tasks column stays fixed while you scroll horizontally.'**
  String showingTip(String shown, String all, String daysPart);

  /// No description provided for @daysVisiblePart.
  ///
  /// In en, this message translates to:
  /// **' · {shown} of {total} days visible'**
  String daysVisiblePart(String shown, String total);

  /// No description provided for @openDaily.
  ///
  /// In en, this message translates to:
  /// **'Open {date} in Daily view'**
  String openDaily(String date);

  /// No description provided for @addTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get addTaskTitle;

  /// No description provided for @taskNameLbl.
  ///
  /// In en, this message translates to:
  /// **'Task name'**
  String get taskNameLbl;

  /// No description provided for @syncMonthlyTip.
  ///
  /// In en, this message translates to:
  /// **'Sync monthly to Google'**
  String get syncMonthlyTip;

  /// No description provided for @syncedMsg.
  ///
  /// In en, this message translates to:
  /// **'Synced {count} events to Google Calendar'**
  String syncedMsg(String count);

  /// No description provided for @syncFailedMsg.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {error}. Connect Google first in View Settings (tune icon).'**
  String syncFailedMsg(String error);

  /// No description provided for @scheduledOf.
  ///
  /// In en, this message translates to:
  /// **'{done}/{total} scheduled'**
  String scheduledOf(String done, String total);

  /// No description provided for @todayChecklist.
  ///
  /// In en, this message translates to:
  /// **'Today (Android checklist)'**
  String get todayChecklist;

  /// No description provided for @taskNameReq.
  ///
  /// In en, this message translates to:
  /// **'Task name *'**
  String get taskNameReq;

  /// No description provided for @taskNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Typing'**
  String get taskNameHint;

  /// No description provided for @scheduledDay.
  ///
  /// In en, this message translates to:
  /// **'Scheduled day:'**
  String get scheduledDay;

  /// No description provided for @addDaysLbl.
  ///
  /// In en, this message translates to:
  /// **'Days (optional)'**
  String get addDaysLbl;

  /// No description provided for @addDaysHint.
  ///
  /// In en, this message translates to:
  /// **'Name is the only required field — leave days empty to create an unscheduled task.'**
  String get addDaysHint;

  /// No description provided for @scheduleLbl.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get scheduleLbl;

  /// No description provided for @setTimeBtn.
  ///
  /// In en, this message translates to:
  /// **'Set time'**
  String get setTimeBtn;

  /// No description provided for @timeDurationLbl.
  ///
  /// In en, this message translates to:
  /// **'Time (duration)'**
  String get timeDurationLbl;

  /// No description provided for @timeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 3h5min, 4h, 30min'**
  String get timeHint;

  /// No description provided for @statusLbl.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLbl;

  /// No description provided for @noteLbl.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get noteLbl;

  /// No description provided for @noteHint.
  ///
  /// In en, this message translates to:
  /// **'Add a note for this task…'**
  String get noteHint;

  /// No description provided for @createsHint.
  ///
  /// In en, this message translates to:
  /// **'Creates task and schedules it for the chosen day (checkbox = scheduled).'**
  String get createsHint;

  /// No description provided for @statsFor.
  ///
  /// In en, this message translates to:
  /// **'Stats for {day}'**
  String statsFor(String day);

  /// No description provided for @totalChip.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalChip;

  /// No description provided for @tasksCount.
  ///
  /// In en, this message translates to:
  /// **'{n} tasks'**
  String tasksCount(String n);

  /// No description provided for @doneChip.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneChip;

  /// No description provided for @progChip.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get progChip;

  /// No description provided for @totalTimeChip.
  ///
  /// In en, this message translates to:
  /// **'Total time'**
  String get totalTimeChip;

  /// No description provided for @doneTimeChip.
  ///
  /// In en, this message translates to:
  /// **'Done time'**
  String get doneTimeChip;

  /// No description provided for @leftChip.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get leftChip;

  /// No description provided for @elapsedChip.
  ///
  /// In en, this message translates to:
  /// **'Elapsed'**
  String get elapsedChip;

  /// No description provided for @pctDone.
  ///
  /// In en, this message translates to:
  /// **'{pct}% done'**
  String pctDone(String pct);

  /// No description provided for @doneSection.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneSection;

  /// No description provided for @moreSuffix.
  ///
  /// In en, this message translates to:
  /// **'+{n} more'**
  String moreSuffix(String n);

  /// No description provided for @leftToDo.
  ///
  /// In en, this message translates to:
  /// **'Left to do'**
  String get leftToDo;

  /// No description provided for @noScheduled.
  ///
  /// In en, this message translates to:
  /// **'No tasks scheduled for this day.'**
  String get noScheduled;

  /// No description provided for @goWeeklyHint.
  ///
  /// In en, this message translates to:
  /// **'Go to Weekly view and check the box for tasks you want on this date.'**
  String get goWeeklyHint;

  /// No description provided for @scheduledLine.
  ///
  /// In en, this message translates to:
  /// **'{a} of {b} tasks scheduled for {day}'**
  String scheduledLine(String a, String b, String day);

  /// No description provided for @rowsScheduled.
  ///
  /// In en, this message translates to:
  /// **'Rows {from}–{to} of {total} scheduled'**
  String rowsScheduled(String from, String to, String total);

  /// No description provided for @manageColsTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Columns'**
  String get manageColsTitle;

  /// No description provided for @introText.
  ///
  /// In en, this message translates to:
  /// **'Add, rename, delete, reorder, and change type. Changing type keeps the column but clears or converts existing values (best-effort).'**
  String get introText;

  /// No description provided for @hiddenBadge.
  ///
  /// In en, this message translates to:
  /// **'hidden'**
  String get hiddenBadge;

  /// No description provided for @showCol.
  ///
  /// In en, this message translates to:
  /// **'Show column'**
  String get showCol;

  /// No description provided for @hideCol.
  ///
  /// In en, this message translates to:
  /// **'Hide column'**
  String get hideCol;

  /// No description provided for @editTypeItem.
  ///
  /// In en, this message translates to:
  /// **'Edit / Change type'**
  String get editTypeItem;

  /// No description provided for @typeChangedWarn.
  ///
  /// In en, this message translates to:
  /// **'Type will change from {from} to {to}. Existing values will be cleared or best-effort converted.'**
  String typeChangedWarn(String from, String to);

  /// No description provided for @insertPosition.
  ///
  /// In en, this message translates to:
  /// **'Insert position'**
  String get insertPosition;

  /// No description provided for @insertHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose where the new column appears. Works for any column type.'**
  String get insertHelp;

  /// No description provided for @anchorLbl.
  ///
  /// In en, this message translates to:
  /// **'Anchor column'**
  String get anchorLbl;

  /// No description provided for @atBeginning.
  ///
  /// In en, this message translates to:
  /// **'At beginning (before all)'**
  String get atBeginning;

  /// No description provided for @atEnd.
  ///
  /// In en, this message translates to:
  /// **'At end (after all)'**
  String get atEnd;

  /// No description provided for @beforeBtn.
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get beforeBtn;

  /// No description provided for @afterBtn.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get afterBtn;

  /// No description provided for @willInsert.
  ///
  /// In en, this message translates to:
  /// **'Will be inserted at position {pos} of {total}'**
  String willInsert(String pos, String total);

  /// No description provided for @unitLbl.
  ///
  /// In en, this message translates to:
  /// **'Unit (h, min, etc)'**
  String get unitLbl;

  /// No description provided for @unitHint.
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get unitHint;

  /// No description provided for @timerHelp.
  ///
  /// In en, this message translates to:
  /// **'Time Length: cells store a duration (e.g. 4h) and a live countdown. Tap cell to set duration, then use timer controls.'**
  String get timerHelp;

  /// No description provided for @statusOptsLbl.
  ///
  /// In en, this message translates to:
  /// **'Status options (label + color):'**
  String get statusOptsLbl;

  /// No description provided for @addOptionLbl.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get addOptionLbl;

  /// No description provided for @labelFieldLbl.
  ///
  /// In en, this message translates to:
  /// **'label'**
  String get labelFieldLbl;

  /// No description provided for @pickColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick color'**
  String get pickColorTitle;

  /// No description provided for @deleteColTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete column?'**
  String get deleteColTitle;

  /// No description provided for @deleteColBody.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? All values in this column will be removed.'**
  String deleteColBody(String name);

  /// No description provided for @footerDragHelp.
  ///
  /// In en, this message translates to:
  /// **'Drag handle to reorder. Columns appear as sub-columns per day in Weekly view. Type changes preserve the column ID.'**
  String get footerDragHelp;

  /// No description provided for @addColTitle.
  ///
  /// In en, this message translates to:
  /// **'Add column'**
  String get addColTitle;

  /// No description provided for @editColTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit column'**
  String get editColTitle;

  /// No description provided for @changeTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Change column type?'**
  String get changeTypeTitle;

  /// No description provided for @changeTypeBody.
  ///
  /// In en, this message translates to:
  /// **'Change \"{name}\" from {from} to {to}? Existing cell values will be cleared or converted.'**
  String changeTypeBody(String name, String from, String to);

  /// No description provided for @changeBtn.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changeBtn;

  /// No description provided for @colNameLbl.
  ///
  /// In en, this message translates to:
  /// **'Column name'**
  String get colNameLbl;

  /// No description provided for @visibleCols.
  ///
  /// In en, this message translates to:
  /// **'Visible columns'**
  String get visibleCols;

  /// No description provided for @visibleColsShort.
  ///
  /// In en, this message translates to:
  /// **'Visible columns:'**
  String get visibleColsShort;

  /// No description provided for @showShort.
  ///
  /// In en, this message translates to:
  /// **'Show:'**
  String get showShort;

  /// No description provided for @visibilityHelp.
  ///
  /// In en, this message translates to:
  /// **'Tap to collapse/expand each per-day field. Hidden columns stay in your data but are not shown in Weekly/Daily.'**
  String get visibilityHelp;

  /// No description provided for @ctCheckbox.
  ///
  /// In en, this message translates to:
  /// **'Checkbox'**
  String get ctCheckbox;

  /// No description provided for @ctCheckboxDesc.
  ///
  /// In en, this message translates to:
  /// **'Single tickbox — done / not done'**
  String get ctCheckboxDesc;

  /// No description provided for @ctStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get ctStatus;

  /// No description provided for @ctStatusDesc.
  ///
  /// In en, this message translates to:
  /// **'Colored dropdown (e.g. none / done / cancel)'**
  String get ctStatusDesc;

  /// No description provided for @ctNumber.
  ///
  /// In en, this message translates to:
  /// **'Number / Duration'**
  String get ctNumber;

  /// No description provided for @ctNumberDesc.
  ///
  /// In en, this message translates to:
  /// **'Number with optional unit (h, min)'**
  String get ctNumberDesc;

  /// No description provided for @ctDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get ctDate;

  /// No description provided for @ctDateDesc.
  ///
  /// In en, this message translates to:
  /// **'Calendar date picker'**
  String get ctDateDesc;

  /// No description provided for @ctDatetime.
  ///
  /// In en, this message translates to:
  /// **'DateTime'**
  String get ctDatetime;

  /// No description provided for @ctDatetimeDesc.
  ///
  /// In en, this message translates to:
  /// **'Date + time picker'**
  String get ctDatetimeDesc;

  /// No description provided for @ctTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get ctTags;

  /// No description provided for @ctTagsDesc.
  ///
  /// In en, this message translates to:
  /// **'Multiple colored tags per cell'**
  String get ctTagsDesc;

  /// No description provided for @ctText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get ctText;

  /// No description provided for @ctTextDesc.
  ///
  /// In en, this message translates to:
  /// **'Free-form notes'**
  String get ctTextDesc;

  /// No description provided for @ctTimer.
  ///
  /// In en, this message translates to:
  /// **'Time Length Selector'**
  String get ctTimer;

  /// No description provided for @ctTimerDesc.
  ///
  /// In en, this message translates to:
  /// **'Estimated duration + live countdown timer'**
  String get ctTimerDesc;

  /// No description provided for @ctSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get ctSchedule;

  /// No description provided for @ctScheduleDesc.
  ///
  /// In en, this message translates to:
  /// **'Time-of-day for that day (e.g. 9:00 AM)'**
  String get ctScheduleDesc;

  /// No description provided for @ctReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get ctReminder;

  /// No description provided for @ctReminderDesc.
  ///
  /// In en, this message translates to:
  /// **'Dated message — email + app notification at that time'**
  String get ctReminderDesc;

  /// No description provided for @remCellTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get remCellTitle;

  /// No description provided for @remDateLbl.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get remDateLbl;

  /// No description provided for @remTimeLbl.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get remTimeLbl;

  /// No description provided for @remMsgLbl.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get remMsgLbl;

  /// No description provided for @remMsgHint.
  ///
  /// In en, this message translates to:
  /// **'What should we remind you of?'**
  String get remMsgHint;

  /// No description provided for @remEmpty.
  ///
  /// In en, this message translates to:
  /// **'Tap to set a reminder…'**
  String get remEmpty;

  /// No description provided for @remClearBtn.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get remClearBtn;

  /// No description provided for @remSavedTip.
  ///
  /// In en, this message translates to:
  /// **'Reminder saved — email + app notification scheduled.'**
  String get remSavedTip;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to 4cus'**
  String get welcome;

  /// No description provided for @emailContinue.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to continue. We’ll create your workspace instantly — no password needed.'**
  String get emailContinue;

  /// No description provided for @whyWorks.
  ///
  /// In en, this message translates to:
  /// **'Why 4cus works'**
  String get whyWorks;

  /// No description provided for @whyText.
  ///
  /// In en, this message translates to:
  /// **'Motivation fades. Written plans don\'t.'**
  String get whyText;

  /// No description provided for @studyQuote.
  ///
  /// In en, this message translates to:
  /// **'“A goal-setting study (Dominican University, 2015) shows people who wrote down a specific plan succeeded 70% of the time, versus 35% — literally double.”'**
  String get studyQuote;

  /// No description provided for @studyRef.
  ///
  /// In en, this message translates to:
  /// **'— Gail Matthews, 2015'**
  String get studyRef;

  /// No description provided for @emailLbl.
  ///
  /// In en, this message translates to:
  /// **'Email address *'**
  String get emailLbl;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. alex@example.com'**
  String get emailHint;

  /// No description provided for @vipLbl.
  ///
  /// In en, this message translates to:
  /// **'VIP key (optional)'**
  String get vipLbl;

  /// No description provided for @emailKeyNote.
  ///
  /// In en, this message translates to:
  /// **'your email is your only key to your data — remember exactly how you typed it'**
  String get emailKeyNote;

  /// No description provided for @cloudNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Cloud is NOT configured in this build — data will stay on THIS device only and will not appear on your other devices.'**
  String get cloudNotConfigured;

  /// No description provided for @worksLine.
  ///
  /// In en, this message translates to:
  /// **'Works on web and Android. Your data syncs instantly via Supabase — if you’re offline, edits queue and retry.'**
  String get worksLine;

  /// No description provided for @suggestLink.
  ///
  /// In en, this message translates to:
  /// **'Have an idea to improve 4cus? Tell us'**
  String get suggestLink;

  /// No description provided for @errEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get errEmail;

  /// No description provided for @errVip.
  ///
  /// In en, this message translates to:
  /// **'Invalid VIP key'**
  String get errVip;

  /// No description provided for @vipRequired.
  ///
  /// In en, this message translates to:
  /// **'VIP required'**
  String get vipRequired;

  /// No description provided for @vipRequiredText.
  ///
  /// In en, this message translates to:
  /// **'Enter your VIP key to unlock Google Calendar sync.'**
  String get vipRequiredText;

  /// No description provided for @vipKeyLbl.
  ///
  /// In en, this message translates to:
  /// **'VIP key'**
  String get vipKeyLbl;

  /// No description provided for @vipKeyHint.
  ///
  /// In en, this message translates to:
  /// **'paste your key'**
  String get vipKeyHint;

  /// No description provided for @unlockBtn.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlockBtn;

  /// No description provided for @enterVipKey.
  ///
  /// In en, this message translates to:
  /// **'Enter a VIP key'**
  String get enterVipKey;

  /// No description provided for @vipSaved.
  ///
  /// In en, this message translates to:
  /// **'VIP key saved — Google sync unlocked!'**
  String get vipSaved;

  /// No description provided for @invalidVipKey.
  ///
  /// In en, this message translates to:
  /// **'Invalid VIP key: {error}'**
  String invalidVipKey(String error);

  /// No description provided for @addLaterNote.
  ///
  /// In en, this message translates to:
  /// **'You can add the VIP key later in Settings. Without it, the sync options stay grayed out.'**
  String get addLaterNote;

  /// No description provided for @cloudOkTip.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync: connected'**
  String get cloudOkTip;

  /// No description provided for @cloudOfflineTip.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync: offline — showing saved data'**
  String get cloudOfflineTip;

  /// No description provided for @demoTip.
  ///
  /// In en, this message translates to:
  /// **'Demo mode: cloud not configured — data stays on this device'**
  String get demoTip;

  /// No description provided for @syncErrorTip.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync failed'**
  String get syncErrorTip;

  /// No description provided for @connectingTip.
  ///
  /// In en, this message translates to:
  /// **'Connecting to cloud…'**
  String get connectingTip;

  /// No description provided for @reloadTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to reload from cloud.'**
  String get reloadTapHint;

  /// No description provided for @signedInWord.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {email}.'**
  String signedInWord(String email);

  /// No description provided for @demoBanner.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — cloud is not configured in this build, so data stays on THIS device only.'**
  String get demoBanner;

  /// No description provided for @recapTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} — notes recap'**
  String recapTitle(String name);

  /// No description provided for @notesRecap.
  ///
  /// In en, this message translates to:
  /// **'Notes recap'**
  String get notesRecap;

  /// No description provided for @notesRecapCount.
  ///
  /// In en, this message translates to:
  /// **'Notes recap ({n})'**
  String notesRecapCount(String n);

  /// No description provided for @noNoteCol.
  ///
  /// In en, this message translates to:
  /// **'No note column yet — add one in Manage Columns to start collecting notes.'**
  String get noNoteCol;

  /// No description provided for @noNotesYet.
  ///
  /// In en, this message translates to:
  /// **'No notes for \"{name}\" yet. Add one from any day cell under \"{col}\".'**
  String noNotesYet(String name, String col);

  /// No description provided for @tapOpenStudio.
  ///
  /// In en, this message translates to:
  /// **'Tap to open in sidebar studio'**
  String get tapOpenStudio;

  /// No description provided for @reminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminderTitle;

  /// No description provided for @reminderHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 10MI, 2H, 1D, 1W, 1M — empty clears it'**
  String get reminderHint;

  /// No description provided for @reminderUnitsHelp.
  ///
  /// In en, this message translates to:
  /// **'MI = minutes · H = hours · D = days · W = weeks · M = months. Notifies before the task\'s next scheduled time.'**
  String get reminderUnitsHelp;

  /// No description provided for @reminderInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use a number followed by MI, H, D, W or M (e.g. 3D).'**
  String get reminderInvalid;

  /// No description provided for @reminderSet.
  ///
  /// In en, this message translates to:
  /// **'Reminder ({r})'**
  String reminderSet(String r);

  /// No description provided for @setReminderItem.
  ///
  /// In en, this message translates to:
  /// **'Set reminder'**
  String get setReminderItem;

  /// No description provided for @bellTip.
  ///
  /// In en, this message translates to:
  /// **'Reminder: {r}'**
  String bellTip(String r);

  /// No description provided for @openTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openTooltip;

  /// No description provided for @tabEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get tabEdit;

  /// No description provided for @tabPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get tabPreview;

  /// No description provided for @writeHint.
  ///
  /// In en, this message translates to:
  /// **'Write your note…'**
  String get writeHint;

  /// No description provided for @previewEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to preview yet.'**
  String get previewEmpty;

  /// No description provided for @autosavedAt.
  ///
  /// In en, this message translates to:
  /// **'Autosaved {time}'**
  String autosavedAt(String time);

  /// No description provided for @savingNow.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get savingNow;

  /// No description provided for @autosavesHint.
  ///
  /// In en, this message translates to:
  /// **'Autosaves as you type'**
  String get autosavesHint;

  /// No description provided for @writeNoteEmpty.
  ///
  /// In en, this message translates to:
  /// **'Tap to write note…'**
  String get writeNoteEmpty;

  /// No description provided for @editColLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit {label}'**
  String editColLabel(String label);

  /// No description provided for @shapeTitle.
  ///
  /// In en, this message translates to:
  /// **'Shape 4cus with us'**
  String get shapeTitle;

  /// No description provided for @shapeMsg.
  ///
  /// In en, this message translates to:
  /// **'The average person doesn’t fail for lack of ambition — they fail for lack of planning and structure. That’s why most goals quietly fade and plans get forgotten.\n\n4cus exists to fix that, and we’re building it in the open. Your suggestion directly shapes what we build next — thank you for helping us build it with you.'**
  String get shapeMsg;

  /// No description provided for @nameEmailLbl.
  ///
  /// In en, this message translates to:
  /// **'Your name or email'**
  String get nameEmailLbl;

  /// No description provided for @suggLbl.
  ///
  /// In en, this message translates to:
  /// **'Your suggestion…'**
  String get suggLbl;

  /// No description provided for @suggHint.
  ///
  /// In en, this message translates to:
  /// **'What would make 4cus better for you?'**
  String get suggHint;

  /// No description provided for @sendBtn.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendBtn;

  /// No description provided for @thankTitle.
  ///
  /// In en, this message translates to:
  /// **'Thank you!'**
  String get thankTitle;

  /// No description provided for @thanksText.
  ///
  /// In en, this message translates to:
  /// **'Your suggestion was received. We read every single one, and the best ideas go straight onto the roadmap.'**
  String get thanksText;

  /// No description provided for @errWriteFirst.
  ///
  /// In en, this message translates to:
  /// **'Please write your suggestion first.'**
  String get errWriteFirst;

  /// No description provided for @errNoCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud is not configured in this build.'**
  String get errNoCloud;

  /// No description provided for @analyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analyticsTitle;

  /// No description provided for @analyticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your progress at a glance'**
  String get analyticsSubtitle;

  /// No description provided for @scheduledChip.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get scheduledChip;

  /// No description provided for @doneChipA.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneChipA;

  /// No description provided for @timePlanned.
  ///
  /// In en, this message translates to:
  /// **'Time planned'**
  String get timePlanned;

  /// No description provided for @timeDone.
  ///
  /// In en, this message translates to:
  /// **'Time done'**
  String get timeDone;

  /// No description provided for @weeklyProgress.
  ///
  /// In en, this message translates to:
  /// **'Weekly progress (last 8 weeks)'**
  String get weeklyProgress;

  /// No description provided for @statusBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Status breakdown'**
  String get statusBreakdown;

  /// No description provided for @timePerTask.
  ///
  /// In en, this message translates to:
  /// **'Time per task'**
  String get timePerTask;

  /// No description provided for @completionPerTask.
  ///
  /// In en, this message translates to:
  /// **'Completion per task'**
  String get completionPerTask;

  /// No description provided for @noTasksYet.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet'**
  String get noTasksYet;

  /// No description provided for @plannedLeg.
  ///
  /// In en, this message translates to:
  /// **'planned'**
  String get plannedLeg;

  /// No description provided for @progLeg.
  ///
  /// In en, this message translates to:
  /// **'in progress'**
  String get progLeg;

  /// No description provided for @cancelLeg.
  ///
  /// In en, this message translates to:
  /// **'cancelled'**
  String get cancelLeg;

  /// No description provided for @doneLeg.
  ///
  /// In en, this message translates to:
  /// **'done'**
  String get doneLeg;

  /// No description provided for @slotsDays.
  ///
  /// In en, this message translates to:
  /// **'{slots} slots · {days} days'**
  String slotsDays(String slots, String days);

  /// No description provided for @searchTasks.
  ///
  /// In en, this message translates to:
  /// **'Search tasks'**
  String get searchTasks;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search tasks…'**
  String get searchHint;

  /// No description provided for @statusFilterLbl.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusFilterLbl;

  /// No description provided for @allStatuses.
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get allStatuses;

  /// No description provided for @tagFilterLbl.
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get tagFilterLbl;

  /// No description provided for @allTags.
  ///
  /// In en, this message translates to:
  /// **'All tags'**
  String get allTags;

  /// No description provided for @hasNoteChip.
  ///
  /// In en, this message translates to:
  /// **'Has note'**
  String get hasNoteChip;

  /// No description provided for @hasNoteOnlyChip.
  ///
  /// In en, this message translates to:
  /// **'Has note only'**
  String get hasNoteOnlyChip;

  /// No description provided for @clearFiltersBtn.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearFiltersBtn;

  /// No description provided for @clearAllFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear all filters'**
  String get clearAllFilters;

  /// No description provided for @filtersActive.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} filter active} other{{count} filters active}}'**
  String filtersActive(int count);

  /// No description provided for @activeShort.
  ///
  /// In en, this message translates to:
  /// **'{count} active'**
  String activeShort(String count);

  /// No description provided for @filtersFooter.
  ///
  /// In en, this message translates to:
  /// **'{count} active • Filters apply to Weekly, Daily and Monthly'**
  String filtersFooter(String count);

  /// No description provided for @tapFilterHint.
  ///
  /// In en, this message translates to:
  /// **'{a} of {b} tasks • tap filter icon for more'**
  String tapFilterHint(String a, String b);

  /// No description provided for @todayTitle.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayTitle;

  /// No description provided for @ofTasksHint.
  ///
  /// In en, this message translates to:
  /// **'{a} of {b} tasks'**
  String ofTasksHint(String a, String b);

  /// No description provided for @androidNote.
  ///
  /// In en, this message translates to:
  /// **'Android simplified view — checkbox + status editing only. Structural edits (add/reorder columns) on Web. Synced via Supabase realtime. Offline queue enabled.'**
  String get androidNote;

  /// No description provided for @editsHint.
  ///
  /// In en, this message translates to:
  /// **'Edits save immediately and update the Monthly heatmap.'**
  String get editsHint;

  /// No description provided for @noScheduledTitle.
  ///
  /// In en, this message translates to:
  /// **'No tasks scheduled for this day.'**
  String get noScheduledTitle;

  /// No description provided for @checkHint.
  ///
  /// In en, this message translates to:
  /// **'Check the box for a task in Weekly or Daily view to schedule it for this date.'**
  String get checkHint;

  /// No description provided for @noneScheduledLine.
  ///
  /// In en, this message translates to:
  /// **'{day} — {total} total tasks, none scheduled.'**
  String noneScheduledLine(String day, String total);

  /// No description provided for @checkScheduledHint.
  ///
  /// In en, this message translates to:
  /// **'Check the box for a task in Weekly or Daily view to schedule it for this date.'**
  String get checkScheduledHint;

  /// No description provided for @timerTitle.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get timerTitle;

  /// No description provided for @editDurationTip.
  ///
  /// In en, this message translates to:
  /// **'Edit duration'**
  String get editDurationTip;

  /// No description provided for @editDurationTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit duration'**
  String get editDurationTitle;

  /// No description provided for @durationLbl.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get durationLbl;

  /// No description provided for @setDurationBtn.
  ///
  /// In en, this message translates to:
  /// **'Set duration'**
  String get setDurationBtn;

  /// No description provided for @durationExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. 4h, 30min, 1h 20m'**
  String get durationExample;

  /// No description provided for @remainingLbl.
  ///
  /// In en, this message translates to:
  /// **'remaining'**
  String get remainingLbl;

  /// No description provided for @completedLbl.
  ///
  /// In en, this message translates to:
  /// **'completed'**
  String get completedLbl;

  /// No description provided for @pausedLbl.
  ///
  /// In en, this message translates to:
  /// **'paused'**
  String get pausedLbl;

  /// No description provided for @elapsedOf.
  ///
  /// In en, this message translates to:
  /// **'{eff} elapsed / {total} total'**
  String elapsedOf(String eff, String total);

  /// No description provided for @startBtn.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startBtn;

  /// No description provided for @resumeBtn.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeBtn;

  /// No description provided for @pauseBtn.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseBtn;

  /// No description provided for @stopBtn.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopBtn;

  /// No description provided for @restartBtn.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restartBtn;

  /// No description provided for @completedBadge.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedBadge;

  /// No description provided for @tagsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tagsTitle;

  /// No description provided for @okBtn.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get okBtn;

  /// No description provided for @notifTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifTitle;

  /// No description provided for @notifHelp.
  ///
  /// In en, this message translates to:
  /// **'Alerts for timer done, daily tasks, and timer reminders — works on Android and web (when tab is open).'**
  String get notifHelp;

  /// No description provided for @timerDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Timer done'**
  String get timerDoneTitle;

  /// No description provided for @timerDoneSub.
  ///
  /// In en, this message translates to:
  /// **'When a time countdown finishes'**
  String get timerDoneSub;

  /// No description provided for @dailyBriefTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily briefing'**
  String get dailyBriefTitle;

  /// No description provided for @dailyBriefSub.
  ///
  /// In en, this message translates to:
  /// **'Send next tasks for today'**
  String get dailyBriefSub;

  /// No description provided for @sendTestNow.
  ///
  /// In en, this message translates to:
  /// **'Send test now'**
  String get sendTestNow;

  /// No description provided for @atDaily.
  ///
  /// In en, this message translates to:
  /// **'at {time} daily'**
  String atDaily(String time);

  /// No description provided for @timerRemTitle.
  ///
  /// In en, this message translates to:
  /// **'Timer reminders'**
  String get timerRemTitle;

  /// No description provided for @timerRemSub.
  ///
  /// In en, this message translates to:
  /// **'Before a timer ends'**
  String get timerRemSub;

  /// No description provided for @minSuffix.
  ///
  /// In en, this message translates to:
  /// **'{m} min'**
  String minSuffix(String m);

  /// No description provided for @noTasksToday.
  ///
  /// In en, this message translates to:
  /// **'No tasks scheduled for today — tap to open 4cus.'**
  String get noTasksToday;

  /// No description provided for @tapToSee.
  ///
  /// In en, this message translates to:
  /// **'Tap to see what’s scheduled for today'**
  String get tapToSee;

  /// No description provided for @gcalTitle.
  ///
  /// In en, this message translates to:
  /// **'Google Calendar sync'**
  String get gcalTitle;

  /// No description provided for @gcalHelp.
  ///
  /// In en, this message translates to:
  /// **'Sync monthly view (scheduled tasks) to your Google Calendar automatically. Put your Google email, accept the consent screen, and you’re done.'**
  String get gcalHelp;

  /// No description provided for @connectBtn.
  ///
  /// In en, this message translates to:
  /// **'Connect Google Calendar'**
  String get connectBtn;

  /// No description provided for @connectHelp.
  ///
  /// In en, this message translates to:
  /// **'You’ll be asked to pick your Google account and Accept calendar access.'**
  String get connectHelp;

  /// No description provided for @disconnectBtn.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnectBtn;

  /// No description provided for @autoSyncLbl.
  ///
  /// In en, this message translates to:
  /// **'Auto-sync monthly'**
  String get autoSyncLbl;

  /// No description provided for @autoSyncHelp.
  ///
  /// In en, this message translates to:
  /// **'When on, every checkbox / schedule / time change for a scheduled day creates/updates a Google event within seconds.'**
  String get autoSyncHelp;

  /// No description provided for @connectFailed.
  ///
  /// In en, this message translates to:
  /// **'Connect failed: {error}'**
  String connectFailed(String error);

  /// No description provided for @connectedAs.
  ///
  /// In en, this message translates to:
  /// **'Connected as {email}'**
  String connectedAs(String email);

  /// No description provided for @rowsVisibleLbl.
  ///
  /// In en, this message translates to:
  /// **'Rows visible at once'**
  String get rowsVisibleLbl;

  /// No description provided for @allRowsItem.
  ///
  /// In en, this message translates to:
  /// **'All rows'**
  String get allRowsItem;

  /// No description provided for @rowsCountItem.
  ///
  /// In en, this message translates to:
  /// **'{n} rows'**
  String rowsCountItem(String n);

  /// No description provided for @daysVisibleLbl.
  ///
  /// In en, this message translates to:
  /// **'Day-columns visible at once (Weekly)'**
  String get daysVisibleLbl;

  /// No description provided for @allDaysItem.
  ///
  /// In en, this message translates to:
  /// **'All (7 days)'**
  String get allDaysItem;

  /// No description provided for @daysCountItem.
  ///
  /// In en, this message translates to:
  /// **'{n} days'**
  String daysCountItem(String n);

  /// No description provided for @cellStyleLbl.
  ///
  /// In en, this message translates to:
  /// **'Cell style (timer & status)'**
  String get cellStyleLbl;

  /// No description provided for @fullBtn.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get fullBtn;

  /// No description provided for @basicBtn.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get basicBtn;

  /// No description provided for @basicHelp.
  ///
  /// In en, this message translates to:
  /// **'Basic shows icon-only timer/status cells — tap one to open the full editor.'**
  String get basicHelp;

  /// No description provided for @appearanceLbl.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceLbl;

  /// No description provided for @darkBtn.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkBtn;

  /// No description provided for @lightBtn.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightBtn;

  /// No description provided for @columnVisibilityHelp.
  ///
  /// In en, this message translates to:
  /// **'Column visibility is saved per user. Hide schedule/time/status/note to focus the table — e.g., show only status or only time.'**
  String get columnVisibilityHelp;

  /// No description provided for @switchDark.
  ///
  /// In en, this message translates to:
  /// **'Switch to dark mode'**
  String get switchDark;

  /// No description provided for @switchLight.
  ///
  /// In en, this message translates to:
  /// **'Switch to light mode'**
  String get switchLight;

  /// No description provided for @changeNameQ.
  ///
  /// In en, this message translates to:
  /// **'Change name?'**
  String get changeNameQ;

  /// No description provided for @changeNameQBody.
  ///
  /// In en, this message translates to:
  /// **'Your data stays under the current name. You can reclaim it later by entering the exact same name again.'**
  String get changeNameQBody;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'fr': return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
