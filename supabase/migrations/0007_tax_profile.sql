-- Tax-return figures used for tax-optimization analysis (one row per user).
create table public.tax_profile (
  user_id uuid primary key references auth.users(id) on delete cascade,
  wages numeric default 0,
  interest numeric default 0,
  ordinary_dividends numeric default 0,
  qualified_dividends numeric default 0,
  long_term_gains numeric default 0,
  short_term_gains numeric default 0,
  business_income numeric default 0,
  ira_pension_distributions numeric default 0,
  ss_benefits numeric default 0,
  other_income numeric default 0,
  pretax_contributions numeric default 0,
  itemized_deductions numeric default 0,
  uses_itemized boolean default false,
  est_total_tax numeric default 0,
  updated_at timestamptz default now()
);

alter table public.tax_profile enable row level security;
create policy "own tax profile" on public.tax_profile
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
