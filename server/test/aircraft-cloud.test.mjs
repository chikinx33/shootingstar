import {test} from 'node:test';
import assert from 'node:assert/strict';
import {randomBytes} from 'node:crypto';
const base=process.env.TEST_BASE||'http://127.0.0.1:8810';
async function call(path,data,token){const r=await fetch(`${base}/api/${path}`,{method:'POST',headers:{'Content-Type':'application/json','X-Client':'native',...(token?{Authorization:`Bearer ${token}`}:{})},body:JSON.stringify(data)});return {status:r.status,body:await r.json()};}
test('live local D1 roundtrip retains assembly and blocks incompatible, locked and old-client writes',async()=>{
 const reg=await call('auth/register',{username:`qa_${randomBytes(5).toString('hex')}`,nickname:'Assembly QA',salt:randomBytes(16).toString('hex'),key:randomBytes(32).toString('hex')});assert.equal(reg.status,200);
 const token=reg.body.token,old={version:4,credits:900,runs:3,totalKills:100,blueprints:5,content:{inventory:[],petLevels:[3,2,0]},unlockedShips:[0,1],selectedShip:1};
 assert.equal((await call('cloud/write',{revision:0,profile:old},token)).status,200);
 const next={...old,aircraft:{version:1,parts:{main:'cannon',auxiliary:'auxShield',ground:'bomb',supportRear:'repair'}}};
 assert.equal((await call('cloud/write',{revision:1,profile:next},token)).status,200);
 assert.deepEqual((await call('cloud/read',{},token)).body.profile,next);
 assert.equal((await call('cloud/write',{revision:2,profile:old},token)).status,409);
 for(const change of [p=>p.aircraft.parts.main='bomb',p=>p.aircraft.parts.supportLeft='ward',p=>p.selectedShip=2]){
  const p=structuredClone(next);change(p);assert.equal((await call('cloud/write',{revision:2,profile:p},token)).status,400);
 }
 assert.deepEqual((await call('cloud/read',{},token)).body.profile,next);
 console.log(JSON.stringify({isolatedQaAccount:reg.body.account.id,modularRoundtrip:true}));
});
