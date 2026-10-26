// Password stretching happens in the official clients (PBKDF2-SHA256 / 600,000,
// unique server-issued salt). The transmitted 256-bit key is password-equivalent;
// TLS is mandatory. D1 stores only a second salted verifier, never that key.
import {timingSafeEqual} from 'node:crypto';
import {createCommerce,commerceConfig,CommerceError} from './commerce.mjs';
import {ensureCommerceSchema} from './commerce_schema.mjs';
import {verifyShopPurchase,shopEnabled} from './shop.mjs';
import {validAircraftSnapshot} from './aircraft_config.mjs';
const enc=new TextEncoder();
const bytesHex=b=>Array.from(b,x=>x.toString(16).padStart(2,'0')).join('');
const randomHex=n=>bytesHex(crypto.getRandomValues(new Uint8Array(n)));
const sha=async value=>bytesHex(new Uint8Array(await crypto.subtle.digest('SHA-256',enc.encode(value))));
const now=()=>Math.floor(Date.now()/1000);
const SESSION=30*86400;
class ApiError extends Error {constructor(status,message,extra={}){super(message);this.status=status;this.extra=extra;}}
const fail=(status,message,extra)=>{throw new ApiError(status,message,extra)};
const q=(db,sql,...args)=>db.prepare(sql).bind(...args);
const first=(db,sql,...args)=>q(db,sql,...args).first();
const rows=async(db,sql,...args)=>(await q(db,sql,...args).all()).results;
const username=v=>typeof v==='string'&&/^[a-z0-9_]{4,24}$/.test(v.trim().toLowerCase())?v.trim().toLowerCase():fail(400,'아이디는 영문 소문자·숫자·밑줄 4~24자로 입력하세요.');
const hex=(value,length)=>typeof value==='string'&&new RegExp(`^[a-f0-9]{${length}}$`).test(value);
const equal=(a,b)=>typeof a==='string'&&typeof b==='string'&&a.length===b.length&&timingSafeEqual(enc.encode(a),enc.encode(b));
const cleanName=(v,max)=>typeof v==='string'&&v.trim().length>0&&v.trim().length<=max?v.trim():fail(400,`이름은 1~${max}자로 입력하세요.`);
function calendar(){const d=new Date(Date.now()+9*3600000);const day=d.toISOString().slice(0,10);const monday=new Date(d);monday.setUTCDate(d.getUTCDate()-((d.getUTCDay()+6)%7));return {day,week:monday.toISOString().slice(0,10)};}
async function rate(db,key,limit,seconds){const at=now(),bucket=Math.floor(at/seconds);const id=await sha(`${key}:${bucket}`);const value=await q(db,'INSERT INTO rate_limits VALUES(?,1,?) ON CONFLICT(key) DO UPDATE SET hits=hits+1 RETURNING hits',id,at+seconds).first();if(value.hits>limit)fail(429,'요청이 많습니다. 잠시 후 다시 시도하세요.');}
function snapshot(value){
 if(!value||Array.isArray(value)||typeof value!=='object'||value.version!==4||!value.content||!Array.isArray(value.content.inventory))fail(400,'지원하지 않는 저장 데이터입니다. 앱을 업데이트하세요.');
 const copy=JSON.parse(JSON.stringify(value));delete copy.content.guildToken;
 if(copy.content.inventory.length>246||JSON.stringify(copy).length>400000)fail(413,'저장 데이터가 너무 큽니다.');
 for(const key of ['credits','runs','totalKills','blueprints'])if(!Number.isSafeInteger(copy[key])||copy[key]<0||copy[key]>1e9)fail(400,'저장 수치가 올바르지 않습니다.');
 if(copy.armamentProgressionVersion!==undefined){
  const weapons=copy.armamentCollection,ids=['pulse','kunai','katana','bat','shotgun','revolver','lightchaser','void','disorder','lance'];
  if(copy.armamentProgressionVersion!==1||!weapons||Array.isArray(weapons)||typeof weapons!=='object'||!Object.hasOwn(weapons,'pulse')||Object.entries(weapons).some(([id,level])=>!ids.includes(id)||!Number.isInteger(level)||level<0||level>10)||!Number.isInteger(copy.selectedArmament)||!Object.hasOwn(weapons,ids[copy.selectedArmament]))fail(400,'주무기 소유·성장 정보가 올바르지 않습니다.');
 }
 if(copy.campaignRewardsVersion!==undefined){
  const book=copy.campaignRewards;
  if(copy.campaignRewardsVersion!==1||!book||Array.isArray(book)||typeof book!=='object'||[['bossWorlds',10],['routes',100]].some(([key,max])=>!Array.isArray(book[key])||book[key].length>max||new Set(book[key]).size!==book[key].length||book[key].some(n=>!Number.isInteger(n)||n<0||n>=max)))fail(400,'항로 보상 기록이 올바르지 않습니다.');
 }
 if(copy.bossGearVersion!==undefined){
  const book=copy.bossGear;
  if(copy.bossGearVersion!==1||!book||typeof book!=='object'||!Array.isArray(book.defeats)||!Array.isArray(book.claimed)||book.defeats.length!==10||book.claimed.length!==10||book.defeats.some(n=>!Number.isInteger(n)||n<0||n>9999)||book.claimed.some((n,i)=>!Number.isInteger(n)||n<0||n>Math.floor((book.defeats[i]+1)/2)))fail(400,'보스 전용 장비 기록이 올바르지 않습니다.');
 }
 if(!validAircraftSnapshot(copy))fail(400,'기체 조립 정보가 올바르지 않습니다.');
 return JSON.stringify(copy);
}
function publicAccount(a){return {id:a.id,username:a.username,nickname:a.nickname};}
function cloud(a){return {revision:a.revision,updatedAt:a.updated,profile:a.profile?JSON.parse(a.profile):null};}
async function authenticate(request,db){
 const bearer=request.headers.get('Authorization')?.replace(/^Bearer /,'');
 const cookie=request.headers.get('Cookie')?.split(';').map(s=>s.trim()).find(s=>s.startsWith('ss_session='))?.slice(11);
 const token=bearer||cookie;if(!token||!hex(token,64))fail(401,'다시 로그인해 주세요.');
 const session=await first(db,'SELECT sessions.hash,accounts.* FROM sessions JOIN accounts ON accounts.id=sessions.account WHERE hash=? AND expires>? AND disabled=0',await sha(token),now());
 if(!session)fail(401,'로그인이 만료되었습니다. 다시 로그인해 주세요.');return session;
}
async function loginResponse(db,a,request,recoveryCode){
 const token=randomHex(32),hash=await sha(token),at=now();
 const inserted=await db.batch([q(db,'DELETE FROM sessions WHERE account=? AND (expires<=? OR hash IN (SELECT hash FROM sessions WHERE account=? ORDER BY created DESC LIMIT -1 OFFSET 9))',a.id,at,a.id),q(db,'INSERT INTO sessions SELECT ?,?,?,?,? WHERE EXISTS(SELECT 1 FROM accounts WHERE id=? AND verifier=? AND disabled=0)',hash,a.id,at+SESSION,at,(request.headers.get('User-Agent')||'device').slice(0,120),a.id,a.verifier)]);
 if(!inserted[1].meta.changes)fail(401,'인증 정보가 변경되었습니다. 다시 로그인하세요.');
 const native=request.headers.get('X-Client')==='native';
 return {body:{account:publicAccount(a),...cloud(a),...(native?{token}:{}),...(recoveryCode?{recoveryCode}:{})},cookie:native?null:`ss_session=${token}; Path=/api; HttpOnly; Secure; SameSite=Strict; Max-Age=${SESSION}`};
}
async function guild(action,data,a,db){
 const {day,week}=calendar();let m=await first(db,'SELECT * FROM members WHERE account=?',a.id);
 if(!m){await q(db,'INSERT OR IGNORE INTO members(account) VALUES(?)',a.id).run();m={guild:null,coins:0,checkday:''};}
 if(action==='create'){
  if(m.guild)fail(409,'이미 길드에 가입되어 있습니다.');const id=randomHex(3).toUpperCase(),name=cleanName(data.name,24);
  await db.batch([q(db,'INSERT INTO guilds(id,name) VALUES(?,?)',id,name),q(db,'UPDATE members SET guild=? WHERE account=? AND guild IS NULL',id,a.id)]);
 } else if(action==='join'){
  if(m.guild)fail(409,'이미 길드에 가입되어 있습니다.');const id=String(data.code||'').trim().toUpperCase();
  if(!await first(db,'SELECT id FROM guilds WHERE id=?',id))fail(404,'길드 코드를 찾을 수 없습니다.');
  try{await q(db,'UPDATE members SET guild=? WHERE account=? AND guild IS NULL',id,a.id).run();}catch(e){if(String(e).includes('guild_full'))fail(409,'길드 정원이 찼습니다.');throw e;}
 } else if(action==='leave'){await q(db,'UPDATE members SET guild=NULL WHERE account=?',a.id).run();}
 else if(['checkin','donate','report','shop','raid'].includes(action)){
  if(!m.guild)fail(409,'길드에 먼저 가입하세요.');
  if(action==='checkin')await db.batch([q(db,'UPDATE guilds SET xp=xp+20 WHERE id=? AND EXISTS(SELECT 1 FROM members WHERE account=? AND checkday<>?)',m.guild,a.id,day),q(db,'UPDATE members SET coins=coins+10,checkday=? WHERE account=? AND checkday<>?',day,a.id,day)]);
  if(action==='donate'){
   const results=await db.batch([q(db,'UPDATE guilds SET xp=xp+30 WHERE id=? AND EXISTS(SELECT 1 FROM members WHERE account=? AND coins>=10)',m.guild,a.id),q(db,'UPDATE members SET coins=coins-10 WHERE account=? AND coins>=10',a.id)]);
   if(!results[1].meta.changes)fail(409,'길드 코인 10개가 필요합니다.');
  }
  if(action==='report'){
   if(typeof data.runId!=='string'||data.runId.length>200||!Number.isSafeInteger(data.kills)||!Number.isSafeInteger(data.seconds)||data.seconds<30||data.kills<10)fail(400,'유효한 전투 기록이 아닙니다.');
   // Gameplay is client-simulated. This bounds/replays reports, not anti-cheat adjudication.
   await q(db,'INSERT OR IGNORE INTO reports SELECT ?,?,?,?,?,? WHERE (SELECT COUNT(*) FROM reports WHERE account=? AND day=?)<3',a.id,data.runId,m.guild,week,day,Math.min(3000,data.kills*3),a.id,day).run();
  }
  if(action==='shop'){
   const id=`shop-${day}`,body=JSON.stringify({id,title:'길드 일일 보급',food:30,plans:2});
   await q(db,"INSERT OR IGNORE INTO rewards SELECT ?,?,'shop',? WHERE EXISTS(SELECT 1 FROM members WHERE account=? AND coins>=10)",a.id,id,body,a.id).run();
   if(!await first(db,'SELECT id FROM rewards WHERE account=? AND id=?',a.id,id))fail(409,'길드 코인 10개가 필요합니다.');
  }
  if(action==='raid'){
   const id=`raid-${m.guild}-${week}`,body=JSON.stringify({id,title:'길드 주간 토벌',gearKeys:3,techKeys:3,food:100});
   await q(db,"INSERT OR IGNORE INTO rewards SELECT ?,?,'raid',? WHERE (SELECT COALESCE(SUM(damage),0) FROM reports WHERE guild=? AND week=?)>=100000 AND EXISTS(SELECT 1 FROM reports WHERE account=? AND guild=? AND week=?)",a.id,id,body,m.guild,week,a.id,m.guild,week).run();
   if(!await first(db,'SELECT id FROM rewards WHERE account=? AND id=?',a.id,id))fail(409,'토벌 완료 및 본인 참여가 필요합니다.');
  }
 }else if(action!=='state')fail(404,'지원하지 않는 길드 요청입니다.');
 m=await first(db,'SELECT * FROM members WHERE account=?',a.id);
 const result={day,week,user:{name:a.nickname,guild:m.guild,coins:m.coins,checkday:m.checkday},directory:await rows(db,'SELECT g.id,g.name,COUNT(m.account) AS members FROM guilds g LEFT JOIN members m ON m.guild=g.id GROUP BY g.id HAVING COUNT(m.account)>0 ORDER BY g.xp DESC LIMIT 20'),rewards:(await rows(db,'SELECT body FROM rewards WHERE account=?',a.id)).map(r=>JSON.parse(r.body))};
 if(m.guild){result.guild=await first(db,'SELECT * FROM guilds WHERE id=?',m.guild);result.members=await rows(db,'SELECT a.nickname AS name FROM members m JOIN accounts a ON a.id=m.account WHERE m.guild=?',m.guild);result.damage=(await first(db,'SELECT COALESCE(SUM(damage),0) AS value FROM reports WHERE guild=? AND week=?',m.guild,week)).value;result.attempts=(await first(db,'SELECT COUNT(*) AS value FROM reports WHERE account=? AND day=?',a.id,day)).value;}
 return result;
}
async function api(request,env){
 const db=env.DB,path=new URL(request.url).pathname.slice(5);
 if(path==='health'&&request.method==='GET'){await first(db,'SELECT 1 FROM accounts LIMIT 1');const c=commerceConfig(env);return {body:{ok:true,version:env.APP_VERSION,storage:'D1',commerce:{billing:c.billing,rewardedAds:c.ads,shop:shopEnabled(env)}}};}
 if(path==='commerce/admob-ssv'&&request.method==='GET'){if(commerceConfig(env).ads)await ensureCommerceSchema(db);return {body:await createCommerce(env).ssv(request)};}
 if(path==='commerce/play-rtdn'&&request.method==='POST'){if(commerceConfig(env).billing)await ensureCommerceSchema(db);return {body:await createCommerce(env).rtdn(request)};}
 if(request.method!=='POST')fail(405,'POST 요청만 허용합니다.');
 if(!request.headers.get('Content-Type')?.startsWith('application/json'))fail(415,'JSON 요청이 필요합니다.');
 if(Number(request.headers.get('Content-Length')||0)>450000)fail(413,'요청이 너무 큽니다.');
 const raw=await request.text();if(raw.length>450000)fail(413,'요청이 너무 큽니다.');let data;try{data=JSON.parse(raw);}catch{fail(400,'JSON 형식 오류입니다.');}
 if(!data||typeof data!=='object'||Array.isArray(data))fail(400,'잘못된 요청입니다.');
 const ip=request.headers.get('CF-Connecting-IP')||'local';
 if(path==='shop/verify'){await rate(db,`shop-ip:${ip}`,30,60);return {body:await verifyShopPurchase(env,data)};}
 if(['auth/challenge','auth/register','auth/login','auth/recover'].includes(path)){
  await rate(db,`auth-ip:${ip}`,80,900);
  if(path==='auth/challenge'){
   const name=username(data.username);const a=await first(db,'SELECT salt FROM accounts WHERE username=? AND disabled=0',name);
   return {body:{salt:a?.salt||randomHex(16),iterations:600000}};
  }
  if(['auth/register','auth/login','auth/recover'].includes(path)){
   const name=username(data.username);await rate(db,`auth-name:${name}`,12,900);
   if(!hex(data.key,64))fail(400,'비밀번호 키 형식이 잘못되었습니다.');
   let a=await first(db,'SELECT * FROM accounts WHERE username=?',name);
   if(path==='auth/register'){
    if(a)fail(409,'이미 사용 중인 아이디입니다.');if(!hex(data.salt,32))fail(400,'인증을 다시 시도하세요.');
    const id=crypto.randomUUID(),recoveryCode=randomHex(24),at=now();
    const created=await q(db,'INSERT OR IGNORE INTO accounts(id,username,nickname,salt,verifier,recovery,created,updated) VALUES(?,?,?,?,?,?,?,?)',id,name,cleanName(data.nickname,16),data.salt,await sha(`${data.salt}:${data.key}`),await sha(recoveryCode),at,at).run();
    if(!created.meta.changes)fail(409,'이미 사용 중인 아이디입니다.');
    a=await first(db,'SELECT * FROM accounts WHERE id=?',id);return loginResponse(db,a,request,recoveryCode);
   }
   if(path==='auth/login'){
    const candidate=await sha(`${a?.salt||'unknown'}:${data.key}`);
    if(!a||a.disabled||!equal(candidate,a.verifier))fail(401,'아이디 또는 비밀번호가 올바르지 않습니다.');
    return loginResponse(db,a,request);
   }
   if(!a||a.disabled||!hex(data.recoveryCode,48)||!equal(await sha(data.recoveryCode),a.recovery))fail(401,'아이디 또는 복구 코드가 올바르지 않습니다.');
   if(!hex(data.salt,32))fail(400,'새 인증 정보가 올바르지 않습니다.');const recoveryCode=randomHex(24);
   const recovered=await db.batch([q(db,'UPDATE accounts SET salt=?,verifier=?,recovery=? WHERE id=? AND recovery=?',data.salt,await sha(`${data.salt}:${data.key}`),await sha(recoveryCode),a.id,a.recovery),q(db,'DELETE FROM sessions WHERE account=? AND EXISTS(SELECT 1 FROM accounts WHERE id=? AND recovery=?)',a.id,a.id,await sha(recoveryCode))]);
   if(!recovered[0].meta.changes)fail(401,'이미 사용한 복구 코드입니다.');
   a=await first(db,'SELECT * FROM accounts WHERE id=?',a.id);return loginResponse(db,a,request,recoveryCode);
  }
 }
 const a=await authenticate(request,db);await rate(db,`user:${a.id}`,180,60);
 await ensureCommerceSchema(db);
 if(path.startsWith('commerce/')){
  await rate(db,`commerce:${a.id}`,path==='commerce/purchase'||path==='commerce/refresh'?12:90,60);
  return {body:await createCommerce(env).route(path,a,data)};
 }
 if(path==='auth/me')return {body:{account:publicAccount(a),...cloud(a)}};
 if(path==='auth/logout'||path==='auth/logout-all'){
  await q(db,path.endsWith('-all')?'DELETE FROM sessions WHERE account=?':'DELETE FROM sessions WHERE hash=?',path.endsWith('-all')?a.id:a.hash).run();
  return {body:{ok:true},cookie:'ss_session=; Path=/api; HttpOnly; Secure; SameSite=Strict; Max-Age=0'};
 }
 if(path==='auth/delete'){
  await rate(db,`delete:${a.id}`,5,900);
  if(username(data.username)!==a.username||!hex(data.key,64))fail(400,'삭제할 계정과 인증 정보를 다시 확인하세요.');
  if(!equal(await sha(`${a.salt}:${data.key}`),a.verifier))fail(401,'현재 비밀번호가 올바르지 않습니다.');
  // Existing foreign keys cascade sessions, save history, membership, reports
  // and rewards. Recheck the verifier in DELETE against concurrent recovery.
  const deleted=await q(db,'DELETE FROM accounts WHERE id=? AND salt=? AND verifier=?',a.id,a.salt,a.verifier).run();
  if(!deleted.meta.changes)fail(409,'인증 정보가 바뀌었습니다. 다시 로그인한 뒤 시도하세요.');
  return {body:{ok:true},cookie:'ss_session=; Path=/api; HttpOnly; Secure; SameSite=Strict; Max-Age=0'};
 }
 if(path==='cloud/read')return {body:cloud(a)};
 if(path==='cloud/write'){
  if(!Number.isSafeInteger(data.revision)||data.revision<0)fail(400,'저장 버전이 올바르지 않습니다.');
  // An older client must not erase the migrated 100-stage campaign fields.
  if(a.profile&&JSON.parse(a.profile).campaignVersion===1&&data.profile?.campaignVersion!==1)fail(409,'새 항로를 보존하려면 앱을 새로고침해 업데이트하세요.',cloud(a));
  if(a.profile&&JSON.parse(a.profile).content?.progressionVersion===1&&data.profile?.content?.progressionVersion!==1)fail(409,'수집품·활동·저장 편성을 보존하려면 앱을 새로고침해 업데이트하세요.',cloud(a));
  if(a.profile&&JSON.parse(a.profile).content?.advancedProgressionVersion===1&&data.profile?.content?.advancedProgressionVersion!==1)fail(409,'일일 도전·장비 고급 성장·펫 각성을 보존하려면 앱을 새로고침해 업데이트하세요.',cloud(a));
  if(a.profile&&JSON.parse(a.profile).armamentProgressionVersion===1&&data.profile?.armamentProgressionVersion!==1)fail(409,'주무기 소유·성장을 보존하려면 앱을 새로고침해 업데이트하세요.',cloud(a));
  if(a.profile&&JSON.parse(a.profile).campaignRewardsVersion===1&&data.profile?.campaignRewardsVersion!==1)fail(409,'보스·항로 보상 기록을 보존하려면 앱을 새로고침해 업데이트하세요.',cloud(a));
  if(a.profile&&JSON.parse(a.profile).bossGearVersion===1&&data.profile?.bossGearVersion!==1)fail(409,'보스 전용 장비를 보존하려면 앱을 새로고침해 업데이트하세요.',cloud(a));
  if(a.profile&&JSON.parse(a.profile).aircraft&&data.profile?.aircraft===undefined&&data.profile?.moduleFleet===undefined)fail(409,'기체 조립을 보존하려면 앱을 새로고침해 업데이트하세요.',cloud(a));
  if(a.profile&&JSON.parse(a.profile).moduleFleet&&data.profile?.moduleFleet===undefined)fail(409,'모듈 파츠와 레벨을 보존하려면 앱을 업데이트하세요.',cloud(a));
  if(a.profile&&JSON.parse(a.profile).catGearVersion===1&&data.profile?.catGearVersion!==1)fail(409,'수호묘 장비와 임무를 보존하려면 앱을 업데이트하세요.',cloud(a));
  // A verified reward must survive choosing device progress after a conflict.
  // Client credits remain free progression; this counter only reconciles the
  // provider-verified increments, and never confers paid ownership.
  snapshot(data.profile);
  const total=(await first(db,'SELECT COALESCE(SUM(credits),0) AS n FROM ad_grants WHERE account=?',a.id)).n;
  if(total>0&&data.profile.verifiedAdCredits===undefined)fail(409,'광고 보상을 보존하려면 앱을 업데이트하세요.',cloud(a));
  const applied=data.profile.verifiedAdCredits??0;
  if(!Number.isSafeInteger(applied)||applied<0||applied>total)fail(400,'광고 보상 저장 기록을 확인하세요.');
  if(total>0||Object.hasOwn(data.profile,'verifiedAdCredits')){
   data.profile.credits=Math.min(9999999,data.profile.credits+total-applied);
   data.profile.verifiedAdCredits=total;
  }
  const value=snapshot(data.profile),at=now();
  const previous=a.profile?JSON.parse(a.profile):null;
  if(previous?.bossGearVersion===1&&['defeats','claimed'].some(key=>previous.bossGear[key].some((n,i)=>data.profile.bossGear[key][i]<n)))fail(409,'이미 기록된 보스 장비 회수 진행을 지울 수 없습니다.',cloud(a));
  if(previous?.campaignRewardsVersion===1&&['bossWorlds','routes'].some(key=>(previous.campaignRewards?.[key]||[]).some(id=>!data.profile.campaignRewards[key].includes(id))))fail(409,'이미 받은 보스·항로 보상 기록을 지울 수 없습니다. 최신 진행을 불러오세요.',cloud(a));
  const result=await q(db,'UPDATE accounts SET profile=?,revision=revision+1,updated=? WHERE id=? AND revision=?',value,at,a.id,data.revision).run();
  if(!result.meta.changes){const current=await first(db,'SELECT * FROM accounts WHERE id=?',a.id);fail(409,'다른 기기에서 진행이 변경되었습니다.',cloud(current));}
  return {body:{revision:data.revision+1,updatedAt:at,verifiedAdCredits:total}};
 }
 if(path.startsWith('guild/'))return {body:await guild(path.slice(6),data,a,db)};
 fail(404,'지원하지 않는 요청입니다.');
}
export default {
 async fetch(request,env){
  const url=new URL(request.url);
  if(!url.pathname.startsWith('/api/'))return env.ASSETS.fetch(request);
  const origin=request.headers.get('Origin');const allowed=origin===url.origin||(env.ALLOW_LOCAL_ORIGIN==='true'&&/^http:\/\/(127\.0\.0\.1|localhost):\d+$/.test(origin||''));
  const headers={'Cache-Control':'no-store','Content-Type':'application/json; charset=utf-8','X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer','Strict-Transport-Security':'max-age=31536000'};
  if(origin&&!allowed)return Response.json({error:'허용되지 않은 출처입니다.'},{status:403,headers});
  if(origin&&allowed){headers['Access-Control-Allow-Origin']=origin;headers['Access-Control-Allow-Credentials']='true';headers.Vary='Origin';}
  if(request.method==='OPTIONS')return new Response(null,{status:204,headers:{...headers,'Access-Control-Allow-Headers':'Content-Type,Authorization,X-Client','Access-Control-Allow-Methods':'POST,GET,OPTIONS'}});
  try{const result=await api(request,env);if(result.cookie)headers['Set-Cookie']=result.cookie;return Response.json(result.body,{headers});}
  catch(error){const status=error instanceof ApiError||error instanceof CommerceError?error.status:500;if(status===500)console.error('api-failure',url.pathname,'internal error');return Response.json({error:status===500?'서버 처리에 실패했습니다. 잠시 후 다시 시도하세요.':error.message,...(error.extra||{})},{status,headers});}
 },
 async scheduled(_event,env){await env.DB.batch([q(env.DB,'DELETE FROM sessions WHERE expires<=?',now()),q(env.DB,'DELETE FROM rate_limits WHERE expires<=?',now())]);await ensureCommerceSchema(env.DB);await createCommerce(env).reconcile();}
};
