-- KMO HR V2 foundation
-- Project: kmo-hr (ybyseaenceyswjnwdmdf)
-- Date: 2026-10-06
-- Security model:
--   * no anonymous HR access
--   * Supabase Auth identity separated from employee records
--   * ADMIN is not an employee record
--   * legal-minimum policy rows cannot be changed by normal ADMIN writes
--   * material changes are audit logged
-- Tables stay in public with hr_ prefix so the current Data API works
-- without requiring a Dashboard exposed-schema change.

create schema if not exists kmo_hr_private;
revoke all on schema kmo_hr_private from public, anon;
grant usage on schema kmo_hr_private to authenticated, service_role;

create table public.hr_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.hr_employees (
  id uuid primary key default gen_random_uuid(),
  employee_code text unique,
  full_name text not null,
  phone text unique,
  start_date date not null,
  employment_status text not null default 'active'
    check (employment_status in ('active','inactive','terminated')),
  probation_end_date date,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.hr_employee_accounts (
  employee_id uuid primary key references public.hr_employees(id) on delete cascade,
  user_id uuid not null unique references auth.users(id) on delete cascade,
  active boolean not null default true,
  linked_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.hr_employee_identities (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.hr_employees(id) on delete cascade,
  provider text not null,
  provider_subject text not null,
  active boolean not null default true,
  linked_at timestamptz not null default now(),
  unique(provider, provider_subject)
);

create table public.hr_schedule_config (
  singleton boolean primary key default true check (singleton),
  timezone text not null default 'Asia/Bangkok',
  work_start time not null default '09:00',
  work_end time not null default '18:00',
  break_minutes integer not null default 60 check (break_minutes >= 0),
  grace_minutes integer not null default 30 check (grace_minutes >= 0),
  weekly_holiday_dow integer not null default 2 check (weekly_holiday_dow between 0 and 6),
  legal_hold boolean not null default true,
  legal_hold_note text,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

insert into public.hr_schedule_config (
  singleton, timezone, work_start, work_end, break_minutes,
  grace_minutes, weekly_holiday_dow, legal_hold, legal_hold_note
) values (
  true, 'Asia/Bangkok', '09:00', '18:00', 60,
  30, 2, true,
  'Owner operational draft. Hazardous welding-work normal hours require legal resolution before final publication/enforcement.'
) on conflict (singleton) do nothing;

create table public.hr_worksites (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  radius_m integer not null default 150 check (radius_m between 20 and 2000),
  max_accuracy_m integer not null default 100 check (max_accuracy_m between 10 and 1000),
  active boolean not null default true,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.hr_policy_versions (
  id uuid primary key default gen_random_uuid(),
  policy_code text not null,
  version integer not null check (version > 0),
  policy_class text not null check (policy_class in ('legal_minimum','kmo_extra')),
  title text not null,
  status text not null default 'draft' check (status in ('draft','published','retired')),
  effective_date date,
  canonical_path text,
  document_sha256 text,
  body jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now(),
  unique(policy_code, version)
);

create table public.hr_leave_requests (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.hr_employees(id),
  leave_type text not null,
  start_date date not null,
  end_date date not null,
  requested_days numeric(6,2),
  reason text,
  evidence_path text,
  status text not null default 'pending'
    check (status in ('pending','approved','rejected','cancelled')),
  legal_policy_version_id uuid references public.hr_policy_versions(id),
  submitted_at timestamptz not null default now(),
  decided_by uuid references auth.users(id),
  decided_at timestamptz,
  decision_note text,
  updated_at timestamptz not null default now(),
  check (end_date >= start_date)
);

create table public.hr_attendance_events (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.hr_employees(id),
  event_type text not null check (event_type in ('clock_in','clock_out')),
  occurred_at timestamptz not null default now(),
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  accuracy_m numeric(8,2) not null check (accuracy_m >= 0),
  worksite_id uuid references public.hr_worksites(id),
  distance_m numeric(10,2),
  geofence_ok boolean not null default false,
  source text not null default 'web',
  created_at timestamptz not null default now()
);

create index hr_attendance_events_employee_time_idx
  on public.hr_attendance_events(employee_id, occurred_at desc);

create table public.hr_attendance_adjustments (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.hr_employees(id),
  attendance_date date not null,
  correction_type text not null
    check (correction_type in ('missing_in','missing_out','wrong_time','other')),
  requested_time timestamptz,
  reason text not null,
  status text not null default 'pending'
    check (status in ('pending','approved','rejected')),
  submitted_at timestamptz not null default now(),
  decided_by uuid references auth.users(id),
  decided_at timestamptz,
  decision_note text,
  updated_at timestamptz not null default now()
);

create table public.hr_incidents (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid references public.hr_employees(id),
  incident_at timestamptz not null,
  category text not null,
  factual_description text not null,
  finding text,
  corrective_action text,
  status text not null default 'open' check (status in ('open','closed')),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  closed_by uuid references auth.users(id),
  closed_at timestamptz,
  updated_at timestamptz not null default now()
);

create table public.hr_incident_statements (
  id uuid primary key default gen_random_uuid(),
  incident_id uuid not null references public.hr_incidents(id) on delete cascade,
  employee_id uuid not null references public.hr_employees(id),
  statement text not null,
  submitted_at timestamptz not null default now()
);

create table public.hr_warnings (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.hr_employees(id),
  incident_id uuid references public.hr_incidents(id),
  warning_type text not null default 'written',
  factual_conduct text not null,
  expected_correction text,
  issued_by uuid not null references auth.users(id),
  issued_at timestamptz not null default now(),
  acknowledged_at timestamptz,
  acknowledgement_note text,
  created_at timestamptz not null default now()
);

create table public.hr_safety_training (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.hr_employees(id),
  topic text not null,
  training_date date not null,
  trainer_provider text,
  method text,
  evidence_path text,
  result text,
  refresh_date date,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table public.hr_safety_incidents (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid references public.hr_employees(id),
  occurred_at timestamptz not null,
  task text,
  location text,
  description text not null,
  injury_first_aid text,
  ppe_in_use text,
  equipment_involved text,
  evidence_path text,
  immediate_action text,
  cause_review text,
  corrective_action text,
  status text not null default 'open' check (status in ('open','closed')),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  closed_by uuid references auth.users(id),
  closed_at timestamptz,
  updated_at timestamptz not null default now()
);

create table public.hr_policy_acknowledgements (
  id uuid primary key default gen_random_uuid(),
  policy_version_id uuid not null references public.hr_policy_versions(id),
  employee_id uuid not null references public.hr_employees(id),
  acknowledged_at timestamptz not null default now(),
  acknowledgement_method text not null default 'web',
  unique(policy_version_id, employee_id)
);

create table public.hr_audit_events (
  id bigint generated always as identity primary key,
  occurred_at timestamptz not null default now(),
  actor_user_id uuid,
  actor_kind text not null default 'system',
  table_name text not null,
  record_id text,
  action text not null,
  before_row jsonb,
  after_row jsonb
);

create or replace function kmo_hr_private.is_admin(p_uid uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.hr_admins a
    where a.user_id = p_uid and a.active = true
  );
$$;

create or replace function kmo_hr_private.current_employee_id(p_uid uuid default auth.uid())
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select ea.employee_id
  from public.hr_employee_accounts ea
  join public.hr_employees e on e.id = ea.employee_id
  where ea.user_id = p_uid
    and ea.active = true
    and e.active = true
  limit 1;
$$;

revoke all on function kmo_hr_private.is_admin(uuid) from public, anon;
revoke all on function kmo_hr_private.current_employee_id(uuid) from public, anon;
grant execute on function kmo_hr_private.is_admin(uuid) to authenticated, service_role;
grant execute on function kmo_hr_private.current_employee_id(uuid) to authenticated, service_role;

create or replace function kmo_hr_private.touch_updated_at()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create or replace function kmo_hr_private.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_id text;
begin
  if tg_op = 'DELETE' then
    v_id := coalesce(to_jsonb(old)->>'id', to_jsonb(old)->>'user_id', to_jsonb(old)->>'singleton');
  else
    v_id := coalesce(to_jsonb(new)->>'id', to_jsonb(new)->>'user_id', to_jsonb(new)->>'singleton');
  end if;

  insert into public.hr_audit_events(
    actor_user_id, actor_kind, table_name, record_id, action, before_row, after_row
  ) values (
    v_actor,
    case when v_actor is null then 'system'
         when kmo_hr_private.is_admin(v_actor) then 'admin'
         else 'employee' end,
    tg_table_name,
    v_id,
    tg_op,
    case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) end,
    case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) end
  );

  return coalesce(new, old);
end;
$$;

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
  if not kmo_hr_private.is_admin(auth.uid()) then
    v_employee := kmo_hr_private.current_employee_id(auth.uid());
    if v_employee is null then
      raise exception 'No active employee account is linked to this user';
    end if;
    new.employee_id := v_employee;
    new.occurred_at := now();
  elsif new.employee_id is null then
    raise exception 'employee_id is required for admin-created attendance event';
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

create trigger hr_admins_touch before update on public.hr_admins
for each row execute function kmo_hr_private.touch_updated_at();
create trigger hr_employees_touch before update on public.hr_employees
for each row execute function kmo_hr_private.touch_updated_at();
create trigger hr_employee_accounts_touch before update on public.hr_employee_accounts
for each row execute function kmo_hr_private.touch_updated_at();
create trigger hr_schedule_config_touch before update on public.hr_schedule_config
for each row execute function kmo_hr_private.touch_updated_at();
create trigger hr_worksites_touch before update on public.hr_worksites
for each row execute function kmo_hr_private.touch_updated_at();
create trigger hr_policy_versions_touch before update on public.hr_policy_versions
for each row execute function kmo_hr_private.touch_updated_at();
create trigger hr_leave_requests_touch before update on public.hr_leave_requests
for each row execute function kmo_hr_private.touch_updated_at();
create trigger hr_attendance_adjustments_touch before update on public.hr_attendance_adjustments
for each row execute function kmo_hr_private.touch_updated_at();
create trigger hr_incidents_touch before update on public.hr_incidents
for each row execute function kmo_hr_private.touch_updated_at();
create trigger hr_safety_incidents_touch before update on public.hr_safety_incidents
for each row execute function kmo_hr_private.touch_updated_at();

create trigger hr_attendance_prepare before insert on public.hr_attendance_events
for each row execute function kmo_hr_private.prepare_attendance_event();

create trigger hr_admins_audit after insert or update or delete on public.hr_admins
for each row execute function kmo_hr_private.audit_row_change();
create trigger hr_employees_audit after insert or update or delete on public.hr_employees
for each row execute function kmo_hr_private.audit_row_change();
create trigger hr_employee_accounts_audit after insert or update or delete on public.hr_employee_accounts
for each row execute function kmo_hr_private.audit_row_change();
create trigger hr_schedule_config_audit after update on public.hr_schedule_config
for each row execute function kmo_hr_private.audit_row_change();
create trigger hr_worksites_audit after insert or update or delete on public.hr_worksites
for each row execute function kmo_hr_private.audit_row_change();
create trigger hr_policy_versions_audit after insert or update or delete on public.hr_policy_versions
for each row execute function kmo_hr_private.audit_row_change();
create trigger hr_leave_requests_audit after insert or update or delete on public.hr_leave_requests
for each row execute function kmo_hr_private.audit_row_change();
create trigger hr_attendance_adjustments_audit after insert or update or delete on public.hr_attendance_adjustments
for each row execute function kmo_hr_private.audit_row_change();
create trigger hr_incidents_audit after insert or update or delete on public.hr_incidents
for each row execute function kmo_hr_private.audit_row_change();
create trigger hr_warnings_audit after insert or update or delete on public.hr_warnings
for each row execute function kmo_hr_private.audit_row_change();
create trigger hr_safety_training_audit after insert or update or delete on public.hr_safety_training
for each row execute function kmo_hr_private.audit_row_change();
create trigger hr_safety_incidents_audit after insert or update or delete on public.hr_safety_incidents
for each row execute function kmo_hr_private.audit_row_change();

alter table public.hr_admins enable row level security;
alter table public.hr_employees enable row level security;
alter table public.hr_employee_accounts enable row level security;
alter table public.hr_employee_identities enable row level security;
alter table public.hr_schedule_config enable row level security;
alter table public.hr_worksites enable row level security;
alter table public.hr_policy_versions enable row level security;
alter table public.hr_leave_requests enable row level security;
alter table public.hr_attendance_events enable row level security;
alter table public.hr_attendance_adjustments enable row level security;
alter table public.hr_incidents enable row level security;
alter table public.hr_incident_statements enable row level security;
alter table public.hr_warnings enable row level security;
alter table public.hr_safety_training enable row level security;
alter table public.hr_safety_incidents enable row level security;
alter table public.hr_policy_acknowledgements enable row level security;
alter table public.hr_audit_events enable row level security;

revoke all on table
  public.hr_admins,
  public.hr_employees,
  public.hr_employee_accounts,
  public.hr_employee_identities,
  public.hr_schedule_config,
  public.hr_worksites,
  public.hr_policy_versions,
  public.hr_leave_requests,
  public.hr_attendance_events,
  public.hr_attendance_adjustments,
  public.hr_incidents,
  public.hr_incident_statements,
  public.hr_warnings,
  public.hr_safety_training,
  public.hr_safety_incidents,
  public.hr_policy_acknowledgements,
  public.hr_audit_events
from anon;

grant select on public.hr_admins to authenticated;
grant select on public.hr_employees to authenticated;
grant select on public.hr_employee_accounts to authenticated;
grant select on public.hr_employee_identities to authenticated;
grant select on public.hr_schedule_config to authenticated;
grant select on public.hr_worksites to authenticated;
grant select on public.hr_policy_versions to authenticated;
grant select, insert, update on public.hr_leave_requests to authenticated;
grant select, insert on public.hr_attendance_events to authenticated;
grant select, insert, update on public.hr_attendance_adjustments to authenticated;
grant select, insert, update on public.hr_incidents to authenticated;
grant select, insert on public.hr_incident_statements to authenticated;
grant select, insert, update on public.hr_warnings to authenticated;
grant select, insert, update on public.hr_safety_training to authenticated;
grant select, insert, update on public.hr_safety_incidents to authenticated;
grant select, insert on public.hr_policy_acknowledgements to authenticated;
grant select on public.hr_audit_events to authenticated;

grant insert, update, delete on public.hr_admins to authenticated;
grant insert, update on public.hr_employees to authenticated;
grant insert, update, delete on public.hr_employee_accounts to authenticated;
grant insert, update, delete on public.hr_employee_identities to authenticated;
grant update on public.hr_schedule_config to authenticated;
grant insert, update, delete on public.hr_worksites to authenticated;
grant insert, update on public.hr_policy_versions to authenticated;

grant usage, select on sequence public.hr_audit_events_id_seq to service_role;

create policy hr_admins_select
on public.hr_admins for select to authenticated
using (user_id = (select auth.uid()) or kmo_hr_private.is_admin((select auth.uid())));

create policy hr_admins_admin_write
on public.hr_admins for all to authenticated
using (kmo_hr_private.is_admin((select auth.uid())))
with check (kmo_hr_private.is_admin((select auth.uid())));

create policy hr_employees_select
on public.hr_employees for select to authenticated
using (
  id = kmo_hr_private.current_employee_id((select auth.uid()))
  or kmo_hr_private.is_admin((select auth.uid()))
);

create policy hr_employees_admin_write
on public.hr_employees for insert to authenticated
with check (kmo_hr_private.is_admin((select auth.uid())));

create policy hr_employees_admin_update
on public.hr_employees for update to authenticated
using (kmo_hr_private.is_admin((select auth.uid())))
with check (kmo_hr_private.is_admin((select auth.uid())));

create policy hr_employee_accounts_select
on public.hr_employee_accounts for select to authenticated
using (
  user_id = (select auth.uid())
  or kmo_hr_private.is_admin((select auth.uid()))
);

create policy hr_employee_accounts_admin_write
on public.hr_employee_accounts for all to authenticated
using (kmo_hr_private.is_admin((select auth.uid())))
with check (kmo_hr_private.is_admin((select auth.uid())));

create policy hr_employee_identities_admin
on public.hr_employee_identities for all to authenticated
using (kmo_hr_private.is_admin((select auth.uid())))
with check (kmo_hr_private.is_admin((select auth.uid())));

create policy hr_schedule_select
on public.hr_schedule_config for select to authenticated
using (
  kmo_hr_private.is_admin((select auth.uid()))
  or kmo_hr_private.current_employee_id((select auth.uid())) is not null
);

create policy hr_schedule_admin_update
on public.hr_schedule_config for update to authenticated
using (kmo_hr_private.is_admin((select auth.uid())))
with check (kmo_hr_private.is_admin((select auth.uid())));

create policy hr_worksites_admin
on public.hr_worksites for all to authenticated
using (kmo_hr_private.is_admin((select auth.uid())))
with check (kmo_hr_private.is_admin((select auth.uid())));

create policy hr_policy_versions_select
on public.hr_policy_versions for select to authenticated
using (
  (status = 'published' and kmo_hr_private.current_employee_id((select auth.uid())) is not null)
  or kmo_hr_private.is_admin((select auth.uid()))
);

create policy hr_policy_versions_admin_insert_kmo_extra
on public.hr_policy_versions for insert to authenticated
with check (
  kmo_hr_private.is_admin((select auth.uid()))
  and policy_class = 'kmo_extra'
);

create policy hr_policy_versions_admin_update_kmo_extra
on public.hr_policy_versions for update to authenticated
using (
  kmo_hr_private.is_admin((select auth.uid()))
  and policy_class = 'kmo_extra'
)
with check (
  kmo_hr_private.is_admin((select auth.uid()))
  and policy_class = 'kmo_extra'
);

create policy hr_leave_select
on public.hr_leave_requests for select to authenticated
using (
  employee_id = kmo_hr_private.current_employee_id((select auth.uid()))
  or kmo_hr_private.is_admin((select auth.uid()))
);

create policy hr_leave_employee_insert
on public.hr_leave_requests for insert to authenticated
with check (
  employee_id = kmo_hr_private.current_employee_id((select auth.uid()))
  and status = 'pending'
  and decided_by is null
  and decided_at is null
);

create policy hr_leave_admin_update
on public.hr_leave_requests for update to authenticated
using (kmo_hr_private.is_admin((select auth.uid())))
with check (kmo_hr_private.is_admin((select auth.uid())));

create policy hr_attendance_select
on public.hr_attendance_events for select to authenticated
using (
  employee_id = kmo_hr_private.current_employee_id((select auth.uid()))
  or kmo_hr_private.is_admin((select auth.uid()))
);

create policy hr_attendance_insert
on public.hr_attendance_events for insert to authenticated
with check (
  employee_id = kmo_hr_private.current_employee_id((select auth.uid()))
  or kmo_hr_private.is_admin((select auth.uid()))
);

create policy hr_adjustments_select
on public.hr_attendance_adjustments for select to authenticated
using (
  employee_id = kmo_hr_private.current_employee_id((select auth.uid()))
  or kmo_hr_private.is_admin((select auth.uid()))
);

create policy hr_adjustments_employee_insert
on public.hr_attendance_adjustments for insert to authenticated
with check (
  employee_id = kmo_hr_private.current_employee_id((select auth.uid()))
  and status = 'pending'
);

create policy hr_adjustments_admin_update
on public.hr_attendance_adjustments for update to authenticated
using (kmo_hr_private.is_admin((select auth.uid())))
with check (kmo_hr_private.is_admin((select auth.uid())));

create policy hr_incidents_select
on public.hr_incidents for select to authenticated
using (
  employee_id = kmo_hr_private.current_employee_id((select auth.uid()))
  or kmo_hr_private.is_admin((select auth.uid()))
);

create policy hr_incidents_admin_write
on public.hr_incidents for all to authenticated
using (kmo_hr_private.is_admin((select auth.uid())))
with check (kmo_hr_private.is_admin((select auth.uid())));

create policy hr_incident_statements_select
on public.hr_incident_statements for select to authenticated
using (
  employee_id = kmo_hr_private.current_employee_id((select auth.uid()))
  or kmo_hr_private.is_admin((select auth.uid()))
);

create policy hr_incident_statements_employee_insert
on public.hr_incident_statements for insert to authenticated
with check (
  employee_id = kmo_hr_private.current_employee_id((select auth.uid()))
);

create policy hr_warnings_select
on public.hr_warnings for select to authenticated
using (
  employee_id = kmo_hr_private.current_employee_id((select auth.uid()))
  or kmo_hr_private.is_admin((select auth.uid()))
);

create policy hr_warnings_admin_write
on public.hr_warnings for all to authenticated
using (kmo_hr_private.is_admin((select auth.uid())))
with check (kmo_hr_private.is_admin((select auth.uid())));

create policy hr_safety_training_select
on public.hr_safety_training for select to authenticated
using (
  employee_id = kmo_hr_private.current_employee_id((select auth.uid()))
  or kmo_hr_private.is_admin((select auth.uid()))
);

create policy hr_safety_training_admin_write
on public.hr_safety_training for all to authenticated
using (kmo_hr_private.is_admin((select auth.uid())))
with check (kmo_hr_private.is_admin((select auth.uid())));

create policy hr_safety_incidents_select
on public.hr_safety_incidents for select to authenticated
using (
  employee_id = kmo_hr_private.current_employee_id((select auth.uid()))
  or kmo_hr_private.is_admin((select auth.uid()))
);

create policy hr_safety_incidents_insert
on public.hr_safety_incidents for insert to authenticated
with check (
  employee_id = kmo_hr_private.current_employee_id((select auth.uid()))
  or kmo_hr_private.is_admin((select auth.uid()))
);

create policy hr_safety_incidents_admin_update
on public.hr_safety_incidents for update to authenticated
using (kmo_hr_private.is_admin((select auth.uid())))
with check (kmo_hr_private.is_admin((select auth.uid())));

create policy hr_ack_select
on public.hr_policy_acknowledgements for select to authenticated
using (
  employee_id = kmo_hr_private.current_employee_id((select auth.uid()))
  or kmo_hr_private.is_admin((select auth.uid()))
);

create policy hr_ack_employee_insert
on public.hr_policy_acknowledgements for insert to authenticated
with check (
  employee_id = kmo_hr_private.current_employee_id((select auth.uid()))
);

create policy hr_audit_admin_select
on public.hr_audit_events for select to authenticated
using (kmo_hr_private.is_admin((select auth.uid())));

-- New HR objects are intentionally not writable/readable by anon.
-- Authenticated access is still restricted by the RLS policies above.
