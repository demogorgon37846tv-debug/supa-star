-- Supabase schema for Grade 5 Stars app
-- Run in Supabase SQL editor

-- Enable pgcrypto for gen_random_uuid()
create extension if not exists "pgcrypto";

-- Profiles table (one row per auth user)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  email text,
  avatar_url text,
  metadata jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Students table: stores pupil info and per-subject stars
create table if not exists public.students (
  id bigint primary key,
  owner_email text not null, -- link to the teacher/admin account that owns these rows
  name text not null,
  lrn text,
  gender text,
  birthday date,
  stars jsonb default '{}', -- e.g. {"overall":10,"english":2,...}
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Leaderboard table: optional separate table for score history
create table if not exists public.leaderboard (
  id uuid default gen_random_uuid() primary key,
  student_id bigint references public.students(id) on delete cascade,
  score integer not null,
  details jsonb,
  created_at timestamptz default now()
);

-- Indexes
create index if not exists idx_students_owner_email on public.students (owner_email);
create index if not exists idx_students_name on public.students (lower(name));
create index if not exists idx_leaderboard_student_score on public.leaderboard (student_id, score desc);

-- Trigger function to update updated_at
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists students_set_updated_at on public.students;
create trigger students_set_updated_at
before update on public.students
for each row execute procedure public.set_updated_at();

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute procedure public.set_updated_at();

-- Recommended RLS (Row Level Security) for clients using anon key
-- Enable RLS on students and leaderboard
alter table public.students enable row level security;
alter table public.leaderboard enable row level security;

-- Policy: allow authenticated users to insert/select/update/delete their own students (owner_email = auth.email())
create policy "students_owner_policy" on public.students
  for all
  using (owner_email = auth.email())
  with check (owner_email = auth.email());

-- Policy: allow read access to leaderboard for authenticated users (optional)
create policy "leaderboard_select_auth" on public.leaderboard
  for select
  using (true);

-- Note: Adjust RLS policies as needed for teachers/admins. Do NOT use service_role key in client code.
