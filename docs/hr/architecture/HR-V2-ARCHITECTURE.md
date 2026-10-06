# KMO HR V2 Architecture

Updated: 2026-10-06
Supabase project: `kmo-hr` (`ybyseaenceyswjnwdmdf`)

## Decision

Reuse the existing Supabase project, but isolate HR V2 with a strict `hr_` table prefix in `public`.

A custom exposed schema was considered. Supabase requires a Dashboard change to add custom schemas to Data API "Exposed schemas". To avoid a manual platform dependency during the initial build, HR V2 uses `public.hr_*` with:
- explicit anonymous privilege revocation;
- RLS on every HR table;
- authenticated-only grants;
- private helper functions in non-exposed schema `kmo_hr_private`;
- audit triggers for material changes.

This keeps `kmo_finance.*`, `wc_*`, links and catalog workloads untouched.

## Identity model

ADMIN and EMPLOYEE are separate principals.

- `hr_admins`: references `auth.users`; admins are not employee attendance/leave subjects.
- `hr_employees`: employment records only.
- `hr_employee_accounts`: optional Supabase Auth binding.
- `hr_employee_identities`: external identities such as LINE user IDs.

Confirmed target:
- ADMIN: 2 equal-permission users.
- EMPLOYEE: 5 technician employees.
- Current bootstrap: 1 confirmed ADMIN account bound by existing Supabase Auth email. Second ADMIN remains to be bound.

## Employee LINE path

Supabase Auth does not provide LINE as a hosted built-in OAuth provider. Employee LINE login will use LIFF + server-side LINE ID-token verification.

Do not trust a LINE user ID supplied directly by browser JavaScript.

Planned flow:
1. LIFF obtains an ID token.
2. HR Edge Function verifies the ID token with LINE using the LINE Login channel ID.
3. Verified LINE subject is matched to `hr_employee_identities`.
4. Edge Function performs the allowed employee action or returns an unlinked identity state.

A new HR LIFF app/endpoint should be created. Existing booking/order LIFF apps must not be repurposed.

## Admin auth

Admin uses Supabase Auth. RLS checks `hr_admins.user_id = auth.uid()`.

No phone-only login and no plaintext PIN authentication.

## Core tables

- hr_admins
- hr_employees
- hr_employee_accounts
- hr_employee_identities
- hr_schedule_config
- hr_worksites
- hr_policy_versions
- hr_leave_requests
- hr_attendance_events
- hr_attendance_adjustments
- hr_incidents
- hr_incident_statements
- hr_warnings
- hr_safety_training
- hr_safety_incidents
- hr_policy_acknowledgements
- hr_audit_events

## Attendance

Current operational draft:
- work start 09:00
- work end 18:00
- break 60 minutes total
- grace 30 minutes
- Tuesday weekly holiday
- legal_hold = true

Clock events require:
- authenticated/verified employee identity;
- latitude/longitude;
- device accuracy within configured limit;
- active KMO worksite geofence;
- server timestamp for normal employee clock events.

Worksite coordinates are not configured yet, so production clock-in remains intentionally blocked.

## Policy protection

`hr_policy_versions.policy_class`:
- `legal_minimum`: normal ADMIN cannot insert/update these rows.
- `kmo_extra`: ADMIN can version/manage these rows.

This prevents the UI from reducing statutory minimum policy through ordinary admin editing.

## Audit

Material tables write before/after JSON to `hr_audit_events`.
Audit data is ADMIN-readable only.

## Current holds

1. Hazardous welding-work normal-hours legal resolution.
2. Social Security current-status verification.
3. Second ADMIN identity binding.
4. Five employee records + LINE identity binding.
5. Worksite geofence coordinates.
6. New HR LIFF app ID / endpoint.
