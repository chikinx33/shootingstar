import unittest, tempfile, hashlib
from pathlib import Path
from guild_service import GuildService

class GuildTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.s=GuildService(Path(self.tmp.name)/'guild.sqlite3')
        self.a=self.s.handle('register',{'name':'pilot A'})['token'];self.b=self.s.handle('register',{'name':'pilot B'})['token']
        self.g=self.s.handle('create',{'name':'QA fleet'},self.a)['guild']['id']
    def tearDown(self):self.tmp.cleanup()
    def test_real_membership_and_shared_contribution(self):
        b=self.s.handle('join',{'code':self.g},self.b);self.assertEqual(len(b['members']),2)
        for token in [self.a,self.b]:self.s.handle('report',{'runId':'same-local-id','kills':100,'seconds':60},token)
        state=self.s.handle('state',{},self.a);self.assertEqual(state['damage'],600)
        self.s.handle('report',{'runId':'same-local-id','kills':100,'seconds':60},self.a)
        self.assertEqual(self.s.handle('state',{},self.a)['damage'],600)
        self.s.handle('leave',{},self.b)
        self.assertEqual(self.s.handle('state',{},self.a)['damage'],600)
    def test_checkin_shop_and_receipts_are_idempotent(self):
        self.s.handle('checkin',{},self.a);state=self.s.handle('checkin',{},self.a);self.assertEqual(state['user']['coins'],10)
        first=self.s.handle('shop',{},self.a);again=self.s.handle('shop',{},self.a)
        self.assertEqual(first['reward'],again['reward']);self.assertEqual(again['user']['coins'],0);self.assertEqual(len(again['rewards']),1)
    def test_daily_raid_limit_and_damage_cap(self):
        for i in range(5):self.s.handle('report',{'runId':str(i),'kills':99999,'seconds':60},self.a)
        state=self.s.handle('state',{},self.a);self.assertEqual(state['damage'],9000);self.assertEqual(state['attempts'],3)
        with self.assertRaises(ValueError):self.s.handle('raid',{},self.a)
    def test_raid_completion_claim_once(self):
        state=self.s.handle('report',{'runId':'raid','kills':100,'seconds':60},self.a)
        # Isolated fixture establishes a completed weekly boss, never production DB.
        with self.s.db() as c:c.execute('UPDATE reports SET damage=100000')
        first=self.s.handle('raid',{},self.a);again=self.s.handle('raid',{},self.a)
        self.assertEqual(first['reward'],again['reward']);self.assertEqual(len(again['rewards']),1)
    def test_auth_and_insufficient_currency(self):
        with self.assertRaises(ValueError):self.s.handle('state',{},'wrong')
        with self.assertRaises(ValueError):self.s.handle('donate',{},self.a)
        with self.assertRaises(ValueError):self.s.handle('join',{'code':'WRONG'},self.b)
        self.assertIsNone(self.s.handle('state',{},self.b)['user']['guild'])

if __name__=='__main__':unittest.main()
