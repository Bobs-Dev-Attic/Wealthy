create table public.liabilities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text,
  type text not null default 'other'
    check (type in ('mortgage','auto','student','credit_card','loan','other')),
  balance numeric not null default 0,
  interest_rate numeric default 0.05,
  monthly_payment numeric default 0,
  created_at timestamptz default now()
);
create index liabilities_user_id_idx on public.liabilities(user_id);

alter table public.liabilities enable row level security;
create policy "own liabilities" on public.liabilities
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
