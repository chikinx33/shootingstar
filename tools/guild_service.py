import json, sqlite3, secrets, hashlib
from datetime import datetime, timezone, timedelta
from pathlib import Path
from contextlib import contextmanager

class GuildService:
    def __init__(self, path):
        self.path = str(path)
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        with self.db() as c:
            c.executescript('''
            CREATE TABLE IF NOT EXISTS users (id TEXT PRIMARY KEY, name TEXT, guild TEXT, coins INTEGER DEFAULT 0, checkday TEXT DEFAULT '');
            CREATE TABLE IF NOT EXISTS guilds (id TEXT PRIMARY KEY, name TEXT, xp INTEGER DEFAULT 0);
            CREATE TABLE IF NOT EXISTS reports (user TEXT, run TEXT, week TEXT, day TEXT, guild TEXT, damage INTEGER, PRIMARY KEY(user,run));
            CREATE TABLE IF NOT EXISTS rewards (user TEXT, id TEXT, body TEXT, PRIMARY KEY(user,id));
            ''')
    @contextmanager
    def db(self):
        c=sqlite3.connect(self.path, timeout=10); c.row_factory=sqlite3.Row
        try:
            with c: yield c
        finally: c.close()
    def handle(self, action, data, token=''):
        if not isinstance(data, dict): raise ValueError('잘못된 요청 형식입니다.')
        now=datetime.now(timezone.utc)+timedelta(hours=9)
        day=now.strftime('%Y-%m-%d'); week=f'{now.isocalendar().year}-{now.isocalendar().week:02}'
        with self.db() as c:
            c.execute('BEGIN IMMEDIATE')
            if action=='register':
                name=str(data.get('name','')).strip()[:16]
                if not name: raise ValueError('닉네임을 입력하세요.')
                token=secrets.token_urlsafe(32); uid=hashlib.sha256(token.encode()).hexdigest()
                c.execute('INSERT INTO users(id,name) VALUES(?,?)',(uid,name))
                return {'token':token}
            uid=hashlib.sha256(token.encode()).hexdigest()
            user=c.execute('SELECT * FROM users WHERE id=?',(uid,)).fetchone()
            if not user: raise ValueError('길드 프로필을 먼저 등록하세요.')
            guild=user['guild']; reward=None
            if action=='create':
                if guild: raise ValueError('이미 길드에 가입되어 있습니다.')
                name=str(data.get('name','')).strip()[:24]
                if not name: raise ValueError('길드 이름을 입력하세요.')
                guild=secrets.token_hex(3).upper()
                c.execute('INSERT INTO guilds(id,name) VALUES(?,?)',(guild,name))
                c.execute('UPDATE users SET guild=? WHERE id=?',(guild,uid))
            elif action=='join':
                if guild: raise ValueError('이미 길드에 가입되어 있습니다.')
                guild=str(data.get('code','')).upper().strip()
                if not c.execute('SELECT 1 FROM guilds WHERE id=?',(guild,)).fetchone(): raise ValueError('초대 코드를 찾을 수 없습니다.')
                if c.execute('SELECT COUNT(*) FROM users WHERE guild=?',(guild,)).fetchone()[0]>=20: raise ValueError('길드 정원이 찼습니다.')
                c.execute('UPDATE users SET guild=? WHERE id=?',(guild,uid))
            elif action=='leave':
                c.execute('UPDATE users SET guild=NULL WHERE id=?',(uid,)); guild=None
            elif action in ('checkin','donate','report','raid','shop'):
                if not guild: raise ValueError('길드 가입 후 이용하세요.')
                if action=='checkin' and user['checkday']!=day:
                    c.execute('UPDATE users SET checkday=?,coins=coins+10 WHERE id=?',(day,uid))
                    c.execute('UPDATE guilds SET xp=xp+20 WHERE id=?',(guild,))
                elif action=='donate':
                    if user['coins']<10: raise ValueError('길드 코인이 부족합니다.')
                    c.execute('UPDATE users SET coins=coins-10 WHERE id=?',(uid,))
                    c.execute('UPDATE guilds SET xp=xp+30 WHERE id=?',(guild,))
                elif action=='report':
                    run=str(data.get('runId',''))[:120]; kills=int(data.get('kills',0)); seconds=int(data.get('seconds',0))
                    count=c.execute('SELECT COUNT(*) FROM reports WHERE user=? AND day=?',(uid,day)).fetchone()[0]
                    if run and seconds>=30 and kills>=10 and count<3:
                        # Development server accepts client battle reports; production needs authoritative validation.
                        c.execute('INSERT OR IGNORE INTO reports VALUES(?,?,?,?,?,?)',(uid,run,week,day,guild,min(3000,max(0,kills*3))))
                elif action in ('raid','shop'):
                    rid=f'raid-{guild}-{week}' if action=='raid' else f'shop-{day}'
                    existing=c.execute('SELECT body FROM rewards WHERE user=? AND id=?',(uid,rid)).fetchone()
                    if existing: reward=json.loads(existing[0])
                    else:
                        if action=='raid':
                            damage=c.execute('SELECT COALESCE(SUM(damage),0) FROM reports WHERE guild=? AND week=?',(guild,week)).fetchone()[0]
                            own=c.execute('SELECT COALESCE(SUM(damage),0) FROM reports WHERE user=? AND week=? AND guild=?',(uid,week,guild)).fetchone()[0]
                            if damage<100000 or own==0: raise ValueError('주간 보스를 격파하고 직접 참여해야 합니다.')
                            reward={'id':rid,'title':'길드 주간 토벌','gearKeys':3,'techKeys':3,'food':100}
                        else:
                            if user['coins']<10: raise ValueError('길드 코인 10개가 필요합니다.')
                            c.execute('UPDATE users SET coins=coins-10 WHERE id=?',(uid,))
                            reward={'id':rid,'title':'길드 일일 보급','food':30,'plans':2}
                        c.execute('INSERT INTO rewards VALUES(?,?,?)',(uid,rid,json.dumps(reward)))
            elif action!='state': raise ValueError('지원하지 않는 요청입니다.')
            user=dict(c.execute('SELECT name,guild,coins,checkday FROM users WHERE id=?',(uid,)).fetchone())
            result={'user':user,'week':week,'day':day,'reward':reward}
            result['directory']=[dict(r) for r in c.execute('SELECT guilds.id,guilds.name,COUNT(users.id) AS members FROM guilds LEFT JOIN users ON users.guild=guilds.id GROUP BY guilds.id ORDER BY guilds.xp DESC LIMIT 20')]
            if guild:
                result['guild']=dict(c.execute('SELECT * FROM guilds WHERE id=?',(guild,)).fetchone())
                result['members']=[dict(r) for r in c.execute('SELECT name FROM users WHERE guild=?',(guild,))]
                result['damage']=c.execute('SELECT COALESCE(SUM(damage),0) FROM reports WHERE guild=? AND week=?',(guild,week)).fetchone()[0]
                result['attempts']=c.execute('SELECT COUNT(*) FROM reports WHERE user=? AND day=?',(uid,day)).fetchone()[0]
            result['rewards']=[json.loads(r[0]) for r in c.execute('SELECT body FROM rewards WHERE user=?',(uid,))]
            return result
