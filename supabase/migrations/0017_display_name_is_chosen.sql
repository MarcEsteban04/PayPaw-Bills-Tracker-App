-- 0017_display_name_is_chosen.sql
--
-- Stops seeding `profiles.display_name` from the email address.
--
-- ## What was wrong
--
-- `handle_new_user` in migration 0002 filled `display_name` with the local part
-- of the address, calling it "a usable starting name rather than an empty
-- screen". That reasoning held while nothing could edit it: a screen with no way
-- to set a name is better off showing something.
--
-- The Profile screen can set one now, and the seed has become the problem it was
-- protecting against. Every account arrives already named after its login, so:
--
--   * nobody is ever *asked* — the screen has nothing to invite, because the
--     field is full;
--   * PayPaw greets people by a string they never chose and presents it as
--     though they did;
--   * "has this person told us their name" becomes unanswerable, because a seed
--     and a choice are stored identically.
--
-- A name is now null until somebody types one. The dashboard still falls back to
-- the local part of the address for its greeting — see
-- `DashboardHeader.nameOrAddress` — so nothing shows an empty heading. The
-- difference is that the fallback is visibly a fallback, and the Profile screen
-- asks.
--
-- ## The backfill undoes 0002's, carefully
--
-- Only where the stored name is *exactly* the local part of the address, which
-- is the seed and nothing else. A name somebody chose is left alone, including
-- one that merely resembles their address — 'marc.delacruz' stays if the address
-- is marc@example.com.
--
-- Somebody whose chosen name happens to equal their own local part loses it and
-- is asked again. That is the one case this gets wrong, it is recoverable in two
-- taps, and the alternative is leaving every account misrepresented forever.

-- ---------------------------------------------------------------------------
-- The trigger function
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- The row still has to exist. Everything else about a profile has a column
  -- default, and the name is the one field only its owner can supply.
  insert into public.profiles (id)
  values (new.id)
  on conflict (id) do nothing;

  return new;
end;
$$;

comment on function public.handle_new_user() is
  'Creates the profile row at sign-up. Leaves display_name null: a name is something the user chooses, and the app asks for it.';

-- ---------------------------------------------------------------------------
-- Undo 0002's backfill
-- ---------------------------------------------------------------------------
update public.profiles p
   set display_name = null
  from auth.users u
 where u.id = p.id
   and p.display_name is not null
   and p.display_name = split_part(coalesce(u.email, ''), '@', 1);
