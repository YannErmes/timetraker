-- Supabase schema for Tracker Sheet — name-based identity + instant realtime sync
-- Run in Supabase SQL editor (works for fresh installs and migrations from email/password)

-- 0. Lightweight identity table: name is the only key (exact typing matters)
create table if not exists public.app_users (
  id uuid primary key,
  name text not null unique,
  created_at timestamp with time zone default now()
);
alter table public.app_users enable row level security;
-- Permissive for anon: name is the key, id is random uuid — client filters by id.
-- For prototype name-based auth, allow anon to read/write app_users (name is unique, id is obscure)
drop policy if exists "Allow all app_users" on public.app_users;
create policy "Allow all app_users" on public.app_users for all using (true) with check (true);
create index if not exists idx_app_users_name on public.app_users(name);

-- 1. Tasks
create table if not exists public.tasks (
  id uuid primary key,
  user_id uuid not null,
  name text not null,
  position int not null,
  created_at timestamp with time zone default now()
);
-- For migration from auth.users FK: drop old FK if exists and re-add to app_users
do $$ begin
  if exists (select 1 from information_schema.table_constraints where constraint_name='tasks_user_id_fkey' and table_name='tasks') then
    alter table public.tasks drop constraint tasks_user_id_fkey;
  end if;
exception when others then null; end $$;
-- Re-add FK to app_users if not already (best-effort, ignore if fails due to existing auth.users data)
do $$ begin
  alter table public.tasks add constraint tasks_user_id_fkey_app foreign key (user_id) references public.app_users(id) on delete cascade;
exception when others then null; end $$;

alter table public.tasks enable row level security;
drop policy if exists "Users can manage own tasks" on public.tasks;
drop policy if exists "Allow all tasks" on public.tasks;
-- Permissive for anon with name-based id (client always filters by user_id)
create policy "Allow all tasks" on public.tasks for all using (true) with check (true);
create index if not exists idx_tasks_user_pos on public.tasks(user_id, position);

-- 2. Column definitions (user-managed columns) — per-user, so id can repeat across users
create table if not exists public.column_definitions (
  id text not null, -- e.g. col_xxx, scoped per user
  user_id uuid not null,
  label text not null,
  type text not null, -- checkbox | status | number | date | datetime | tags | text | timer | schedule
  position int not null,
  config jsonb not null default '{}'::jsonb, -- { options: [{id,label,colorHex}], unit: 'h' }
  visible_days jsonb, -- null or ["tuesday", ...]
  created_at timestamp with time zone default now(),
  primary key (user_id, id)
);
-- Fix PK for per-user columns: was `id` alone, now `(user_id, id)`
do $$ begin
  -- drop old PK if it exists and is on (id) only
  if exists (select 1 from pg_constraint where conname='column_definitions_pkey') then
    begin
      alter table public.column_definitions drop constraint column_definitions_pkey;
    exception when others then null;
    end;
    begin
      alter table public.column_definitions add primary key (user_id, id);
    exception when others then
      -- if already composite or other error, try to ensure PK exists
      begin
        alter table public.column_definitions add primary key (user_id, id);
      exception when others then null;
      end;
    end;
  end if;
exception when others then null; end $$;

do $$ begin
  if exists (select 1 from information_schema.table_constraints where constraint_name='column_definitions_user_id_fkey' and table_name='column_definitions') then
    alter table public.column_definitions drop constraint column_definitions_user_id_fkey;
  end if;
exception when others then null; end $$;
do $$ begin
  alter table public.column_definitions add constraint coldefs_user_id_fkey_app foreign key (user_id) references public.app_users(id) on delete cascade;
exception when others then null; end $$;

alter table public.column_definitions enable row level security;
drop policy if exists "Users manage own columns" on public.column_definitions;
drop policy if exists "Allow all columns" on public.column_definitions;
create policy "Allow all columns" on public.column_definitions for all using (true) with check (true);
create index if not exists idx_cols_user_pos on public.column_definitions(user_id, position);

-- 3. Day entries (one per Task per date per user)
create table if not exists public.day_entries (
  id uuid primary key,
  user_id uuid not null,
  task_id uuid not null references public.tasks(id) on delete cascade,
  entry_date date not null,
  checked boolean not null default false,
  data jsonb not null default '{}'::jsonb, -- columnId -> value
  updated_at timestamp with time zone default now(),
  unique(user_id, task_id, entry_date)
);
do $$ begin
  if exists (select 1 from information_schema.table_constraints where constraint_name='day_entries_user_id_fkey' and table_name='day_entries') then
    alter table public.day_entries drop constraint day_entries_user_id_fkey;
  end if;
exception when others then null; end $$;
do $$ begin
  alter table public.day_entries add constraint day_entries_user_id_fkey_app foreign key (user_id) references public.app_users(id) on delete cascade;
exception when others then null; end $$;

alter table public.day_entries enable row level security;
drop policy if exists "Users manage own entries" on public.day_entries;
drop policy if exists "Allow all entries" on public.day_entries;
create policy "Allow all entries" on public.day_entries for all using (true) with check (true);
create index if not exists idx_entries_user_date on public.day_entries(user_id, entry_date);
create index if not exists idx_entries_task on public.day_entries(task_id);

-- Realtime: enable postgres_changes publication for instant sync (web <-> Android <2s)
-- In Supabase Dashboard: Database > Publications > supabase_realtime > add tables, or run:
do $$ begin
  alter publication supabase_realtime add table public.app_users;
exception when others then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.tasks;
exception when others then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.column_definitions;
exception when others then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.day_entries;
exception when others then null; end $$;

-- Note: instant writes: every create/update/delete does immediate supabase upsert/insert/delete
-- and is also queued in SharedPreferences via OfflineCache if offline, then flushed on reconnect.
-- No batch timer — see lib/services/supabase_service.dart setCellValue/toggleChecked/addTask etc.
