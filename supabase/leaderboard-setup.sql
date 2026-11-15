-- Zombie Smash leaderboard: setup for Supabase (starts with an empty board).
-- How to run: Supabase dashboard > your project > SQL Editor > New query > paste ALL of this > Run.
-- It is safe to run again. The game talks to four functions only; the tables are locked down.

-- FRESH START: this removes any earlier leaderboard tables and scores and builds a clean board.
drop function if exists public.zs7_begin_run(text, text);
drop function if exists public.zs7_finish_run(text, uuid, integer, integer, integer, integer, boolean);
drop function if exists public.zs7_leaderboard();
drop function if exists public.zs7_admin(text, text);
drop table if exists public.zs7_runs cascade;
drop table if exists public.zs7_legacy cascade;

create extension if not exists pgcrypto;

create table if not exists public.zs7_runs (
  ticket uuid primary key default gen_random_uuid(),
  device text not null check (device ~ '^[a-f0-9]{64}$'),
  name text not null check (char_length(name) between 2 and 24),
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  score integer,
  kills integer,
  seconds integer,
  wave integer,
  accepted boolean not null default false
);
create index if not exists zs7_runs_board on public.zs7_runs (accepted, score desc);

create table if not exists public.zs7_legacy (
  username text primary key,
  score integer not null
);

create table if not exists public.zs7_admin_codes (
  code text primary key
);

alter table public.zs7_runs enable row level security;
alter table public.zs7_legacy enable row level security;
alter table public.zs7_admin_codes enable row level security;
-- No policies on purpose: the app can only use the functions below.

-- 1. Start a run: returns a ticket the game keeps until the run ends.
create or replace function public.zs7_begin_run(p_device text, p_name text)
returns uuid language plpgsql security definer set search_path = public as $$
declare t uuid;
begin
  if p_device !~ '^[a-f0-9]{64}$' or p_name is null or char_length(trim(p_name)) not between 2 and 24 then
    raise exception 'bad request' using errcode = '22023';
  end if;
  insert into zs7_runs (device, name) values (p_device, trim(p_name)) returning ticket into t;
  return t;
end $$;

-- 2. Finish a run: true when the score is accepted.
create or replace function public.zs7_finish_run(
  p_device text, p_ticket uuid, p_score integer, p_kills integer,
  p_seconds integer, p_wave integer, p_practice boolean default false)
returns boolean language plpgsql security definer set search_path = public as $$
declare r zs7_runs;
begin
  if p_practice then return false; end if;
  select * into r from zs7_runs where ticket = p_ticket and device = p_device for update;
  if not found then raise exception 'unknown run' using errcode = '22023'; end if;
  if r.finished_at is not null then return r.accepted; end if;
  if p_score < 0 or p_kills < 0 or p_seconds < 1 or p_wave < 1 or p_score > 5000000 then
    raise exception 'bad score' using errcode = '22023';
  end if;
  -- Sanity checks against faked scores: a real run takes time and scores at a limited rate.
  update zs7_runs set finished_at = now(), score = p_score, kills = p_kills, seconds = p_seconds, wave = p_wave,
    accepted = (extract(epoch from (now() - started_at)) >= least(p_seconds, 20) * 0.5
                and p_score <= (p_seconds + 30) * 2500)
  where ticket = p_ticket returning accepted into r.accepted;
  return r.accepted;
end $$;

-- 3. The public board: best score per player name, top 50, with the original records mixed in.
create or replace function public.zs7_leaderboard()
returns table (username text, score integer, legacy boolean)
language sql security definer set search_path = public as $$
  -- One row per player: their best score. A player's cheat-marked runs ('.cht') only count if they have no clean run.
  select username, score, false as legacy from (
    select distinct on (lower(regexp_replace(name, '\.cht$', '')))
           name as username, score
      from zs7_runs where accepted and score is not null
      order by lower(regexp_replace(name, '\.cht$', '')), (lower(name) like '%.cht'), score desc
  ) best
  order by score desc limit 50;
$$;

-- 4. Admin check for the in-app admin panel: true only for a code you add to zs7_admin_codes.
create or replace function public.zs7_admin(p_device text, p_code text)
returns boolean language sql security definer set search_path = public as $$
  select exists (select 1 from zs7_admin_codes where code = p_code);
$$;

revoke all on function public.zs7_begin_run(text, text) from public;
revoke all on function public.zs7_finish_run(text, uuid, integer, integer, integer, integer, boolean) from public;
revoke all on function public.zs7_leaderboard() from public;
revoke all on function public.zs7_admin(text, text) from public;
grant execute on function public.zs7_begin_run(text, text) to anon, authenticated;
grant execute on function public.zs7_finish_run(text, uuid, integer, integer, integer, integer, boolean) to anon, authenticated;
grant execute on function public.zs7_leaderboard() to anon, authenticated;
grant execute on function public.zs7_admin(text, text) to anon, authenticated;

-- Optional: add your own admin code (change it first, then remove the two dashes):
-- insert into public.zs7_admin_codes (code) values ('choose-a-long-secret-code');
