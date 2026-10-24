import {test} from 'node:test';
import assert from 'node:assert/strict';
import {randomBytes} from 'node:crypto';
import {mkdirSync,writeFileSync} from 'node:fs';
const base=process.env.TEST_BASE||'http://127.0.0.1:8789';
async function call(path,data={},token){const r=await fetch(`${base}/api/${path}`,{method:'POST',headers:{'Content-Type':'application/json','X-Client':'native',...(token?{Authorization:`Bearer ${token}`}:{})},body:JSON.stringify(data)});return {status:r.status,body:await r.json(),cookie:r.headers.get('set-cookie')};}
test('password-confirmed deletion revokes all sessions and removes account identity and saved data',async()=>{
 const username=`qa_${randomBytes(5).toString('hex')}`,salt=randomBytes(16).toString('hex'),key=randomBytes(32).toString('hex');
 const register=await call('auth/register',{username,nickname:'Deletion QA',salt,key});assert.equal(register.status,200);
 const token=register.body.token,id=register.body.account.id;
 const second=await call('auth/login',{username,key});assert.equal(second.status,200);
 const profile={version:4,credits:500,runs:3,totalKills:100,blueprints:2,content:{inventory:[]}};
 assert.equal((await call('cloud/write',{revision:0,profile},token)).status,200);
 assert.equal((await call('cloud/write',{revision:1,profile:{...profile,credits:501}},token)).status,200);
 assert.equal((await call('guild/create',{name:'Deletion test guild'},token)).status,200);
 assert.equal((await call('guild/report',{runId:'delete-report',kills:20,seconds:35},token)).status,200);
 assert.equal((await call('auth/delete',{username,key})).status,401);
 assert.equal((await call('auth/delete',{username:'someone_else',key},token)).status,400);
 assert.equal((await call('auth/delete',{username,key:'0'.repeat(64)},token)).status,401);
 assert.equal((await call('cloud/read',{},token)).status,200,'failed confirmation must preserve data');
 const removed=await call('auth/delete',{username,key},token);assert.equal(removed.status,200);assert.equal(removed.body.ok,true);assert.match(removed.cookie,/Max-Age=0/);
 assert.equal((await call('auth/me',{},token)).status,401);
 assert.equal((await call('auth/me',{},second.body.token)).status,401);
 assert.equal((await call('auth/login',{username,key})).status,401);
 const fresh=await call('auth/register',{username,nickname:'Fresh QA',salt,key});assert.equal(fresh.status,200);assert.notEqual(fresh.body.account.id,id);assert.equal(fresh.body.profile,null);
 mkdirSync('.local',{recursive:true});writeFileSync('.local/account-deletion-proof.json',JSON.stringify({deletedAccountId:id,replacementAccountId:fresh.body.account.id,allSessionsRevoked:true,identityReusable:true}));
});
