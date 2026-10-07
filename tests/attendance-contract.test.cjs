const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const edge = fs.readFileSync('supabase/functions/kmo-hr-line/index.ts', 'utf8');
const migration = fs.readFileSync('supabase/migrations/20261006201500_hr_line_employee_portal.sql', 'utf8');

test('Edge derives the event from server status and never reads client eventType', () => {
  assert.doesNotMatch(edge, /input\.eventType/);
  assert.match(edge, /const eventType = before\.nextAction;/);
  assert.match(edge, /before = await buildStatus\(\)/);
});

test('existing attendance RPC remains service-only and transaction-locked', () => {
  assert.match(migration, /pg_advisory_xact_lock\(hashtextextended\(p_employee_id::text \|\| ':' \|\| v_day::text, 0\)\)/);
  assert.match(migration, /grant execute on function public\.hr_record_line_attendance[\s\S]*?to service_role;/);
  assert.match(migration, /revoke all on function public\.hr_record_line_attendance[\s\S]*?from public, anon, authenticated;/);
});
