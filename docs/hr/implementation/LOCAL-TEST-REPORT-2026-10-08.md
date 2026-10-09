> Historical evidence snapshot captured 2026-10-08. Its Production, release, and cleanup status describes only that point in time and was superseded on 2026-10-09. For the final Production migration, release, live checks, and cleanup result, see [the final preflight and release report](PRODUCTION-PREFLIGHT-2026-10-08.md). Test results below are retained as recorded; the 22/22 SQL security run used the real isolated Supabase Local PostgreSQL database with synthetic data and rollback.

# KMO HR — Final Test & Release Gate Report

วันที่: 2026-10-08 (Asia/Bangkok)

## สรุป Gate

- Supabase Local Test: **PASS WITH RUNNER NOTE** — apply migration จริงบน Supabase Local และ SQL security test ผ่าน 22/22; CLI test runner ค้นไฟล์ไม่พบ จึงรันไฟล์เดิมด้วย psql เข้า Local DB โดยตรง
- Independent Review: **PASS WITH NOTES** — PR #1 PASS; PR #2 PASS WITH NOTES
- Production Release: **HOLD** — ยังไม่มีหลักฐาน Backup/Restore Point และพบ migration-history version ไม่ตรงกับชื่อไฟล์ใน branch
- Live Website Verification: **ยังไม่ทำ** — รอ Owner อนุมัติ Merge/Deploy
- Cleanup: **ยังไม่ทำ** — รอ Release ผ่านตาม Gate

## Source และสภาพแวดล้อม

- Repository: kmorackbarcustom/kmo-tools
- PR #1 head: 81d2fa5c3de819cb18321d0ddfeb7623c2af490d
- PR #2 head: 617af59582b9d7128d2213537edb4107f79dfc27 (ต่อจาก PR #1)
- Temporary workspace: /tmp/kmo-hr-final-test.uQUzVO/kmo-tools
- Temporary tools: /tmp/kmo-hr-final-test.uQUzVO/tooling/deno
- Colima profile: kmo-hr-release-test — Docker runtime, 4 CPU, 8 GiB RAM, 60 GiB disk
- Docker context: colima-kmo-hr-release-test
- Colima Default profile: ยังคง Stopped ตามเดิม ไม่ถูกแก้ไข
- Docker Server: 29.5.2 ภายใน profile ทดสอบ
- Supabase CLI: 2.116.0
- Supabase Local database: PostgreSQL 17.6.1.165
- Supabase CLI แสดง Not linked.; ไม่ได้เชื่อมต่อ Local stack กับ Cloud Production

## Supabase Local และ Migration Evidence

CLI สร้าง config เฉพาะใน temporary clone แล้วเริ่ม Supabase Local สำเร็จ การเริ่มระบบใช้ migration ทั้งห้าจาก branch ตามลำดับ:

1. 20261006174000_hr_v2_foundation.sql
2. 20261006175500_hr_v2_hardening_bootstrap.sql
3. 20261006201500_hr_line_employee_portal.sql
4. 20261006202500_hr_line_link_invoker.sql
5. 20261008053722_hr_attendance_service_role_only.sql

Local migration history แสดงครบทั้งห้าเวอร์ชัน

### Test Results

- `node --test tests/*.test.cjs`: **24 passed, 0 failed**
- `deno test tests/attendance-state.test.ts`: **7 passed, 0 failed**
- `deno check supabase/functions/kmo-hr-line/index.ts`: **ผ่าน**
- `git diff --check`: **ผ่าน**
- ไฟล์ `supabase/tests/hr_attendance_security.test.sql`: **22/22 assertions ผ่าน** บน Supabase Local PostgreSQL จริง ผ่าน pgTAP; ครอบคลุม direct INSERT denial สำหรับ anon/employee/admin, effective grants (รวม PUBLIC และ service_role), RLS/SELECT policies, RPC permission, clock-in/out sequence และ duplicate prevention
- SQL test ทำงานใน transaction และจบด้วย ROLLBACK; ใช้ synthetic data เท่านั้น
- ข้อจำกัด runner: `supabase test db --local` รายงาน no pgTAP tests found; เมื่อส่ง path ไฟล์ตรงพบ parser/path error ใน CLI runner จึงสร้าง pgTAP extension แล้ว pipe source SQL เดิมเข้า psql container ของ Supabase Local โดยตรง ผลทดสอบข้างต้นมาจากฐานข้อมูล Local จริง ไม่ใช่ PGlite
- ไม่ได้สร้าง test attendance ใน Production

## ผลกระทบ PR #1 ต่อ PR #2 และหน้าแรก

Independent Reviewer ตรวจ source ปัจจุบันแบบ read-only:
- PR #1: **PASS** — security migration ถอน INSERT จาก anon/authenticated/PUBLIC, คง INSERT ของ service_role, ลบเฉพาะ direct insert policy; RLS/SELECT และ service-only RPC ที่ใช้ advisory transaction lock ยังอยู่
- PR #2: **PASS WITH NOTES** — Attendance History ตรวจ active ADMIN ก่อนอ่านข้อมูล, ใช้ query แบบอ่านอย่างเดียว และรักษาขอบเขต RLS; หน้าแรกมีลิงก์ relative `hr/attendance.html` ที่ resolve ใต้ `/kmo-tools/` และยังคงทางลัด HR Admin
- รวม: **PASS WITH NOTES** — ไม่พบ source-level blocker; GitHub metadata ระบุทั้ง PR open/mergeable แต่ไม่มี status checks หรือ submitted review decision
- Reviewer ไม่ได้รันทดสอบ Local หรือ Live ซ้ำ; ผล execution ในรายงานนี้มาจากการทดสอบบน Mac ของผู้ทำงาน

## Production State Read-Only Check

Supabase project `kmo-hr` (`ybyseaenceyswjnwdmdf`) ตอบสถานะ ACTIVE_HEALTHY, PostgreSQL 17.6.1.084, region ap-northeast-2

Production migration history ล่าสุดที่เกี่ยวกับ HR:
- 20261006104402 — hr_v2_foundation
- 20261006104528 — hr_v2_hardening_bootstrap
- 20261006132912 — hr_line_employee_portal
- 20261006134110 — hr_line_link_invoker

Migration security ใหม่ยังไม่อยู่ใน Production history ซึ่งตรงกับขอบเขตที่คาดไว้ แต่ version ของ migrations เดิมใน Production **ไม่ตรง** กับ timestamp ของไฟล์ source ปัจจุบัน (20261006174000, 20261006175500, 20261006201500, 20261006202500) ห้ามใช้ `supabase db push` แบบกว้างจนกว่าจะ reconcile migration ledger เพื่อกันการ apply migration เก่าซ้ำ

ยังยืนยัน Backup/Restore Point ไม่ได้: Supabase connector ที่ใช้ให้ project metadata และ migration history แต่ไม่มี inventory ของ backup/restore point ให้ตรวจ จึงต้องให้ Owner/ผู้ดูแลยืนยัน backup ล่าสุดและวิธี restore ก่อน Release

## Prepared Production Plan (ยังไม่ดำเนินการ)

### ก่อน Migration

1. Owner/ผู้ดูแลยืนยัน backup/restore point ล่าสุด พร้อมเวลาและวิธี restore ที่ตรวจสอบแล้ว
2. Reconcile Production migration ledger กับ Git source เพราะ version ของ migration เดิมต่างกัน; ห้าม reapply migrations เดิมหรือใช้ bulk push จนกว่าจะยืนยันสถานะ
3. ยืนยันว่าการเปลี่ยนแปลงที่จะ apply มีเพียง forward migration `20261008053722_hr_attendance_service_role_only.sql`

### Apply และ Verify

หลังมี Owner approval และปิดข้อ 1–3 แล้ว:
1. Apply เฉพาะ security migration ผ่านวิธีที่บันทึก migration history ได้ถูกต้อง
2. ตรวจ catalog/grants แบบ read-only: ไม่มี INSERT สำหรับ anon/authenticated/PUBLIC; service_role ยังคง INSERT และ EXECUTE RPC
3. ตรวจว่า RLS เปิดอยู่, policy SELECT ยังอยู่, policy `hr_attendance_insert` ไม่มีแล้ว
4. ไม่เขียน attendance ทดสอบใน Production
5. ถ้า verification ไม่ผ่าน ให้หยุด Release ทันทีและเก็บ logs/evidence

### Recovery

- ถ้าการ apply ล้มเหลวก่อน commit: หยุด ตรวจ migration state และแก้สาเหตุก่อน retry
- ถ้า migration commit แล้วแต่ verification/การทำงานไม่ผ่าน: หยุด Merge/Deploy และใช้ restore procedure ที่ Owner ยืนยัน หรือทำ compensating forward migration หลังวิเคราะห์
- ห้ามเปิด direct INSERT ให้ authenticated กลับโดยอัตโนมัติ เพราะจะคืนช่องทางที่ migration นี้ปิด
- หลัง Production verification ผ่าน จึง Merge PR #1 → main แล้ว PR #2 → main; รอ GitHub Pages deploy ก่อน smoke test หน้าแรก, HR Admin, Attendance History และ Employee Portal พร้อมดู logs/errors และสิทธิ
- หาก smoke/permission check ไม่ผ่าน ให้หยุด Release และรายงาน Owner

## ยังไม่ดำเนินการ

ไม่มี Production write/migration, PR merge, Pages deployment, live website smoke test, หรือ cleanup ใด ๆ งานเหล่านี้รอ Owner approval และการยืนยัน backup/migration-history reconciliation ก่อน

Temporary workspace, Deno binary/cache, Local Supabase containers/images/volumes และ Colima profile ทดสอบยังคงอยู่ชั่วคราวเพื่อรักษาหลักฐาน Disk ก่อนเริ่ม: 484 GiB available. Disk หลัง cleanup: ยังไม่มี (ยังไม่ cleanup).

## Production Security State (Read-Only)

Catalog query on Production confirmed:
- anon direct attendance INSERT: **denied**
- authenticated direct attendance INSERT: **allowed**
- service_role attendance INSERT: **allowed**
- direct `hr_attendance_insert` policy: **still present**
- `hr_attendance_select` policy and attendance RLS: **present**
- RPC EXECUTE: anon/authenticated **denied**, service_role **allowed**

จึงยืนยันว่า security migration ใหม่ยังจำเป็นกับ Production; ช่องทาง authenticated direct INSERT ยังเปิดอยู่ในสภาพปัจจุบัน คำสั่งข้างต้นเป็น SELECT-only ไม่มีการ insert หรือแก้ไขข้อมูล Production
- PUBLIC direct attendance INSERT: **denied** (effective ACL check).