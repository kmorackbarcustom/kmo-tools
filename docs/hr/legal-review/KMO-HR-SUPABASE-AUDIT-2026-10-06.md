# KMO HR Supabase Audit — 2026-10-06

Project: `kmo-hr`
Project ref: `ybyseaenceyswjnwdmdf`
Region: Northeast Asia (Seoul)
Audit mode: READ-ONLY

## Executive decision

**DO NOT build HR V1 on top of the existing legacy HR tables as-is.**

The project can still be reused, but the legacy HR model/security must be isolated and remediated first. Safest low-cost path: keep existing catalog/finance workloads untouched, create a new versioned HR schema/model, migrate only verified data, then retire the legacy HR pages/tables after cutover.

## Current workloads in this project

This project is not HR-only anymore. It currently contains:
- legacy HR tables in `public`
- KMO finance schema `kmo_finance`
- WSTERA/KMO catalog tables with `wc_` prefix
- personal links table
- product/catalog storage buckets

Therefore destructive cleanup of the project could break unrelated live systems.

## Legacy HR data currently present

Actual counts:
- employees: 7
- leave_quota: 7
- leave_requests: 0
- bonus_settings: 1
- bonus_calculations: 7
- bonus_history: 0
- auth.users: 3
- medical-certs objects: 0

Legacy employee roles:
- owner: 4 active
- staff: 3 active
- no employee row is linked by id to an auth.users id
- no employee email matches an auth.users email

This conflicts with the new target:
- ADMIN: 2, equal system rights, not employee attendance/leave subjects
- EMPLOYEE: 5

## CRITICAL S-01 — employee PII + PIN exposed to anonymous users

`public.employees` has RLS enabled, but policy:
`Everyone can view basic employee info`
uses `USING (true)`.

Both `anon` and `authenticated` roles have SELECT privilege.

Verified as role `anon`:
- 7 employee rows visible
- 7 emails visible
- 7 phone numbers visible
- 4 PIN values visible

All 4 PINs are 4-digit numeric values stored as plain text.

This is an active privacy/security exposure while employee data exists.

## CRITICAL S-02 — legacy login is not real authentication

Production repo:
`D:\AI-Workspace\projects\kmorackbarcustom.github.io`

`hr-staff.html`:
- asks for phone only
- queries `employees?phone=...` using anon key
- uses returned employee row as the logged-in identity
- no Supabase Auth session

Anyone who knows/enumerates an employee phone can impersonate that employee.

`hr-admin.html`:
- asks phone + 4-digit PIN
- fetches the full employee row using anon key
- compares the plaintext PIN in browser JavaScript
- because the employee table itself is anonymously readable, this PIN check provides no real security

Do not reuse this login design.

## CRITICAL S-03 — bonus tables are public-write capable

Tables:
- `public.bonus_settings`
- `public.bonus_calculations`
- `public.bonus_history`

RLS is DISABLED on all three.

Both `anon` and `authenticated` currently have SELECT / INSERT / UPDATE / DELETE privileges.

Supabase security advisor reports ERROR:
- policy exists but RLS disabled
- RLS disabled in public schema

Existing policies are inert until RLS is enabled.

## CRITICAL S-04 — public executable bonus recalculation

Function:
`public.bonus_recalculate_all(integer)`

Executable by:
- anon: YES
- authenticated: YES

The function recalculates bonus records and contains automatic leave-occurrence penalties.

## POLICY P-01 — automatic leave penalty conflicts with new KMO policy

Existing trigger logic:
- vacation -> not counted
- sick + medical certificate -> not counted
- maternity/special -> not counted
- other leave, including sick without certificate and personal leave -> counted as occurrence

Automatic bonus penalty:
- 0–4 occurrences: 0%
- 5: 10%
- 6: 20%
- 7: 30%
- 8+: 40%

Penalty money is redistributed to employees with zero penalty.

This conflicts with the new rule that frequent sick leave is not automatically misconduct/punishment and with the decision not to create automatic wage/disciplinary penalties. Do not carry this mechanism into HR V1 without a separate lawful/owner-approved bonus policy review.

## POLICY P-02 — legacy leave quota does not match new legal baseline

All 7 current quota rows for 2026:
- vacation_days = 8
- personal_days = 5
- sick_days_no_cert = 2

The new KMO requirement is statutory minimum only unless KMO explicitly approves extra benefit.

The `sick_days_no_cert` concept must not be treated as a general cap on lawful sick leave.

Existing leave types:
- sick
- personal
- vacation
- maternity
- special

This model does not cover the full current statutory leave taxonomy required by the 2026 policy work.

## ARCH A-01 — auth identity model is broken for current RLS

Legacy RLS checks such as:
`auth.uid() = employee_id`
and
`employees.id = auth.uid()`

But none of the 7 employee ids match any of the 3 `auth.users` ids.

Therefore the legacy RLS authorization model is not aligned with actual Supabase Auth identities.

New V1 must separate:
- auth identity
- admin profile
- employee record
- role/membership

## PRIVACY D-01 — medical certificate storage is public

Bucket:
`medical-certs`

Current setting:
- public = true
- object count = 0

Medical certificates are sensitive employment/health evidence and must not use a public bucket in the new system.

A repo hardening SQL file exists, but current database storage policies do not show the old `anon can upload medical certs` policy. Regardless, the bucket being public is unacceptable for HR V1.

## MIGRATION M-01 — legacy HR schema is not reproducible

Remote migration history currently contains only later catalog/link migrations (Aug–Sep 2026). No migration for the legacy employee/leave/bonus schema is present.

The HR tables appear to be legacy/manual schema outside the tracked migration history.

New HR work must be migration-first.

## Other security findings

- Supabase leaked-password protection: disabled
- security/performance advisors report broad GraphQL discoverability and RLS-policy inefficiencies
- no live Edge Functions reported for this project at audit time

## Recommended architecture

Reuse the same Supabase project only to avoid new recurring cost, but do NOT mutate catalog/finance tables.

Create a clean HR V2 boundary, e.g.:

`kmo_hr.*`

Core model:
- admins
- employees
- employee_identities
- attendance_events
- attendance_adjustments
- leave_requests
- leave_entitlements / legal_policy_versions
- incidents
- warnings
- safety_training
- safety_incidents
- policy_acknowledgements
- audit_events

Rules:
- no plaintext PIN authentication
- no phone-only authentication
- no anonymous HR reads/writes
- employee/admin identity mapped to Supabase Auth or approved LINE identity flow
- admin and employee records are separate
- private storage for medical/sensitive evidence
- statutory minimum policy versioned and immutable downward
- all privileged changes audited
- no automatic leave-based bonus penalty
- migrations committed to repository before DB apply

## Gate

**REMEDIATE / STOP USING LEGACY HR SECURITY MODEL**

Before HR V1 implementation:
1. decide whether legacy `hr-admin.html` / `hr-staff.html` are still in use;
2. close anonymous employee/PIN exposure;
3. disable or secure legacy bonus tables/function;
4. make medical evidence storage private;
5. build HR V2 through migrations without touching `kmo_finance` or `wc_*` workloads.
