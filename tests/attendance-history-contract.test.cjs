const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const page = fs.readFileSync('hr/attendance.html', 'utf8');
const admin = fs.readFileSync('hr/admin.html', 'utf8');
const migration = fs.readFileSync('supabase/migrations/20261006174000_hr_v2_foundation.sql', 'utf8');

test('Admin links to the read-only attendance history page', () => {
  assert.match(admin, /href="attendance\.html"[^>]*>บันทึกเวลาทำงาน</);
  assert.match(page, /href="admin\.html"[^>]*>กลับหน้า Admin</);
});

test('page verifies active ADMIN membership before showing data', () => {
  assert.match(page, /db\.from\('hr_admins'\)[\s\S]*?\.eq\('user_id', data\.session\.user\.id\)[\s\S]*?\.eq\('active', true\)/);
  assert.match(page, /if \(!adminResult\.data\)[\s\S]*?db\.auth\.signOut\(\)/);
  assert.match(page, /db\.from\('hr_employees'\)/);
  assert.match(page, /db\.from\('hr_attendance_events'\)/);
  assert.match(migration, /create policy hr_employees_select[\s\S]*?or kmo_hr_private\.is_admin\(\(select auth\.uid\(\)\)\)/);
  assert.match(migration, /create policy hr_attendance_select[\s\S]*?or kmo_hr_private\.is_admin\(\(select auth\.uid\(\)\)\)/);
});

test('queries only approved fields and bounds every list query with pagination', () => {
  assert.match(page, /\.select\('id,employee_code,full_name,start_date,active'\)/);
  assert.match(page, /\.select\('id,employee_id,event_type,occurred_at'\)/);
  assert.match(page, /\.gte\('occurred_at', startIso\)[\s\S]*?\.lt\('occurred_at', endIso\)/);
  assert.match(page, /\.range\(offset, end\)/);
  assert.match(page, /async function fetchAllEmployees\(\)[\s\S]*?history\.fetchPagedRows\(/);
  assert.match(page, /async function fetchDayEvents\(date, employeeId\)[\s\S]*?history\.fetchPagedRows\(/);
  assert.doesNotMatch(page, /service_role|latitude|longitude|accuracy_m|provider_subject/);
  assert.doesNotMatch(page, /\.insert\(|\.update\(|\.delete\(|\.rpc\(/);
});

test('employee names, codes, and event details are rendered with textContent', () => {
  assert.match(page, /option\.textContent = `\$\{employee\.employee_code/);
  assert.match(page, /cell\.textContent = value/);
  assert.match(page, /item\.textContent = `\$\{eventType\}/);
  assert.doesNotMatch(page, /\.innerHTML\s*=/);
});

test('inline page script parses as JavaScript', () => {
  const scripts = [...page.matchAll(/<script>([\s\S]*?)<\/script>/g)];
  assert.equal(scripts.length, 1);
  assert.doesNotThrow(() => new vm.Script(scripts[0][1], { filename: 'hr/attendance.html' }));
});
