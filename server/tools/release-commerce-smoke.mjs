// Creates and deletes ONLY a synthetic account. Never purchases or requests ads.
import assert from 'node:assert/strict';
import {randomBytes} from 'node:crypto';
import {mkdirSync,writeFileSync} from 'node:fs';
const base=process.env.COMMERCE_SMOKE_BASE||'http://127.0.0.1:8829';
if(!/^http:\/\/127\.0\.0\.1:\d+$/.test(base)&&process.env.COMMERCE_SMOKE_PRODUCTION!=='1')throw Error('Explicit production smoke configuration is required');
const proof={version:'v10.0.29',base,scope:'synthetic account only; billing/ads disabled; no provider transaction',checks:[]};
const credentials={username:'q29_'+randomBytes(6).toString('hex'),nickname:'후원 구조 검증',salt:randomBytes(16).toString('hex'),key:randomBytes(32).toString('hex')};
let token;
async function call(path,data={},session=token){
 const r=await fetch(base+'/api/'+path,{method:'POST',headers:{'Content-Type':'application/json','X-Client':'native',...(session?{Authorization:'Bearer '+session}:{})},body:JSON.stringify(data),signal:AbortSignal.timeout(15000)});
 proof.checks.push({path,status:r.status});return {status:r.status,body:await r.json()};
}
try{
 const health=await (await fetch(base+'/api/health?commerce-smoke='+Date.now())).json();assert.equal(health.version,'10.0.29');assert.deepEqual(health.commerce,{billing:false,rewardedAds:false});
 const registration=await call('auth/register',credentials,null);assert.equal(registration.status,200);token=registration.body.token;assert.ok(token);
 const profile={version:4,credits:150,runs:0,totalKills:0,blueprints:0,content:{inventory:[]},verifiedAdCredits:0};
 assert.equal((await call('cloud/write',{revision:0,profile})).status,200);
 const state=await call('commerce/state');assert.equal(state.status,200);assert.equal(state.body.billingAvailable,false);assert.equal(state.body.adsAvailable,false);assert.equal(state.body.supporter,false);assert.equal(state.body.remaining,2);
 assert.equal((await call('commerce/purchase',{productId:'unconfigured',token:'not-a-store-token'})).status,503);
 assert.equal((await call('commerce/ad-begin',{runId:'unconfigured',seconds:60,kills:20})).status,503);
 const saved=await call('cloud/read');assert.equal(saved.status,200);assert.deepEqual(saved.body.profile,profile);
 proof.fixedSchemaInitializedThroughBinding=true;proof.baseProgressPreserved=true;
}finally{
 if(token){
  const deleted=await call('auth/delete',{username:credentials.username,key:credentials.key});proof.syntheticAccountDeleted=deleted.status===200;assert.equal(deleted.status,200);
  assert.equal((await call('auth/me')).status,401);proof.deletedSessionRejected=true;
 }
 const out=process.env.COMMERCE_SMOKE_REPORT||'../.local/commerce-v29/operating-api-proof.json';
 mkdirSync(new URL('../.local/',import.meta.url),{recursive:true});
 writeFileSync(out,JSON.stringify(proof,null,2));console.log(JSON.stringify(proof));
}
