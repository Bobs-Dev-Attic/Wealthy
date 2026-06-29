-- Individual investment holdings (stocks / ETFs / mutual funds) with cached prices.
create table public.holdings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  symbol text not null,
  name text,
  shares numeric not null default 0,
  account_type text not null default 'taxable'
    check (account_type in ('taxable','traditional','roth','hsa')),
  cost_basis numeric default 0,
  last_price numeric,
  last_price_at timestamptz,
  created_at timestamptz default now()
);
create index holdings_user_id_idx on public.holdings(user_id);

alter table public.holdings enable row level security;
create policy "own holdings" on public.holdings
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
