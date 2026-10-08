const test = require('node:test');
const assert = require('node:assert/strict');
const history = require('../hr/assets/attendance-history.js');

const employees = [
  { id: 'active-a', employee_code: 'KMO-002', full_name: 'Bee', start_date: '2026-01-01', active: true },
  { id: 'active-b', employee_code: 'KMO-001', full_name: 'Ann', start_date: '2026-01-01', active: true },
  { id: 'inactive', employee_code: 'KMO-000', full_name: 'Former', start_date: '2025-01-01', active: false },
];

const event = (employee_id, event_type, occurred_at, id = `${employee_id}-${event_type}`) => ({
  id,
  employee_id,
  event_type,
  occurred_at,
});

test('uses Bangkok calendar date and UTC query boundaries', () => {
  assert.equal(history.getBangkokDate(new Date('2026-10-07T17:05:00.000Z')), '2026-10-08');
  assert.deepEqual(history.getBangkokDayRange('2026-10-08'), {
    startIso: '2026-10-07T17:00:00.000Z',
    endIso: '2026-10-08T17:00:00.000Z',
  });
  const range = history.getBangkokDayRange('2026-10-08');
  const belongsToDay = (timestamp) => timestamp >= range.startIso && timestamp < range.endIso;
  assert.equal(belongsToDay('2026-10-07T17:05:00.000Z'), true);
  assert.equal(belongsToDay('2026-10-08T17:00:00.000Z'), false);
  assert.equal(history.shiftDate('2026-01-01', -1), '2025-12-31');
  assert.equal(history.shiftDate('2024-03-01', -1), '2024-02-29');
});

test('formats recorded event times in Bangkok regardless of host timezone', () => {
  assert.equal(history.formatBangkokTime('2026-10-07T17:05:00.000Z'), '00:05');
  assert.equal(history.formatBangkokTimestamp('2026-10-07T17:05:09.000Z'), '08/10/2026, 00:05:09');
});

test('today includes active employees without records and recorded inactive employees', () => {
  const rows = history.buildRows(employees, [
    event('inactive', 'clock_in', '2026-10-07T17:05:00.000Z'),
  ], { date: '2026-10-08', todayDate: '2026-10-08' });

  assert.deepEqual(rows.map((row) => row.employee.id), ['inactive', 'active-b', 'active-a']);
  assert.equal(rows[0].statusKey, 'clock_in_only');
  assert.equal(rows[1].statusKey, 'no_event_today');
  assert.equal(rows[1].statusText, 'ยังไม่มีบันทึกวันนี้');
});

test('historical unfiltered dates show only employees with recorded events', () => {
  const rows = history.buildRows(employees, [
    event('inactive', 'clock_in', '2026-10-07T17:05:00.000Z'),
  ], { date: '2026-10-08', todayDate: '2026-10-09' });

  assert.deepEqual(rows.map((row) => row.employee.id), ['inactive']);
  assert.equal(history.buildRows(employees, [], { date: '2026-10-07', todayDate: '2026-10-09' }).length, 0);
});

test('selected employee with no event gets a neutral no-record message', () => {
  const rows = history.buildRows(employees, [], {
    date: '2026-10-07',
    todayDate: '2026-10-09',
    employeeId: 'active-a',
  });

  assert.equal(rows.length, 1);
  assert.equal(rows[0].statusKey, 'no_events');
  assert.equal(rows[0].statusText, 'ไม่พบรายการลงเวลาในวันที่เลือก');
});

test('classifies valid clock-in and clock-in/out pair from recorded facts', () => {
  const rows = history.buildRows(employees, [
    event('active-b', 'clock_in', '2026-10-07T17:00:00.000Z'),
    event('active-a', 'clock_in', '2026-10-07T17:01:00.000Z'),
    event('active-a', 'clock_out', '2026-10-08T10:00:00.000Z'),
  ], { date: '2026-10-08', todayDate: '2026-10-09' });

  assert.equal(rows.find((row) => row.employee.id === 'active-b').statusKey, 'clock_in_only');
  const pair = rows.find((row) => row.employee.id === 'active-a');
  assert.equal(pair.statusKey, 'complete');
  assert.equal(pair.events.length, 2);
});

test('flags clock-out only, duplicates, reversed order, unknown type, and orphan events', () => {
  const rows = history.buildRows(employees, [
    event('active-a', 'clock_out', '2026-10-07T18:00:00.000Z', 'out-only'),
    event('active-b', 'clock_in', '2026-10-07T17:00:00.000Z', 'in-1'),
    event('active-b', 'clock_in', '2026-10-07T17:01:00.000Z', 'in-2'),
    event('inactive', 'clock_out', '2026-10-07T17:00:00.000Z', 'reverse-out'),
    event('inactive', 'clock_in', '2026-10-07T18:00:00.000Z', 'reverse-in'),
    event('missing-employee', 'clock_in', '2026-10-07T17:00:00.000Z', 'orphan'),
    event('active-a', 'unknown', '2026-10-07T19:00:00.000Z', 'unknown'),
  ], { date: '2026-10-08', todayDate: '2026-10-09' });

  assert.ok(rows.every((row) => row.statusKey === 'review_required'));
  assert.equal(rows.find((row) => row.events[0].id === 'in-1').events.length, 2);
  assert.equal(rows.find((row) => row.events[0].id === 'orphan').employee.full_name, 'ไม่พบข้อมูลพนักงาน');
});

test('flags a clock-out at the same instant as clock-in as an unexpected sequence', () => {
  const rows = history.buildRows(employees, [
    event('active-a', 'clock_in', '2026-10-07T17:00:00.000Z', 'same-in'),
    event('active-a', 'clock_out', '2026-10-07T17:00:00.000Z', 'same-out'),
  ], { date: '2026-10-08', todayDate: '2026-10-09' });
  assert.equal(rows[0].statusKey, 'review_required');
});

test('rejects invalid date inputs instead of building an unbounded query range', () => {
  assert.throws(() => history.getBangkokDayRange('2026-02-30'), /Invalid date/);
  assert.throws(() => history.shiftDate('not-a-date', 1), /Invalid date/);
});

test('reads every page and preserves the requested Supabase offsets', async () => {
  const ranges = [];
  const rows = await history.fetchPagedRows(async (start, end) => {
    ranges.push([start, end]);
    if (start === 0) return { data: ['a', 'b'], error: null };
    return { data: ['c'], error: null };
  }, 2);

  assert.deepEqual(ranges, [[0, 1], [2, 3]]);
  assert.deepEqual(rows, ['a', 'b', 'c']);
});

test('does not turn paginated API errors or malformed responses into empty results', async () => {
  await assert.rejects(
    history.fetchPagedRows(async () => ({ data: null, error: new Error('denied') }), 2),
    /denied/,
  );
  await assert.rejects(
    history.fetchPagedRows(async () => ({ data: null, error: null }), 2),
    /Invalid paginated response/,
  );
});
