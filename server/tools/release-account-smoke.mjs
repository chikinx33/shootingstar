// Synthetic account only. Never accepts an existing user's credentials or ID.
import assert from 'node:assert/strict';
import {randomBytes} from 'node:crypto';
import {writeFileSync} from 'node:fs';
const base='https://shootingstar-online.chikinx1.workers.dev';
const username='qa_rel_'+randomBytes(5).toString('hex');
const salt=randomBytes(16).toString('hex'),key=randomBytes(32).toString('hex');
const calls=[];let token,id,deleted=false,blocked=false;
async function post(path,data={},auth=token){
 const r=await fetch(base+'/api/'+path,{method:'POST',signal:AbortSignal.timeout(10000),
  headers:{'Content-Type':'application/json','X-Client':'native',...(auth?{Authorization:'Bearer '+auth}:{})},body:JSON.stringify(data)});
 calls.push({path,status:r.status});if(r.status===403)blocked=true;
 let body;try{body=await r.json();}catch{throw Error('Non-JSON response: '+path+' '+r.status);}
 return {status:r.status,body};
}
try{
 const h=await fetch(base+'/api/health?release='+Date.now(),{signal:AbortSignal.timeout(10000)});
 const health=await h.json();assert.equal(h.status,200);assert.equal(health.version,'10.0.27');assert.equal(health.ok,true);
 const reg=await post('auth/register',{username,salt,key,nickname:'출시 검증'},null);
 assert.equal(reg.status,200);assert.equal(reg.body.account.username,username);
 token=reg.body.token;id=reg.body.account.id;assert(token&&id);
 const profile={version:4,credits:150,runs:0,totalKills:0,blueprints:0,content:{inventory:[]}};
 assert.equal((await post('cloud/write',{revision:0,profile})).status,200);
 const read=await post('cloud/read');assert.equal(read.status,200);assert.equal(read.body.profile.credits,150);assert.equal(read.body.revision,1);
 const remove=await post('auth/delete',{username,key});assert.equal(remove.status,200);assert.equal(remove.body.ok,true);deleted=true;
 assert.equal((await post('auth/me')).status,401);
 assert.equal((await post('cloud/read')).status,401);
 assert.equal((await post('auth/login',{username,key},null)).status,401);
 console.log(JSON.stringify({version:'v10.0.27',health,calls,syntheticAccountDeleted:true,oldSessionRejected:true}));
}finally{
 // If a response was lost, recover only this randomly named account with the
 // generated credential. A known Access block is never retried.
 if(!deleted&&!blocked){
  if(!token){const login=await post('auth/login',{username,key},null);if(login.status===200&&login.body.account.username===username){token=login.body.token;id=login.body.account.id;}}
  if(token&&id){const r=await post('auth/delete',{username,key});deleted=r.status===200&&r.body.ok===true;}
 }
 writeFileSync('../.local/complete-v27/production-account-proof.json',JSON.stringify({version:'v10.0.27',syntheticAccountId:id??null,syntheticUsername:username,syntheticAccountDeleted:deleted,accessBlocked:blocked,calls},null,2));
 if(!deleted&&!blocked)process.exitCode=1;
}
