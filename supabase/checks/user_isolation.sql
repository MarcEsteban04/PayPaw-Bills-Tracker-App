-- user_isolation.sql
--
-- Proves that one account cannot reach another's data. This is the deliverable of
-- Sprint 20: RLS being *enabled* is checked by rls_audit.sql, but "enabled" and
-- "correct" are different claims, and only this one matters to a user.
--
-- ---------------------------------------------------------------------------
-- How it works
--
-- PostgREST authenticates a request by setting `request.jwt.claims` and switching
-- to the `authenticated` role. Setting both by hand reproduces exactly what a
-- signed-in client sees — no second device, no app build, no test account signed
-- in on a phone.
--
-- Every block is wrapped in begin/rollback, so nothing here can leave data behind
-- even where it succeeds.
--
-- ---------------------------------------------------------------------------
-- Before running
--
-- Create two accounts through the app, then get their ids:
--
--   select id, email from auth.users order by created_at;
--
-- Replace AAAA... and BBBB... below. Give user A at least one bill first, either
-- through the app or with the seed block at the bottom.
-- ---------------------------------------------------------------------------


-- ===========================================================================
-- 1. Each account sees only its own bills
-- ===========================================================================
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA","role":"authenticated"}';

  select 'A sees' as who, count(*) as bills from public.bills;
  -- expect: A's own bills only
rollback;

begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB","role":"authenticated"}';

  select 'B sees' as who, count(*) as bills from public.bills;
  -- expect: 0, if B has created nothing
rollback;


-- ===========================================================================
-- 2. B cannot read a specific bill of A's, even knowing its id
--
-- The important one. Guessing an id should gain nothing: RLS filters rows, so the
-- result is *empty*, not "permission denied". An error would itself leak the fact
-- that the row exists.
-- ===========================================================================
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB","role":"authenticated"}';

  select count(*) as should_be_zero
  from public.bills
  where id = 'PASTE-A-BILL-ID-BELONGING-TO-A';
rollback;


-- ===========================================================================
-- 3. B cannot write a row that belongs to A
--
-- This is what `with check` is for. A policy with only `using` would allow this
-- insert and then hide the row from B afterwards — data written into someone
-- else's account, invisible to the person who wrote it.
-- ===========================================================================
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB","role":"authenticated"}';

  insert into public.bills (user_id, name, amount_minor, due_on)
  values (
    'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA',
    'planted by B',
    100000,
    current_date
  );
  -- expect: ERROR — new row violates row-level security policy
rollback;


-- ===========================================================================
-- 4. B cannot reach A's bills through the status view
--
-- Separate from case 2 because it fails for a different reason. A view without
-- security_invoker runs as its definer and bypasses RLS entirely, so this returns
-- A's rows while every direct table query correctly returns none. That asymmetry
-- is exactly the bug this case exists to catch.
-- ===========================================================================
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB","role":"authenticated"}';

  select count(*) as should_be_zero from public.bill_status;
rollback;


-- ===========================================================================
-- 5. The shared categories are readable, and not writable
-- ===========================================================================
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB","role":"authenticated"}';

  select count(*) as system_categories_visible
  from public.categories where user_id is null;
  -- expect: 13

  update public.categories set name = 'hijacked' where user_id is null;
  -- expect: 0 rows updated. The write policy requires user_id = auth.uid(), and
  -- the shared rows have user_id null, so no row matches. Not an error — RLS
  -- filters, and filtering to nothing is the correct outcome.
rollback;


-- ===========================================================================
-- 6. An anonymous caller sees nothing at all
--
-- The state of a request made with the publishable key and no session — which is
-- the state anyone who decompiles the app can reach.
-- ===========================================================================
begin;
  set local role anon;

  select count(*) as anon_bills from public.bills;
  -- expect: 0, or "permission denied" from the explicit revoke. Either is fine;
  -- what must not happen is a row coming back.
rollback;


-- ===========================================================================
-- Optional: give A a bill to test against, without using the app
-- ===========================================================================
-- begin;
--   set local role authenticated;
--   set local request.jwt.claims = '{"sub":"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA","role":"authenticated"}';
--
--   insert into public.bills (user_id, name, amount_minor, due_on)
--   values (
--     'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA',
--     'Meralco electricity',
--     245050,                        -- ₱2,450.50 — minor units, always
--     current_date + 5
--   )
--   returning id;
-- commit;                            -- commit, so later cases have something to find
