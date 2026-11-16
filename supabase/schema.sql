-- PAUSE cross-device sync schema.
-- Apply in a *new, dedicated* Supabase project's SQL editor.
-- Raw website/app histories and iPhone Screen Time reports are NEVER stored here.
begin;

create table if not exists public.pause_devices (
    user_id uuid not null references auth.users(id) on delete cascade,
    id uuid not null,
    kind text not null check (kind in ('mac', 'iphone', 'board')),
    label text not null check (char_length(label) between 1 and 80),
    last_seen timestamptz not null default now(),
    primary key (user_id, id)
);

create table if not exists public.pause_usage_daily (
    user_id uuid not null,
    device_id uuid not null,
    day date not null,
    category text not null check (category in ('social', 'creative', 'entertainment', 'other')),
    seconds integer not null check (seconds between 0 and 86400),
    updated_at timestamptz not null default now(),
    primary key (user_id, device_id, day, category),
    foreign key (user_id, device_id)
        references public.pause_devices(user_id, id) on delete cascade
);

create table if not exists public.pause_board_state (
    user_id uuid primary key references auth.users(id) on delete cascade,
    message text check (message is null or char_length(message) between 1 and 280),
    source text not null default 'manual'
        check (source in ('manual','threshold','preset','system')),
    updated_at timestamptz not null default now()
);

create table if not exists public.pause_nudge_events (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    device_id uuid,
    category text not null check (category in ('social','creative','entertainment','other')),
    occurred_at timestamptz not null default now(),
    delivery text not null default 'recorded'
        check (delivery in ('recorded','sent','delivered','failed')),
    constraint pause_event_device foreign key (user_id, device_id)
        references public.pause_devices(user_id, id) on delete set null (device_id)
);

create index if not exists pause_usage_by_day
    on public.pause_usage_daily(user_id, day desc);
create index if not exists pause_events_by_date
    on public.pause_nudge_events(user_id, occurred_at desc);

-- Last-write time is server assigned so clients cannot forge board freshness.
create or replace function public.pause_touch_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists pause_board_touch on public.pause_board_state;
create trigger pause_board_touch before insert or update
    on public.pause_board_state for each row
    execute function public.pause_touch_updated_at();

drop trigger if exists pause_usage_touch on public.pause_usage_daily;
create trigger pause_usage_touch before insert or update
    on public.pause_usage_daily for each row
    execute function public.pause_touch_updated_at();

-- No anonymous client can access these records, even if project API defaults change.
revoke all on public.pause_devices, public.pause_usage_daily,
    public.pause_board_state, public.pause_nudge_events from anon, authenticated;
grant select, insert, update, delete
    on public.pause_devices, public.pause_usage_daily,
       public.pause_board_state, public.pause_nudge_events
    to authenticated;

alter table public.pause_devices enable row level security;
alter table public.pause_usage_daily enable row level security;
alter table public.pause_board_state enable row level security;
alter table public.pause_nudge_events enable row level security;

-- One person's JWT can access only rows owned by that exact user.
-- All update policies include WITH CHECK so ownership cannot be reassigned.
drop policy if exists "pause devices select" on public.pause_devices;
create policy "pause devices select" on public.pause_devices
    for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "pause devices insert" on public.pause_devices;
create policy "pause devices insert" on public.pause_devices
    for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "pause devices update" on public.pause_devices;
create policy "pause devices update" on public.pause_devices
    for update to authenticated
    using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id);
drop policy if exists "pause devices delete" on public.pause_devices;
create policy "pause devices delete" on public.pause_devices
    for delete to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "pause usage select" on public.pause_usage_daily;
create policy "pause usage select" on public.pause_usage_daily
    for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "pause usage insert" on public.pause_usage_daily;
create policy "pause usage insert" on public.pause_usage_daily
    for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "pause usage update" on public.pause_usage_daily;
create policy "pause usage update" on public.pause_usage_daily
    for update to authenticated
    using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id);
drop policy if exists "pause usage delete" on public.pause_usage_daily;
create policy "pause usage delete" on public.pause_usage_daily
    for delete to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "pause board select" on public.pause_board_state;
create policy "pause board select" on public.pause_board_state
    for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "pause board insert" on public.pause_board_state;
create policy "pause board insert" on public.pause_board_state
    for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "pause board update" on public.pause_board_state;
create policy "pause board update" on public.pause_board_state
    for update to authenticated
    using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id);
drop policy if exists "pause board delete" on public.pause_board_state;
create policy "pause board delete" on public.pause_board_state
    for delete to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "pause events select" on public.pause_nudge_events;
create policy "pause events select" on public.pause_nudge_events
    for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "pause events insert" on public.pause_nudge_events;
create policy "pause events insert" on public.pause_nudge_events
    for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "pause events update" on public.pause_nudge_events;
create policy "pause events update" on public.pause_nudge_events
    for update to authenticated
    using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id);
drop policy if exists "pause events delete" on public.pause_nudge_events;
create policy "pause events delete" on public.pause_nudge_events
    for delete to authenticated using ((select auth.uid()) = user_id);

-- The trigger needs no elevated privileges and is not a public RPC.
revoke all on function public.pause_touch_updated_at() from public, anon, authenticated;

commit;
