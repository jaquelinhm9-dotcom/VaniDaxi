create table if not exists public.marketplace_service_zones (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  city text not null,
  state text not null,
  country text not null default 'México',
  delivery_mode text not null default 'vanidaxi_managed'
    check (delivery_mode in ('vanidaxi_managed','seller_shipping')),
  is_active boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (city,state,country)
);

alter table public.marketplace_service_zones enable row level security;
revoke all on table public.marketplace_service_zones from anon, authenticated;
grant select on table public.marketplace_service_zones to anon, authenticated;

drop policy if exists marketplace_service_zones_public_active on public.marketplace_service_zones;
create policy marketplace_service_zones_public_active
on public.marketplace_service_zones for select to anon, authenticated
using (is_active=true);

insert into public.marketplace_service_zones(name,city,state,country,delivery_mode,is_active,sort_order)
values('Mazatlán','Mazatlán','Sinaloa','México','vanidaxi_managed',true,1)
on conflict (city,state,country) do update set
  name=excluded.name,delivery_mode=excluded.delivery_mode,is_active=excluded.is_active,
  sort_order=excluded.sort_order,updated_at=now();

create or replace function public.is_marketplace_service_zone_active(p_city text,p_state text,p_country text default 'México')
returns boolean language sql stable security definer set search_path=public
as $function$
select exists(
  select 1 from public.marketplace_service_zones z
  where z.is_active=true
    and lower(translate(trim(z.city),'áéíóúüÁÉÍÓÚÜñÑ','aeiouuAEIOUUnN'))=lower(translate(trim(coalesce(p_city,'')),'áéíóúüÁÉÍÓÚÜñÑ','aeiouuAEIOUUnN'))
    and lower(translate(trim(z.state),'áéíóúüÁÉÍÓÚÜñÑ','aeiouuAEIOUUnN'))=lower(translate(trim(coalesce(p_state,'')),'áéíóúüÁÉÍÓÚÜñÑ','aeiouuAEIOUUnN'))
    and lower(translate(trim(z.country),'áéíóúüÁÉÍÓÚÜñÑ','aeiouuAEIOUUnN'))=lower(translate(trim(coalesce(p_country,'México')),'áéíóúüÁÉÍÓÚÜñÑ','aeiouuAEIOUUnN'))
);
$function$;
revoke all on function public.is_marketplace_service_zone_active(text,text,text) from public;

create or replace function public.assign_order_delivery_provider()
returns trigger language plpgsql security definer set search_path=public
as $function$
declare zone record; addr jsonb; city text; state text; country text;
begin
  addr:=coalesce(new.shipping_address,'{}'::jsonb);
  city:=lower(translate(trim(coalesce(addr->>'city','')),'áéíóúüÁÉÍÓÚÜñÑ','aeiouuAEIOUUnN'));
  state:=lower(translate(trim(coalesce(addr->>'state','')),'áéíóúüÁÉÍÓÚÜñÑ','aeiouuAEIOUUnN'));
  country:=lower(translate(trim(coalesce(addr->>'country','México')),'áéíóúüÁÉÍÓÚÜñÑ','aeiouuAEIOUUnN'));
  select z.* into zone from public.marketplace_service_zones z
  where z.is_active=true
    and lower(translate(trim(z.city),'áéíóúüÁÉÍÓÚÜñÑ','aeiouuAEIOUUnN'))=city
    and lower(translate(trim(z.state),'áéíóúüÁÉÍÓÚÜñÑ','aeiouuAEIOUUnN'))=state
    and lower(translate(trim(z.country),'áéíóúüÁÉÍÓÚÜñÑ','aeiouuAEIOUUnN'))=country
  order by z.sort_order asc,z.created_at asc limit 1;
  if zone.id is not null and zone.delivery_mode='vanidaxi_managed' then
    new.delivery_provider:='vanidaxi'; new.delivery_custody:='seller';
  else
    new.delivery_provider:='seller'; new.delivery_custody:='seller';
  end if;
  if new.delivery_status is null then new.delivery_status:='pending'; end if;
  if new.delivery_updated_at is null then new.delivery_updated_at:=now(); end if;
  return new;
end;
$function$;

create or replace function public.create_commercial_order(
 p_items jsonb,p_shipping_address jsonb default '{}'::jsonb,p_promotion_id uuid default null::uuid,p_promo_code text default null::text)
returns uuid language plpgsql security definer set search_path=public
as $function$
declare
 v_uid uuid:=auth.uid(); v_order_id uuid; v_item jsonb; v_product public.products%rowtype; v_promo public.promotions%rowtype;
 v_qty integer; v_unit numeric; v_subtotal numeric:=0; v_discount numeric:=0; v_shipping numeric:=0; v_total numeric:=0; v_before_stock integer;
 v_promo_code text:=nullif(upper(trim(coalesce(p_promo_code,''))),'');
 v_order_number text:='VD-'||to_char(now(),'YYYYMMDDHH24MISS')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
begin
 if v_uid is null then raise exception 'authentication required'; end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'cart is empty'; end if;
 if not public.is_marketplace_service_zone_active(p_shipping_address->>'city',p_shipping_address->>'state',coalesce(p_shipping_address->>'country','México')) then
   raise exception 'VaniDaxi actualmente opera solo en Mazatlán, Sinaloa';
 end if;
 perform set_config('vani.allow_stock_change','on',true);
 insert into public.orders(order_number,user_id,status,subtotal,discount,shipping_cost,total,shipping_address)
 values(v_order_number,v_uid,'pending',0,0,0,0,coalesce(p_shipping_address,'{}'::jsonb)) returning id into v_order_id;
 for v_item in select * from jsonb_array_elements(p_items) loop
   v_qty:=greatest(1,least(coalesce((v_item->>'qty')::integer,1),100));
   select * into v_product from public.products where id=(v_item->>'product_id')::uuid for update;
   if not found or v_product.status<>'approved' then raise exception 'product is not available'; end if;
   if coalesce(v_product.stock,0)<v_qty then raise exception 'insufficient stock'; end if;
   v_unit:=v_product.price; if v_unit is null or v_unit<0 then raise exception 'invalid product price'; end if; v_before_stock:=v_product.stock;
   update public.products set stock=stock-v_qty,updated_at=now() where id=v_product.id and stock>=v_qty;
   if not found then raise exception 'insufficient stock'; end if;
   insert into public.inventory_movements(product_id,seller_id,actor_id,movement_type,quantity_delta,stock_before,stock_after,note)
   values(v_product.id,v_product.seller_id,v_uid,'sale',-v_qty,v_before_stock,v_before_stock-v_qty,'Reserva de inventario al crear pedido');
   insert into public.order_items(order_id,product_id,seller_id,product_name,quantity,unit_price,total_price,unit_cost,cost_total)
   values(v_order_id,v_product.id,v_product.seller_id,v_product.name,v_qty,v_unit,v_unit*v_qty,coalesce(v_product.cost_price,0),coalesce(v_product.cost_price,0)*v_qty);
   v_subtotal:=v_subtotal+v_unit*v_qty;
 end loop;
 if p_promotion_id is not null then
   select * into v_promo from public.promotions where id=p_promotion_id for update;
 elsif v_promo_code is not null then
   select * into v_promo from public.promotions where upper(promo_code)=v_promo_code for update;
 else
   select * into v_promo from public.promotions p
   where p.is_active=true and p.automatic=true
     and (p.start_at is null or p.start_at<=now())
     and (p.end_at is null or p.end_at>=now())
     and (p.usage_limit is null or p.usage_count<p.usage_limit)
     and (not p.registration_promotion or exists(select 1 from public.user_promotions up where up.user_id=v_uid and up.promotion_id=p.id and up.used=false))
   order by p.created_at desc limit 1 for update;
 end if;
 if v_promo.id is not null then
   if not v_promo.is_active then raise exception 'promotion is not active'; end if;
   if v_promo.start_at is not null and v_promo.start_at>now() then raise exception 'promotion is not active yet'; end if;
   if v_promo.end_at is not null and v_promo.end_at<now() then raise exception 'promotion has expired'; end if;
   if v_promo.usage_limit is not null and v_promo.usage_count>=v_promo.usage_limit then raise exception 'promotion usage limit reached'; end if;
   if v_promo.registration_promotion and not exists(select 1 from public.user_promotions up where up.user_id=v_uid and up.promotion_id=v_promo.id and up.used=false) then raise exception 'promotion is not assigned to this user'; end if;
   if v_promo.promotion_type='percentage' then v_discount=round(v_subtotal*least(greatest(v_promo.discount_value,0),100)/100,2);
   elsif v_promo.promotion_type='fixed_amount' then v_discount=least(v_subtotal,greatest(v_promo.discount_value,0));
   elsif v_promo.promotion_type='free_shipping' then v_discount=0; v_shipping=0; end if;
   update public.promotions set usage_count=coalesce(usage_count,0)+1,updated_at=now() where id=v_promo.id;
   if v_promo.registration_promotion then update public.user_promotions set used=true,used_at=coalesce(used_at,now()) where user_id=v_uid and promotion_id=v_promo.id and used=false; end if;
 end if;
 v_discount:=least(v_subtotal,greatest(v_discount,0)); v_total:=greatest(0,round(v_subtotal-v_discount+v_shipping,2));
 update public.orders set subtotal=round(v_subtotal,2),discount=round(v_discount,2),shipping_cost=round(v_shipping,2),total=v_total,
   promotion_id=case when v_promo.id is not null then v_promo.id else null end,updated_at=now() where id=v_order_id;
 return v_order_id;
end;
$function$;
revoke all on function public.create_commercial_order(jsonb,jsonb,uuid,text) from public;
grant execute on function public.create_commercial_order(jsonb,jsonb,uuid,text) to authenticated;
