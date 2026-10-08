begin;
select plan(22);

create temporary table attendance_security_fixture (
  admin_uid uuid not null,
  employee_uid uuid not null,
  employee_two_uid uuid not null,
  employee_id uuid not null,
  employee_two_id uuid not null,
  worksite_latitude double precision not null,
  worksite_longitude double precision not null
) on commit drop;

insert into public.hr_worksites(name, latitude, longitude, radius_m, max_accuracy_m)
select 'attendance security test fixture', 13.7563, 100.5018, 2000, 100
where not exists (select 1 from public.hr_worksites where active = true);

insert into attendance_security_fixture
select gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
       ws.latitude, ws.longitude
from public.hr_worksites ws
where ws.active = true
order by ws.created_at
limit 1;

grant select on attendance_security_fixture to anon, authenticated, service_role;

insert into auth.users (id, aud, role, email, encrypted_password)
select admin_uid, 'authenticated', 'authenticated', 'attendance-admin-test@example.invalid', ''
from attendance_security_fixture
union all
select employee_uid, 'authenticated', 'authenticated', 'attendance-employee-test@example.invalid', ''
from attendance_security_fixture
union all
select employee_two_uid, 'authenticated', 'authenticated', 'attendance-employee-two-test@example.invalid', ''
from attendance_security_fixture;

insert into public.hr_admins(user_id, display_name, active)
select admin_uid, 'Synthetic Attendance Admin', true from attendance_security_fixture;

insert into public.hr_employees(id, employee_code, full_name, start_date, active)
select employee_id, 'TEST-ATT-1', 'Synthetic Attendance Employee 1', current_date, true
from attendance_security_fixture
union all
select employee_two_id, 'TEST-ATT-2', 'Synthetic Attendance Employee 2', current_date, true
from attendance_security_fixture;

insert into public.hr_employee_accounts(employee_id, user_id, active)
select employee_id, employee_uid, true from attendance_security_fixture
union all
select employee_two_id, employee_two_uid, true from attendance_security_fixture;

select ok(not has_table_privilege('anon', 'public.hr_attendance_events', 'INSERT'), 'anon has no direct attendance INSERT privilege');
select ok(not has_table_privilege('authenticated', 'public.hr_attendance_events', 'INSERT'), 'authenticated has no direct attendance INSERT privilege');
select ok(has_table_privilege('service_role', 'public.hr_attendance_events', 'INSERT'), 'service_role retains attendance INSERT privilege');
select ok(not exists (
  select 1
  from pg_class c
  cross join lateral aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) acl
  where c.oid = 'public.hr_attendance_events'::regclass
    and acl.grantee = 0
    and acl.privilege_type = 'INSERT'
), 'PUBLIC has no direct attendance INSERT privilege');
select ok(not exists (
  select 1 from pg_policy
  where polrelid = 'public.hr_attendance_events'::regclass
    and polname = 'hr_attendance_insert'
), 'direct attendance INSERT policy is removed');
select ok(exists (
  select 1 from pg_policy
  where polrelid = 'public.hr_attendance_events'::regclass
    and polname = 'hr_attendance_select'
    and polcmd = 'r'
), 'attendance SELECT RLS policy remains');
select ok((select relrowsecurity from pg_class where oid = 'public.hr_attendance_events'::regclass), 'attendance RLS remains enabled');
select ok(has_function_privilege('service_role', 'public.hr_record_line_attendance(uuid,text,double precision,double precision,numeric)', 'EXECUTE'), 'service_role can execute the attendance RPC');
select ok(not has_function_privilege('authenticated', 'public.hr_record_line_attendance(uuid,text,double precision,double precision,numeric)', 'EXECUTE'), 'authenticated cannot execute the attendance RPC');
select ok(not has_function_privilege('anon', 'public.hr_record_line_attendance(uuid,text,double precision,double precision,numeric)', 'EXECUTE'), 'anon cannot execute the attendance RPC');

select set_config('request.jwt.claim.role', 'anon', true);
set local role anon;
select throws_ok(
  $$insert into public.hr_attendance_events(employee_id, event_type, latitude, longitude, accuracy_m)
    select employee_id, 'clock_in', worksite_latitude, worksite_longitude, 5 from attendance_security_fixture$$,
  '42501', null, 'anonymous direct INSERT is denied'
);
reset role;

select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', (select employee_uid::text from attendance_security_fixture), true);
set local role authenticated;
select throws_ok(
  $$insert into public.hr_attendance_events(employee_id, event_type, latitude, longitude, accuracy_m)
    select employee_id, 'clock_in', worksite_latitude, worksite_longitude, 5 from attendance_security_fixture$$,
  '42501', null, 'employee direct INSERT is denied'
);
reset role;

select set_config('request.jwt.claim.sub', (select admin_uid::text from attendance_security_fixture), true);
set local role authenticated;
select throws_ok(
  $$insert into public.hr_attendance_events(employee_id, event_type, latitude, longitude, accuracy_m)
    select employee_id, 'clock_in', worksite_latitude, worksite_longitude, 5 from attendance_security_fixture$$,
  '42501', null, 'admin direct INSERT is denied'
);
reset role;

select set_config('request.jwt.claim.role', 'service_role', true);
set local role service_role;
select lives_ok(
  $$select * from public.hr_record_line_attendance(
    (select employee_id from attendance_security_fixture), 'clock_in',
    (select worksite_latitude from attendance_security_fixture),
    (select worksite_longitude from attendance_security_fixture), 5)$$,
  'service-role RPC accepts the first clock-in'
);
select throws_ok(
  $$select * from public.hr_record_line_attendance(
    (select employee_id from attendance_security_fixture), 'clock_in',
    (select worksite_latitude from attendance_security_fixture),
    (select worksite_longitude from attendance_security_fixture), 5)$$,
  'P0001', 'Clock-in has already been recorded for today', 'duplicate clock-in is denied'
);
select throws_ok(
  $$select * from public.hr_record_line_attendance(
    (select employee_two_id from attendance_security_fixture), 'clock_out',
    (select worksite_latitude from attendance_security_fixture),
    (select worksite_longitude from attendance_security_fixture), 5)$$,
  'P0001', 'Clock-in is required before clock-out', 'clock-out before clock-in is denied'
);
select lives_ok(
  $$select * from public.hr_record_line_attendance(
    (select employee_id from attendance_security_fixture), 'clock_out',
    (select worksite_latitude from attendance_security_fixture),
    (select worksite_longitude from attendance_security_fixture), 5)$$,
  'service-role RPC accepts clock-out after clock-in'
);
select throws_ok(
  $$select * from public.hr_record_line_attendance(
    (select employee_id from attendance_security_fixture), 'clock_out',
    (select worksite_latitude from attendance_security_fixture),
    (select worksite_longitude from attendance_security_fixture), 5)$$,
  'P0001', 'Clock-out has already been recorded for today', 'duplicate clock-out is denied'
);
select lives_ok(
  $$select * from public.hr_record_line_attendance(
    (select employee_two_id from attendance_security_fixture), 'clock_in',
    (select worksite_latitude from attendance_security_fixture),
    (select worksite_longitude from attendance_security_fixture), 5)$$,
  'service-role RPC accepts a different employee clock-in'
);
reset role;

select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', (select employee_uid::text from attendance_security_fixture), true);
set local role authenticated;
select ok((select count(*) = 2 from public.hr_attendance_events), 'employee SELECT RLS returns only their own events');
select ok((select count(*) = 0 from public.hr_attendance_events where employee_id = (select employee_two_id from attendance_security_fixture)), 'employee SELECT RLS hides another employee events');
reset role;

select set_config('request.jwt.claim.sub', (select admin_uid::text from attendance_security_fixture), true);
set local role authenticated;
select ok((select count(*) = 3 from public.hr_attendance_events), 'admin SELECT RLS still returns all authorized events');
reset role;

select * from finish();
rollback;
