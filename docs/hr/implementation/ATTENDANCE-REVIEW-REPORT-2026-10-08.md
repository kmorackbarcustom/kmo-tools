# KMO HR — Attendance PR Independent Review Report

วันที่: 2026-10-08 (Asia/Bangkok)

## Source of Truth และ PR

- Repository: `kmorackbarcustom/kmo-tools`
- `main`: `738d302f7eb96fe9a2a1d71bee0c8ab05b1eee5c`
- PR #1 Hardening → `main`: `codex/hr-attendance-ux-hardening-20261007` @ `2ce2add561a3fdbbafe56cb5c52fd67e48268ce3`
- PR #2 History → Hardening: `codex/attendance-history-v1-20261008` @ `e47bab0d854fd7418ee440c607ba2e3a534837eb`
- [PR #1](https://github.com/kmorackbarcustom/kmo-tools/pull/1)
- [PR #2](https://github.com/kmorackbarcustom/kmo-tools/pull/2)

Independent Reviewer inspected source and tests from both requested branch refs read-only. Commander Final Review rechecked the primary RLS/trigger/RPC finding against SQL. No source code was changed for this review.

## ผล review

### PR #1 — Attendance UX Hardening: REMEDIATE / BLOCKED

Hardening derives `eventType` from `buildStatus()` and sends it to `hr_record_line_attendance` (`supabase/functions/kmo-hr-line/index.ts:316-352`). The RPC is service-role-only and enforces sequence under a transaction advisory lock (`supabase/migrations/20261006201500_hr_line_employee_portal.sql:260-284,327-330`).

The baseline migration still grants `authenticated` direct `INSERT` on `hr_attendance_events` (`supabase/migrations/20261006174000_hr_v2_foundation.sql:492`) and `hr_attendance_insert` permits the user's linked employee row (`:624-629`). The insert trigger sets employee/time and validates site/accuracy/geofence (`:342-393`), but has no daily sequence/count checks or advisory lock. Authenticated PostgREST inserts can therefore bypass the new Edge-derived state and locked RPC. That leaves duplicate/out-of-order writes possible.

This exposure is inherited from `main`, not introduced by Hardening. It still violates this batch's system-level acceptance: the hardening brief requires authoritative server state, no duplicate/stale writes, and no RLS regression (`docs/hr/implementation/ATTENDANCE-UX-HARDENING-CODEX-BRIEF-2026-10-07.md:326-339`; plan `:91-106,184-198`). **The source finding is confirmed; no Production write was attempted.**

### PR #2 — Attendance History V1: PASS WITH NOTES (isolated diff)

The page checks active Admin membership before data access (`hr/attendance.html:117-131,242-264,299-314`). Only `boot()` invokes `loadAttendance(true)`; date, employee, and refresh listeners use zero-argument callbacks (`:363-365`). Its database queries are read-only, bounded, and select the approved fields (`:134-155`). The database read policies remain the server-side authority (`supabase/migrations/20261006174000_hr_v2_foundation.sql:521-526,617-622`). The regression test covers literal-`true`, falsey values, Event-like objects, and listener wrappers (`tests/attendance-history-contract.test.cjs:24-39`).

This isolated page diff passes with the notes above, but its base includes PR #1. The combined merge train remains blocked by PR #1's state-integrity finding.

## Owner-confirmed Live Auth

Owner reports Admin login and real attendance read, historical date selection, and logout PASS; non-admin UI denial PASS; and non-admin SELECT checks for both `hr_employees` and `hr_attendance_events` returning `count=0,error=null` PASS. These results are documented as Owner-confirmed, not independently reproduced. See [Live Auth Verification Report](ATTENDANCE-LIVE-AUTH-VERIFICATION-REPORT-2026-10-08.md).

These checks establish the tested UI and SELECT-isolation cases. They do not test direct authenticated INSERT and do not waive the written attendance-integrity acceptance criterion.

## Automated Verification

Rerun from the exact source branch worktrees:

- Hardening: `node --test tests/*.test.cjs` — **4 passed, 0 failed**.
- Hardening: `deno test tests/attendance-state.test.ts` — **7 passed, 0 failed**.
- History candidate (includes unchanged Hardening): `node --test tests/*.test.cjs` — **21 passed, 0 failed**.
- History candidate: `deno test tests/attendance-state.test.ts` — **7 passed, 0 failed**.
- Both refs: `deno check supabase/functions/kmo-hr-line/index.ts` — **passed**.
- Both PR ranges: `git diff --check` — **passed**.
- Windows worktree `deno fmt --check` reports CRLF/LF differences; checking the exact LF Git blobs in a temporary directory passes for both formatted files.
- PR state snapshot: both OPEN and mergeable; GitHub `reviewDecision` and `statusCheckRollup` are empty. This written review report is not a submitted GitHub approval.

## Merge Readiness / Stop Boundary

- Live Auth gate: **PASS (Owner-confirmed for the listed cases)**.
- PR #1 source review: **REMEDIATE / BLOCKED**.
- PR #2 source review: **PASS WITH NOTES in isolation**.
- Combined merge readiness: **HOLD** until the authenticated direct INSERT path is removed or an equivalent sequence/locking control is proven. Any Owner exception must explicitly acknowledge that the written integrity criterion remains unmet.
- No merge, deploy, or Production attendance write was performed.
