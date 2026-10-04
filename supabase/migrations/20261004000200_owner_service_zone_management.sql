create or replace function public.list_owner_service_zones()
returns setof public.marketplace_service_zones
language plpgsql security definer set search_path=public
as $function$
begin
  if not public.is_owner_admin() then raise exception 'owner admin required'; end if;
  return query select * from public.marketplace_service_zones order by sort_order asc,created_at asc;
end;
$function$;
revoke all on function public.list_owner_service_zones() from public;
grant execute on function public.list_owner_service_zones() to authenticated;

create or replace function public.upsert_owner_service_zone(
 p_id uuid default null,p_name text default null,p_city text default null,p_state text default null,p_country text default 'México',
 p_delivery_mode text default 'seller_shipping',p_is_active boolean default false)
returns public.marketplace_service_zones
language plpgsql security definer set search_path=public
as $function$
declare r public.marketplace_service_zones;
begin
 if not public.is_owner_admin() then raise exception 'owner admin required'; end if;
 if nullif(trim(coalesce(p_name,'')),'') is null or nullif(trim(coalesce(p_city,'')),'') is null or nullif(trim(coalesce(p_state,'')),'') is null then
   raise exception 'name, city and state are required';
 end if;
 if p_delivery_mode not in ('vanidaxi_managed','seller_shipping') then raise exception 'invalid delivery mode'; end if;
 if p_id is null then
   insert into public.marketplace_service_zones(name,city,state,country,delivery_mode,is_active,updated_at)
   values(trim(p_name),trim(p_city),trim(p_state),trim(coalesce(p_country,'México')),p_delivery_mode,p_is_active,now()) returning * into r;
 else
   update public.marketplace_service_zones set name=trim(p_name),city=trim(p_city),state=trim(p_state),country=trim(coalesce(p_country,'México')),
     delivery_mode=p_delivery_mode,is_active=p_is_active,updated_at=now() where id=p_id returning * into r;
   if not found then raise exception 'service zone not found'; end if;
 end if;
 insert into public.admin_activity_logs(admin_id,action,target_type,target_id,description,metadata)
 values(auth.uid(),case when p_is_active then 'service_zone_activated' else 'service_zone_updated' end,
   'marketplace_service_zones',r.id,'Updated marketplace service zone',
   jsonb_build_object('name',r.name,'city',r.city,'state',r.state,'delivery_mode',r.delivery_mode,'is_active',r.is_active));
 return r;
end;
$function$;
revoke all on function public.upsert_owner_service_zone(uuid,text,text,text,text,text,boolean) from public;
grant execute on function public.upsert_owner_service_zone(uuid,text,text,text,text,text,boolean) to authenticated;
