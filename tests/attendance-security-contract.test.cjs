const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const migrationsDir = path.join(__dirname, '..', 'supabase', 'migrations');

test('attendance INSERT lockdown is a forward-only migration and preserves the read/RPC boundary', () => {
  const names = fs.readdirSync(migrationsDir).filter((name) =>
    /^\d+_hr_attendance_service_role_only\.sql$/.test(name)
  );

  assert.equal(names.length, 1, 'expected one generated service-role-only migration');

  const migration = fs.readFileSync(path.join(migrationsDir, names[0]), 'utf8');
  assert.match(migration, /revoke\s+insert\s+on\s+(?:table\s+)?public\.hr_attendance_events\s+from\s+anon\s*,\s*authenticated\s*,\s*public\s*;/i);
  assert.match(migration, /drop\s+policy\s+if\s+exists\s+hr_attendance_insert\s+on\s+public\.hr_attendance_events\s*;/i);
  assert.doesNotMatch(migration, /drop\s+policy\s+if\s+exists\s+hr_attendance_select/i);
  assert.doesNotMatch(migration, /revoke\s+insert\s+on\s+(?:table\s+)?public\.hr_attendance_events\s+from\s+[^;]*service_role/i);
});
