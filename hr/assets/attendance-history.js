(function attachAttendanceHistory(root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (root) root.KmoAttendanceHistory = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function createAttendanceHistory() {
  'use strict';

  const BANGKOK_OFFSET_MS = 7 * 60 * 60 * 1000;
  const datePattern = /^\d{4}-\d{2}-\d{2}$/;

  function parseDate(dateValue) {
    if (typeof dateValue !== 'string' || !datePattern.test(dateValue)) {
      throw new Error('Invalid date');
    }
    const parsed = new Date(`${dateValue}T00:00:00.000Z`);
    if (!Number.isFinite(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== dateValue) {
      throw new Error('Invalid date');
    }
    return parsed;
  }

  function getBangkokDate(now = new Date()) {
    const parts = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Bangkok',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).formatToParts(now);
    const fields = Object.fromEntries(parts.map((part) => [part.type, part.value]));
    return `${fields.year}-${fields.month}-${fields.day}`;
  }

  function shiftDate(dateValue, amount) {
    if (!Number.isInteger(amount)) throw new Error('Invalid date offset');
    const date = parseDate(dateValue);
    date.setUTCDate(date.getUTCDate() + amount);
    return date.toISOString().slice(0, 10);
  }

  function getBangkokDayRange(dateValue) {
    const startDate = parseDate(dateValue);
    const endDate = parseDate(shiftDate(dateValue, 1));
    return {
      startIso: new Date(startDate.getTime() - BANGKOK_OFFSET_MS).toISOString(),
      endIso: new Date(endDate.getTime() - BANGKOK_OFFSET_MS).toISOString(),
    };
  }

  function formatBangkokTime(timestamp) {
    const date = new Date(timestamp);
    if (!Number.isFinite(date.getTime())) return 'เวลาไม่ถูกต้อง';
    return new Intl.DateTimeFormat('en-GB', {
      timeZone: 'Asia/Bangkok',
      hour: '2-digit',
      minute: '2-digit',
      hourCycle: 'h23',
    }).format(date);
  }

  function formatBangkokTimestamp(timestamp) {
    const date = new Date(timestamp);
    if (!Number.isFinite(date.getTime())) return 'เวลาไม่ถูกต้อง';
    return new Intl.DateTimeFormat('en-GB', {
      timeZone: 'Asia/Bangkok',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hourCycle: 'h23',
    }).format(date);
  }

  async function fetchPagedRows(createQuery, pageSize = 500) {
    if (!Number.isInteger(pageSize) || pageSize < 1) throw new Error('Invalid page size');
    const rows = [];
    for (let offset = 0; ; offset += pageSize) {
      const { data, error } = await createQuery(offset, offset + pageSize - 1);
      if (error) throw error;
      if (!Array.isArray(data)) throw new Error('Invalid paginated response');
      rows.push(...data);
      if (data.length < pageSize) return rows;
    }
  }

  function compareText(left, right) {
    return String(left ?? '').localeCompare(String(right ?? ''), 'th', { numeric: true, sensitivity: 'base' });
  }

  function compareEmployees(left, right) {
    return compareText(left.employee_code || '', right.employee_code || '')
      || compareText(left.full_name || '', right.full_name || '')
      || compareText(left.id || '', right.id || '');
  }

  function classifyEvents(events) {
    const sortedEvents = [...events].sort((left, right) => {
      const timeDelta = new Date(left.occurred_at).getTime() - new Date(right.occurred_at).getTime();
      if (Number.isFinite(timeDelta) && timeDelta !== 0) return timeDelta;
      return compareText(left.id, right.id);
    });
    const clockIns = sortedEvents.filter((event) => event.event_type === 'clock_in');
    const clockOuts = sortedEvents.filter((event) => event.event_type === 'clock_out');
    const invalidTimestamp = sortedEvents.some((event) => !Number.isFinite(new Date(event.occurred_at).getTime()));
    const unexpectedType = sortedEvents.some((event) => !['clock_in', 'clock_out'].includes(event.event_type));
    const reversedSequence = clockIns.length === 1 && clockOuts.length === 1
      && new Date(clockOuts[0].occurred_at).getTime() <= new Date(clockIns[0].occurred_at).getTime();

    if (invalidTimestamp || unexpectedType || clockIns.length > 1 || clockOuts.length > 1
      || clockOuts.length > 0 && clockIns.length === 0 || reversedSequence) {
      return { statusKey: 'review_required', statusText: 'ข้อมูลต้องตรวจสอบ', clockIn: null, clockOut: null, events: sortedEvents };
    }

    return {
      statusKey: clockIns.length === 1 && clockOuts.length === 1 ? 'complete' : 'clock_in_only',
      statusText: clockIns.length === 1 && clockOuts.length === 1
        ? 'ลงเวลาครบ'
        : 'มีเวลาเข้า · ยังไม่มีเวลาออก',
      clockIn: clockIns[0] || null,
      clockOut: clockOuts[0] || null,
      events: sortedEvents,
    };
  }

  function buildRows(employees, events, options) {
    const { date, todayDate, employeeId = '' } = options || {};
    parseDate(date);
    parseDate(todayDate);
    const employeeMap = new Map((employees || []).map((employee) => [employee.id, employee]));
    const eventGroups = new Map();

    for (const event of events || []) {
      if (employeeId && event.employee_id !== employeeId) continue;
      const key = event.employee_id || '';
      if (!eventGroups.has(key)) eventGroups.set(key, []);
      eventGroups.get(key).push(event);
    }

    let employeeIds;
    if (employeeId) {
      employeeIds = [employeeId];
    } else if (date === todayDate) {
      const ids = new Set((employees || []).filter((employee) => employee.active).map((employee) => employee.id));
      for (const id of eventGroups.keys()) ids.add(id);
      employeeIds = [...ids];
    } else {
      employeeIds = [...eventGroups.keys()];
    }

    return employeeIds.map((id) => {
      const employee = employeeMap.get(id) || {
        id,
        employee_code: '',
        full_name: 'ไม่พบข้อมูลพนักงาน',
        active: false,
      };
      const employeeEvents = eventGroups.get(id) || [];
      if (!employeeEvents.length) {
        return {
          employee,
          events: [],
          clockIn: null,
          clockOut: null,
          statusKey: date === todayDate && employee.active && !employeeId ? 'no_event_today' : 'no_events',
          statusText: date === todayDate && employee.active && !employeeId
            ? 'ยังไม่มีบันทึกวันนี้'
            : 'ไม่พบรายการลงเวลาในวันที่เลือก',
        };
      }
      if (!employeeMap.has(id)) {
        return {
          employee,
          events: [...employeeEvents].sort((left, right) => {
            const timeDelta = new Date(left.occurred_at).getTime() - new Date(right.occurred_at).getTime();
            if (Number.isFinite(timeDelta) && timeDelta !== 0) return timeDelta;
            return compareText(left.id, right.id);
          }),
          clockIn: null,
          clockOut: null,
          statusKey: 'review_required',
          statusText: 'ข้อมูลต้องตรวจสอบ',
        };
      }
      return { employee, ...classifyEvents(employeeEvents) };
    }).sort((left, right) => compareEmployees(left.employee, right.employee));
  }

  return {
    buildRows,
    fetchPagedRows,
    formatBangkokTime,
    formatBangkokTimestamp,
    getBangkokDate,
    getBangkokDayRange,
    shiftDate,
  };
});
