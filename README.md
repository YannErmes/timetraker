# Tracker Sheet — Flutter (Web + Android) + Supabase

Spreadsheet-style task tracker organized like a calendar. Mirrors the screenshot: **Tasks as rows**, each day as a column group with `checkbox` (done today) + custom columns (`time` duration + `status` color dropdown by default). Users add unlimited custom columns (checkbox / status / number/duration / date / datetime / multi-select tags / text).

## Stack
- **Flutter** single codebase, targets **Web (primary) + Android (secondary)**
- **Supabase** Postgres + `postgres_changes` realtime subscriptions + Supabase Auth (email/password only)
- **Riverpod** for state, `shared_preferences` + `connectivity_plus` for offline queue on Android

## Run

1. **Supabase setup**
   - Create project at supabase.com
   - Run `supabase/schema.sql` in SQL Editor
   - In Dashboard → Database → Publications, enable Realtime for `tasks`, `column_definitions`, `day_entries`
   - Copy URL + anon key

2. **Configure**
   ```bash
   flutter pub get
   ```

   Pass keys at build/run:
   ```bash
   flutter run -d chrome --dart-define SUPABASE_URL=https://xxx.supabase.co --dart-define SUPABASE_ANON_KEY=eyJ...
   flutter run -d android --dart-define SUPABASE_URL=... --dart-define SUPABASE_ANON_KEY=...
   ```

   If no keys provided, app runs in **Demo mode** (in-memory + offline cache, no Supabase). Any email/password logs in.

3. **Web (main)**
   ```bash
   flutter run -d chrome
   ```
   - Weekly (default) — spreadsheet with sticky header + sticky Tasks column, horizontal scroll, inline editing, add/remove/reorder tasks & columns via ✏️ panel
   - Daily — single day, all tasks + all columns, room for detail
   - Monthly — heatmap grid, completion rate per day, tap to jump to Daily

4. **Android (checklist)**
   ```bash
   flutter run -d android
   ```
   Shows today's tasks as checklist: toggle `checked`, edit `time`/`status` (and other columns read/write). No column structural edits on mobile. Offline queue: checkbox updates cached in `shared_preferences` and flushed via `connectivity_plus` when back online.

## Data model

```dart
Task: id(uuid), name, position, createdAt, userId
ColumnDefinition: id(text), label, type(enum), position, config(jsonb: {options:[{id,label,colorHex}], unit}), visibleDays?
DayEntry: id(uuid), taskId, userId, entryDate(date), checked(bool), data(jsonb: columnId -> value)
```

Auth = Supabase Auth email/password only. RLS: `auth.uid() = user_id` on all tables. Realtime channels filtered by `user_id`.

## Project layout
```
lib/
  config/supabase_config.dart  # dart-define keys
  models/                      # task, day_entry, column_definition, enums
  services/supabase_service.dart + sync_service.dart
  providers/app_providers.dart
  screens/auth_screen.dart, home_screen.dart
  widgets/weekly_grid.dart, daily_view.dart, monthly_view.dart, android_checklist.dart, column_settings_panel.dart
  utils/date_utils.dart
supabase/schema.sql
```

## Screenshot behavior replicated
- `cancel` = red (#C62828) pill, `done` = green (#2E7D32), `none` = gray (#E0E0E0) — configurable per column via color picker in column settings
- `time` column accepts `8h`, `48h`, `30min`, `4h` free text (number/duration type + unit)
- Empty Tasks rows render as placeholders; dashed blue outline area corresponds to horizontal scroll container

## Nice-to-haves (scaffolded)
- Analytics dialog: completion rate per task per week/month
- Dark mode via ThemeData
- Recurring weekly templates: duplicate previous week's tasks via “Add task” + position logic (extend in supabase_service)

## Reorder
- Columns: drag in right drawer (ReorderableListView)
- Tasks: position field + menu; grid drag reordering can be added by wrapping WeeklyGrid rows in ReorderableListView

## Offline
- `OfflineCache` stores tasks/columns/entries JSON + `PendingMutation` queue in SharedPreferences
- On connectivity regain, `_flushQueue()` upserts/inserts deletes sequentially
