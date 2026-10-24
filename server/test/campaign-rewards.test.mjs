import {test} from 'node:test';
import assert from 'node:assert/strict';
import {randomBytes} from 'node:crypto';
const base=process.env.TEST_BASE||'http://127.0.0.1:8810';
async function call(path,data,token){const r=await fetch(`${base}/api/${path}`,{method:'POST',headers:{'Content-Type':'application/json','X-Client':'native',...(token?{Authorization:`Bearer ${token}`}:{})},body:JSON.stringify(data)});return {status:r.status,body:await r.json()};}
test('campaign reward records roundtrip and reject downgrade, malformed sets and claim deletion',async()=>{
 const reg=await call('auth/register',{username:`qa_${randomBytes(5).toString('hex')}`,nickname:'Reward QA',salt:randomBytes(16).toString('hex'),key:randomBytes(32).toString('hex')});assert.equal(reg.status,200);const token=reg.body.token;
 const old={version:4,credits:777,runs:3,totalKills:100,blueprints:5,content:{inventory:[]}};
 assert.equal((await call('cloud/write',{revision:0,profile:old},token)).status,200);
 const next={...old,campaignRewardsVersion:1,campaignRewards:{bossWorlds:[0,2],routes:[0,20]}};
 assert.equal((await call('cloud/write',{revision:1,profile:next},token)).status,200);
 assert.equal((await call('cloud/write',{revision:2,profile:old},token)).status,409);
 assert.equal((await call('cloud/write',{revision:2,profile:{...next,campaignRewardsVersion:2}},token)).status,409);
 for(const change of [{campaignRewards:null},{campaignRewards:{bossWorlds:[10],routes:[]}},{campaignRewards:{bossWorlds:[0,0],routes:[]}},{campaignRewards:{bossWorlds:[],routes:[100]}},{campaignRewards:{bossWorlds:[],routes:['0']}}]){
  assert.equal((await call('cloud/write',{revision:2,profile:{...next,...change}},token)).status,400);
 }
 assert.equal((await call('cloud/write',{revision:2,profile:{...next,campaignRewards:{bossWorlds:[0],routes:[0]}}},token)).status,409);
 assert.deepEqual((await call('cloud/read',{},token)).body.profile,next);
 const expanded={...next,campaignRewards:{bossWorlds:[0,2,9],routes:[0,20,99]}};
 assert.equal((await call('cloud/write',{revision:2,profile:expanded},token)).status,200);
 assert.equal((await call('cloud/write',{revision:2,profile:expanded},token)).status,409);
 assert.deepEqual((await call('cloud/read',{},token)).body.profile,expanded);
 console.log(JSON.stringify({isolatedQaAccount:reg.body.account.id}));
});
