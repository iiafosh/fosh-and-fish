-- fosh&fish online backend for Supabase (accounts, cloud saves, leaderboard).
--
-- Run once: Supabase Dashboard -> SQL Editor -> New query -> paste this whole file -> Run.
-- Safe to run again after changes (everything is "if not exists" / "or replace" / drop-then-create).
-- Setup guide: docs/BACKEND.md. Client: scripts/net/backend.gd. Local stand-in: tools/mock_supabase.py.
--
--   profiles     one row per account: the public fisher name (unique, case-insensitive)
--   saves        one row per account: the whole save (jsonb) + level / prestige / money_earned copied from it
--   leaderboard  a public, read-only view: name, level, prestige, money earned. Never emails, ids or saves.
--
-- Security: Row Level Security on both tables: a player can read and write only their own rows.
-- The game is client-authoritative (the save is made on the player's device), so the leaderboard can be
-- cheated by a determined player. saves_guard() below rejects impossible saves; see docs/BACKEND.md.


-- ============================================================== profiles
create table if not exists public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(display_name) between 2 and 24),
  banned       boolean not null default false,          -- owner only: true hides a cheater from the leaderboard
  created_at   timestamptz not null default now()
);
create unique index if not exists profiles_display_name_key on public.profiles (lower(display_name));

alter table public.profiles enable row level security;

drop policy if exists "profiles: read own" on public.profiles;
create policy "profiles: read own" on public.profiles
  for select to authenticated using ((select auth.uid()) = id);
drop policy if exists "profiles: insert own" on public.profiles;
create policy "profiles: insert own" on public.profiles
  for insert to authenticated with check ((select auth.uid()) = id);
drop policy if exists "profiles: update own" on public.profiles;
create policy "profiles: update own" on public.profiles
  for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

-- players may only ever touch their name (never "banned")
revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant insert (id, display_name), update (display_name) on public.profiles to authenticated;

-- A profile for every new account, named from the sign-up form (raw_user_meta_data.display_name).
-- Taken names get a "#1234" suffix so sign-up never fails; the player can rename in the game.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  base      text := left(btrim(coalesce(new.raw_user_meta_data ->> 'display_name', '')), 20);
  candidate text;
  tries     int  := 0;
begin
  if char_length(base) < 2 then
    base := 'Fisher';
  end if;
  candidate := base;
  loop
    begin
      insert into public.profiles (id, display_name) values (new.id, candidate)
        on conflict (id) do nothing;
      exit;
    exception when unique_violation then              -- the name is taken (case-insensitive)
      tries := tries + 1;
      candidate := left(base, 15) || '#' || case when tries < 20
        then lpad(floor(random() * 10000)::int::text, 4, '0')
        else left(replace(new.id::text, '-', ''), 8) end;
    end;
  end loop;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ================================================================= saves
create table if not exists public.saves (
  user_id      uuid primary key references auth.users (id) on delete cascade,
  data         jsonb not null,                           -- VF.to_dict(): the whole save
  level        int not null default 1,                   -- these three are copied from data by saves_guard()
  prestige     int not null default 0,
  money_earned bigint not null default 0,
  overwrite    boolean not null default false,           -- sent by the game: "the player chose to replace a
                                                         -- cloud save that has more progress"
  updated_at   timestamptz not null default now()
);
create index if not exists saves_rank on public.saves (prestige desc, level desc, money_earned desc);

alter table public.saves enable row level security;

drop policy if exists "saves: read own" on public.saves;
create policy "saves: read own" on public.saves
  for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "saves: insert own" on public.saves;
create policy "saves: insert own" on public.saves
  for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "saves: update own" on public.saves;
create policy "saves: update own" on public.saves
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

revoke all on public.saves from anon, authenticated;     -- logged-out visitors can't read any save
grant select, insert, update on public.saves to authenticated;

-- Plausibility guard, runs on every upload (the game uploads with an upsert:
-- POST /rest/v1/saves + "Prefer: resolution=merge-duplicates").
--   * data must be a JSON object under 256 KB
--   * level / prestige / money_earned are taken from data (so the leaderboard always matches the save)
--   * ranges: level 1..25000 (the game's cap), prestige 0..10000, money_earned >= 0
--   * no downgrades: a save with less progress (lower prestige, or same prestige and lower level) can't
--     replace the cloud save unless overwrite = true (the player picked "Keep this device")
--   * prestige can rise by at most 1 per 10 minutes since the last upload (+1), so a single upload can't
--     jump from P2 to P900. The first upload of an account can't be checked against anything.
-- Errors reach the game as HTTP 400 with the message; "save_downgrade" makes the game ask the player.
create or replace function public.saves_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  lv numeric;
  pr numeric;
  me numeric;
begin
  if jsonb_typeof(new.data) is distinct from 'object' then
    raise exception 'implausible save: data must be a JSON object';
  end if;
  if pg_column_size(new.data) > 262144 then
    raise exception 'implausible save: too big';
  end if;
  begin
    lv := coalesce((new.data ->> 'level')::numeric, 1);
    pr := coalesce((new.data ->> 'prestige')::numeric, 0);
    me := coalesce((new.data #>> '{stats,money_earned}')::numeric, 0);
  exception when others then
    raise exception 'implausible save: level / prestige / money_earned must be numbers';
  end;
  if lv < 1 or lv > 25000 or pr < 0 or pr > 10000 or me < 0 then
    raise exception 'implausible save: out of range';
  end if;
  new.level        := trunc(lv)::int;
  new.prestige     := trunc(pr)::int;
  new.money_earned := least(trunc(me), 9223372036854775807)::bigint;
  new.updated_at   := now();
  if tg_op = 'UPDATE' then
    new.user_id := old.user_id;                          -- a save can't move to another account
    if not new.overwrite
       and (new.prestige < old.prestige or (new.prestige = old.prestige and new.level < old.level)) then
      raise exception 'save_downgrade: the cloud save has more progress (send overwrite=true to replace it)';
    end if;
    if new.prestige - old.prestige > 1 + floor(extract(epoch from (now() - old.updated_at)) / 600) then
      raise exception 'implausible save: prestige rose too fast';
    end if;
    new.overwrite := false;
  end if;
  -- (on INSERT, "overwrite" is left as sent: in an upsert, BEFORE INSERT changes show up in EXCLUDED and
  --  would cancel the flag for the UPDATE that follows. The game always sends it explicitly.)
  return new;
end;
$$;

drop trigger if exists saves_guard on public.saves;
create trigger saves_guard
  before insert or update on public.saves
  for each row execute function public.saves_guard();


-- =========================================================== leaderboard
-- security_invoker = false: the view runs as its owner, so anyone with the anon key can read it even though
-- RLS hides other players' rows in the tables. It exposes ONLY these four columns. (Supabase's linter will
-- flag it as a "security definer view"; that is intended here.)
drop view if exists public.leaderboard;
create view public.leaderboard
with (security_invoker = false)
as
  select p.display_name, s.level, s.prestige, s.money_earned
  from public.saves s
  join public.profiles p on p.id = s.user_id
  where not p.banned
  order by s.prestige desc, s.level desc, s.money_earned desc;

revoke all on public.leaderboard from anon, authenticated;
grant select on public.leaderboard to anon, authenticated;


-- ======================================================= delete account
-- In-game "Delete account": removes the login, which cascades to the profile and the cloud save.
-- (App stores require an in-app way to delete an account.)
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
