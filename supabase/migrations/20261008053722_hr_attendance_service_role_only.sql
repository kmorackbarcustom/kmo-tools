-- Attendance events must be written only by the server-authoritative RPC.
-- Preserve the Edge Function's service_role insert privilege while closing the
-- direct Data API path for anonymous and authenticated users.
revoke insert on table public.hr_attendance_events
  from anon, authenticated, public;

grant insert on table public.hr_attendance_events to service_role;

drop policy if exists hr_attendance_insert
  on public.hr_attendance_events;
