# KMO EMPLOYEE PRIVACY NOTICE — DRAFT V1
Date: 2026-10-06
Status: DRAFT FOR PDPA REVIEW

## Purpose
KMO processes only employee data reasonably necessary to manage employment, attendance, leave, safety, work administration, legal compliance and security.

## Data categories planned for HR V1
- employee identity and contact data;
- LINE-linked employee identifier where used for login;
- employment start/probation status;
- attendance timestamps;
- geolocation submitted at clock-in/out, including accuracy and timestamp;
- leave requests and supporting evidence only where necessary;
- time-correction requests;
- disciplinary/incident records;
- safety training records;
- safety incidents / first-aid information limited to what is necessary;
- acknowledgement of policies;
- ADMIN audit logs.

## Data intentionally excluded by default
- salary amount in HR V1;
- full payroll data;
- national-ID-card image unless a specific lawful purpose requires it;
- unnecessary health details;
- biometric/face-scan attendance.

## Geolocation
Location is used only to verify attendance within the KMO work-site geofence.
The system should retain the minimum information needed to prove attendance and investigate corrections.
Server-side validation must be used; employee location must not be tracked continuously.

## CCTV
KMO has CCTV, employees have been informed and signs are posted.
Before final publication KMO must document:
- purposes;
- areas covered;
- authorized viewers;
- retention period;
- disclosure conditions;
- contact/rights channel.

## Access control
- Employee: own attendance/leave/status where applicable.
- ADMIN: authorized HR/operations data needed for duties.
- Sensitive health/incident evidence: restricted to authorized ADMIN access.
- Every material ADMIN change should be auditable.

## Storage/security
Production HR data should use private database/storage with RLS or equivalent access controls.
No anonymous/public browser writes.
Files containing health/incident/identity evidence must not be publicly accessible.

## Retention
Final retention schedule is pending legal/operational review.
Do not keep personal data indefinitely by default.
Retention must be tied to purpose, legal claims/compliance and deletion/anonymization process.

## Employee rights/contact
Final notice must state the KMO contact channel for privacy requests and the rights available under applicable PDPA rules.

## Legal basis
Final production notice must map each processing purpose to the lawful basis actually relied upon. Do not use blanket consent for processing that is necessary for employment/legal compliance where another basis is appropriate.

## Status
REMEDIATE before production:
- finalize retention periods;
- designate privacy contact;
- finalize CCTV retention/access;
- finalize legal-basis mapping;
- publish employee-facing notice before HR production use.
