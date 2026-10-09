export type AttendanceEvent = {
  event_type: string;
  occurred_at: string;
};

export type AttendanceState =
  | "not_clocked_in"
  | "working"
  | "completed"
  | "review_required";

export type AttendanceSummary = {
  attendanceState: AttendanceState;
  nextAction: "clock_in" | "clock_out" | null;
  clockInAt: string | null;
  clockOutAt: string | null;
};

export function deriveAttendanceState(
  events: AttendanceEvent[],
): AttendanceSummary {
  const invalid = (): AttendanceSummary => ({
    attendanceState: "review_required",
    nextAction: null,
    clockInAt: null,
    clockOutAt: null,
  });

  if (events.length === 0) {
    return {
      attendanceState: "not_clocked_in",
      nextAction: "clock_in",
      clockInAt: null,
      clockOutAt: null,
    };
  }

  if (events.some((event) => !Number.isFinite(Date.parse(event.occurred_at)))) {
    return invalid();
  }

  if (events.length === 1 && events[0].event_type === "clock_in") {
    return {
      attendanceState: "working",
      nextAction: "clock_out",
      clockInAt: events[0].occurred_at,
      clockOutAt: null,
    };
  }

  if (
    events.length === 2 &&
    events[0].event_type === "clock_in" &&
    events[1].event_type === "clock_out" &&
    Date.parse(events[0].occurred_at) <= Date.parse(events[1].occurred_at)
  ) {
    return {
      attendanceState: "completed",
      nextAction: null,
      clockInAt: events[0].occurred_at,
      clockOutAt: events[1].occurred_at,
    };
  }

  return invalid();
}

export function isValidLocation(location: Record<string, unknown>) {
  const { latitude, longitude, accuracy } = location;
  return typeof latitude === "number" && Number.isFinite(latitude) &&
    latitude >= -90 && latitude <= 90 &&
    typeof longitude === "number" && Number.isFinite(longitude) &&
    longitude >= -180 && longitude <= 180 &&
    typeof accuracy === "number" && Number.isFinite(accuracy) &&
    accuracy >= 0 && accuracy <= 5000;
}

export function normalizeRpcAttendanceError(message: string) {
  const known: Array<[string, string]> = [
    ["outside the KMO attendance geofence", "OUTSIDE_GEOFENCE"],
    ["Location accuracy is outside", "GPS_ACCURACY_TOO_LOW"],
    ["worksite geofence is not configured", "WORKSITE_NOT_CONFIGURED"],
    ["already been recorded", "ATTENDANCE_STATE_CHANGED"],
    ["Clock-in is required", "ATTENDANCE_STATE_CHANGED"],
  ];
  return known.find(([needle]) => message.includes(needle))?.[1] ??
    "ATTENDANCE_REJECTED";
}
