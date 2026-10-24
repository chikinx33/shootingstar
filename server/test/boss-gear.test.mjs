import {test} from 'node:test';
import assert from 'node:assert/strict';
import {randomBytes} from 'node:crypto';
const base=process.env.TEST_BASE||'http://127.0.0.1:8810';
async function call(path,data,token){const r=await fetch(`${base}/api/${path}`,{method:'POST',headers:{'Content-Type':'application/json','X-Client':'native',...(token?{Authorization:`Bearer ${token}`}:{})},body:JSON.stringify(data)});return {status:r.status,body:await r.json()};}
test('boss gear records and new item identities survive roundtrip, downgrade and rollback attempts',async()=>{
 const reg=await call('auth/register',{username:`qa_${randomBytes(5).toString('hex')}`,nickname:'Boss Gear QA',salt:randomBytes(16).toString('hex'),key:randomBytes(32).toString('hex')});assert.equal(reg.status,200);const token=reg.body.token;
 const old={version:4,credits:777,runs:3,totalKills:100,blueprints:5,content:{inventory:[]}};
 assert.equal((await call('cloud/write',{revision:0,profile:old},token)).status,200);
 const next={...old,bossGearVersion:1,bossGear:{defeats:[3,0,0,0,0,0,0,0,0,0],claimed:[2,0,0,0,0,0,0,0,0,0]},content:{inventory:[{id:7,spec:12,rank:2},{id:8,spec:13,rank:2}],equippedGear:[1,2,3,7,5,8]}};
 assert.equal((await call('cloud/write',{revision:1,profile:next},token)).status,200);
 assert.equal((await call('cloud/write',{revision:2,profile:old},token)).status,409);
 for(const book of [null,{defeats:[],claimed:[]},{defeats:[-1,...Array(9).fill(0)],claimed:Array(10).fill(0)},{defeats:Array(10).fill(0),claimed:[1,...Array(9).fill(0)]}]){
  assert.equal((await call('cloud/write',{revision:2,profile:{...next,bossGear:book}},token)).status,400);
 }
 const rollback={...next,bossGear:{defeats:[3,0,0,0,0,0,0,0,0,0],claimed:[1,0,0,0,0,0,0,0,0,0]}};
 assert.equal((await call('cloud/write',{revision:2,profile:rollback},token)).status,409);
 assert.deepEqual((await call('cloud/read',{},token)).body.profile,next);
 console.log(JSON.stringify({isolatedQaAccount:reg.body.account.id}));
});
