revoke execute on function public.is_marketplace_service_zone_active(text,text,text) from anon, authenticated, public;
grant execute on function public.is_marketplace_service_zone_active(text,text,text) to service_role;

revoke execute on function public.list_owner_service_zones() from anon;
revoke execute on function public.upsert_owner_service_zone(uuid,text,text,text,text,text,boolean) from anon;

revoke execute on function public.list_account_deletion_requests() from anon;
revoke execute on function public.resolve_account_deletion_request(uuid,text,text) from anon;
