# KMO HR LEGAL & COMPLIANCE REVIEW — V1

Date: 2026-10-06
Status: REMEDIATE BEFORE OWNER APPROVAL / IMPLEMENTATION
Scope: 5 Thai technician employees, age 18+, monthly paid; ADMIN = shop owner + system admin.

> This is an internal compliance review, not a substitute for advice from a licensed Thai lawyer or labour officer.

## Executive finding

### 🔴 BLOCKER L-01 — Current 09:00–18:00 schedule cannot be approved as-is for welding work
KMO confirmed that all 5 employees are technicians and their regular tasks include gas welding.
The Ministry of Labour identifies metal welding as work that may be hazardous to employees' health and safety. Such work has a normal-work limit of no more than 7 hours/day (and the official labour guidance also states the corresponding 42 hours/week baseline), rather than the general 8 hours/day / 48 hours/week rule.

KMO's proposed schedule 09:00–18:00 with 1 hour break = 8 actual work hours/day. Therefore this schedule MUST NOT be published as the final rule for employees performing welding until KMO restructures the work schedule / task classification and confirms compliance.

Decision required from Owner:
- redesign normal working hours for technicians so hazardous work is within the legal limit; and
- obtain labour/safety professional confirmation if KMO intends to distinguish hazardous welding time from other general technician duties.

Do not solve this by simply calling the eighth hour “OT”. Hazardous-work overtime/holiday-work restrictions must be checked before allowing it.

Source: Ministry of Labour — Rights and Duties of Employers and Employees:
https://www.mol.go.th/employee/สิทธิหน้าที่นายจ้าง-ลูกจ้าง

## L-02 — Break
Current proposal: total break >= 1 hour/day, flexible rather than fixed.
Legal baseline: break totaling at least 1 hour/day, generally after no more than 5 consecutive hours; shorter individual breaks may be agreed in advance if total >=1 hour.
Status: PASS WITH IMPLEMENTATION CONDITION.
System/policy must not allow a flexible break arrangement that results in >5 continuous working hours contrary to the legal rule.

## L-03 — Weekly holiday
Tuesday is the weekly holiday.
Baseline: at least 1 weekly holiday and spacing generally no more than 6 days.
Status: PASS.

## L-04 — Traditional holidays
KMO prioritizes New Year, Songkran and National Labour Day, with other dates announced in advance.
Legal baseline: at least 13 traditional holidays/year including National Labour Day, selected from annual official, religious, or local customary holidays; replacement rules apply when required.
Status: PASS WITH CONTROL.
System must prevent publishing annual holiday calendar below legal minimum.

## L-05 — Annual vacation
KMO policy = legal minimum only.
After 1 continuous year: at least 6 working days/year. For <1 year employer may provide proportionately.
Status: PASS. Do not create an automatic carry-over benefit unless separately approved/agreed as legally appropriate.

## L-06 — Sick leave
KMO policy = legal minimum.
- Sick leave: as actually sick.
- Paid sick leave: up to 30 working days/year.
- For sick leave of 3 working days or more, employer may request qualifying medical certificate; if employee cannot produce it, employee must explain.
- Frequent one-day sick leave must NOT automatically become misconduct. Pattern flags may trigger fact review, not guilt.
Status: PASS.

## L-07 — Necessary business leave
KMO policy = statutory minimum only.
System legal baseline must be versioned and not owner-editable downward.
Status: PASS subject to final current-law entitlement table used at implementation.

## L-08 — Maternity / family leave — IMPORTANT 2025 amendment
Labour Protection Act (No. 9) B.E. 2568 has been effective since 7 Dec 2025.
Current baseline includes:
- maternity leave up to 120 days per pregnancy;
- employer-paid maternity leave up to 60 days;
- additional child-care leave in specified newborn illness/disability circumstances, up to 15 days with statutory partial-pay treatment;
- spouse leave to assist a spouse who gives birth, up to 15 days with statutory paid entitlement.
Status: MUST INCLUDE even if current workforce happens not to use it. Legal rights cannot be omitted from policy engine because of current employee demographics.
Source: Ministry of Labour:
https://www.mol.go.th/news/เริ่มใช้แล้ว-กม-ลาคลอด-120-วัน-ตรีนุช-สั่งกรมสวัสดิการฯ-เร่งทำความเข้าใจนายจ้าง-ปรับสิทธิลาคลอดตามกฎหมายใหม่

## L-09 — Attendance
Approved design:
- normal clock-in target remains subject to L-01 schedule remediation;
- grace period 30 min is KMO leniency and does not redefine normal start time;
- after grace = LATE record only, no automatic fine;
- no clock-in + no valid leave = ABSENT after workday closes;
- employee explanation/correction due by next working day;
- missing clock-out = MISSING_CLOCK_OUT;
- early clock-out = EARLY_LEAVE;
- all corrections require ADMIN approval and immutable audit history.
Status: PASS as recordkeeping design.

## L-10 — OT / work after scheduled hours
Clock-out after normal hours must NOT automatically create payable/approved OT. Record actual clock-out and create OT_REVIEW.
However actual working time cannot be disguised as “forgot to clock out”; Owner must determine actual work performed.
OT payment practice remains OWNER CONFIRM REQUIRED.
Because KMO performs hazardous welding work, do not enable an OT approval workflow for hazardous work until the statutory restriction is verified and the work schedule is remediated.
Status: BLOCKED FOR IMPLEMENTATION pending L-01 + owner OT confirmation.

## L-11 — Tuesday holiday work
Tuesday remains WEEKLY_HOLIDAY. Owner may not convert it to a normal day retroactively.
Exceptional work (e.g. flood recovery) must be recorded separately as HOLIDAY_WORK_REVIEW and handled under statutory consent/restriction/pay rules.
For hazardous welding work, holiday-work restrictions require compliance check before approval.
Status: REMEDIATE.

## L-12 — Wages
Employees monthly paid; pay at month-end.
HR V1 stores NO salary amount and performs NO payroll.
Status: PASS.

## L-13 — Wage deductions / customer or KMO property damage
No fines and no automatic deductions.
If damage occurs:
incident -> evidence -> fact investigation -> classify accident/negligence/intentional conduct -> ADMIN decision.
Where the law permits recovery by wage deduction for employee-caused damage, statutory conditions and written consent requirements must be satisfied; otherwise use lawful civil recovery route.
Source: Ministry of Labour legal Q&A explaining sections 76/77.
Status: PASS with no deduction engine in V1.

## L-14 — Discipline
General flow:
incident record -> verbal/recorded warning -> written warning -> further lawful disciplinary action.
No automatic fines.
Serious cases do not necessarily require every progressive step if law permits otherwise, but evidence/fact review is mandatory.
Written-warning validity / Labour Protection Act s.119 conditions must be reflected in final forms.
Status: PASS WITH LEGAL TEMPLATE REVIEW.

## L-15 — Absence and dismissal
Do not auto-terminate based on attendance status.
Section 119 serious-misconduct conditions must be assessed by facts. Official Ministry guidance confirms written-warning conditions and abandonment for 3 consecutive days (whether holiday intervenes or not) without reasonable cause as relevant s.119 grounds.
Status: PASS if system only flags cases for review.

## L-16 — Work regulations threshold
KMO currently has 5 employees. Section 108 formal written work-regulation duty applies when employer has 10+ employees.
KMO may voluntarily adopt written rules now, which is recommended. If headcount reaches 10, system must alert Owner because statutory formalities apply.
Source: Ministry of Labour e-Labour work regulations guidance.
Status: PASS.

## L-17 — Probation
KMO policy: 119 days; ADMIN alert 14 days before end.
Probation does not remove employee status or statutory rights. No automatic termination on day 119.
Status: PASS.

## L-18 — Employment contract
Indefinite-term employment; written contract required by KMO policy for new hires. Existing staff should sign current-date documentation rather than backdating.
Status: PASS.

## L-19 — Resignation / offboarding
Notice rule not yet hard-coded. Must align with Thai law and wage-payment cycle; do not invent a flat “30 days” until final legal drafting.
Offboarding may require handover and return of property but must not unlawfully withhold wages.
Status: OWNER/LEGAL CONFIRM.

## L-20 — Safety / PPE
Confirmed tasks: gas welding, grinding, steel cutting, drilling, press/bending machine, painting, motorcycle lifting/jacks, accessory installation.
Confirmed PPE: welding mask, safety glasses, gloves, paint-vapour respirator, safety shoes, hearing protection (available but often not worn).
Rules must require task-appropriate PPE. For required PPE, unsafe work stops until PPE is worn. Repeated refusal may enter disciplinary process after fact record.
Status: REMEDIATE — enforcement + documented training required.

## L-21 — Safety training
Current state: informal peer/on-the-job teaching only.
Create formal safety-training records. Verify which tasks require specific statutory training/qualified trainers before treating informal teaching as compliant.
Status: REMEDIATE.

## L-22 — Machinery / gas / fire
Confirmed: machinery listed above, fire extinguisher, oxygen cylinder, unknown paired fuel-gas type.
Need site checklist for guards, press safety, welding equipment, regulators/hoses/leak checks, cylinder restraint/storage, fire controls and inspection dates.
Fuel gas type = SITE CHECK REQUIRED.
Source: DLPW OSH machinery regulation B.E. 2564.
Status: REMEDIATE / SITE INSPECTION REQUIRED.

## L-23 — Noise
Grinding/cutting/press operations require noise-risk review. Hearing protection exists but is not consistently used.
Need determine whether statutory measurement/analysis and hearing-conservation requirements are triggered by actual exposure.
Source: DLPW heat/light/noise regulation B.E. 2559 and measurement guidance.
Status: REMEDIATE / MEASUREMENT ASSESSMENT REQUIRED.

## L-24 — Mobile phone / clothing / intoxicants / smoking
Approved KMO safety rules:
- no personal-phone use while actively performing hazardous tasks;
- no headphones during machinery/hazardous work;
- safe clothing, no sandals, loose clothing/jewellery; long hair secured; required PPE;
- no working while intoxicated; illegal drugs prohibited;
- smoking/vaping prohibited in work/hazard/gas/flammable areas; only designated safe area.
Status: PASS as internal safety rules, subject to final wording.

## L-25 — Customer vehicles/property
No road test rides.
No taking/using customer vehicle except authorized work handling.
Damage handled through incident/investigation; no automatic salary deduction.
Status: PASS.

## L-26 — Personal work / diversion of KMO customers
Personal vehicle/friend work may be allowed only with Owner permission; material/tool/space charges agreed with Owner.
KMO-originated customers/orders/business opportunities may not be diverted for personal receipt without Owner authorization.
Status: PASS.

## L-27 — Customer data / trade information
Customer personal data and genuine KMO confidential/trade information may only be used for authorized work purposes.
No personal copying, diversion or unauthorized disclosure.
Status: PASS, subject to PDPA notice/access/retention controls.

## L-28 — Social content
Employees may create personal content and earn income using KMO space if it does not disrupt work/safety or disclose customer data, confidential/unreleased KMO work, trade secrets or internal commercial terms.
Official-looking use of KMO name/logo or sponsorship relying on KMO brand requires Owner approval.
Status: PASS.

## L-29 — Tools/property leaving shop
Owner approval required before KMO tools/materials/parts/property leave the shop.
Status: PASS.

## L-30 — CCTV / PDPA
CCTV exists, employees informed and signs posted.
Still verify notice contents, purposes, access control, retention period and data-subject channel. “There is a sign” alone is not full PDPA compliance.
Status: REVIEW REQUIRED.

## L-31 — HR data / PDPA
Data minimization:
- no salary amount in HR V1;
- no ID-card image by default unless necessary for a defined legal/business purpose;
- sensitive incident/health evidence private and restricted;
- geolocation captured only for attendance purpose, with accuracy + timestamp and server-side geofence validation;
- audit logs for ADMIN changes.
Need Employee Privacy Notice + retention schedule + rights/contact channel before production.
Status: REMEDIATE.

## L-32 — Social Security
Whether all 5 employees are enrolled under s.33 is unknown.
Status: OWNER CONFIRM REQUIRED / HIGH PRIORITY.

# Gate decision

**REMEDIATE / STOP FINAL PUBLICATION**

Do not publish the final employee rules or enable OT/holiday-work automation until:
1. L-01 hazardous-work hours are resolved.
2. OT/holiday-work legal workflow is confirmed.
3. Safety training/site controls are assessed.
4. Social Security status is confirmed.
5. PDPA employee notice/retention/access controls are defined.

The most urgent finding is L-01: KMO's technicians perform welding, so the previously proposed 09:00–18:00 with 1-hour break cannot simply be approved as an 8-hour normal working day.


## Owner/Operations decisions — 2026-10-06

### Working hours — TEMPORARY DRAFT DECISION
Use KMO's stated operating schedule for the current draft: 09:00–18:00, total break 1 hour, Tuesday weekly holiday.
**LEGAL HOLD:** This is NOT marked legally cleared. Ministry of Labour guidance lists metal welding among hazardous work with a stricter normal-hours limit. Resolve this in back-office legal/operational review before final publication/enforcement. Do not represent the draft schedule as legally approved.

### Welding gases — corrected site information
KMO uses both CO2 and Argon. The earlier Google Form question framed the gas as paired with oxygen and produced an unreliable answer. Do not infer an oxygen/fuel-gas setup from that form. Future safety inventory must record each actual cylinder/process from its label and equipment configuration.

### Social Security — HOLD / VERIFY
Current operational report: employees were previously in the system, but registration/status changed after the prior company closed. Team suspects some may be continuing under Section 39 and paying contributions themselves.
Do NOT lock Section 39 as the correct classification yet. Section 39 is voluntary continuation for a former Section 33 insured person after ending employee status, subject to eligibility/time conditions. If the 5 people are currently KMO employees and KMO is an employer covered by Section 33, Section 33 employer registration duties may apply. Verify actual SSO status before final compliance sign-off.
