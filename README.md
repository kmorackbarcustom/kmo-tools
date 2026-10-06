# KMO Tools Workspace

Canonical local workspace for KMO Tools development and HR/compliance documentation.

## Repository
GitHub: kmorackbarcustom/kmo-tools

## HR workspace
- docs/hr/legal-review — Thai labour / OSH / PDPA compliance review
- docs/hr/owner-approval — documents for KMO owner review and approval
- docs/hr/safety — safety compliance notes/checklists

## Current HR V1 scope
5 employees (all Thai technicians, age 18+), 2 equal ADMIN users (owner + system admin).
No payroll/salary amount storage in HR V1.
Attendance uses shop geofence. LINE is employee identity. Telegram is used for admin notifications.

## HR V2 infrastructure
Supabase project: `kmo-hr` (`ybyseaenceyswjnwdmdf`).
Database migrations live under `supabase/migrations`.
HR V2 tables use the `hr_` prefix with RLS; anonymous HR access is revoked.
Architecture: `docs/hr/architecture/HR-V2-ARCHITECTURE.md`.

## Rule
Do not treat draft policy as final law. Legal minimums must be verified against current authoritative Thai sources before publication.
