-- KMO HR V2 foundation hardening + bootstrap
-- Date: 2026-10-06

create index if not exists hr_employee_accounts_user_idx
  on public.hr_employee_accounts(user_id);
create index if not exists hr_employee_identities_employee_idx
  on public.hr_employee_identities(employee_id);
create index if not exists hr_leave_requests_employee_dates_idx
  on public.hr_leave_requests(employee_id, start_date desc, end_date);
create index if not exists hr_leave_requests_decided_by_idx
  on public.hr_leave_requests(decided_by);
create index if not exists hr_leave_requests_policy_idx
  on public.hr_leave_requests(legal_policy_version_id);
create index if not exists hr_attendance_events_worksite_idx
  on public.hr_attendance_events(worksite_id);
create index if not exists hr_attendance_adjustments_employee_date_idx
  on public.hr_attendance_adjustments(employee_id, attendance_date desc);
create index if not exists hr_attendance_adjustments_decided_by_idx
  on public.hr_attendance_adjustments(decided_by);
create index if not exists hr_incidents_employee_idx
  on public.hr_incidents(employee_id);
create index if not exists hr_incidents_created_by_idx
  on public.hr_incidents(created_by);
create index if not exists hr_incidents_closed_by_idx
  on public.hr_incidents(closed_by);
create index if not exists hr_incident_statements_incident_idx
  on public.hr_incident_statements(incident_id);
create index if not exists hr_incident_statements_employee_idx
  on public.hr_incident_statements(employee_id);
create index if not exists hr_warnings_employee_idx
  on public.hr_warnings(employee_id);
create index if not exists hr_warnings_incident_idx
  on public.hr_warnings(incident_id);
create index if not exists hr_warnings_issued_by_idx
  on public.hr_warnings(issued_by);
create index if not exists hr_safety_training_employee_idx
  on public.hr_safety_training(employee_id);
create index if not exists hr_safety_training_created_by_idx
  on public.hr_safety_training(created_by);
create index if not exists hr_safety_incidents_employee_idx
  on public.hr_safety_incidents(employee_id);
create index if not exists hr_safety_incidents_created_by_idx
  on public.hr_safety_incidents(created_by);
create index if not exists hr_safety_incidents_closed_by_idx
  on public.hr_safety_incidents(closed_by);
create index if not exists hr_policy_ack_employee_idx
  on public.hr_policy_acknowledgements(employee_id);
create index if not exists hr_policy_versions_created_by_idx
  on public.hr_policy_versions(created_by);
create index if not exists hr_policy_versions_updated_by_idx
  on public.hr_policy_versions(updated_by);
create index if not exists hr_worksites_created_by_idx
  on public.hr_worksites(created_by);
create unique index if not exists hr_one_active_worksite_idx
  on public.hr_worksites((active)) where active = true;

drop policy if exists hr_admins_admin_write on public.hr_admins;
create policy hr_admins_admin_insert
on public.hr_admins for insert to authenticated
with check (kmo_hr_private.is_admin((select auth.uid())));
create policy hr_admins_admin_update
on public.hr_admins for update to authenticated
using (kmo_hr_private.is_admin((select auth.uid())))
with check (kmo_hr_private.is_admin((select auth.uid())));
create policy hr_admins_admin_delete
on public.hr_admins for delete to authenticated
using (kmo_hr_private.is_admin((select auth.uid())));

drop policy if exists hr_employee_accounts_admin_write on public.hr_employee_accounts;
create policy hr_employee_accounts_admin_insert
on public.hr_employee_accounts for insert to authenticated
with check (kmo_hr_private.is_admin((select auth.uid())));
create policy hr_employee_accounts_admin_update
on public.hr_employee_accounts for update to authenticated
using (kmo_hr_private.is_admin((select auth.uid())))
with check (kmo_hr_private.is_admin((select auth.uid())));
create policy hr_employee_accounts_admin_delete
on public.hr_employee_accounts for delete to authenticated
using (kmo_hr_private.is_admin((select auth.uid())));

drop policy if exists hr_incidents_admin_write on public.hr_incidents;
create policy hr_incidents_admin_insert
on public.hr_incidents for insert to authenticated
with check (kmo_hr_private.is_admin((select auth.uid())));
create policy hr_incidents_admin_update
on public.hr_incidents for update to authenticated
using (kmo_hr_private.is_admin((select auth.uid())))
with check (kmo_hr_private.is_admin((select auth.uid())));
create policy hr_incidents_admin_delete
on public.hr_incidents for delete to authenticated
using (kmo_hr_private.is_admin((select auth.uid())));

drop policy if exists hr_warnings_admin_write on public.hr_warnings;
create policy hr_warnings_admin_insert
on public.hr_warnings for insert to authenticated
with check (kmo_hr_private.is_admin((select auth.uid())));
create policy hr_warnings_admin_update
on public.hr_warnings for update to authenticated
using (kmo_hr_private.is_admin((select auth.uid())))
with check (kmo_hr_private.is_admin((select auth.uid())));
create policy hr_warnings_admin_delete
on public.hr_warnings for delete to authenticated
using (kmo_hr_private.is_admin((select auth.uid())));

drop policy if exists hr_safety_training_admin_write on public.hr_safety_training;
create policy hr_safety_training_admin_insert
on public.hr_safety_training for insert to authenticated
with check (kmo_hr_private.is_admin((select auth.uid())));
create policy hr_safety_training_admin_update
on public.hr_safety_training for update to authenticated
using (kmo_hr_private.is_admin((select auth.uid())))
with check (kmo_hr_private.is_admin((select auth.uid())));
create policy hr_safety_training_admin_delete
on public.hr_safety_training for delete to authenticated
using (kmo_hr_private.is_admin((select auth.uid())));

create trigger hr_employee_identities_audit
after insert or update or delete on public.hr_employee_identities
for each row execute function kmo_hr_private.audit_row_change();

create trigger hr_incident_statements_audit
after insert or update or delete on public.hr_incident_statements
for each row execute function kmo_hr_private.audit_row_change();

create trigger hr_policy_ack_audit
after insert or update or delete on public.hr_policy_acknowledgements
for each row execute function kmo_hr_private.audit_row_change();

-- Bootstrap the currently confirmed system admin without hard-coding auth UUID.
insert into public.hr_admins(user_id, display_name, active)
select id, 'Wachiraya Jankhonkan', true
from auth.users
where lower(email) = lower('titazmth@gmail.com')
on conflict (user_id) do update
set display_name = excluded.display_name,
    active = true,
    updated_at = now();
