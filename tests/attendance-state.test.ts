import {
  deriveAttendanceState,
  isValidLocation,
  normalizeRpcAttendanceError,
} from "../supabase/functions/kmo-hr-line/attendance_state.ts";

Deno.test("no events expects clock-in", () => {
  const state = deriveAttendanceState([]);
  if (
    state.attendanceState !== "not_clocked_in" ||
    state.nextAction !== "clock_in"
  ) {
    throw new Error(`unexpected state: ${JSON.stringify(state)}`);
  }
});

Deno.test("clock-in only expects clock-out", () => {
  const state = deriveAttendanceState([
    { event_type: "clock_in", occurred_at: "2026-10-07T02:00:00.000Z" },
  ]);
  if (state.attendanceState !== "working" || state.nextAction !== "clock_out") {
    throw new Error(`unexpected state: ${JSON.stringify(state)}`);
  }
});

Deno.test("clock-in and later clock-out is complete", () => {
  const state = deriveAttendanceState([
    { event_type: "clock_in", occurred_at: "2026-10-07T02:00:00.000Z" },
    { event_type: "clock_out", occurred_at: "2026-10-07T11:00:00.000Z" },
  ]);
  if (state.attendanceState !== "completed" || state.nextAction !== null) {
    throw new Error(`unexpected state: ${JSON.stringify(state)}`);
  }
});

Deno.test("orphan, duplicate, and reversed events require review", () => {
  const cases = [
    [{ event_type: "clock_out", occurred_at: "2026-10-07T11:00:00.000Z" }],
    [
      { event_type: "clock_in", occurred_at: "2026-10-07T02:00:00.000Z" },
      { event_type: "clock_in", occurred_at: "2026-10-07T03:00:00.000Z" },
    ],
    [
      { event_type: "clock_out", occurred_at: "2026-10-07T02:00:00.000Z" },
      { event_type: "clock_in", occurred_at: "2026-10-07T03:00:00.000Z" },
    ],
  ];
  for (const events of cases) {
    if (deriveAttendanceState(events).attendanceState !== "review_required") {
      throw new Error(
        `corrupt state was not rejected: ${JSON.stringify(events)}`,
      );
    }
  }
});

Deno.test("location validation rejects malformed or out-of-range coordinates", () => {
  if (!isValidLocation({ latitude: 13.7, longitude: 100.5, accuracy: 20 })) {
    throw new Error("valid location was rejected");
  }
  for (
    const location of [
      { latitude: "13.7", longitude: 100.5, accuracy: 20 },
      { latitude: 91, longitude: 100.5, accuracy: 20 },
      { latitude: 13.7, longitude: 181, accuracy: 20 },
      { latitude: 13.7, longitude: 100.5, accuracy: 5001 },
    ]
  ) {
    if (isValidLocation(location)) {
      throw new Error(
        `invalid location was accepted: ${JSON.stringify(location)}`,
      );
    }
  }
});

Deno.test("RPC sequence conflicts normalize to a safe stale-state code", () => {
  for (
    const message of [
      "Clock-in has already been recorded for today",
      "Clock-out has already been recorded for today",
      "Clock-in is required before clock-out",
    ]
  ) {
    if (normalizeRpcAttendanceError(message) !== "ATTENDANCE_STATE_CHANGED") {
      throw new Error(`conflict was not normalized: ${message}`);
    }
  }
});

Deno.test("RPC location rejections keep their stable error codes", () => {
  const cases = [
    ["Location is outside the KMO attendance geofence", "OUTSIDE_GEOFENCE"],
    ["Location accuracy is outside the allowed range", "GPS_ACCURACY_TOO_LOW"],
    ["worksite geofence is not configured", "WORKSITE_NOT_CONFIGURED"],
  ];
  for (const [message, expected] of cases) {
    if (normalizeRpcAttendanceError(message) !== expected) {
      throw new Error(`unexpected error mapping for ${message}`);
    }
  }
});
