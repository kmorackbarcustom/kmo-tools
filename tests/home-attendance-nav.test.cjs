const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const home = fs.readFileSync('index.html', 'utf8');

test('KMO Tools home links to Attendance History using the existing card pattern', () => {
  const card = home.match(/<a\s+class="card"\s+href="hr\/attendance\.html">([\s\S]*?)<\/a>/i);

  assert.ok(card, 'expected an Attendance History card with a project-relative path');
  assert.match(card[1], /<div\s+class="t">ประวัติเวลาทำงาน<\/div>/);
  assert.match(card[1], /<div\s+class="d">ดูเวลาเข้า–ออกงาน · เลือกวันที่ย้อนหลัง · ค้นหาพนักงาน<\/div>/);
  assert.equal(new URL('hr/attendance.html', 'https://kmorackbarcustom.github.io/kmo-tools/').pathname, '/kmo-tools/hr/attendance.html');
});

test('existing HR Admin home card remains available', () => {
  assert.match(home, /<a\s+class="card"\s+href="hr\/admin\.html">[\s\S]*?<div\s+class="t">KMO HR — Admin<\/div>/i);
});
