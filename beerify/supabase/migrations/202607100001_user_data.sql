create table if not exists public.user_data (
  user_id uuid primary key references auth.users(id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.user_data enable row level security;

grant select, insert, update, delete on public.user_data to authenticated;

create policy "Users read their Beerify data"
on public.user_data for select to authenticated
using ((select auth.uid()) = user_id);

create policy "Users insert their Beerify data"
on public.user_data for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy "Users update their Beerify data"
on public.user_data for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Users delete their Beerify data"
on public.user_data for delete to authenticated
using ((select auth.uid()) = user_id);
