import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const LINE_CHANNEL_ID = "2011901861";
const ALLOWED_ORIGIN = "https://kmorackbarcustom.github.io";

const corsHeaders = {
  "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
  "Access-Control-Allow-Headers": "content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};

type LineProfile = {
  sub: string;
  aud?: string;
  exp?: number;
  name?: string;
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
  });
}

function isAllowedOrigin(req: Request) {
  const origin = req.headers.get("origin");
  return !origin || origin === ALLOWED_ORIGIN;
}

async function verifyLineIdToken(idToken: string): Promise<LineProfile> {
  const body = new URLSearchParams({
    id_token: idToken,
    client_id: LINE_CHANNEL_ID,
  });

  const response = await fetch("https://api.line.me/oauth2/v2.1/verify", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });

  const payload = await response.json().catch(() => null);
  if (!response.ok || !payload?.sub) {
    throw new Error("LINE_ID_TOKEN_INVALID");
  }

  if (String(payload.aud ?? "") !== LINE_CHANNEL_ID) {
    throw new Error("LINE_CHANNEL_MISMATCH");
  }

  if (payload.exp && Number(payload.exp) <= Math.floor(Date.now() / 1000)) {
    throw new Error("LINE_ID_TOKEN_EXPIRED");
  }

  return {
    sub: String(payload.sub),
    aud: String(payload.aud ?? ""),
    exp: Number(payload.exp ?? 0),
    name: typeof payload.name === "string" ? payload.name.slice(0, 100) : undefined,
  };
}

function bangkokDateString(now = new Date()) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Bangkok",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(now);
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? "";
  return `${get("year")}-${get("month")}-${get("day")}`;
}

function bangkokDayBounds(dateString: string) {
  const startMs = new Date(`${dateString}T00:00:00+07:00`).getTime();
  return {
    start: new Date(startMs).toISOString(),
    end: new Date(startMs + 24 * 60 * 60 * 1000).toISOString(),
  };
}

function localMinutes(iso: string) {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Asia/Bangkok",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(new Date(iso));
  const hour = Number(parts.find((p) => p.type === "hour")?.value ?? 0);
  const minute = Number(parts.find((p) => p.type === "minute")?.value ?? 0);
  return hour * 60 + minute;
}

function timeStringMinutes(value: string) {
  const [h, m] = value.split(":").map(Number);
  return h * 60 + m;
}

function classifyEvent(
  event: { event_type: string; occurred_at: string },
  schedule: { work_start: string; work_end: string; grace_minutes: number },
) {
  const minute = localMinutes(event.occurred_at);
  if (event.event_type === "clock_in") {
    const start = timeStringMinutes(schedule.work_start);
    if (minute <= start) return "on_time";
    if (minute <= start + Number(schedule.grace_minutes ?? 0)) return "grace";
    return "late";
  }

  const end = timeStringMinutes(schedule.work_end);
  if (minute < end) return "early_leave";
  if (minute > end) return "after_hours_review";
  return "clocked_out";
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") return json({ error: "METHOD_NOT_ALLOWED" }, 405);
  if (!isAllowedOrigin(req)) return json({ error: "ORIGIN_NOT_ALLOWED" }, 403);

  let input: Record<string, unknown>;
  try {
    input = await req.json();
  } catch {
    return json({ error: "INVALID_JSON" }, 400);
  }

  const idToken = typeof input.idToken === "string" ? input.idToken : "";
  if (!idToken || idToken.length > 8192) {
    return json({ error: "LINE_ID_TOKEN_REQUIRED" }, 401);
  }

  let line: LineProfile;
  try {
    line = await verifyLineIdToken(idToken);
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "LINE_AUTH_FAILED" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    console.error("Missing Supabase Edge Function environment");
    return json({ error: "SERVER_CONFIG_ERROR" }, 500);
  }

  const db = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: identity, error: identityError } = await db
    .from("hr_employee_identities")
    .select("employee_id")
    .eq("provider", "line")
    .eq("provider_subject", line.sub)
    .eq("active", true)
    .maybeSingle();

  if (identityError) {
    console.error("identity lookup failed", identityError);
    return json({ error: "IDENTITY_LOOKUP_FAILED" }, 500);
  }

  if (!identity) {
    const { data: existingRequest } = await db
      .from("hr_line_link_requests")
      .select("id,status")
      .eq("provider_subject", line.sub)
      .maybeSingle();

    if (existingRequest) {
      const { error: updateError } = await db
        .from("hr_line_link_requests")
        .update({
          display_name: line.name ?? null,
          last_seen_at: new Date().toISOString(),
        })
        .eq("id", existingRequest.id);

      if (updateError) console.error("link request touch failed", updateError);

      return json({
        linked: false,
        linkStatus: existingRequest.status,
        displayName: line.name ?? null,
      });
    }

    const { error: insertError } = await db
      .from("hr_line_link_requests")
      .insert({
        provider_subject: line.sub,
        display_name: line.name ?? null,
        status: "pending",
      });

    if (insertError) {
      console.error("link request insert failed", insertError);
      return json({ error: "LINK_REQUEST_FAILED" }, 500);
    }

    return json({
      linked: false,
      linkStatus: "pending",
      displayName: line.name ?? null,
    });
  }

  const { data: employee, error: employeeError } = await db
    .from("hr_employees")
    .select("id,employee_code,full_name,active,employment_status")
    .eq("id", identity.employee_id)
    .maybeSingle();

  if (employeeError) {
    console.error("employee lookup failed", employeeError);
    return json({ error: "EMPLOYEE_LOOKUP_FAILED" }, 500);
  }

  if (!employee?.active || employee.employment_status !== "active") {
    return json({ error: "EMPLOYEE_INACTIVE" }, 403);
  }

  async function buildStatus() {
    const [scheduleResult, worksiteResult] = await Promise.all([
      db.from("hr_schedule_config")
        .select("timezone,work_start,work_end,break_minutes,grace_minutes,weekly_holiday_dow")
        .eq("singleton", true)
        .single(),
      db.from("hr_worksites")
        .select("id")
        .eq("active", true)
        .limit(1),
    ]);

    if (scheduleResult.error) throw scheduleResult.error;

    const date = bangkokDateString();
    const bounds = bangkokDayBounds(date);
    const { data: events, error: eventsError } = await db
      .from("hr_attendance_events")
      .select("id,event_type,occurred_at,distance_m")
      .eq("employee_id", employee.id)
      .gte("occurred_at", bounds.start)
      .lt("occurred_at", bounds.end)
      .order("occurred_at", { ascending: true });

    if (eventsError) throw eventsError;

    const schedule = scheduleResult.data;
    const typedEvents = (events ?? []).map((event) => ({
      ...event,
      attendance_status: classifyEvent(event, schedule),
    }));

    const hasIn = typedEvents.some((e) => e.event_type === "clock_in");
    const hasOut = typedEvents.some((e) => e.event_type === "clock_out");
    const nextAction = !hasIn ? "clock_in" : !hasOut ? "clock_out" : null;

    const weekday = new Intl.DateTimeFormat("en-US", {
      timeZone: "Asia/Bangkok",
      weekday: "short",
    }).format(new Date());
    const dowMap: Record<string, number> = {
      Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6,
    };

    return {
      linked: true,
      employee: {
        id: employee.id,
        employeeCode: employee.employee_code,
        fullName: employee.full_name,
      },
      date,
      worksiteReady: (worksiteResult.data?.length ?? 0) > 0,
      dayKind: dowMap[weekday] === schedule.weekly_holiday_dow ? "weekly_holiday" : "regular",
      schedule: {
        workStart: schedule.work_start,
        workEnd: schedule.work_end,
        graceMinutes: schedule.grace_minutes,
      },
      events: typedEvents,
      nextAction,
    };
  }

  const action = typeof input.action === "string" ? input.action : "status";

  if (action === "status") {
    try {
      return json(await buildStatus());
    } catch (error) {
      console.error("status failed", error);
      return json({ error: "STATUS_FAILED" }, 500);
    }
  }

  if (action !== "clock") return json({ error: "INVALID_ACTION" }, 400);

  const eventType = input.eventType === "clock_out" ? "clock_out"
    : input.eventType === "clock_in" ? "clock_in"
    : "";
  const location = input.location && typeof input.location === "object"
    ? input.location as Record<string, unknown>
    : {};

  const latitude = Number(location.latitude);
  const longitude = Number(location.longitude);
  const accuracy = Number(location.accuracy);

  if (
    !eventType ||
    !Number.isFinite(latitude) || latitude < -90 || latitude > 90 ||
    !Number.isFinite(longitude) || longitude < -180 || longitude > 180 ||
    !Number.isFinite(accuracy) || accuracy < 0 || accuracy > 5000
  ) {
    return json({ error: "INVALID_ATTENDANCE_INPUT" }, 400);
  }

  const { data: eventRows, error: rpcError } = await db.rpc("hr_record_line_attendance", {
    p_employee_id: employee.id,
    p_event_type: eventType,
    p_latitude: latitude,
    p_longitude: longitude,
    p_accuracy_m: accuracy,
  });

  if (rpcError) {
    const message = String(rpcError.message ?? "");
    const known = [
      ["outside the KMO attendance geofence", "OUTSIDE_GEOFENCE"],
      ["Location accuracy is outside", "GPS_ACCURACY_TOO_LOW"],
      ["already been recorded", "ALREADY_RECORDED"],
      ["Clock-in is required", "CLOCK_IN_REQUIRED"],
      ["worksite geofence is not configured", "WORKSITE_NOT_CONFIGURED"],
    ].find(([needle]) => message.includes(needle));

    console.warn("attendance rejected", known?.[1] ?? "ATTENDANCE_REJECTED");
    return json({ error: known?.[1] ?? "ATTENDANCE_REJECTED" }, 409);
  }

  try {
    const status = await buildStatus();
    return json({
      ok: true,
      event: Array.isArray(eventRows) ? eventRows[0] ?? null : eventRows,
      ...status,
    });
  } catch (error) {
    console.error("post-clock status failed", error);
    return json({
      ok: true,
      event: Array.isArray(eventRows) ? eventRows[0] ?? null : eventRows,
    });
  }
});
