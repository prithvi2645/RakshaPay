-- Live demo view for RakshaPay.
--
-- Run this once in the Supabase SQL Editor, after schema.sql.
-- Safe to re-run.
--
-- WHY A VIEW: `reports` and `risk_logs` are insert-only to clients — RLS gives
-- them no SELECT policy at all, and that stays true. This view is owned by
-- postgres, so it can count those tables and expose ONLY the totals. No VPA,
-- no device token, no score, no timestamp of any individual row ever leaves
-- the database. Counts reveal nothing about any person or any report.
--
-- Deliberately NOT exposed: which VPAs sit below the 3-device threshold.
-- Publishing that would let anyone watch what is being reported before the
-- community has confirmed it, which is exactly what the threshold protects
-- against.

create or replace view public.live_stats as
select
  (select count(*) from public.reports)                            as total_reports,
  (select count(distinct device_hash) from public.reports)         as reporting_devices,
  (select count(*) from public.scam_patterns)                      as patterns_tracked,
  (select count(*) from public.scam_patterns where active)         as patterns_active,
  (select count(*) from public.risk_logs)                          as payments_scored,
  (select count(*) from public.risk_logs where level = 'highRisk') as high_risk_blocked,
  (select count(*) from public.risk_logs where level = 'caution')  as caution_raised,
  (select count(*) from public.risk_logs where level = 'safe')     as scored_safe,
  now()                                                            as as_of;

grant select on public.live_stats to anon, authenticated;

-- The active shared patterns a device would sync. Already readable through the
-- scam_patterns RLS policy; this just gives the dashboard a tidy shape.
create or replace view public.active_patterns as
select vpa, report_count, reason_codes, first_reported_at, last_reported_at
from public.scam_patterns
where active
order by last_reported_at desc
limit 50;

grant select on public.active_patterns to anon, authenticated;
