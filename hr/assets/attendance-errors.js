(function (root) {
  const knownCodes = new Set([
    'LINE_ID_TOKEN_REQUIRED', 'LINE_ID_TOKEN_INVALID', 'LINE_ID_TOKEN_EXPIRED',
    'LINE_CHANNEL_MISMATCH', 'EMPLOYEE_INACTIVE', 'OUTSIDE_GEOFENCE',
    'GPS_ACCURACY_TOO_LOW', 'WORKSITE_NOT_CONFIGURED', 'INVALID_ATTENDANCE_INPUT',
    'ATTENDANCE_ALREADY_COMPLETE', 'ATTENDANCE_STATE_CHANGED',
    'ATTENDANCE_REVIEW_REQUIRED', 'ATTENDANCE_REJECTED', 'STATUS_FAILED',
  ]);

  function normalizeAttendanceErrorCode(error) {
    if (error?.message === 'GEO_UNSUPPORTED') return 'GEO_UNSUPPORTED';
    if (typeof error?.code === 'number') {
      if (error.code === 1) return 'GEO_PERMISSION_DENIED';
      if (error.code === 2) return 'GEO_UNAVAILABLE';
      if (error.code === 3) return 'GEO_TIMEOUT';
      return 'GEO_UNAVAILABLE';
    }
    const code = typeof error?.code === 'string' ? error.code : '';
    return knownCodes.has(code) ? code : 'ATTENDANCE_REQUEST_FAILED';
  }

  root.normalizeAttendanceErrorCode = normalizeAttendanceErrorCode;
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = { normalizeAttendanceErrorCode };
  }
})(globalThis);
