import {test} from 'node:test';
import assert from 'node:assert/strict';
import {randomBytes,pbkdf2Sync} from 'node:crypto';
const base=process.env.TEST_BASE||'http://127.0.0.1:8789';
async function call(path,data={},token,extra={}) {const r=await fetch(`${base}/api/${path}`,{method:'POST',headers:{'Content-Type':'application/json','X-Client':'native',...(token?{Authorization:`Bearer ${token}`} :{}),...extra},body:JSON.stringify(data)});return {status:r.status,body:await r.json(),headers:r.headers};}
const profile=credits=>({version:4,credits,runs:3,totalKills:100,blueprints:5,content:{inventory:[]}});

test('permanent armament ownership and reinforcement survive old clients, bad data and stale CAS',async()=>{
 const reg=await call('auth/register',{username:`qa_${randomBytes(5).toString('hex')}`,nickname:'Armament QA',salt:randomBytes(16).toString('hex'),key:randomBytes(32).toString('hex')});
 assert.equal(reg.status,200);const token=reg.body.token;
 const old=profile(1200);
 assert.equal((await call('cloud/write',{revision:0,profile:old},token)).status,200);
 const upgraded={...old,armamentProgressionVersion:1,armamentCollection:{pulse:0,shotgun:4},selectedArmament:4};
 assert.equal((await call('cloud/write',{revision:1,profile:upgraded},token)).status,200);
 const rejected=await call('cloud/write',{revision:2,profile:old},token);
 assert.equal(rejected.status,409);assert.deepEqual(rejected.body.profile,upgraded);
 for(const change of [{armamentCollection:{}},{armamentCollection:{pulse:11}},{armamentCollection:{pulse:0,shotgun:-1}},{armamentCollection:{pulse:0,shotgun:2.5}},{armamentCollection:{pulse:0,injected:3}},{selectedArmament:5},{armamentCollection:null}]) {
   assert.equal((await call('cloud/write',{revision:2,profile:{...upgraded,...change}},token)).status,400);
 }
 assert.equal((await call('cloud/write',{revision:1,profile:upgraded},token)).status,409);
 const after=(await call('cloud/read',{},token)).body;
 assert.equal(after.revision,2);assert.deepEqual(after.profile,upgraded);
 const next={...upgraded,credits:1000,armamentCollection:{pulse:0,shotgun:5}};
 assert.equal((await call('cloud/write',{revision:2,profile:next},token)).status,200);
 assert.deepEqual((await call('cloud/read',{},token)).body.profile,next);
 console.log(JSON.stringify({qaAccounts:[reg.body.account.id]}));
});

test('expanded progression and presets cannot be erased by an older client',async()=>{
 const reg=await call('auth/register',{username:`qa_${randomBytes(5).toString('hex')}`,nickname:'Progress QA',salt:randomBytes(16).toString('hex'),key:randomBytes(32).toString('hex')});
 assert.equal(reg.status,200);const token=reg.body.token;
 const upgraded={...profile(777),campaignVersion:1,hangarPresets:[{name:'함대 A'}],content:{inventory:[],progressionVersion:1,collections:{keys:2,levels:[1]},journal:{signIns:7,chapterClaims:[0]}}};
 assert.equal((await call('cloud/write',{revision:0,profile:upgraded},token)).status,200);
 const old={...profile(200),campaignVersion:1};
 const rejected=await call('cloud/write',{revision:1,profile:old},token);
 assert.equal(rejected.status,409);assert.equal(rejected.body.profile.content.journal.signIns,7);
 const after=(await call('cloud/read',{},token)).body;
 assert.equal(after.revision,1);assert.deepEqual(after.profile.hangarPresets,upgraded.hangarPresets);
 assert.deepEqual(after.profile.content.collections,upgraded.content.collections);
 assert.equal((await call('cloud/write',{revision:1,profile:{...upgraded,credits:888}},token)).status,200);
 console.log(JSON.stringify({qaAccounts:[reg.body.account.id]}));
});
test('advanced progression survives older client and CAS collision',async()=>{
 const reg=await call('auth/register',{username:`qa_${randomBytes(5).toString('hex')}`,nickname:'Advanced QA',salt:randomBytes(16).toString('hex'),key:randomBytes(32).toString('hex')});
 assert.equal(reg.status,200);const token=reg.body.token;
 const upgraded={...profile(500),campaignVersion:1,hangarPresets:[{name:'Keep'}],content:{inventory:[],progressionVersion:1,advancedProgressionVersion:1,dailyChallenge:{tokens:8,cleared:[2]},advancedEquipment:{entries:[{id:1,refinement:2}]},petBond:{favor:[50,0,0],awakening:[1,0,0]}}};
 assert.equal((await call('cloud/write',{revision:0,profile:upgraded},token)).status,200);
 const old={...upgraded,content:{inventory:[],progressionVersion:1}};
 const reject=await call('cloud/write',{revision:1,profile:old},token);assert.equal(reject.status,409);assert.deepEqual(reject.body.profile,upgraded);
 assert.equal((await call('cloud/write',{revision:1,profile:{...upgraded,credits:600}},token)).status,200);
 assert.equal((await call('cloud/write',{revision:1,profile:upgraded},token)).status,409);
 const after=(await call('cloud/read',{},token)).body;assert.equal(after.revision,2);assert.deepEqual(after.profile.content,upgraded.content);assert.deepEqual(after.profile.hangarPresets,upgraded.hangarPresets);
 console.log(JSON.stringify({qaAccounts:[reg.body.account.id]}));
});
test('account isolation, cross-device CAS saves, shared guild, replay safety, session recovery',async()=>{
 const name=`qa_${randomBytes(5).toString('hex')}`,salt=randomBytes(16).toString('hex'),password=randomBytes(20).toString('hex');
 const key=pbkdf2Sync(password,Buffer.from(salt,'hex'),600000,32,'sha256').toString('hex');
 assert.equal((await call('cloud/read')).status,401);
 assert.equal((await call('auth/challenge',{username:name},null,{Origin:'https://evil.example'})).status,403);
 const reg=await call('auth/register',{username:name,nickname:'QA One',salt,key});assert.equal(reg.status,200);
 const a=reg.body;assert.equal(a.recoveryCode.length,48);assert.ok(a.token);assert.equal(a.revision,0);
 assert.equal((await call('auth/login',{username:name,key:'0'.repeat(64)})).status,401);
 assert.equal((await call('auth/challenge',{username:name})).body.salt,salt);
 const b=(await call('auth/login',{username:name,key})).body;
 const writes=await Promise.all([call('cloud/write',{revision:0,profile:profile(200)},a.token),call('cloud/write',{revision:0,profile:profile(300)},b.token)]);
 assert.deepEqual(writes.map(x=>x.status).sort(),[200,409]);
 const remote=(await call('cloud/read',{},b.token)).body;assert.equal(remote.revision,1);assert.ok([200,300].includes(remote.profile.credits));
 assert.equal((await call('cloud/write',{revision:1,profile:profile(-1)},a.token)).status,400);
 const guild=(await call('guild/create',{name:'QA Fleet'},a.token)).body;assert.equal(guild.members.length,1);
 const other=(await call('auth/register',{username:`${name}b`,nickname:'QA Two',salt:randomBytes(16).toString('hex'),key:randomBytes(32).toString('hex')})).body;
 assert.equal((await call('cloud/read',{},other.token)).body.profile,null);
 assert.equal((await call('guild/join',{code:guild.guild.id},other.token)).body.members.length,2);
 await Promise.all([call('guild/checkin',{},a.token),call('guild/checkin',{},b.token)]);
 let state=(await call('guild/state',{},a.token)).body;assert.equal(state.user.coins,10);assert.equal(state.guild.xp,20);
 await Promise.all([call('guild/shop',{},a.token),call('guild/shop',{},b.token)]);
 state=(await call('guild/state',{},a.token)).body;assert.equal(state.user.coins,0);assert.equal(state.rewards.length,1);
 for(let i=0;i<4;i++)assert.equal((await call('guild/report',{runId:`run-${i}`,kills:1000,seconds:60},a.token)).status,200);
 assert.equal((await call('guild/report',{runId:'run-0',kills:1000,seconds:60},b.token)).status,200);
 state=(await call('guild/state',{},other.token)).body;assert.equal(state.damage,9000);
 const newSalt=randomBytes(16).toString('hex'),newKey=randomBytes(32).toString('hex');
 const recovered=await call('auth/recover',{username:name,recoveryCode:a.recoveryCode,salt:newSalt,key:newKey});assert.equal(recovered.status,200);
 assert.equal((await call('cloud/read',{},a.token)).status,401);assert.equal((await call('cloud/read',{},b.token)).status,401);
 assert.equal((await call('auth/recover',{username:name,recoveryCode:a.recoveryCode,salt:newSalt,key:newKey})).status,401);
 assert.equal((await call('cloud/read',{},recovered.body.token)).body.revision,1);
 await call('auth/logout-all',{},recovered.body.token);
 assert.equal((await call('cloud/read',{},recovered.body.token)).status,401);
 // Only emit non-secret identifiers for scoped QA cleanup.
 console.log(JSON.stringify({qaAccounts:[a.account.id,other.account.id],qaGuild:guild.guild.id}));
});
test('web sessions are HttpOnly cookies and reject malformed JSON',async()=>{
 const name=`qa_${randomBytes(5).toString('hex')}`;
 const result=await call('auth/register',{username:name,nickname:'QA Cookie',salt:randomBytes(16).toString('hex'),key:randomBytes(32).toString('hex')},null,{'X-Client':'web'});
 assert.equal(result.status,200);assert.equal(result.body.token,undefined);
 const cookie=result.headers.get('set-cookie');assert.match(cookie,/HttpOnly; Secure; SameSite=Strict/);
 const me=await call('auth/me',{},null,{Cookie:cookie.split(';')[0]});assert.equal(me.status,200);
 const response=await fetch(`${base}/api/cloud/write`,{method:'POST',headers:{'Content-Type':'application/json'},body:'{broken'});assert.equal(response.status,400);
 console.log(JSON.stringify({qaAccounts:[result.body.account.id]}));
});

test('migrated campaign cannot be overwritten by an old client',async()=>{
 const reg=await call('auth/register',{username:`qa_${randomBytes(5).toString('hex')}`,nickname:'Campaign QA',salt:randomBytes(16).toString('hex'),key:randomBytes(32).toString('hex')});
 assert.equal(reg.status,200);const token=reg.body.token;
 const upgraded={...profile(777),campaignVersion:1,campaignLoop:2,cycleClears:[0,1],pilotLevel:20,selectedStage:2};
 assert.equal((await call('cloud/write',{revision:0,profile:upgraded},token)).status,200);
 const rejected=await call('cloud/write',{revision:1,profile:profile(200)},token);
 assert.equal(rejected.status,409);assert.equal(rejected.body.profile.campaignLoop,2);
 const after=(await call('cloud/read',{},token)).body;
 assert.equal(after.revision,1);assert.equal(after.profile.credits,777);
 assert.equal((await call('cloud/write',{revision:1,profile:{...upgraded,credits:888}},token)).status,200);
 console.log(JSON.stringify({qaAccounts:[reg.body.account.id]}));
});
