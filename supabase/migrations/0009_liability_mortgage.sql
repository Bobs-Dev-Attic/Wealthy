-- Mortgage details and optional amortization parameters for liabilities.
alter table public.liabilities
  add column if not exists mortgage_kind text
    check (mortgage_kind is null or mortgage_kind in ('fixed', 'variable', 'jumbo')),
  add column if not exists term_years integer not null default 0,
  add column if not exists extra_monthly_payment numeric not null default 0;
