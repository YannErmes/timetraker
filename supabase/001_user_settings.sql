-- Run this once in the Supabase SQL editor (Dashboard > SQL > New query).
-- It adds the per-user settings row that stores the Custom-theme background
-- photo, so a customer's picture follows them to any other device.
--
-- Safe to run more than once.

create table if not exists public.user_settings (
  user_id uuid primary key references public.app_users(id) on delete cascade,
  background_b64 text,
  background_brightness real,
  updated_at timestamp with time zone not null default now()
);

alter table public.user_settings enable row level security;

drop policy if exists "Allow all user_settings" on public.user_settings;
create policy "Allow all user_settings" on public.user_settings for all using (true) with check (true);
