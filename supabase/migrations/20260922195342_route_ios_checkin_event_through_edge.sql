create or replace function public.apply_ios_checkin_event(
    p_user_id uuid,
    p_client_id uuid,
    p_local_date date,
    p_period text,
    p_timezone text,
    p_ciphertext text,
    p_schema_version integer,
    p_client_updated_at timestamptz,
    p_deleted_at timestamptz default null
)
returns public.ios_checkin_events
language plpgsql
security definer
set search_path = public
as $$
declare
    result public.ios_checkin_events;
begin
    if p_period not in ('morning', 'evening') then
        raise exception 'Invalid check-in period' using errcode = '22023';
    end if;

    insert into public.ios_checkin_events (
        user_id, client_id, local_date, period, timezone, ciphertext,
        schema_version, client_updated_at, deleted_at
    ) values (
        p_user_id, p_client_id, p_local_date, p_period, p_timezone, p_ciphertext,
        p_schema_version, p_client_updated_at, p_deleted_at
    )
    on conflict (user_id, client_id) do update
    set local_date = excluded.local_date,
        period = excluded.period,
        timezone = excluded.timezone,
        ciphertext = excluded.ciphertext,
        schema_version = excluded.schema_version,
        client_updated_at = excluded.client_updated_at,
        deleted_at = excluded.deleted_at,
        updated_at = now()
    where excluded.client_updated_at > public.ios_checkin_events.client_updated_at
    returning * into result;

    if result.id is null then
        select * into result
        from public.ios_checkin_events
        where user_id = p_user_id and client_id = p_client_id;
    end if;

    return result;
end;
$$;

revoke all on function public.apply_ios_checkin_event(
    uuid, uuid, date, text, text, text, integer, timestamptz, timestamptz
) from public, anon, authenticated;
grant execute on function public.apply_ios_checkin_event(
    uuid, uuid, date, text, text, text, integer, timestamptz, timestamptz
) to service_role;
