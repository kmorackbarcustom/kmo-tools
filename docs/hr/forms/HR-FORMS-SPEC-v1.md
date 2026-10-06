# KMO HR FORMS — V1 SPEC
Date: 2026-10-06
Status: DRAFT

## F-01 Leave Request
Fields:
- employee_id
- leave_type
- start_date / end_date
- partial-day/time if supported
- reason (minimum necessary)
- emergency flag
- supporting file only where legally/operationally necessary
- submitted_at
- status: PENDING / APPROVED / REJECTED / CANCELLED
- decided_by / decided_at / decision_note
Rules:
- planned leave: request >=1 day ahead where reasonably possible;
- emergency/sickness: retrospective/urgent notice allowed;
- statutory minimums cannot be reduced by ADMIN.

## F-02 Time Correction
Fields:
- attendance_date
- correction_type: MISSING_IN / MISSING_OUT / WRONG_TIME / OTHER
- requested_time
- reason
- submitted_at
- decision / decided_by / decided_at
Rules:
- employee cannot directly mutate attendance;
- preserve original record;
- approved correction creates auditable adjustment.

## F-03 Incident / Employee Explanation
Fields:
- incident date/time
- category
- factual description
- employee explanation
- witnesses (if relevant)
- attachments (optional/minimum necessary)
- safety/customer/property impact
- ADMIN finding
- corrective action
Rules:
- allegations are not findings;
- separate facts, employee statement and ADMIN conclusion.

## F-04 Written Warning
Fields:
- employee
- incident/reference
- factual conduct
- rule/order involved
- prior warning reference if legally relevant
- expected correction
- warning issue date
- expiry/review metadata where applicable
- issuer
- employee acknowledgement / refusal-to-sign witness process
Rules:
- must not overstate automatic-dismissal consequences;
- serious-misconduct handling requires legal/fact review.

## F-05 Rules Acknowledgement
Fields:
- employee
- rule version
- effective date
- canonical document/hash reference
- acknowledged_at
- acknowledgement method
Statement:
Employee acknowledges receipt/access to the rules; acknowledgement is not a waiver of statutory rights.

## F-06 Safety Training Record
Fields:
- employee
- topic
- date
- trainer/provider
- method
- evidence/attachment
- assessment/result if relevant
- expiry/refresh date if applicable

## F-07 Safety Incident / Near Miss
Fields:
- date/time
- task
- location
- what happened
- injury/first aid (minimum necessary)
- PPE in use
- equipment involved
- optional photos
- immediate containment
- root/cause review
- corrective action
- closed_by / closed_at

## F-08 Holiday Work Review
Fields:
- date (normally Tuesday weekly holiday)
- instructed_by (Owner)
- reason
- employees involved
- actual time
- work type
- hazardous-task flag
- legal/pay review
- approved pay classification
Rules:
- never reclassify weekly holiday as normal day after the fact.

## F-09 OT Review
Fields:
- date
- employee
- scheduled end
- actual clock-out
- claimed/observed work interval
- Owner instruction/approval reference
- work description
- hazardous-task flag
- approved OT interval
- rejected reason
Rules:
- late clock-out alone is not proof of OT;
- actual work cannot be erased merely because pre-approval was missing.

## F-10 Offboarding Checklist
- desired/confirmed last work date
- resignation notice review
- pending jobs
- customer motorcycles/status
- parts/materials
- tools/property
- keys/equipment
- access revocation
- final documents
- handover complete
Rule:
handover and lawful wage payment are separate obligations.

## F-11 Policy Change Record
Fields:
- policy id/version
- legal minimum vs KMO extra
- before
- after
- reason
- effective date
- changed_by
- approved_by
Rules:
- legal minimum cannot be changed downward by ADMIN;
- every KMO-extra change is versioned/audited.
