-- RakshaPay — Supabase (Postgres) backend.
--
-- Report aggregation is an AFTER INSERT trigger that lives inside the database,
-- so there is no separate runtime to deploy or keep awake.
--
-- Run once: Supabase dashboard -> SQL Editor -> paste -> Run.
-- Safe to re-run; every statement is idempotent.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

-- Community scam-pattern database. Every device syncs the active rows to build
-- its local cache. Clients can only ever read this; all writes come from the
-- trigger below.
create table if not exists public.scam_patterns (
  vpa               text        primary key,
  reason_codes      text[]      not null default '{}',
  report_count      integer     not null default 0,
  active            boolean     not null default false,
  first_reported_at timestamptz not null default now(),
  last_reported_at  timestamptz not null default now()
);

create index if not exists scam_patterns_active_idx
  on public.scam_patterns (vpa) where active;

-- Anonymised scam reports. No account required (matches the privacy-first
-- design) — a per-install random token stands in for identity.
--
-- The UNIQUE (vpa, device_hash) constraint is what makes the 3-report
-- threshold mean three DISTINCT devices: the database physically refuses a
-- second report of the same VPA from the same install, so three taps from one
-- phone cannot flag a real merchant.
create table if not exists public.reports (
  id          bigint      generated always as identity primary key,
  vpa         text        not null,
  reason_code text        not null,
  device_hash text        not null,
  created_at  timestamptz not null default now(),
  constraint reports_vpa_len    check (char_length(vpa) between 1 and 100),
  constraint reports_reason_len check (char_length(reason_code) between 1 and 50),
  constraint reports_device_len check (char_length(device_hash) between 16 and 128),
  constraint reports_one_per_device unique (vpa, device_hash)
);

-- Anonymised risk-scoring telemetry: score and level only, never raw SMS, QR
-- or notification content. Used to watch model behaviour in aggregate.
--
-- level/source are deliberately NOT constrained to a value list: the client
-- swallows telemetry failures silently, so a stale CHECK would drop data with
-- no visible error. Length limits only.
create table if not exists public.risk_logs (
  id         bigint      generated always as identity primary key,
  level      text        not null,
  score      integer     not null check (score between 0 and 100),
  source     text        not null,
  created_at timestamptz not null default now(),
  constraint risk_logs_level_len  check (char_length(level) <= 20),
  constraint risk_logs_source_len check (char_length(source) <= 20)
);

create index if not exists risk_logs_created_at_idx
  on public.risk_logs (created_at desc);

-- ---------------------------------------------------------------------------
-- Aggregation trigger
-- ---------------------------------------------------------------------------

-- SECURITY DEFINER so it can write scam_patterns, which no client role may
-- touch. search_path is pinned so the elevated function can't be hijacked by a
-- caller-controlled search_path.
create or replace function public.aggregate_report()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  -- A VPA becomes an active shared pattern only after this many distinct
  -- devices report it, so one bad-faith reporter cannot flag a real merchant.
  c_threshold constant integer := 3;
  v_vpa       text := lower(btrim(new.vpa));
begin
  insert into public.scam_patterns as p
    (vpa, reason_codes, report_count, active, first_reported_at, last_reported_at)
  values
    (v_vpa, array[new.reason_code], 1, 1 >= c_threshold, now(), now())
  on conflict (vpa) do update
    set report_count     = p.report_count + 1,
        active           = (p.report_count + 1) >= c_threshold,
        reason_codes     = (
          select array_agg(distinct rc)
          from unnest(p.reason_codes || excluded.reason_codes) as rc
        ),
        last_reported_at = now();

  return new;
end;
$$;

drop trigger if exists on_report_created on public.reports;
create trigger on_report_created
  after insert on public.reports
  for each row execute function public.aggregate_report();

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.scam_patterns enable row level security;
alter table public.reports       enable row level security;
alter table public.risk_logs     enable row level security;

-- scam_patterns: world-readable, but only the active rows. No write policy
-- exists, so the app physically cannot author a pattern.
drop policy if exists scam_patterns_read_active on public.scam_patterns;
create policy scam_patterns_read_active
  on public.scam_patterns for select to anon, authenticated
  using (active = true);

-- reports: insert-only. No select policy, so reports are write-only from the
-- client and can never be read back, edited or deleted — same as before.
drop policy if exists reports_insert_anon on public.reports;
create policy reports_insert_anon
  on public.reports for insert to anon, authenticated
  with check (
        char_length(btrim(vpa))         between 1 and 100
    and char_length(btrim(reason_code)) between 1 and 50
    and char_length(device_hash)        between 16 and 128
  );

-- risk_logs: insert-only telemetry, same shape.
drop policy if exists risk_logs_insert_anon on public.risk_logs;
create policy risk_logs_insert_anon
  on public.risk_logs for insert to anon, authenticated
  with check (score between 0 and 100);

grant usage  on schema public       to anon, authenticated;
grant select on public.scam_patterns to anon, authenticated;
grant insert on public.reports       to anon, authenticated;
grant insert on public.risk_logs     to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Analytics
-- ---------------------------------------------------------------------------

create or replace view public.risk_summary as
select
  date_trunc('day', created_at)::date as day,
  source,
  level,
  count(*)                as events,
  round(avg(score))::int  as avg_score
from public.risk_logs
group by 1, 2, 3
order by 1 desc, 2, 3;

create or replace view public.top_reported_vpas as
select vpa, report_count, active, reason_codes, last_reported_at
from public.scam_patterns
order by report_count desc, last_reported_at desc
limit 50;

-- Dashboard/SQL-editor use only. Views run with the definer's rights, so
-- granting these to anon would hand the app a read path into risk_logs that
-- RLS otherwise denies.
revoke all on public.risk_summary      from anon, authenticated;
revoke all on public.top_reported_vpas from anon, authenticated;
