-- ForgeFit production schema. Run once in Supabase SQL Editor.
-- Frontend must use only the anon/publishable key. Never expose service_role.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Użytkownik',
  bodyweight numeric(6,2) not null default 0 check (bodyweight >= 0),
  created_at timestamptz not null default now()
);
create table if not exists public.training_groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  invite_code text not null unique default upper(substr(encode(gen_random_bytes(8), 'hex'), 1, 10)),
  owner_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table if not exists public.group_members (
  group_id uuid not null references public.training_groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','member')),
  joined_at timestamptz not null default now(),
  primary key (group_id,user_id)
);
create table if not exists public.exercises (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  muscle_group text not null default 'Całe ciało',
  increment_kg numeric(5,2) not null default 2.5 check (increment_kg > 0),
  increment_mode text not null default 'total' check (increment_mode in ('total','side')),
  rest_seconds integer not null default 120 check (rest_seconds >= 0),
  target_sets integer not null default 3 check (target_sets > 0),
  target_reps_min integer not null default 8 check (target_reps_min > 0),
  target_reps_max integer not null default 12 check (target_reps_max >= target_reps_min),
  created_at timestamptz not null default now()
);
create table if not exists public.workouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null default 'Trening',
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  notes text
);
create table if not exists public.workout_sets (
  id uuid primary key default gen_random_uuid(),
  workout_id uuid not null references public.workouts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  exercise_id uuid not null references public.exercises(id) on delete cascade,
  set_number integer not null default 1 check (set_number > 0),
  weight_kg numeric(7,2) not null check (weight_kg >= 0),
  reps integer not null check (reps > 0),
  rir numeric(3,1) check (rir >= 0 and rir <= 10),
  rpe numeric(3,1) check (rpe >= 1 and rpe <= 10),
  is_warmup boolean not null default false,
  created_at timestamptz not null default now()
);
create table if not exists public.progression_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  exercise_id uuid references public.exercises(id) on delete cascade,
  title text not null,
  detail text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create table if not exists public.personal_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  exercise_id uuid not null references public.exercises(id) on delete cascade,
  workout_set_id uuid not null references public.workout_sets(id) on delete cascade,
  record_type text not null default 'estimated_1rm',
  score numeric(8,2) not null,
  achieved_at timestamptz not null default now(),
  unique(user_id,exercise_id,workout_set_id,record_type)
);
create index if not exists workouts_user_started_idx on public.workouts(user_id,started_at desc);
create index if not exists sets_user_exercise_created_idx on public.workout_sets(user_id,exercise_id,created_at desc);
create index if not exists memberships_user_idx on public.group_members(user_id,group_id);

-- Make existing installations compatible with a blank profile (0 kg until user fills it in).
alter table public.profiles drop constraint if exists profiles_bodyweight_check;
alter table public.profiles add constraint profiles_bodyweight_check check (bodyweight >= 0);

alter table public.profiles enable row level security;
alter table public.training_groups enable row level security;
alter table public.group_members enable row level security;
alter table public.exercises enable row level security;
alter table public.workouts enable row level security;
alter table public.workout_sets enable row level security;
alter table public.progression_notifications enable row level security;
alter table public.personal_records enable row level security;

drop policy if exists profiles_select_own on public.profiles;
drop policy if exists profiles_insert_own on public.profiles;
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_select_own on public.profiles for select to authenticated using (id=auth.uid());
create policy profiles_insert_own on public.profiles for insert to authenticated with check (id=auth.uid());
create policy profiles_update_own on public.profiles for update to authenticated using (id=auth.uid()) with check (id=auth.uid());

drop policy if exists exercises_own_all on public.exercises;
drop policy if exists workouts_own_all on public.workouts;
drop policy if exists sets_own_all on public.workout_sets;
drop policy if exists notifications_own_all on public.progression_notifications;
drop policy if exists records_own_all on public.personal_records;
create policy exercises_own_all on public.exercises for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy workouts_own_all on public.workouts for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy sets_own_all on public.workout_sets for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy notifications_own_all on public.progression_notifications for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy records_own_all on public.personal_records for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());

-- Group data is read through SECURITY DEFINER functions below, never via broad table policies.
revoke all on public.training_groups from anon, authenticated;
revoke all on public.group_members from anon, authenticated;

create or replace function public.create_training_group(group_name text)
returns table(id uuid, name text, invite_code text, role text)
language plpgsql security definer set search_path=public,pg_temp as $$
declare new_group public.training_groups;
begin
  if auth.uid() is null then raise exception 'Zaloguj się.'; end if;
  if length(trim(group_name)) < 2 then raise exception 'Nazwa grupy musi mieć co najmniej 2 znaki.'; end if;
  insert into public.training_groups(name,owner_id) values(trim(group_name),auth.uid()) returning * into new_group;
  insert into public.group_members(group_id,user_id,role) values(new_group.id,auth.uid(),'owner');
  return query select new_group.id,new_group.name,new_group.invite_code,'owner'::text;
end $$;

create or replace function public.join_training_group(code_input text)
returns table(id uuid, name text, invite_code text, role text)
language plpgsql security definer set search_path=public,pg_temp as $$
declare g public.training_groups;
begin
  if auth.uid() is null then raise exception 'Zaloguj się.'; end if;
  select * into g from public.training_groups where invite_code=upper(trim(code_input));
  if g.id is null then raise exception 'Nie znaleziono grupy o takim kodzie.'; end if;
  insert into public.group_members(group_id,user_id,role) values(g.id,auth.uid(),'member') on conflict(group_id,user_id) do nothing;
  return query select g.id,g.name,g.invite_code,'member'::text;
end $$;

create or replace function public.my_training_groups()
returns table(id uuid, name text, invite_code text, role text)
language sql stable security definer set search_path=public,pg_temp as $$
  select g.id,g.name,g.invite_code,gm.role from public.training_groups g
  join public.group_members gm on gm.group_id=g.id where gm.user_id=auth.uid() order by g.created_at;
$$;

-- Relative-strength ranking: compares users in any shared group, matching exercise names.
create or replace function public.group_strength_leaderboard(exercise_name_input text)
returns table(display_name text, best_1rm numeric, bodyweight numeric, bodyweight_percent numeric, best_weight numeric, best_reps integer)
language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
  if auth.uid() is null then raise exception 'Zaloguj się.'; end if;
  if not exists (select 1 from public.group_members mine where mine.user_id=auth.uid()) then
    raise exception 'Dołącz do grupy treningowej, aby zobaczyć ranking znajomych.';
  end if;
  return query
  with shared_users as (
    select distinct other.user_id from public.group_members mine
    join public.group_members other on other.group_id=mine.group_id
    where mine.user_id=auth.uid()
  ), scored as (
    select p.display_name,p.bodyweight,
      (s.weight_kg*(1+s.reps::numeric/30)) as one_rm,s.weight_kg,s.reps,
      row_number() over(partition by p.id order by (s.weight_kg*(1+s.reps::numeric/30)) desc) as rn
    from shared_users su join public.profiles p on p.id=su.user_id
    join public.exercises e on e.user_id=p.id and lower(trim(e.name))=lower(trim(exercise_name_input))
    join public.workout_sets s on s.exercise_id=e.id and s.user_id=p.id
    where p.bodyweight>0
  )
  select scored.display_name,round(scored.one_rm,2),scored.bodyweight,
    round(scored.one_rm/scored.bodyweight*100,2),scored.weight_kg,scored.reps
  from scored where rn=1 order by (scored.one_rm/scored.bodyweight) desc;
end $$;
revoke all on function public.create_training_group(text) from public;
revoke all on function public.join_training_group(text) from public;
revoke all on function public.my_training_groups() from public;
revoke all on function public.group_strength_leaderboard(text) from public;
grant execute on function public.create_training_group(text) to authenticated;
grant execute on function public.join_training_group(text) to authenticated;
grant execute on function public.my_training_groups() to authenticated;
grant execute on function public.group_strength_leaderboard(text) to authenticated;
