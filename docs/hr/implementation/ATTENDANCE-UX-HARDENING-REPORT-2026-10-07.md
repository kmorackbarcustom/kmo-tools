# KMO HR Attendance UX Hardening — Implementation Report

Date: 2026-10-07 (Asia/Bangkok)

## Implementation

- Branch: `codex/hr-attendance-ux-hardening-20261007`
- Starting HEAD: `738d302f7eb96fe9a2a1d71bee0c8ab05b1eee5c`
- Implementation commit: `c97fa4a28fe7204ba445a3c0027bfbbfeca8387f`
- Changed files:
  - `hr/employee.html`
  - `hr/assets/attendance-errors.js`
  - `supabase/functions/kmo-hr-line/index.ts`
  - `supabase/functions/kmo-hr-line/attendance_state.ts`
  - `tests/attendance-state.test.ts`
  - `tests/attendance-errors.test.cjs`
  - `tests/attendance-contract.test.cjs`
  - `docs/hr/implementation/ATTENDANCE-UX-HARDENING-REPORT-2026-10-07.md`
- Database migration: none. Existing service-only RPC and advisory transaction lock remain unchanged.
- Admin source: unchanged.

## Verified

- Deno state/location/RPC tests: 7 passed.
- Node geolocation/error tests: 2 passed.
- Node Edge/RPC contract tests: 2 passed.
- `deno check supabase/functions/kmo-hr-line/index.ts`: passed.
- `deno fmt --check` for new state module and tests: passed.
- Extracted Employee and Admin inline JavaScript syntax: passed.
- `git diff --check`: passed.
- Client source scan found no Service Role key or Channel Secret.
- No production attendance rows were created for testing.

## Deployment and live checks

- Supabase project: `kmo-hr` (`ybyseaenceyswjnwdmdf`).
- Edge Function `kmo-hr-line`: deployed as version 2; `verify_jwt=false` preserved.
- Missing LINE token: HTTP 401 `LINE_ID_TOKEN_REQUIRED`.
- Invalid LINE token: HTTP 401 `LINE_ID_TOKEN_INVALID`.
- Live Employee page `/kmo-tools/hr/employee.html`: HTTP 200, still serving the pre-merge UI.
- Live Admin page `/kmo-tools/hr/admin.html`: HTTP 200; LINE status and employee-code edit checks passed.
- No successful live clock-in/out was attempted to avoid writing production attendance.

## Review handoff

The implementation branch is pushed and is not merged. The new Employee UX and its error-mapping asset will become live only after the branch is reviewed and merged to `main`. Edge version 2 is already live and remains compatible with the current page because it ignores the old client-supplied `eventType` and derives the write type from server state.

Remaining live verification after merge: confirm the updated Employee page and error asset load from GitHub Pages, then exercise location acceptance/rejection with an authorized employee at the shop. Duplicate/stale database enforcement was verified against the existing RPC lock and covered by deterministic state/error tests; no production concurrency test was run.
