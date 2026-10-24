-- Paid ownership is never accepted from accounts.profile. Tokens are encrypted
-- for provider rechecks; removing an account removes its commerce data too.
CREATE TABLE IF NOT EXISTS store_purchases (
 token_hash TEXT PRIMARY KEY,
 account TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
 product TEXT NOT NULL, token_cipher TEXT NOT NULL, state TEXT NOT NULL,
 acknowledged INTEGER NOT NULL DEFAULT 0, checked INTEGER NOT NULL,
 next_check INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS store_recheck ON store_purchases(next_check);
CREATE INDEX IF NOT EXISTS store_owner ON store_purchases(account,state);
CREATE TABLE IF NOT EXISTS ad_attempts (
 nonce TEXT PRIMARY KEY,
 account TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
 run TEXT NOT NULL, day TEXT NOT NULL, created INTEGER NOT NULL,
 expires INTEGER NOT NULL, closed INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS ad_attempt_owner ON ad_attempts(account,expires);
CREATE TABLE IF NOT EXISTS ad_grants (
 transaction_id TEXT PRIMARY KEY,
 nonce TEXT NOT NULL UNIQUE REFERENCES ad_attempts(nonce) ON DELETE CASCADE,
 account TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
 run TEXT NOT NULL, day TEXT NOT NULL, credits INTEGER NOT NULL CHECK(credits=20),
 created INTEGER NOT NULL, UNIQUE(account,run)
);
CREATE INDEX IF NOT EXISTS ad_daily ON ad_grants(account,day);
-- The insert and wallet update share one SQLite statement transaction. A stale
-- cloud upload conflicts on revision instead of erasing the verified reward.
CREATE TRIGGER IF NOT EXISTS ad_reward AFTER INSERT ON ad_grants BEGIN
 UPDATE accounts SET profile=json_set(profile,'$.credits',MIN(9999999,json_extract(profile,'$.credits')+NEW.credits),'$.verifiedAdCredits',COALESCE(json_extract(profile,'$.verifiedAdCredits'),0)+NEW.credits),
 revision=revision+1,updated=NEW.created WHERE id=NEW.account AND profile IS NOT NULL;
END;
