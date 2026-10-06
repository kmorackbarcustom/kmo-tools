# KMO HR — WORKSPACE STATUS

Updated: 2026-10-06
Gate: REMEDIATE / STOP FINAL PUBLICATION

## Completed
- Discovery baseline captured.
- Current-law review started against Ministry of Labour / DLPW / OSH / PDPA sources.
- Legal & Compliance Review v1 created.
- Owner Action Pack v1 created.
- Safety Site Checklist v1 created.

## 🔴 Critical finding
All 5 employees are technicians and regular work includes welding. Ministry of Labour guidance classifies metal welding as hazardous work subject to a stricter normal-working-hours limit than general work. Therefore the previously proposed 09:00–18:00 schedule with 1-hour break (8 actual hours) is NOT approved for final publication as-is.

## Files
- legal-review/LEGAL-COMPLIANCE-REVIEW-v1.md
- owner-approval/OWNER-ACTION-PACK-v1.md
- safety/SAFETY-SITE-CHECKLIST-v1.md

## Owner / operations decisions captured
- Working schedule draft: 09:00–18:00, total break 1 hour, Tuesday weekly holiday. LEGAL HOLD remains for hazardous-work hours.
- OT: Owner orders/approves before OT; hourly payment at not less than statutory rate.
- Benefits confirmed: lunch. Accommodation / performance-based bonus require exact-policy wording.
- Welding gases corrected: CO2 + Argon. Earlier oxygen-pair question is invalid.
- Social Security: HOLD / VERIFY actual current status before final compliance sign-off.

## Infrastructure cleanup — 2026-10-06
Legacy HR V1 was confirmed unused and removed from Supabase project `kmo-hr` (`ybyseaenceyswjnwdmdf`):
- removed legacy employee / leave / bonus tables;
- removed legacy leave/bonus functions and policies;
- removed empty `medical-certs` bucket;
- removed insecure legacy `hr-admin.html` and `hr-staff.html` from production repository;
- cleanup migrations tracked and pushed in commit `746c177`.

Unrelated workloads were preserved:
- `kmo_finance.*`
- `wc_*`
- `links`
- catalog storage
- `auth.users`

## Next
1. Finalize legal matrix / resolve legal holds.
2. Design clean HR V2 schema and identity model in `kmo-hr`.
3. Implement Auth / ADMIN=2 / EMPLOYEE=5 / RLS / audit baseline.
4. Implement attendance + leave thin vertical slice.
5. Finalize Privacy Notice, safety records and Work Rules.
6. Generate versioned canonical PDF after final legal/owner sign-off.

## HR V2 foundation — 2026-10-06
Implemented in Supabase project `kmo-hr` (`ybyseaenceyswjnwdmdf`):
- clean `hr_*` schema boundary in public;
- RLS enabled on every HR table;
- anonymous HR privileges revoked;
- private authorization helpers in `kmo_hr_private`;
- ADMIN and EMPLOYEE identity separated;
- attendance geofence enforcement at DB trigger level;
- legal-minimum policy rows protected from normal ADMIN writes;
- material change audit log;
- current operational schedule seeded with `legal_hold=true`;
- first confirmed ADMIN account bootstrapped from existing Supabase Auth user;
- second ADMIN and 5 employees not yet bound.

Migrations:
- `supabase/migrations/20261006174000_hr_v2_foundation.sql`
- `supabase/migrations/20261006175500_hr_v2_hardening_bootstrap.sql`

Architecture: `docs/hr/architecture/HR-V2-ARCHITECTURE.md`

Current implementation blockers:
1. second ADMIN identity;
2. 5 employee records / LINE bindings;
3. KMO worksite geofence coordinates;
4. new HR LIFF app ID/endpoint;
5. legal holds remain for work hours and Social Security.

## HR V2 admin console — 2026-10-06
Added `hr/admin.html` with:
- Supabase Auth email/password login;
- ADMIN membership verification through RLS;
- active employee / pending leave / today attendance counters;
- employee creation + probation-end calculation;
- employee deactivation;
- KMO worksite geofence capture from browser Location;
- current schedule/legal-hold display;
- recent audit log view.

Local checks:
- inline JavaScript syntax: PASS (`node --check`);
- local HTTP index: 200;
- local HTTP `/hr/admin.html`: 200.

Employee-facing portal is not enabled yet. It will use a new HR LIFF app and server-side LINE ID-token verification; existing booking/order LIFF apps will not be repurposed.

## Employee rules page — 2026-10-06
Added employee-facing `/hr/rules.html` as the highest-priority HR page.
Visible employee page intentionally does NOT display internal workflow labels such as Draft / Legal Hold / Final.
It shows:
- rule title;
- version 1.0;
- effective date and last-updated date;
- work schedule summary;
- attendance / OT / leave / safety / customer property / discipline / confidentiality / CCTV / offboarding rules;
- print / save-PDF action;
- future acknowledgement section.
Internal legal/compliance holds remain in back-office documentation only.
