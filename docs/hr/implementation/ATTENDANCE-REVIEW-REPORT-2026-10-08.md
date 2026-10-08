# KMO HR — Attendance PR Independent Review Report

วันที่: 2026-10-08 (Asia/Bangkok)

## Source of Truth และ PR

- Repository: `kmorackbarcustom/kmo-tools`
- `main`: `738d302f7eb96fe9a2a1d71bee0c8ab05b1eee5c`
- PR #1 Hardening → `main`: `codex/hr-attendance-ux-hardening-20261007`; security remediation source reviewed at `4cdced3e9bcd12c3296b08228457df95b07645ad`. A later documentation-only commit records this review.
- PR #2 History → Hardening: source reviewed at `c32b7b46248b23ccc5ccd098f2a7baedeca05bb1`; after PR #1's documentation-only update, PR #2 was rebased onto the new base and its current head is `c927409d2da8c0cafcbb954a99fa53c1a7d91362`. The rebase retains the reviewed source changes.
- [PR #1](https://github.com/kmorackbarcustom/kmo-tools/pull/1)
- [PR #2](https://github.com/kmorackbarcustom/kmo-tools/pull/2)

The Independent Reviewer inspected the current remote source and test refs read-only. This report supersedes the earlier review snapshot below, whose PR heads and PR #1 verdict are stale. The review is an independent source review, not a submitted GitHub review approval.

## ผล Review

### PR #1 — Attendance UX Hardening + Security Remediation: PASS

The new forward-only migration revokes direct `INSERT` from `anon`, `authenticated`, and `PUBLIC`, explicitly retains the `service_role` grant, and drops only `hr_attendance_insert`. It leaves the attendance SELECT policy and RLS in place. Previously applied migrations were not edited.

The reviewer confirmed that the Edge Function still uses its server-side service-role key and calls `hr_record_line_attendance`; the RPC remains service-role-only, takes the employee/day advisory transaction lock, and rejects duplicate or out-of-order events. The existing insert trigger retains the service-role path.

The source pgTAP file covers effective table privileges, policies/RLS, direct insert denial for anonymous/employee/admin cases, service-role RPC, duplicates, sequence checks, and Employee/Admin SELECT behavior. The independent reviewer inspected this coverage but did not independently reproduce the PGlite database execution.

### PR #2 — Attendance History V1 + Home Navigation: PASS WITH NOTES

The new home card follows the existing card pattern, retains the HR Admin link, and links to `hr/attendance.html` with a relative path. The regression test verifies it resolves as `/kmo-tools/hr/attendance.html` under the repository's GitHub Pages base. This corrects the absolute-path issue identified during review of the earlier PR #2 head.

The reviewer confirmed the History page still checks active Admin authorization before reading data, keeps its queries read-only, retains the SELECT RLS policies, calls `loadAttendance(true)` only from boot, and wraps UI listeners so Event objects are not accidentally passed as arguments. Non-admin direct access remains denied by the page guard.

### Owner-confirmed Live Auth

Owner reports Admin login and real Attendance read, historical date selection, and logout PASS; non-admin UI denial PASS; and non-admin SELECT checks for both `hr_employees` and `hr_attendance_events` returning `count=0,error=null` PASS. These are recorded as Owner-confirmed results, not independently reproduced by the reviewer or Codex during this remediation.

## Test Evidence and Limitations

- PR #1 source worktree: `node --test tests/*.test.cjs` — **5 passed, 0 failed**.
- PR #2 source worktree: `node --test tests/*.test.cjs` — **24 passed, 0 failed**.
- Both branches: `deno test tests/attendance-state.test.ts` — **7 passed, 0 failed** each.
- Both branches: `deno check supabase/functions/kmo-hr-line/index.ts` — **passed**.
- Migration/security: all project migrations including the new forward migration were applied in an ephemeral PostgreSQL 18.3 PGlite WASM database; the repository SQL security test ran under a minimal TAP-compatible harness — **22/22 assertions passed**. Synthetic data only; transaction rolled back. The Independent Reviewer inspected the SQL test source but did not reproduce this PGlite run.
- Browser smoke: local preview at desktop 1440×900 and mobile 390×844; home and target pages returned HTTP 200, new card navigated to Attendance History, direct unauthenticated page access showed the login view and kept the app view hidden, existing HR Admin navigation remained, no horizontal overflow or page JS errors.
- Inline scripts in Admin, Employee, and Attendance pages parsed successfully; `git diff --check` passed for both PR ranges.
- Supabase local-stack `supabase test db` was not run: this environment has no Docker or `psql`, and this repository has no `supabase/config.toml`. The isolated PostgreSQL run is evidence for the migrations and security assertions, but is not a Supabase local-stack execution. Repeat the migration tests on an approved Supabase test/staging database before Production migration.
- GitHub currently reports both PRs OPEN and mergeable; `reviewDecision` and `statusCheckRollup` are empty. No CI checks are configured/reported in the PR snapshot.

## Merge Readiness / Stop Boundary

- PR #1 source review: **PASS**.
- PR #2 source review: **PASS WITH NOTES**.
- Combined source/test merge readiness: **PASS WITH NOTES**. Reviewer-confirmed source findings are addressed and the current PR refs have no merge conflict. The notes are the unavailable Supabase local-stack run and empty GitHub review/check fields; neither is represented as a passing CI result.
- Production migration readiness: **not authorized by this review**. Follow the proposed backup, forward-migration, ACL/policy/RPC verification, and approved staging validation steps in `ATTENDANCE-SECURITY-REMEDIATION-REPORT-2026-10-08.md` before requesting separate Owner approval.
- No merge, deployment, Production migration, or Production Attendance write was performed.
