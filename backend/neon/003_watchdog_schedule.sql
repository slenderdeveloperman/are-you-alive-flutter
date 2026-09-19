-- AYA 0.3 / FLD-AYA-01
-- Database-local watchdog scheduling and retention.
--
-- Neon supports pg_cron. This evaluator is intentionally database-local:
-- it can mark records overdue and enqueue a witness alert without depending
-- on the subject phone or an application server.
--
-- Outbound delivery remains a separate worker/provider concern. Do not
-- represent witness alerts as operational until that consumer is deployed.

create extension if not exists pg_cron;

-- Idempotent migration: remove an older copy of our named jobs if present.
do $$
declare
  v_job record;
begin
  for v_job in
    select jobid
    from cron.job
    where jobname in ('aya_watchdog_evaluator', 'aya_watchdog_retention')
  loop
    perform cron.unschedule(v_job.jobid);
  end loop;
end;
$$;

select cron.schedule(
  'aya_watchdog_evaluator',
  '*/15 * * * *',
  $$select public.evaluate_watchdogs();$$
);

-- Delivered alert envelopes are operational metadata, not a permanent archive.
-- Keep 30 days for delivery/debugging, then remove them.
select cron.schedule(
  'aya_watchdog_retention',
  '17 3 * * *',
  $$delete from public.witness_alert_outbox
    where delivered_at is not null
      and delivered_at < now() - interval '30 days';$$
);

-- Operational inspection:
-- select jobname, schedule, active from cron.job
-- where jobname like 'aya_watchdog_%';
--
-- select status, return_message, start_time, end_time
-- from cron.job_run_details
-- order by start_time desc
-- limit 20;
