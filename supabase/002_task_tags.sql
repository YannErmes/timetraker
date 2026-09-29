-- Run this once in the Supabase SQL editor (Dashboard > SQL > New query).
-- Adds the task-level tags: a tag attached to the task itself, which is
-- different from the tags column that tags a task on one particular day.
-- A task tagged "project" keeps that tag on every day, including days it was
-- never scheduled on.
--
-- Safe to run more than once. The app treats a missing column as "no tags",
-- so a workspace that has not run this yet still works, it just cannot save
-- task tags until it does.

do $$ begin
  alter table public.tasks add column if not exists tags jsonb not null default '[]'::jsonb;
exception when others then null; end $$;

create index if not exists idx_tasks_tags on public.tasks using gin (tags);
