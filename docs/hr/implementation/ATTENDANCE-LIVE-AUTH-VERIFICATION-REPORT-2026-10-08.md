# KMO HR — Live Auth Verification Report

วันที่บันทึก: 2026-10-08 (Asia/Bangkok)

## แหล่งที่มาของหลักฐาน

ผลด้านล่างเป็นผลทดสอบที่ **Owner ยืนยัน** ผ่านระบบ KMO HR จริง ไม่ใช่ผลที่ Codex หรือ Independent Reviewer ทำซ้ำเอง

## ผลที่ Owner ยืนยัน

| Scenario | ผล | หลักฐานที่ Owner รายงาน |
|---|---|---|
| Admin Login และดู Attendance จริง | PASS | เข้าหน้าและอ่าน Attendance จริงได้ |
| Admin เลือกดูย้อนหลัง | PASS | เปลี่ยนเป็นวันที่ย้อนหลังและดูได้ |
| Admin Logout | PASS | Logout สำเร็จ |
| Non-admin UI ถูกปฏิเสธ | PASS | UI ปฏิเสธการเข้าถึง |
| Non-admin RLS: `hr_employees` | PASS | `count=0`, `error=null` |
| Non-admin RLS: `hr_attendance_events` | PASS | `count=0`, `error=null` |

## ขอบเขตของผล

- การยืนยันเป็น Owner-reported evidence; ไม่มี credentials, token, PII หรือ raw attendance rows ถูกบันทึกในรายงานนี้.
- ผลนี้ยืนยัน non-admin SELECT isolation ตามสอง query ที่ Owner ระบุ; ไม่ได้ยืนยัน live INSERT denial หรือปิดช่องทาง direct authenticated INSERT ที่ตรวจพบใน migration.
- ไม่ได้ทดสอบการเขียน/แก้/ลบ attendance ใน Production ในงานนี้.
- ผลนี้ไม่ใช่การอนุมัติ Merge หรือ Deploy.

## Source branch ที่เตรียมทดสอบ

- Hardening PR: `codex/hr-attendance-ux-hardening-20261007` @ `2ce2add561a3fdbbafe56cb5c52fd67e48268ce3`
- Attendance History PR: `codex/attendance-history-v1-20261008` @ `e47bab0d854fd7418ee440c607ba2e3a534837eb`
- Preview URL: `http://127.0.0.1:4173/hr/attendance.html`

## ข้อสรุป

**Live Auth Gate: PASS ตามการยืนยันของ Owner สำหรับ Admin UI/read flow และ Non-admin SELECT isolation ที่ระบุข้างต้น.** Security review ของ source ยังมี finding เรื่อง direct authenticated INSERT/state integrity แยกต่างหาก; ให้ติดตามใน Review Report ก่อนตัดสิน Merge.
