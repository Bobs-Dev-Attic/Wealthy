-- Wealthy: profile + wealth data schema with RLS scoped to auth.uid()
-- Applied to Supabase project `Wealthy` (ref bdnvnyqvikcaujhjqemr).

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  name text,
  birth_date date,
  retirement_age int default 65,
  life_expectancy int default 95,
  filing_status text default 'single'
    check (filing_status in ('single','married_joint','married_separate','head_of_household')),
  state text,
  has_password boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table public.accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  type text not null check (type in ('taxable','traditional','roth','hsa','cash')),
  balance numeric not null default 0,
  cost_basis numeric default 0,
  expected_return numeric default 0.06,
  return_stdev numeric default 0.12,
  created_at timestamptz default now()
);
create index accounts_user_id_idx on public.accounts(user_id);

create table public.income_sources (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text,
  type text not null check (type in ('social_security','pension','annuity','employment','other')),
  annual_amount numeric not null default 0,
  start_age int default 67,
  end_age int,
  cola_rate numeric default 0.02,
  created_at timestamptz default now()
);
create index income_sources_user_id_idx on public.income_sources(user_id);

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text,
  category text not null check (category in ('living','healthcare','housing','travel','other')),
  annual_amount numeric not null default 0,
  inflation_rate numeric default 0.03,
  start_age int,
  end_age int,
  created_at timestamptz default now()
);
create index expenses_user_id_idx on public.expenses(user_id);

create table public.plan_assumptions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  inflation numeric default 0.03,
  healthcare_inflation numeric default 0.05,
  market_return_mean numeric default 0.06,
  market_return_stdev numeric default 0.12,
  withdrawal_strategy text default 'inflation_adjusted'
    check (withdrawal_strategy in ('fixed_percent','inflation_adjusted','guardrails','vpw')),
  withdrawal_rate numeric default 0.04,
  simulation_count int default 1000,
  end_age int default 95,
  ss_claim_age int default 67,
  updated_at timestamptz default now()
);

alter table public.profiles         enable row level security;
alter table public.accounts         enable row level security;
alter table public.income_sources   enable row level security;
alter table public.expenses         enable row level security;
alter table public.plan_assumptions enable row level security;

create policy "own profile"  on public.profiles
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own accounts" on public.accounts
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own income"   on public.income_sources
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own expenses" on public.expenses
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own plan"     on public.plan_assumptions
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Seed profile + assumptions automatically on new auth user.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles(user_id, name)
    values (new.id, nullif(new.raw_user_meta_data->>'name', ''));
  insert into public.plan_assumptions(user_id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
