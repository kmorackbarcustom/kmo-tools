const test = require('node:test');
const assert = require('node:assert/strict');
const { normalizeAttendanceErrorCode } = require('../hr/assets/attendance-errors.js');

test('normalizes standard GeolocationPositionError codes', () => {
  assert.equal(normalizeAttendanceErrorCode({ code: 1 }), 'GEO_PERMISSION_DENIED');
  assert.equal(normalizeAttendanceErrorCode({ code: 2 }), 'GEO_UNAVAILABLE');
  assert.equal(normalizeAttendanceErrorCode({ code: 3 }), 'GEO_TIMEOUT');
});

test('does not expose unknown browser or server error text', () => {
  assert.equal(normalizeAttendanceErrorCode({ message: 'browser secret text' }), 'ATTENDANCE_REQUEST_FAILED');
  assert.equal(normalizeAttendanceErrorCode({ code: 'UNKNOWN_INTERNAL_CODE' }), 'ATTENDANCE_REQUEST_FAILED');
  assert.equal(normalizeAttendanceErrorCode({ message: 'GEO_UNSUPPORTED' }), 'GEO_UNSUPPORTED');
});
