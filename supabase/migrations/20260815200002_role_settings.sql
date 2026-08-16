-- 0002 — statement and idle-in-transaction timeouts.
-- docs/backend-supabase.md §15.7, §15.2, §15.4.
--
-- This is second rather than last on purpose (b1 §3): every later migration and every test then
-- runs under the same timeouts the deployed database uses. A migration that only passes without a
-- statement timeout is a migration that will fail on deploy.
--
-- A single long-lived transaction holds back the vacuum horizon for the ENTIRE database, not just
-- its own rows. One hung mobile client with an open transaction is therefore a cluster-wide bloat
-- event, and this timeout is what turns it into an error instead. It is also what makes §9.3's
-- 100-value cursor overlap sound (§15.4), so it is load-bearing twice.

alter role authenticated set statement_timeout = '30s';
alter role authenticated set idle_in_transaction_session_timeout = '30s';

alter role anon set statement_timeout = '10s';
alter role anon set idle_in_transaction_session_timeout = '30s';
