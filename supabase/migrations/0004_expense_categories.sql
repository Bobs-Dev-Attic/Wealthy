-- Expand the allowed expense categories.
alter table public.expenses drop constraint if exists expenses_category_check;
alter table public.expenses add constraint expenses_category_check
  check (category in (
    'housing','utilities','food','transportation','healthcare','insurance',
    'entertainment','personal','education','childcare','pets','travel',
    'charity','living','other'
  ));
