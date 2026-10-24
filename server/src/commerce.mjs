import {createHash,createPrivateKey,createPublicKey,sign,verify,randomBytes,createCipheriv,createDecipheriv} from 'node:crypto';

export class CommerceError extends Error {
 constructor(status,message){super(message);this.status=status;}
}
const fail=(status,message)=>{throw new CommerceError(status,message);};
const hash=value=>createHash('sha256').update(value).digest('hex');
const q=(db,sql,...args)=>db.prepare(sql).bind(...args);
const first=(db,sql,...args)=>q(db,sql,...args).first();
const rows=async(db,sql,...args)=>(await q(db,sql,...args).all()).results;
const realAdId=(value,separator)=>new RegExp(`^ca-app-pub-(?!3940256099942544)\\d{16}${separator}\\d{10}$`).test(value||'');
export function commerceConfig(env){
 const product=env.PLAY_SUPPORTER_PRODUCT||'',packageName=env.PLAY_PACKAGE||'';
 const billing=env.COMMERCE_BILLING_ENABLED==='true'&&/^[a-z][a-z0-9_.]{2,100}$/.test(product)&&!product.startsWith('android.test.')&&packageName==='com.shootingstar.shootingstar'&&!!env.PLAY_SERVICE_ACCOUNT&&/^[a-f0-9]{64}$/.test(env.PLAY_TOKEN_KEY||'')&&!!env.PLAY_RTDN_AUDIENCE&&!!env.PLAY_RTDN_EMAIL;
 const ads=env.COMMERCE_ADS_ENABLED==='true'&&realAdId(env.ADMOB_APP_ID,'~')&&realAdId(env.ADMOB_REWARDED_UNIT,'/')&&env.ADMOB_APP_ID.split('~')[0]===env.ADMOB_REWARDED_UNIT.split('/')[0];
 return {billing,ads,product,packageName,adUnit:env.ADMOB_REWARDED_UNIT||'',appId:env.ADMOB_APP_ID||'',reward:20,dailyCap:2};
}
const keyCache=new Map(),oauthCache=new Map();
async function fetchJson(fetcher,url,options){
 const response=await fetcher(url,{...options,signal:AbortSignal.timeout(8000)});
 if(!response.ok)throw new CommerceError(response.status===404||response.status===410?response.status:502,'제공자 확인에 실패했습니다. 잠시 후 다시 시도하세요.');
 return response.status===204?{}:response.json();
}
async function googleKeys(fetcher,url,at){
 let cached=keyCache.get(url);
 if(!cached||cached.until<at){cached={body:await fetchJson(fetcher,url),until:at+3600};keyCache.set(url,cached);}
 return cached.body;
}
export function sealToken(token,hexKey){
 const iv=randomBytes(12),cipher=createCipheriv('aes-256-gcm',Buffer.from(hexKey,'hex'),iv);
 const value=Buffer.concat([cipher.update(token,'utf8'),cipher.final()]);
 return Buffer.concat([iv,cipher.getAuthTag(),value]).toString('base64url');
}
export function unsealToken(value,hexKey){
 const bytes=Buffer.from(value,'base64url'),decipher=createDecipheriv('aes-256-gcm',Buffer.from(hexKey,'hex'),bytes.subarray(0,12));
 decipher.setAuthTag(bytes.subarray(12,28));return Buffer.concat([decipher.update(bytes.subarray(28)),decipher.final()]).toString('utf8');
}
// Raw, percent-escaped query bytes are signed. Never rebuild/reorder them.
export function checkSsvSignature(url,keys){
 const raw=new URL(url).search.slice(1),match=/^(.+)&signature=([A-Za-z0-9_%-]+={0,2})&key_id=(\d+)$/.exec(raw);
 if(!match||raw.length>10000)fail(400,'광고 검증 형식이 올바르지 않습니다.');
 const params=new URLSearchParams(raw),seen=new Set();
 for(const [key] of params){if(seen.has(key))fail(400,'중복 검증 매개변수입니다.');seen.add(key);}
 const entry=keys.keys?.find(k=>String(k.keyId)===match[3]);
 if(!entry||!verify('sha256',Buffer.from(match[1]),entry.pem,Buffer.from(decodeURIComponent(match[2]),'base64url')))fail(401,'광고 서명을 확인하지 못했습니다.');
 return Object.fromEntries(params);
}
export function checkRtdnJwt(token,keys,audience,email,at){
 try{
  const parts=token.split('.');if(parts.length!==3)throw Error();
  const header=JSON.parse(Buffer.from(parts[0],'base64url')),body=JSON.parse(Buffer.from(parts[1],'base64url'));
  const key=keys.keys?.find(k=>k.kid===header.kid&&k.kty==='RSA');
  if(header.alg!=='RS256'||!key||!verify('RSA-SHA256',Buffer.from(parts[0]+'.'+parts[1]),createPublicKey({key,format:'jwk'}),Buffer.from(parts[2],'base64url'))||!['accounts.google.com','https://accounts.google.com'].includes(body.iss)||body.aud!==audience||body.email!==email||body.email_verified!==true||!Number.isFinite(body.exp)||body.exp<=at||!Number.isFinite(body.iat)||body.iat>at+60||body.iat<at-7200)throw Error();
  return body;
 }catch{fail(401,'알림 발신자를 확인하지 못했습니다.');}
}

// Dependencies are injected by unit tests only, never via an HTTP flag or env
// bypass. Production always uses the fixed Google HTTPS endpoints below.
export function createCommerce(env,{fetcher=fetch,clock=()=>Math.floor(Date.now()/1000)}={}){
 const db=env.DB,config=commerceConfig(env);
 const accountBinding=id=>hash(`shootingstar.play.account.v1:${id}`);
 async function accessToken(){
  const key=hash(env.PLAY_SERVICE_ACCOUNT),cached=oauthCache.get(key),at=clock();
  if(cached&&cached.until>at)return cached.token;
  let credentials;try{credentials=JSON.parse(env.PLAY_SERVICE_ACCOUNT);}catch{fail(503,'결제 서비스 설정을 확인하고 있습니다.');}
  const header=Buffer.from(JSON.stringify({alg:'RS256',typ:'JWT'})).toString('base64url');
  const body=Buffer.from(JSON.stringify({iss:credentials.client_email,scope:'https://www.googleapis.com/auth/androidpublisher',aud:'https://oauth2.googleapis.com/token',iat:at,exp:at+3600})).toString('base64url');
  const value=header+'.'+body,signature=sign('RSA-SHA256',Buffer.from(value),createPrivateKey(credentials.private_key)).toString('base64url');
  const result=await fetchJson(fetcher,'https://oauth2.googleapis.com/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion:value+'.'+signature})});
  if(typeof result.access_token!=='string')fail(502,'결제 인증 응답을 확인하지 못했습니다.');
  oauthCache.set(key,{token:result.access_token,until:at+Math.min(3500,Number(result.expires_in)||300)-60});return result.access_token;
 }
 async function providerPurchase(token,product,ack=false){
  const base=`https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(config.packageName)}/purchases/products/${encodeURIComponent(product)}/tokens/${encodeURIComponent(token)}`;
  return fetchJson(fetcher,base+(ack?':acknowledge':''),{method:ack?'POST':'GET',headers:{Authorization:`Bearer ${await accessToken()}`,...(ack?{'Content-Type':'application/json'}:{})},...(ack?{body:'{}'}:{})});
 }
 async function state(account){
  const purchases=await rows(db,"SELECT product FROM store_purchases WHERE account=? AND state='purchased'",account.id);
  const day=new Date(clock()*1000).toISOString().slice(0,10);
  const grants=await rows(db,'SELECT transaction_id AS id,run,credits,day FROM ad_grants WHERE account=? ORDER BY created DESC LIMIT 20',account.id);
  const used=(await first(db,'SELECT COUNT(*) AS n FROM ad_grants WHERE account=? AND day=?',account.id,day)).n;
  return {billingAvailable:config.billing,adsAvailable:config.ads,productId:config.billing?config.product:null,adUnitId:config.ads?config.adUnit:null,adAppId:config.ads?config.appId:null,accountBinding:accountBinding(account.id),supporter:purchases.length>0,reward:20,remaining:Math.max(0,2-used),day,grants};
 }
 async function verifyPurchase(account,data){
  if(!config.billing)fail(503,'후원 상품을 준비하고 있습니다.');
  const token=data.token,product=data.productId;
  if(product!==config.product||typeof token!=='string'||token.length<10||token.length>4096)fail(400,'구매 정보를 다시 확인하세요.');
  const tokenHash=hash(token),old=await first(db,'SELECT * FROM store_purchases WHERE token_hash=?',tokenHash);
  if(old&&old.account!==account.id)fail(409,'다른 게임 계정에 연결된 구매입니다.');
  const purchase=await providerPurchase(token,product);
  if(purchase.obfuscatedExternalAccountId!==accountBinding(account.id)||purchase.productId&&purchase.productId!==product||purchase.purchaseToken&&purchase.purchaseToken!==token||purchase.quantity!==undefined&&purchase.quantity!==1)fail(403,'현재 계정의 구매가 아닙니다.');
  if(![0,1,2].includes(purchase.purchaseState))fail(502,'구매 상태를 확인하지 못했습니다.');
  const status=['purchased','revoked','pending'][purchase.purchaseState],at=clock();
  await q(db,"INSERT INTO store_purchases VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(token_hash) DO UPDATE SET state=CASE WHEN store_purchases.state='revoked' THEN 'revoked' ELSE excluded.state END,acknowledged=MAX(store_purchases.acknowledged,excluded.acknowledged),checked=excluded.checked,next_check=excluded.next_check WHERE store_purchases.account=excluded.account",tokenHash,account.id,product,sealToken(token,env.PLAY_TOKEN_KEY),status,purchase.acknowledgementState===1?1:0,at,at+(purchase.acknowledgementState===1?86400:3600)).run();
  const stored=await first(db,'SELECT * FROM store_purchases WHERE token_hash=?',tokenHash);
  if(stored.account!==account.id)fail(409,'다른 게임 계정에 연결된 구매입니다.');
  let acknowledged=stored.acknowledged===1;
  if(stored.state==='purchased'&&!acknowledged){
   // Ownership is durable BEFORE ack; temporary ack failure is retried by the
   // scheduler/restore. The client never completes an unverified purchase.
   try{await providerPurchase(token,product,true);await q(db,'UPDATE store_purchases SET acknowledged=1 WHERE token_hash=?',tokenHash).run();acknowledged=true;}catch{ /* retry without exposing token/provider response */ }
  }
  return {purchaseState:stored.state,acknowledged,...await state(account)};
 }
 async function beginAd(account,data){
  if(!config.ads)fail(503,'선택형 광고를 준비하고 있습니다.');
  const {runId,seconds,kills}=data,at=clock(),day=new Date(at*1000).toISOString().slice(0,10);
  // Sorties remain client simulated. Require a settled, uploaded run; this is
  // replay/eligibility protection, not a claim of server-side anti-cheat.
  const current=await first(db,'SELECT profile FROM accounts WHERE id=?',account.id),profile=current?.profile?JSON.parse(current.profile):null;
  if(typeof runId!=='string'||!/^[a-zA-Z0-9_-]{1,100}$/.test(runId)||!Number.isSafeInteger(seconds)||seconds<30||seconds>86400||!Number.isSafeInteger(kills)||kills<10||kills>1e7||!profile?.processedRunIds?.includes(runId)||!Number.isSafeInteger(profile?.credits)||profile.credits>9999979)fail(409,'정산과 저장이 끝난 유효한 출격에서 선택하세요.');
  if(await first(db,'SELECT 1 FROM ad_grants WHERE account=? AND run=?',account.id,runId))fail(409,'이미 추가 보상을 받은 출격입니다.');
  const existing=await first(db,'SELECT * FROM ad_attempts WHERE account=? AND run=? AND expires>? AND closed=0 ORDER BY created DESC LIMIT 1',account.id,runId,at);
  if(existing)return {nonce:existing.nonce,userId:accountBinding(account.id),expires:existing.expires,...await state(account)};
  // Reserve available slots while an ad may be on screen. A cancelled/no-fill
  // request closes its reservation, without consuming the successful day cap.
  const nonce=randomBytes(24).toString('hex');
  const inserted=await q(db,'INSERT INTO ad_attempts SELECT ?,?,?,?,?,?,0 WHERE (SELECT COUNT(*) FROM ad_grants WHERE account=? AND day=?)+(SELECT COUNT(*) FROM ad_attempts a WHERE account=? AND day=? AND expires>? AND closed=0 AND NOT EXISTS(SELECT 1 FROM ad_grants g WHERE g.nonce=a.nonce))<2',nonce,account.id,runId,day,at,at+900,account.id,day,account.id,day,at).run();
  if(!inserted.meta.changes)fail(409,'오늘의 추가 보상은 2회까지입니다. 진행 중인 광고도 확인해 주세요.');
  return {nonce,userId:accountBinding(account.id),expires:at+900,...await state(account)};
 }
 async function ssv(request){
  if(!config.ads)fail(503,'선택형 광고를 준비하고 있습니다.');
  const at=clock(),keys=await googleKeys(fetcher,'https://www.gstatic.com/admob/reward/verifier-keys.json',at),params=checkSsvSignature(request.url,keys);
  const nonce=params.custom_data,stamp=Number(params.timestamp),transaction=params.transaction_id;
  if(!/^[a-f0-9]{48}$/.test(nonce||'')||!/^[a-zA-Z0-9_.-]{1,200}$/.test(transaction||'')||!Number.isSafeInteger(stamp)||stamp>at*1000+60000||params.reward_amount!=='20'||params.reward_item!=='credits'||![config.adUnit,config.adUnit.split('/')[1]].includes(params.ad_unit))fail(400,'광고 보상 정보를 확인하지 못했습니다.');
  const prior=await first(db,'SELECT * FROM ad_grants WHERE transaction_id=?',transaction);
  if(prior){if(prior.nonce!==nonce)fail(409,'다른 요청의 거래입니다.');return {ok:true,duplicate:true};}
  if(stamp<at*1000-86400000)fail(400,'광고 확인 시간이 지났습니다.');
  const attempt=await first(db,'SELECT * FROM ad_attempts WHERE nonce=?',nonce);
  if(!attempt||params.user_id!==accountBinding(attempt.account)||stamp<attempt.created*1000-60000||stamp>attempt.expires*1000)fail(403,'유효한 보상 요청이 아닙니다.');
  const rewardDay=new Date(stamp).toISOString().slice(0,10);
  await q(db,"INSERT OR IGNORE INTO ad_grants SELECT ?,nonce,account,run,?,20,? FROM ad_attempts WHERE nonce=? AND EXISTS(SELECT 1 FROM accounts WHERE id=ad_attempts.account AND profile IS NOT NULL AND json_extract(profile,'$.credits')<=9999979) AND (SELECT COUNT(*) FROM ad_grants WHERE account=ad_attempts.account AND day=?)<2",transaction,rewardDay,at,nonce,rewardDay).run();
  const granted=await first(db,'SELECT * FROM ad_grants WHERE transaction_id=?',transaction);
  if(!granted){
   const sameRun=await first(db,'SELECT 1 FROM ad_grants WHERE account=? AND run=?',attempt.account,attempt.run);
   if(!sameRun)fail(409,'추가 보상 상한을 확인해 주세요.');
  }
  return {ok:true,granted:!!granted};
 }
 async function reconcileOne(row){
  try{return await verifyPurchase({id:row.account},{productId:row.product,token:unsealToken(row.token_cipher,env.PLAY_TOKEN_KEY)});}
  catch(error){
   if(error.status===404||error.status===410)await q(db,"UPDATE store_purchases SET state='revoked',checked=?,next_check=? WHERE token_hash=?",clock(),clock()+86400,row.token_hash).run();
   else await q(db,'UPDATE store_purchases SET next_check=? WHERE token_hash=?',clock()+3600,row.token_hash).run();
  }
 }
 async function reconcile(){
  if(config.billing){for(const row of await rows(db,"SELECT * FROM store_purchases WHERE next_check<=? AND state<>'revoked' ORDER BY acknowledged,next_check LIMIT 30",clock()))await reconcileOne(row);}
  await q(db,'DELETE FROM ad_attempts WHERE expires<? AND NOT EXISTS(SELECT 1 FROM ad_grants WHERE nonce=ad_attempts.nonce)',clock()-86400).run();
 }
 async function rtdn(request){
  if(!config.billing)fail(503,'구매 알림을 준비하고 있습니다.');
  const token=request.headers.get('Authorization')?.replace(/^Bearer /,'');if(!token)fail(401,'알림 인증이 필요합니다.');
  const keys=await googleKeys(fetcher,'https://www.googleapis.com/oauth2/v3/certs',clock());
  checkRtdnJwt(token,keys,env.PLAY_RTDN_AUDIENCE,env.PLAY_RTDN_EMAIL,clock());
  const raw=await request.text();if(raw.length>20000)fail(413,'알림이 너무 큽니다.');
  let payload;try{payload=JSON.parse(Buffer.from(JSON.parse(raw).message.data,'base64').toString('utf8'));}catch{fail(400,'알림 형식 오류입니다.');}
  if(payload.packageName!==config.packageName)fail(403,'다른 패키지의 알림입니다.');
  if(payload.testNotification)return {ok:true,test:true};
  const purchaseToken=payload.oneTimeProductNotification?.purchaseToken||payload.voidedPurchaseNotification?.purchaseToken;
  if(typeof purchaseToken!=='string'||purchaseToken.length>4096)fail(400,'구매 토큰이 없습니다.');
  const row=await first(db,'SELECT * FROM store_purchases WHERE token_hash=?',hash(purchaseToken));
  if(row){
   // A signed notification is a prompt to query Google, never ownership proof.
   const result=await reconcileOne(row);
   if(!result){const updated=await first(db,'SELECT state FROM store_purchases WHERE token_hash=?',row.token_hash);if(updated?.state!=='revoked')fail(502,'구매 재확인을 재시도합니다.');}
  }
  return {ok:true};
 }
 async function route(path,account,data){
  if(path==='commerce/state')return state(account);
  if(path==='commerce/purchase')return verifyPurchase(account,data);
  if(path==='commerce/refresh'){
   if(config.billing)for(const row of await rows(db,"SELECT * FROM store_purchases WHERE account=? AND state<>'revoked' ORDER BY checked LIMIT 10",account.id))await reconcileOne(row);
   return state(account);
  }
  if(path==='commerce/ad-begin')return beginAd(account,data);
  if(path==='commerce/ad-close'){
   if(typeof data.nonce!=='string'||!/^[a-f0-9]{48}$/.test(data.nonce))fail(400,'광고 요청을 확인하세요.');
   await q(db,'UPDATE ad_attempts SET closed=1 WHERE nonce=? AND account=?',data.nonce,account.id).run();return state(account);
  }
  fail(404,'지원하지 않는 상품 요청입니다.');
 }
 return {route,state,verifyPurchase,beginAd,ssv,rtdn,reconcile};
}
