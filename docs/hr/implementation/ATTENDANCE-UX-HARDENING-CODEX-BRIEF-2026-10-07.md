# CODEX BRIEF — KMO HR Attendance UX Hardening

Date: 2026-10-07  
Repo: `D:\AI-Workspace\projects\kmo-tools`  
Read first: `docs/hr/implementation/ATTENDANCE-UX-HARDENING-PLAN-2026-10-07.md`

## Mission

Implement one focused hardening batch for the KMO HR LINE Employee Portal attendance flow.

The goal is to make attendance state obvious to employees and make the server/database authoritative for whether the next event is clock-in or clock-out.

Do not expand scope into unrelated HR features.

## Current production baseline

Important current files:

- `hr/employee.html`
- `hr/admin.html`
- `supabase/functions/kmo-hr-line/index.ts`
- `supabase/migrations/20261006201500_hr_line_employee_portal.sql`
- `supabase/migrations/20261006202500_hr_line_link_invoker.sql`

Current Admin UX commit:

- `0077660 fix: show LINE status in HR admin`

Preserve that behavior.

Current dedicated HR LINE configuration:

- LINE Login channel ID: `2011901861`
- LIFF ID: `2011901861-phCm6tbP`
- Employee LIFF entry: `https://liff.line.me/2011901861-phCm6tbP`

These IDs are non-secret. Do not add or expose Channel Secret or Supabase Service Role.

## Real-user findings to fix

1. A desktop clock attempt outside the shop returned the raw code `INVALID_ATTENDANCE_INPUT`.
2. The write was correctly rejected; no attendance event was created.
3. Employee UI currently relies on server `nextAction`, but it does not make the current attendance state visually explicit enough.
4. Browser geolocation error handling uses `err.message` as if it contained numeric geolocation codes. Standard Geolocation errors expose `err.code`.
5. Clock API currently accepts `eventType` from the client. DB sequence rules protect the data, but server should derive or strictly validate the expected event from DB state.

## Required implementation

### A. Make attendance status explicit on Employee Portal

Add a prominent attendance summary/card above the event history.

Server-derived UI states:

#### No clock-in today

Display equivalent Thai wording:

```
วันนี้ยังไม่ได้เข้างาน
```

Primary button:

```
ลงเวลาเข้า
```

#### Clock-in exists, clock-out absent

Display:

```
เข้างานแล้ว HH:MM
รอลงเวลาออก
```

Primary button:

```
ลงเวลาออก
```

#### Clock-in and clock-out both exist

Display:

```
วันนี้ลงเวลาครบแล้ว
เข้า HH:MM · ออก HH:MM
```

Button disabled:

```
ลงเวลาครบแล้ว
```

Existing event history can remain below the summary.

Do not use internal codes as employee-facing primary text.

### B. Server decides clock-in vs clock-out

Preferred request contract:

```json
{
  "action": "clock",
  "location": {
    "latitude": 0,
    "longitude": 0,
    "accuracy": 0
  }
}
```

Do not trust a client-supplied event type.

For a clock request:

1. authenticate LINE as today;
2. resolve active employee as today;
3. query today's attendance state using Asia/Bangkok day bounds;
4. server derives expected event:
   - no clock-in → `clock_in`
   - clock-in and no clock-out → `clock_out`
   - both → reject as attendance complete
   - impossible/corrupt state → fail closed, review required
5. call existing service-only attendance RPC with the server-derived event type;
6. return fresh authoritative status after success.

If you retain `eventType` temporarily for backward compatibility, ignore it or validate it against server-derived expected state. A tampered client must not be able to force the wrong event type.

Do not weaken existing DB protections.

### C. Add explicit attendance state to server response

Return an explicit server-derived state. Recommended shape:

```json
{
  "attendanceState": "not_clocked_in",
  "nextAction": "clock_in",
  "clockInAt": null,
  "clockOutAt": null
}
```

Allowed state names may differ, but they must be unambiguous and documented in code.

At minimum support:

- not clocked in
- working / clocked in
- completed
- invalid/review-required if data is inconsistent

### D. Fix browser geolocation error normalization

Current employee code catches location errors incorrectly.

Normalize `navigator.geolocation.getCurrentPosition` errors using `GeolocationPositionError.code`.

Stable app codes:

- `GEO_PERMISSION_DENIED`
- `GEO_UNAVAILABLE`
- `GEO_TIMEOUT`
- `GEO_UNSUPPORTED`

Map them to clear Thai text.

Do not expose the browser's raw English exception when a known mapping exists.

### E. Fix attendance/location error UX

Employee-facing page must never show raw `INVALID_ATTENDANCE_INPUT`.

Required mappings include:

- `OUTSIDE_GEOFENCE`
  - “อยู่นอกพื้นที่ลงเวลาของร้าน กรุณาลงเวลาเมื่ออยู่ที่ร้าน”
- `GPS_ACCURACY_TOO_LOW`
  - “ตำแหน่งจากอุปกรณ์ไม่แม่นยำพอ กรุณาเปิด GPS และแนะนำให้ใช้มือถือ”
- `WORKSITE_NOT_CONFIGURED`
  - “ระบบยังไม่ได้ตั้งพื้นที่ลงเวลา กรุณาติดต่อ Admin”
- attendance complete
  - “วันนี้ลงเวลาครบแล้ว”
- stale/changed state
  - refresh authoritative status and show a safe retry message if needed

For malformed coordinate payloads, use a generic Thai validation error; do not show raw internal code.

Do not relax the configured accuracy or geofence checks just to make desktop work.

### F. Handle stale state and concurrency safely

Cases:

- double click
- second browser tab
- second device
- old page left open
- another device clocked before current request

Requirements:

- no duplicate attendance event;
- DB remains final enforcement;
- Edge re-checks current state before write;
- stale request fails safely;
- client refreshes status after conflict where appropriate.

### G. Preserve Admin UX

Do not break:

- LINE status column
- LINE display name
- `ผูกแล้ว` / `ยังไม่ผูก`
- employee code edit button
- pending link request flow
- employee table refresh after binding

No Admin redesign is required in this task.

## Data/security constraints

Do not change these invariants:

- employee attendance writes go through Edge Function / service-only RPC;
- browser never receives Service Role;
- timestamp comes from server;
- fresh location only when clock button is pressed;
- no continuous tracking;
- no IP geolocation fallback;
- no manual coordinates on employee portal;
- no face/photo attendance;
- no customer LINE UUID/HR UUID consolidation;
- no phone/name auto-binding;
- no anonymous HR table write access;
- no weakening RLS;
- no test attendance inserted into production as part of automated testing.

## Scope guard

Do NOT implement:

- payroll
- deductions/fines
- OT calculation
- OT approval flow
- absence automation
- missing clock-out automation
- leave workflow
- holiday-pay automation
- Social Security
- legal-policy changes
- privacy notice finalization
- work-rules changes
- customer LINE/OA changes
- broad HR schema redesign

If a migration is truly required, explain why before adding it. Prefer no DB migration if the existing schema/RPC is sufficient.

## Test requirements

Create or use a deterministic test approach for pure/state logic where practical.

Required cases:

### State machine
- no events → clock-in
- clock-in only → clock-out
- clock-in + clock-out → complete
- clock-out without clock-in → invalid/review-required

### Tamper/stale
- client-provided wrong event type cannot force wrong event
- duplicate clock-in rejected
- duplicate clock-out rejected
- clock-out before clock-in rejected
- stale state after another device write does not duplicate

### Location/errors
- geolocation permission denied mapping
- unavailable mapping
- timeout mapping
- malformed coordinates
- low GPS accuracy
- outside geofence
- valid location path

### Regression
- unlinked LINE request flow remains
- active linked employee status remains
- inactive employee blocked
- Admin page inline JS remains valid
- Employee page inline JS remains valid

## Verification commands/checks

Before editing:

1. confirm branch/worktree status;
2. inspect current code, not memory;
3. note current HEAD.

Before commit:

- extract/check inline JavaScript with `node --check`;
- run `git diff --check`;
- run any new deterministic tests;
- inspect diff for secrets;
- ensure no production data mutation was used as a test shortcut.

Deployment:

- deploy `kmo-hr-line` only if Edge code changed and checks pass;
- verify custom auth still rejects missing/invalid LINE token;
- verify live employee page returns HTTP 200;
- verify live admin page still contains LINE status/edit-code UX;
- do not create fake attendance in production for verification.

## Acceptance criteria

PASS only if all are true:

1. Employee sees one obvious current state: not clocked in / clocked in / complete.
2. Button action follows authoritative server state.
3. Client cannot decide or override the actual event type written.
4. Desktop/phone location errors show understandable Thai messages.
5. Raw `INVALID_ATTENDANCE_INPUT` is not shown to employee.
6. Outside-geofence and low-accuracy cases remain blocked.
7. Duplicate/stale requests do not create duplicate events.
8. Existing LINE binding and Admin UX still work.
9. No secret exposure/RLS/service-role regression.
10. Tests/checks pass and live deployment evidence is recorded.

## Handoff requirements

When finished, stop and report:

- branch name;
- starting HEAD;
- implementation commit;
- files changed;
- whether any migration was added;
- Edge Function deployment version if changed;
- exact checks/tests and results;
- live verification results;
- remaining risks or items intentionally deferred.

Also create a short implementation report under:

`docs/hr/implementation/`

Suggested filename:

`ATTENDANCE-UX-HARDENING-REPORT-2026-10-07.md`

Do not start another HR phase after this batch. Stop for Owner review.
