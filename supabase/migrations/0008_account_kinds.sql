-- Split tax-deferred / Roth accounts into specific kinds (401(k) vs IRA) so
-- balances can be tracked separately. Tax treatment is unchanged: *_401k and
-- *_ira share a tax bucket. Legacy 'traditional'/'roth' values are kept valid
-- so existing rows pass the constraint until the user re-saves them.

alter table public.accounts drop constraint if exists accounts_type_check;
alter table public.accounts add constraint accounts_type_check
  check (type in (
    'taxable',
    'traditional_401k', 'traditional_ira',
    'roth_401k', 'roth_ira',
    'hsa', 'cash',
    'traditional', 'roth' -- legacy
  ));

alter table public.holdings drop constraint if exists holdings_account_type_check;
alter table public.holdings add constraint holdings_account_type_check
  check (account_type in (
    'taxable',
    'traditional_401k', 'traditional_ira',
    'roth_401k', 'roth_ira',
    'hsa',
    'traditional', 'roth' -- legacy
  ));
