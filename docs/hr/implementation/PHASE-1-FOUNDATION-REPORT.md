# KMO HR V2 — Phase 1 Foundation Report

Date: 2026-10-06
Result: PASS WITH INPUTS PENDING

## Implemented

- Reused Supabase project `kmo-hr` without touching finance/catalog workloads.
- Removed legacy HR before this phase.
- Created 17 HR V2 tables with RLS enabled.
- Revoked anonymous HR access.
- Added private authorization helpers.
- Separated ADMIN from EMPLOYEE records.
- Added current schedule config with legal hold.
- Added geofence-enforced attendance event preparation.
- Added leave, incident, warning, safety, acknowledgement and audit foundations.
- Protected legal-minimum policy rows from normal ADMIN editing.
- Added indexes and removed duplicate permissive RLS policy warnings.
- Bootstrapped the first confirmed ADMIN from the existing Supabase Auth account.

## Verification

Database checks:
- ADMIN rows: 1
- EMPLOYEE rows: 0
- schedule legal_hold rows: 1
- anon SELECT on employee HR data: false
- anon INSERT leave: false
- anon INSERT attendance: false
- Supabase security advisor HR ERROR findings: 0
- duplicate permissive HR policy warnings: 0

## Not activated yet

Attendance remains intentionally unusable until a KMO worksite geofence is configured.
Employee access remains intentionally unusable until employees and LINE identities are bound.

## Required inputs for next phase

1. second ADMIN identity;
2. five employee records;
3. KMO worksite latitude/longitude (or a location capture at the shop);
4. new HR LIFF app ID/endpoint.

## Legal holds remain separate

- hazardous welding-work normal hours;
- Social Security status/classification.

These do not block database/UI development, but they block final policy publication where applicable.
