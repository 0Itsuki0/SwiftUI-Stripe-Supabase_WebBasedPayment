drop table if exists user_entitlements CASCADE;

create table user_entitlements (
  id uuid references auth.users(id) not null primary key,
  -- A foreign key constraint can only reference a base table (a real, stored table) in the same database, not a view, a foreign data wrapper table, or another temporary object.
  subscription_id text default null,
  stripe_customer_id text default null,

  price_id text default null,
  product_id text default null,

  subscription_status text default null,
  current_period_start timestamp with time zone default null,
  current_period_end timestamp with time zone default null
);

-- RLS policy
alter table user_entitlements
enable row level security;

create policy "user can select their own entitlement"
on user_entitlements for select
to authenticated
using ( (select auth.uid()) = id );

create policy "user can update their own entitlement"
on user_entitlements for update
to authenticated
using ( (select auth.uid()) = id )
with check ( (select auth.uid()) = id );


-- trigger function
drop function if exists public.handle_new_user() cascade;
drop trigger if exists on_auth_user_created on auth.users;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.user_entitlements (id)
  values (new.id);
  return new;
end;
$$;

-- create trigger
create or replace trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- real time
alter publication supabase_realtime
add table user_entitlements;