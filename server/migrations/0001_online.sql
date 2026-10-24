PRAGMA foreign_keys = ON;
CREATE TABLE accounts (
 id TEXT PRIMARY KEY, username TEXT NOT NULL UNIQUE, nickname TEXT NOT NULL,
 salt TEXT NOT NULL, verifier TEXT NOT NULL, recovery TEXT NOT NULL,
 profile TEXT, revision INTEGER NOT NULL DEFAULT 0, updated INTEGER NOT NULL,
 created INTEGER NOT NULL, disabled INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE sessions (hash TEXT PRIMARY KEY, account TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE, expires INTEGER NOT NULL, created INTEGER NOT NULL, device TEXT NOT NULL);
CREATE INDEX sessions_account ON sessions(account);
CREATE INDEX sessions_expiry ON sessions(expires);
CREATE TABLE rate_limits (key TEXT PRIMARY KEY, hits INTEGER NOT NULL, expires INTEGER NOT NULL);
CREATE INDEX rates_expiry ON rate_limits(expires);
CREATE TABLE save_history (account TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE, revision INTEGER NOT NULL, profile TEXT NOT NULL, updated INTEGER NOT NULL, PRIMARY KEY(account,revision));
CREATE TRIGGER backup_save BEFORE UPDATE OF profile ON accounts WHEN OLD.profile IS NOT NULL AND NEW.profile IS NOT OLD.profile BEGIN
 INSERT OR REPLACE INTO save_history VALUES(OLD.id,OLD.revision,OLD.profile,OLD.updated);
 DELETE FROM save_history WHERE account=OLD.id AND revision < OLD.revision-4;
END;
CREATE TABLE guilds (id TEXT PRIMARY KEY, name TEXT NOT NULL, xp INTEGER NOT NULL DEFAULT 0);
CREATE TABLE members (account TEXT PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE, guild TEXT REFERENCES guilds(id), coins INTEGER NOT NULL DEFAULT 0 CHECK(coins>=0), checkday TEXT NOT NULL DEFAULT '');
CREATE INDEX member_guild ON members(guild);
CREATE TRIGGER guild_capacity BEFORE UPDATE OF guild ON members WHEN NEW.guild IS NOT NULL AND NEW.guild IS NOT OLD.guild AND (SELECT COUNT(*) FROM members WHERE guild=NEW.guild)>=20 BEGIN SELECT RAISE(ABORT,'guild_full'); END;
CREATE TABLE reports (account TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE, run TEXT NOT NULL, guild TEXT NOT NULL, week TEXT NOT NULL, day TEXT NOT NULL, damage INTEGER NOT NULL, PRIMARY KEY(account,run));
CREATE INDEX report_guild_week ON reports(guild,week);
CREATE INDEX report_account_day ON reports(account,day);
CREATE TABLE rewards (account TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE, id TEXT NOT NULL, kind TEXT NOT NULL, body TEXT NOT NULL, PRIMARY KEY(account,id));
CREATE TRIGGER pay_shop AFTER INSERT ON rewards WHEN NEW.kind='shop' BEGIN UPDATE members SET coins=coins-10 WHERE account=NEW.account; END;
