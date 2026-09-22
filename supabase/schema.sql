-- Supabase schema for Tracker Sheet
-- Run in Supabase SQL editor

-- 1. Tasks
create table if not exists public.tasks (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  position int not null,
  created_at timestamp with time zone default now()
);
alter table public.tasks enable row level security;
create policy "Users can manage own tasks" on public.tasks for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create index if not exists idx_tasks_user_pos on public.tasks(user_id, position);

-- 2. Column definitions (user-managed columns)
create table if not exists public.column_definitions (
  id text primary key, -- e.g. col_xxx
  user_id uuid not null references auth.users(id) on delete cascade,
  label text not null,
  type text not null, -- checkbox | status | number | date | datetime | tags | text
  position int not null,
  config jsonb not null default '{}'::jsonb, -- { options: [{id,label,colorHex}], unit: 'h' }
  visible_days jsonb, -- null or ["tuesday", ...]
  created_at timestamp with time zone default now()
);
alter table public.column_definitions enable row level security;
create policy "Users manage own columns" on public.column_definitions for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create index if not exists idx_cols_user_pos on public.column_definitions(user_id, position);

-- 3. Day entries (one per Task per date per user)
create table if not exists public.day_entries (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  task_id uuid not null references public.tasks(id) on delete cascade,
  entry_date date not null,
  checked boolean not null default false,
  data jsonb not null default '{}'::jsonb, -- columnId -> value
  updated_at timestamp with time zone default now(),
  unique(user_id, task_id, entry_date)
);
alter table public.day_entries enable row level security;
create policy "Users manage own entries" on public.day_entries for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create index if not exists idx_entries_user_date on public.day_entries(user_id, entry_date);
create index if not exists idx_entries_task on public.day_entries(task_id);

-- Realtime: enable postgres_changes publication
-- In Supabase Dashboard: Database > Publications > check tables, or run:
-- alter publication supabase_realtime add table public.tasks, public.column_definitions, public.day_entries;

-- Seed helper: insert default columns for new user via function/trigger (optional)
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.column_definitions (id, user_id, label, type, position, config)
  values
    ('col_time', new.id, 'time', 'number', 1, '{"unit":"h"}'::jsonb),
    ('col_status', new.id, 'status', 'number', 2, '{"options":[{"id":"none","label":"none","colorHex":"#E0E0E0"},{"id":"done","label":"done","colorHex":"#2E7D32"},{"id":"cancel","label":"cancel","colorHex":"#C62828"}]}'::jsonb);
  return new;
end;
$$ language plpgsql security definer;

-- Uncomment to auto-seed on signup:
-- drop trigger if exists on_auth_user_created on auth.users;
-- create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
