-- Applied remotely as migration hr_line_link_invoker.
-- Replace the admin LINE-link RPC to run under caller privileges/RLS.
create or replace function public.hr_link_line_identity(
  p_request_id uuid,
  p_employee_id uuid
)
returns void
language plpgsql
security invoker
set search_path = public, kmo_hr_private, pg_temp
as $$
declare
  v_request public.hr_line_link_requests%rowtype;
  v_existing public.hr_employee_identities%rowtype;
begin
  if not kmo_hr_private.is_admin(auth.uid()) then
    raise exception 'ADMIN permission required';
  end if;

  select * into v_request
  from public.hr_line_link_requests
  where id = p_request_id
  for update;

  if v_request.id is null then raise exception 'LINE link request not found'; end if;
  if v_request.status <> 'pending' then raise exception 'LINE link request is not pending'; end if;

  if not exists (
    select 1 from public.hr_employees e
    where e.id = p_employee_id and e.active = true
  ) then
    raise exception 'Active employee not found';
  end if;

  select * into v_existing
  from public.hr_employee_identities
  where provider = 'line' and provider_subject = v_request.provider_subject
  limit 1;

  if v_existing.id is not null and v_existing.employee_id <> p_employee_id then
    raise exception 'This LINE account is already linked to another employee';
  end if;

  if exists (
    select 1 from public.hr_employee_identities i
    where i.employee_id = p_employee_id
      and i.provider = 'line'
      and i.active = true
      and i.provider_subject <> v_request.provider_subject
  ) then
    raise exception 'This employee already has an active LINE identity';
  end if;

  insert into public.hr_employee_identities(employee_id, provider, provider_subject, active)
  values (p_employee_id, 'line', v_request.provider_subject, true)
  on conflict (provider, provider_subject)
  do update set employee_id = excluded.employee_id, active = true;

  update public.hr_line_link_requests
  set status = 'linked',
      employee_id = p_employee_id,
      decided_by = auth.uid(),
      decided_at = now(),
      last_seen_at = now()
  where id = p_request_id;
end;
$$;

revoke all on function public.hr_link_line_identity(uuid, uuid) from public, anon;
grant execute on function public.hr_link_line_identity(uuid, uuid) to authenticated;
