-- Phase: HR V2 LINE employee portal + attendance bridge
-- Date: 2026-10-06
-- Purpose:
--   * verified LINE identities can request HR linking without Supabase Auth
--   * ADMIN approves LINE -> employee mapping
--   * service-role Edge Function records attendance atomically
--   * attendance timestamps remain server-controlled and geofence-validated

create table if not exists public.hr_line_link_requests (
  id uuid primary key default gen_random_uuid(),
  provider_subject text not null unique,
  display_name text,
  status text not null default 'pending'
    check (status in ('pending','linked','rejected')),
  employee_id uuid references public.hr_employees(id) on delete set null,
  requested_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  decided_by uuid references auth.users(id),
  decided_at timestamptz
);

alter table public.hr_line_link_requests enable row level security;

revoke all on table public.hr_line_link_requests from anon;
revoke all on table public.hr_line_link_requests from authenticated;
grant select, update on table public.hr_line_link_requests to authenticated;
grant all on table public.hr_line_link_requests to service_role;

drop policy if exists hr_line_link_requests_admin_select on public.hr_line_link_requests;
create policy hr_line_link_requests_admin_select
on public.hr_line_link_requests for select to authenticated
using (kmo_hr_private.is_admin((select auth.uid())));

drop policy if exists hr_line_link_requests_admin_update on public.hr_line_link_requests;
create policy hr_line_link_requests_admin_update
on public.hr_line_link_requests for update to authenticated
using (kmo_hr_private.is_admin((select auth.uid())))
with check (kmo_hr_private.is_admin((select auth.uid())));

create unique index if not exists hr_employee_one_active_line_identity_idx
on public.hr_employee_identities(employee_id)
where provider = 'line' and active = true;

drop trigger if exists hr_employee_identities_audit on public.hr_employee_identities;
create trigger hr_employee_identities_audit
after insert or update or delete on public.hr_employee_identities
for each row execute function kmo_hr_private.audit_row_change();

create or replace function public.hr_link_line_identity(
  p_request_id uuid,
  p_employee_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, kmo_hr_private, pg_temp
as $$
declare
  v_request public.hr_line_link_requests%rowtype;
  v_existing public.hr_employee_identities%rowtype;
begin
  if not kmo_hr_private.is_admin(auth.uid()) then
    raise exception 'ADMIN permission required';
  end if;

  select * into v_request
  from public.hr_line_link_requests
  where id = p_request_id
  for update;

  if v_request.id is null then
    raise exception 'LINE link request not found';
  end if;

  if v_request.status <> 'pending' then
    raise exception 'LINE link request is not pending';
  end if;

  if not exists (
    select 1 from public.hr_employees e
    where e.id = p_employee_id and e.active = true
  ) then
    raise exception 'Active employee not found';
  end if;

  select * into v_existing
  from public.hr_employee_identities
  where provider = 'line'
    and provider_subject = v_request.provider_subject
  limit 1;

  if v_existing.id is not null and v_existing.employee_id <> p_employee_id then
    raise exception 'This LINE account is already linked to another employee';
  end if;

  if exists (
    select 1
    from public.hr_employee_identities i
    where i.employee_id = p_employee_id
      and i.provider = 'line'
      and i.active = true
      and i.provider_subject <> v_request.provider_subject
  ) then
    raise exception 'This employee already has an active LINE identity';
  end if;

  insert into public.hr_employee_identities(
    employee_id, provider, provider_subject, active
  ) values (
    p_employee_id, 'line', v_request.provider_subject, true
  )
  on conflict (provider, provider_subject)
  do update set
    employee_id = excluded.employee_id,
    active = true;

  update public.hr_line_link_requests
  set status = 'linked',
      employee_id = p_employee_id,
      decided_by = auth.uid(),
      decided_at = now(),
      last_seen_at = now()
  where id = p_request_id;
end;
$$;

revoke all on function public.hr_link_line_identity(uuid, uuid) from public, anon;
grant execute on function public.hr_link_line_identity(uuid, uuid) to authenticated, service_role;

create or replace function kmo_hr_private.prepare_attendance_event()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_employee uuid;
  v_site public.hr_worksites%rowtype;
  v_distance double precision;
begin
  if auth.role() = 'service_role' then
    if new.employee_id is null then
      raise exception 'employee_id is required for service-created attendance event';
    end if;
    new.occurred_at := now();
  elsif not kmo_hr_private.is_admin(auth.uid()) then
    v_employee := kmo_hr_private.current_employee_id(auth.uid());
    if v_employee is null then
      raise exception 'No active employee account is linked to this user';
    end if;
    new.employee_id := v_employee;
    new.occurred_at := now();
  elsif new.employee_id is null then
    raise exception 'employee_id is required for admin-created attendance event';
  end if;

  if not exists (
    select 1 from public.hr_employees e
    where e.id = new.employee_id and e.active = true
  ) then
    raise exception 'Active employee not found';
  end if;

  select * into v_site
  from public.hr_worksites
  where active = true
  order by created_at asc
  limit 1;

  if v_site.id is null then
    raise exception 'KMO worksite geofence is not configured';
  end if;

  if new.accuracy_m > v_site.max_accuracy_m then
    raise exception 'Location accuracy is outside the allowed limit';
  end if;

  v_distance := 6371000 * 2 * asin(
    sqrt(
      power(sin(radians(new.latitude - v_site.latitude) / 2), 2) +
      cos(radians(v_site.latitude)) * cos(radians(new.latitude)) *
      power(sin(radians(new.longitude - v_site.longitude) / 2), 2)
    )
  );

  if v_distance > v_site.radius_m then
    raise exception 'Location is outside the KMO attendance geofence';
  end if;

  new.worksite_id := v_site.id;
  new.distance_m := round(v_distance::numeric, 2);
  new.geofence_ok := true;
  return new;
end;
$$;

create or replace function public.hr_record_line_attendance(
  p_employee_id uuid,
  p_event_type text,
  p_latitude double precision,
  p_longitude double precision,
  p_accuracy_m numeric
)
returns table (
  event_id uuid,
  event_type text,
  occurred_at timestamptz,
  distance_m numeric,
  attendance_status text,
  day_kind text
)
language plpgsql
security definer
set search_path = public, kmo_hr_private, pg_temp
as $$
declare
  v_schedule public.hr_schedule_config%rowtype;
  v_now timestamptz := now();
  v_day date;
  v_day_start timestamptz;
  v_day_end timestamptz;
  v_existing_in int;
  v_existing_out int;
  v_event public.hr_attendance_events%rowtype;
  v_local_time time;
  v_day_kind text;
  v_status text;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Service role required';
  end if;

  if p_event_type not in ('clock_in', 'clock_out') then
    raise exception 'Invalid attendance event type';
  end if;

  if p_latitude is null or p_longitude is null or p_accuracy_m is null then
    raise exception 'Location and accuracy are required';
  end if;

  if not exists (
    select 1 from public.hr_employees e
    where e.id = p_employee_id and e.active = true
  ) then
    raise exception 'Active employee not found';
  end if;

  select * into v_schedule
  from public.hr_schedule_config
  where singleton = true;

  if v_schedule.singleton is null then
    raise exception 'Schedule configuration not found';
  end if;

  v_day := (v_now at time zone v_schedule.timezone)::date;
  v_day_start := (v_day::timestamp at time zone v_schedule.timezone);
  v_day_end := ((v_day + 1)::timestamp at time zone v_schedule.timezone);

  perform pg_advisory_xact_lock(hashtextextended(p_employee_id::text || ':' || v_day::text, 0));

  select
    count(*) filter (where a.event_type = 'clock_in'),
    count(*) filter (where a.event_type = 'clock_out')
  into v_existing_in, v_existing_out
  from public.hr_attendance_events a
  where a.employee_id = p_employee_id
    and a.occurred_at >= v_day_start
    and a.occurred_at < v_day_end;

  if p_event_type = 'clock_in' then
    if v_existing_in > 0 or v_existing_out > 0 then
      raise exception 'Clock-in has already been recorded for today';
    end if;
  else
    if v_existing_in = 0 then
      raise exception 'Clock-in is required before clock-out';
    end if;
    if v_existing_out > 0 then
      raise exception 'Clock-out has already been recorded for today';
    end if;
  end if;

  insert into public.hr_attendance_events(
    employee_id, event_type, latitude, longitude, accuracy_m, source
  ) values (
    p_employee_id, p_event_type, p_latitude, p_longitude, p_accuracy_m, 'line_liff'
  )
  returning * into v_event;

  v_local_time := (v_event.occurred_at at time zone v_schedule.timezone)::time;
  v_day_kind := case
    when extract(dow from (v_event.occurred_at at time zone v_schedule.timezone))::int = v_schedule.weekly_holiday_dow
      then 'weekly_holiday'
    else 'regular'
  end;

  if p_event_type = 'clock_in' then
    if v_local_time <= v_schedule.work_start then
      v_status := 'on_time';
    elsif v_local_time <= (v_schedule.work_start + make_interval(mins => v_schedule.grace_minutes))::time then
      v_status := 'grace';
    else
      v_status := 'late';
    end if;
  else
    if v_local_time < v_schedule.work_end then
      v_status := 'early_leave';
    elsif v_local_time > v_schedule.work_end then
      v_status := 'after_hours_review';
    else
      v_status := 'clocked_out';
    end if;
  end if;

  return query
  select
    v_event.id,
    v_event.event_type,
    v_event.occurred_at,
    v_event.distance_m,
    v_status,
    v_day_kind;
end;
$$;

revoke all on function public.hr_record_line_attendance(uuid, text, double precision, double precision, numeric)
from public, anon, authenticated;
grant execute on function public.hr_record_line_attendance(uuid, text, double precision, double precision, numeric)
to service_role;

create index if not exists hr_line_link_requests_status_idx
on public.hr_line_link_requests(status, requested_at desc);
