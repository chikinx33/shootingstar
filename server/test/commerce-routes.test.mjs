import {test} from 'node:test';
import assert from 'node:assert/strict';
import {randomBytes} from 'node:crypto';
const base=process.env.TEST_BASE||'http://127.0.0.1:8789';
test('real local Worker/D1 keeps unconfigured commerce closed and isolates paid ownership from saves',async()=>{
 const credentials={username:'q29_'+randomBytes(6).toString('hex'),nickname:'결제 격리 검증',salt:randomBytes(16).toString('hex'),key:randomBytes(32).toString('hex')};
 const call=async(path,data={},token)=>{
  const response=await fetch(`${base}/api/${path}`,{method:'POST',headers:{'Content-Type':'application/json','X-Client':'native',...(token?{Authorization:'Bearer '+token}:{})},body:JSON.stringify(data)});
  return {status:response.status,body:await response.json()};
 };
 const registered=await call('auth/register',credentials);assert.equal(registered.status,200);const token=registered.body.token;
 assert.equal((await call('commerce/state')).status,401);
 const state=await call('commerce/state',{},token);assert.equal(state.status,200);assert.equal(state.body.billingAvailable,false);assert.equal(state.body.adsAvailable,false);assert.equal(state.body.supporter,false);assert.equal(state.body.productId,null);assert.equal(state.body.remaining,2);
 assert.equal((await call('commerce/ad-begin',{runId:'fake',seconds:60,kills:20},token)).status,503);
 assert.equal((await call('commerce/purchase',{token:'fake',productId:'fake'},token)).status,503);
 const profile={version:4,credits:150,runs:1,totalKills:20,blueprints:0,content:{inventory:[]},supporter:true,verifiedAdCredits:0};
 assert.equal((await call('cloud/write',{revision:0,profile},token)).status,200);
 assert.equal((await call('commerce/refresh',{},token)).body.supporter,false);
 assert.equal((await fetch(base+'/api/commerce/admob-ssv?signature=fake&key_id=1')).status,503);
 assert.equal((await call('commerce/play-rtdn')).status,503);
 assert.equal((await call('auth/delete',{username:credentials.username,key:credentials.key},token)).status,200);
 assert.equal((await call('commerce/state',{},token)).status,401);
});
