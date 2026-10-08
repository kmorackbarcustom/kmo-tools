# KMO HR — Attendance Direct INSERT Remediation

วันที่: 2026-10-08 (Asia/Bangkok)

## Scope and source

- Repository: `kmorackbarcustom/kmo-tools`
- PR #1 branch: `codex/hr-attendance-ux-hardening-20261007` → `main`
- Remediation is a new forward-only migration: `supabase/migrations/20261008053722_hr_attendance_service_role_only.sql`.
- Previously applied migrations remain unchanged.
- No Production database, attendance data, Edge Function, or deployment was changed.

## Finding and change

The foundation migration granted `INSERT` on `public.hr_attendance_events` to `authenticated` and created `hr_attendance_insert` (`20261006174000_hr_v2_foundation.sql:492,624-629`). This allowed a PostgREST caller to bypass the Edge Function's authoritative status check and the RPC transaction lock.

The new migration:

1. Revokes table `INSERT` from `anon`, `authenticated`, and `PUBLIC`.
2. Explicitly grants table `INSERT` to `service_role`.
3. Drops only `hr_attendance_insert`.
4. Leaves `hr_attendance_select`, RLS enablement, and `hr_record_line_attendance` unchanged.

The Edge Function continues to read `SUPABASE_SERVICE_ROLE_KEY` from its server environment and call `hr_record_line_attendance` (`supabase/functions/kmo-hr-line/index.ts:152-153,346`). The RPC still rejects non-service-role calls and checks the event sequence under `pg_advisory_xact_lock` (`20261006201500_hr_line_employee_portal.sql:229,260-284,327-330`).

## Isolated database security tests

`supabase/tests/hr_attendance_security.test.sql` is a pgTAP test file with synthetic users, employees, one test worksite, and transaction rollback. It covers:

- Effective INSERT privileges for `anon`, `authenticated`, `PUBLIC`, and `service_role`.
- Removal of the insert policy, continued RLS enablement, preserved SELECT policy, and RPC execute grants.
- Anonymous, employee, and Admin direct INSERT denial.
- Service-role RPC clock-in/out, duplicate clock-in/out denial, and clock-out-before-clock-in denial.
- Employee-only and Admin-allowed SELECT behavior.

I applied all current project HR migrations, including the new migration, to an ephemeral isolated PostgreSQL WASM database with synthetic `auth` roles/functions, then executed this test file using a minimal TAP-compatible harness. **22/22 assertions passed.** The test transaction rolled back. This did not connect to Production or write Production attendance.

The environment has Supabase CLI 2.116.0 but no Docker or `psql`; the repository also has no `supabase/config.toml`. Therefore `supabase test db` against the Supabase local stack was unavailable. The PGlite run verifies PostgreSQL grants, RLS, trigger/RPC behavior against the actual repository migrations; final confirmation on the Supabase test/staging image is still recommended before a separately approved Production migration.

## Other checks

- `node --test tests/*.test.cjs` — **5 passed, 0 failed** on PR #1.
- `deno test tests/attendance-state.test.ts` — **7 passed, 0 failed**.
- `deno check supabase/functions/kmo-hr-line/index.ts` — **passed**.
- `git diff --check` — **passed**.
- Existing Employee Portal, Admin, and RPC paths were not edited.

## Proposed Production migration and fallback

Production steps are for Owner approval separately:

1. Confirm a fresh backup/restore point and current migration history for the `kmo-hr` project.
2. Apply only the new forward migration through the approved migration process.
3. Verify effective table privileges, absence of `hr_attendance_insert`, preserved SELECT RLS, and service-role RPC execute/INSERT privileges.
4. Validate Edge Function → service-role RPC behavior using an approved non-Production test environment before production rollout. Do not create test attendance in Production.
5. Monitor the attendance Edge Function and RPC for permission errors; keep employee writes on the server RPC path.

The migration changes privileges/policy only and no rows. If the migration fails before commit, correct the cause and retry after checking migration state. If applied but the Edge/RPC path fails, diagnose the service-role grants/configuration and pause the affected clocking path if necessary. Do **not** restore authenticated direct INSERT as an automatic rollback: that recreates the reviewed vulnerability. Any compensating privilege migration requires a new explicit Owner risk decision.

## Review and merge boundary

- Security test evidence: **PASS in isolated PostgreSQL WASM; Supabase local-stack test remains unavailable here**.
- Independent review: pending.
- Merge readiness: **HOLD pending independent review and Owner's separate merge approval**.
- No merge, deployment, Production migration, or Production attendance write was performed.
