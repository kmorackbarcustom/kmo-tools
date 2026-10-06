# KMO HR — Attendance UX Hardening Plan

Date: 2026-10-07  
Owner scope: LINE Employee Portal → Attendance  
Target repo: `D:\AI-Workspace\projects\kmo-tools`

## 1. Objective

Harden the real employee attendance flow after first live-user testing so that:

1. employees always know whether the next action is clock-in or clock-out;
2. the server/database, not the browser, remains the source of truth for attendance state;
3. location failures are explained in Thai instead of exposing internal codes such as `INVALID_ATTENDANCE_INPUT`;
4. stale/double-click/tampered requests fail safely;
5. the current HR Admin LINE-link UX remains intact.

This batch is UX + attendance-flow hardening only. It is not a payroll, OT, leave, legal-policy, or work-rules batch.

## 2. Current baseline

Already live:

- Employee Portal: `hr/employee.html`
- Edge Function: `supabase/functions/kmo-hr-line/index.ts`
- Server-side LINE ID-token verification
- Explicit Admin LINE ↔ employee binding
- Server timestamp
- Geofence and GPS-accuracy validation
- DB protection against duplicate clock-in/clock-out and clock-out-before-clock-in
- Bangkok-local attendance day
- Admin employee table now shows LINE status and supports editing employee code
- Current admin UX fix commit: `0077660`

Observed real-use findings:

- A desktop test outside the shop returned `INVALID_ATTENDANCE_INPUT`.
- The request was correctly rejected and no attendance event was written.
- Current employee UI does switch its button from clock-in → clock-out → complete based on server status, but the state is not visually explicit enough.
- Current browser geolocation error handling checks `err.message` for numeric codes; standard Geolocation errors expose a numeric `err.code`, so user-facing mapping can fall through to generic/internal errors.
- Current clock request sends `eventType` from the client. DB rules protect sequence, but we want the Edge Function to derive/validate the expected action from authoritative DB state.

## 3. Target employee experience

### State A — no attendance yet today

Show prominently:

```
วันนี้ยังไม่ได้เข้างาน
เวลาเข้างานปกติ 09:00
```

Primary button:

```
ลงเวลาเข้า
```

### State B — clock-in exists, clock-out does not

Show prominently:

```
เข้างานแล้ว 08:56
รอลงเวลาออก
```

Primary button:

```
ลงเวลาออก
```

### State C — clock-in and clock-out both exist

Show prominently:

```
วันนี้ลงเวลาครบแล้ว
เข้า 08:56 · ออก 18:07
```

Primary action disabled:

```
ลงเวลาครบแล้ว
```

Existing event history may remain below this summary.

## 4. Server-authoritative attendance rule

The client may display `nextAction`, but it must not be trusted as the authority for what event is written.

Preferred design:

1. client sends `action: "clock"` + fresh location only;
2. Edge Function queries today's authoritative attendance state;
3. Edge Function determines the expected next event:
   - no clock-in → `clock_in`
   - clock-in only → `clock_out`
   - both present → reject as complete
4. Edge Function calls the existing service-only attendance RPC using the server-derived event type;
5. DB sequence constraints remain the final enforcement layer.

If retaining `eventType` in the request for compatibility, the server must derive its own expected event and reject/ignore any mismatch. Client-supplied event type must never be the source of truth.

No client clock or client timestamp may be accepted.

## 5. Attendance state contract

Status response should remain easy for the static page to render and should include an explicit state.

Recommended:

```json
{
  "attendanceState": "not_clocked_in | working | completed",
  "nextAction": "clock_in | clock_out | null",
  "clockInAt": "ISO or null",
  "clockOutAt": "ISO or null",
  "events": []
}
```

The exact shape may differ if Codex finds a cleaner minimal change, but there must be one unambiguous server-derived state used by the UI.

Handle corrupted/impossible state fail-closed. Example: clock-out exists without clock-in → do not guess; show a review-required state and prevent another write until corrected by Admin.

## 6. Error taxonomy

Internal/raw errors must not be shown directly to employees.

### Browser / device location

Normalize to stable application codes:

- `GEO_UNSUPPORTED`
- `GEO_PERMISSION_DENIED`
- `GEO_UNAVAILABLE`
- `GEO_TIMEOUT`

Thai UX:

- unsupported → “อุปกรณ์นี้ไม่รองรับการอ่านตำแหน่ง”
- permission denied → “ยังไม่ได้อนุญาตตำแหน่ง กรุณาเปิดสิทธิ Location ให้ LINE/Browser แล้วลองใหม่”
- unavailable → “อ่านตำแหน่งไม่ได้ กรุณาเปิด GPS/Location แล้วลองใหม่”
- timeout → “อ่านตำแหน่งนานเกินไป กรุณาลองใหม่ หรือใช้มือถือที่เปิด GPS”

### Server attendance/location

Stable codes:

- `OUTSIDE_GEOFENCE`
- `GPS_ACCURACY_TOO_LOW`
- `WORKSITE_NOT_CONFIGURED`
- `ATTENDANCE_ALREADY_COMPLETE`
- `ATTENDANCE_STATE_CHANGED` or equivalent safe stale-state code
- `EMPLOYEE_INACTIVE`
- malformed input → internal/generic validation message, not a raw code

Thai UX examples:

- outside geofence → “อยู่นอกพื้นที่ลงเวลาของร้าน กรุณาลงเวลาเมื่ออยู่ที่ร้าน”
- GPS weak → “ตำแหน่งจากอุปกรณ์ไม่แม่นยำพอ กรุณาเปิด GPS และแนะนำให้ใช้มือถือ”
- worksite missing → “ระบบยังไม่ได้ตั้งพื้นที่ลงเวลา กรุณาติดต่อ Admin”
- complete → “วันนี้ลงเวลาครบแล้ว”
- stale state → refresh status automatically and tell user to try again if still needed

`INVALID_ATTENDANCE_INPUT` may remain as an internal diagnostic code if useful, but it must not be surfaced verbatim to the employee.

## 7. Desktop behavior

Desktop is not banned, but location quality must remain enforced.

Rules:

- never bypass accuracy/geofence for desktop;
- if desktop location is too weak, explain that clearly;
- recommend mobile + GPS when appropriate;
- no fallback to IP location;
- no manual coordinate entry on employee page.

## 8. Concurrency and stale-state behavior

Protect against:

- double click;
- two tabs;
- two devices;
- old portal state;
- replay after another device already clocked in/out.

Expected behavior:

- DB/advisory-lock protection remains;
- server re-checks authoritative state before write;
- stale attempt does not create a duplicate;
- client refreshes server status after a conflict/rejection when safe.

## 9. Admin regression requirements

Do not break current Admin behavior from commit `0077660`:

- employee table has LINE column;
- shows `ผูกแล้ว` / `ยังไม่ผูก`;
- shows LINE display name when available;
- employee code can be edited;
- successful LINE binding refreshes employee table immediately;
- pending LINE requests still work.

No redesign of Admin beyond fixes required to prevent regression.

## 10. Data/security invariants

Must remain true:

- LINE Channel ID may be client/server config; no secret goes to browser/repo.
- Service Role stays only in Edge Function environment.
- Browser cannot write attendance tables directly.
- attendance timestamp is server-generated.
- fresh geolocation only at clock action; no continuous tracking.
- raw attendance events are immutable to employee.
- geofence and accuracy checks remain server/DB enforced.
- one active LINE identity per employee.
- no customer-system identity matching.
- no phone/display-name auto-binding.
- no production test rows or fake attendance inserted for automated tests.

## 11. Test matrix

At minimum verify:

### Attendance state
1. no events → state not-clocked-in, next clock-in
2. clock-in only → state working, next clock-out
3. clock-in + clock-out → state complete, no next action
4. impossible/corrupt sequence → fail closed / review-required

### Clock request
5. first valid clock → records clock-in
6. next valid clock → records clock-out
7. third clock → rejected, no duplicate
8. stale client after another device clocks → rejected/refreshed safely
9. manipulated client event type cannot force wrong event

### Location
10. permission denied → correct Thai message
11. unavailable/timeout → correct Thai message
12. malformed lat/lng → safe generic validation
13. poor accuracy → GPS-specific message
14. outside geofence → outside-area message
15. valid on-site location → accepted

### Regression
16. unlinked LINE still creates/updates pending request
17. linked active employee gets status
18. inactive employee denied
19. Admin LINE status/edit-code UI still loads
20. inline JS syntax passes

## 12. Verification before deployment

Required:

- inspect real current code before editing;
- start from clean/synced branch;
- syntax-check extracted inline JS with `node --check`;
- `git diff --check`;
- test Edge logic without writing fake production attendance;
- verify unauthenticated Edge request still rejects;
- verify no secret/client service-role regression;
- deploy Edge Function only after local/code checks pass;
- verify live Employee Portal loads;
- verify live Admin page still has LINE status/edit-code UX;
- report exact files changed, tests, deployment version, commit, and remaining risks.

## 13. Non-goals

Do not touch in this batch:

- payroll or wage deductions
- OT approval/payment rules
- automatic absence generation
- missing-clock-out automation
- leave workflow
- weekly-holiday compensation rules
- legal-hold wording
- Social Security
- work rules
- privacy policy finalization
- customer KMO LINE/OA or booking identities
- broad HR schema redesign

## 14. Success criteria

This batch is PASS only when a normal employee can understand the whole attendance state without knowing internal system terms:

```
ยังไม่เข้า → ลงเวลาเข้า
เข้าแล้ว → ลงเวลาออก
ครบแล้ว → ปิดปุ่ม
ผิดพื้นที่/GPS → บอกสาเหตุเป็นภาษาไทย
```

and the server/database independently decides and enforces what attendance event is legal to record.
