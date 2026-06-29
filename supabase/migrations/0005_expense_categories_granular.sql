-- Add granular expense categories that match the guided interview line items.
alter table public.expenses drop constraint if exists expenses_category_check;
alter table public.expenses add constraint expenses_category_check
  check (category in (
    'housing','electricity','water','gas','internet','phone','utilities',
    'groceries','dining','food','transportation','insurance','healthcare',
    'subscriptions','entertainment','personal','education','childcare','pets',
    'charity','travel','living','other'
  ));
