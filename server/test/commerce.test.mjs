// Isolated in-memory SQLite + locally generated signatures only. No store,
// advertising request, production account, or payment is used by these tests.
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
import {generateKeyPairSync,sign,createHash,randomBytes} from 'node:crypto';
import {createCommerce,commerceConfig,sealToken,unsealToken,checkSsvSignature,checkRtdnJwt} from '../src/commerce.mjs';
import worker from '../src/worker.mjs';
import {ensureCommerceSchema} from '../src/commerce_schema.mjs';

const rsa=generateKeyPairSync('rsa',{modulusLength:2048}),ec=generateKeyPairSync('ec',{namedCurve:'prime256v1'});
const pem=ec.publicKey.export({type:'spki',format:'pem'}),keys={keys:[{keyId:77,pem}]};
const jwk={...rsa.publicKey.export({format:'jwk'}),kid:'test-key'};
const sha=v=>createHash('sha256').update(v).digest('hex');
function database(){
 const sql=new DatabaseSync(':memory:');
 for(const file of ['0001_online.sql','0002_commerce.sql'])sql.exec(readFileSync(new URL('../migrations/'+file,import.meta.url),'utf8'));
 return {sql,prepare(source){return {bind(...args){return {
  async first(){return sql.prepare(source).get(...args)??null;},
  async all(){return {results:sql.prepare(source).all(...args)};},
  async run(){const result=sql.prepare(source).run(...args);return {meta:{changes:Number(result.changes)}};},
 };}};},async batch(statements){sql.exec('BEGIN');try{const results=[];for(const s of statements)results.push(await s.run());sql.exec('COMMIT');return results;}catch(e){sql.exec('ROLLBACK');throw e;}}};
}
test('binding migration matches the SQL schema, is additive, idempotent and preserves existing saves',async()=>{
 const reference=database(),actual=database();
 actual.sql.exec('DROP TRIGGER ad_reward; DROP TABLE ad_grants; DROP TABLE ad_attempts; DROP TABLE store_purchases;');
 actual.sql.prepare('INSERT INTO accounts(id,username,nickname,salt,verifier,recovery,profile,created,updated) VALUES(?,?,?,?,?,?,?,?,?)').run('retained','kept','Kept','salt','verifier','recovery','{"credits":321}',1,1);
 await Promise.all([ensureCommerceSchema(actual),ensureCommerceSchema(actual)]);
 const normalize=db=>db.sql.prepare("SELECT name,replace(replace(replace(sql,char(10),''),char(13),''),' ','') AS definition FROM sqlite_master WHERE name LIKE 'store_%' OR name LIKE 'ad_%' ORDER BY name").all();
 assert.deepEqual(normalize(actual),normalize(reference));
 assert.equal(actual.sql.prepare('SELECT profile FROM accounts WHERE id=?').get('retained').profile,'{"credits":321}');
 // Running the management migration after binding initialization is safe.
 actual.sql.exec(readFileSync(new URL('../migrations/0002_commerce.sql',import.meta.url),'utf8'));
 assert.deepEqual(normalize(actual),normalize(reference));
});
function fixture(){
 const DB=database(),states=new Map(),acks=[],time={at:1792454400};
 const env={DB,PLAY_PACKAGE:'com.shootingstar.shootingstar',PLAY_SUPPORTER_PRODUCT:'supporter_cosmetic',COMMERCE_BILLING_ENABLED:'true',COMMERCE_ADS_ENABLED:'true',PLAY_TOKEN_KEY:'a'.repeat(64),PLAY_RTDN_AUDIENCE:'https://game.test/api/commerce/play-rtdn',PLAY_RTDN_EMAIL:'notifications@game.test',PLAY_SERVICE_ACCOUNT:JSON.stringify({client_email:'isolated@test.invalid',private_key:rsa.privateKey.export({type:'pkcs8',format:'pem'})}),ADMOB_APP_ID:'ca-app-pub-1111111111111111~1111111111',ADMOB_REWARDED_UNIT:'ca-app-pub-1111111111111111/2222222222'};
 const profile={version:4,credits:150,runs:1,totalKills:30,blueprints:0,content:{inventory:[]},processedRunIds:['run1','run2','run3','run4'],verifiedAdCredits:0};
 const key='b'.repeat(64),salt='a'.repeat(32);
 for(const id of ['alice','bob'])DB.sql.prepare('INSERT INTO accounts(id,username,nickname,salt,verifier,recovery,profile,created,updated) VALUES(?,?,?,?,?,?,?,?,?)').run(id,id,'Test',salt,sha(salt+':'+key),'recovery',JSON.stringify(profile),time.at,time.at);
 let failAck=false,failGet=0;
 const fetcher=async(url,options={})=>{
  if(url==='https://www.gstatic.com/admob/reward/verifier-keys.json')return Response.json(keys);
  if(url==='https://www.googleapis.com/oauth2/v3/certs')return Response.json({keys:[jwk]});
  if(url==='https://oauth2.googleapis.com/token')return Response.json({access_token:'isolated-provider-token',expires_in:3600});
  assert.ok(url.startsWith('https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.shootingstar.shootingstar/purchases/products/supporter_cosmetic/tokens/'));
  assert.equal(options.headers.Authorization,'Bearer isolated-provider-token');
  const token=decodeURIComponent(url.split('/tokens/')[1].replace(/:acknowledge$/,''));
  if(url.endsWith(':acknowledge')){acks.push(token);return new Response(failAck?'{}':null,{status:failAck?503:204});}
  if(failGet)return new Response('{}',{status:failGet});
  return states.has(token)?Response.json(states.get(token)):new Response('{}',{status:404});
 };
 const service=createCommerce(env,{fetcher,clock:()=>time.at});
 const owner={id:'alice'},binding=sha('shootingstar.play.account.v1:alice');
 const purchased=(token,status=0)=>states.set(token,{productId:'supporter_cosmetic',purchaseToken:token,purchaseState:status,acknowledgementState:0,quantity:1,obfuscatedExternalAccountId:binding});
 function url(nonce,{transaction='txn1',user=binding,stamp=time.at*1000,unit='2222222222',amount='20',item='credits'}={}){
  const raw=new URLSearchParams({ad_network:'5450213213286189855',ad_unit:unit,custom_data:nonce,reward_amount:amount,reward_item:item,timestamp:String(stamp),transaction_id:transaction,user_id:user}).toString();
  return 'https://game.test/api/commerce/admob-ssv?'+raw+'&signature='+sign('sha256',Buffer.from(raw),ec.privateKey).toString('base64url')+'&key_id=77';
 }
 const begin=runId=>service.beginAd(owner,{runId,seconds:60,kills:20});
 const grant=(attempt,options)=>service.ssv(new Request(url(attempt.nonce,options)));
 const wallet=()=>JSON.parse(DB.sql.prepare('SELECT profile FROM accounts WHERE id=?').get('alice').profile);
 const call=async(path,data={},revision)=>{
  const token='c'.repeat(64);DB.sql.prepare('INSERT OR IGNORE INTO sessions VALUES(?,?,?,?,?)').run(sha(token),'alice',Math.floor(Date.now()/1000)+3600,1,'unit test');
  const request=new Request('https://game.test/api/'+path,{method:'POST',headers:{'Content-Type':'application/json','X-Client':'native',Authorization:'Bearer '+token},body:JSON.stringify(data)});
  const response=await worker.fetch(request,{...env,COMMERCE_BILLING_ENABLED:'false',COMMERCE_ADS_ENABLED:'false'});
  return {status:response.status,body:await response.json()};
 };
 return {DB,env,service,states,acks,time,owner,binding,purchased,begin,grant,url,wallet,profile,key,call,set failAck(v){failAck=v;},set failGet(v){failGet=v;}};
}
const rejectsStatus=(fn,status)=>assert.rejects(fn,e=>e.status===status);
test('commerce fails closed with missing configuration, sample IDs and mismatched publisher IDs',async()=>{
 const f=fixture();assert.equal(commerceConfig({}).billing,false);assert.equal(commerceConfig({}).ads,false);
 assert.equal(commerceConfig({...f.env,ADMOB_APP_ID:'ca-app-pub-3940256099942544~3347511713'}).ads,false);
 assert.equal(commerceConfig({...f.env,ADMOB_APP_ID:'ca-app-pub-2222222222222222~1111111111'}).ads,false);
 assert.equal(commerceConfig({...f.env,PLAY_SUPPORTER_PRODUCT:'android.test.purchased'}).billing,false);
 const off=createCommerce({DB:f.DB},{fetcher:()=>{throw Error('must not contact provider');}});
 await rejectsStatus(()=>off.verifyPurchase(f.owner,{}),503);await rejectsStatus(()=>off.beginAd(f.owner,{}),503);
 assert.equal((await off.state(f.owner)).supporter,false);
});
test('pending purchase has no entitlement; purchased receipt is bound, encrypted and duplicate safe',async()=>{
 const f=fixture(),token='pending-to-purchased-token';f.purchased(token,2);
 assert.equal((await f.service.verifyPurchase(f.owner,{productId:'supporter_cosmetic',token})).supporter,false);assert.equal(f.acks.length,0);
 f.purchased(token);await Promise.all([1,2,3].map(()=>f.service.verifyPurchase(f.owner,{productId:'supporter_cosmetic',token})));
 assert.equal((await f.service.state(f.owner)).supporter,true);
 assert.equal(f.DB.sql.prepare('SELECT COUNT(*) n FROM store_purchases').get().n,1);
 const row=f.DB.sql.prepare('SELECT * FROM store_purchases').get();assert.ok(!row.token_cipher.includes(token));assert.equal(unsealToken(row.token_cipher,f.env.PLAY_TOKEN_KEY),token);
 await rejectsStatus(()=>f.service.verifyPurchase({id:'bob'},{productId:'supporter_cosmetic',token}),409);
});
test('self-reported ownership, wrong product/account/quantity and unknown receipts cannot grant',async()=>{
 const f=fixture(),token='invalid-bound-token';
 f.DB.sql.prepare('UPDATE accounts SET profile=? WHERE id=?').run(JSON.stringify({...f.profile,supporter:true}),'alice');
 assert.equal((await f.service.state(f.owner)).supporter,false);
 f.purchased(token);f.states.get(token).obfuscatedExternalAccountId='bob';
 await rejectsStatus(()=>f.service.verifyPurchase(f.owner,{productId:'supporter_cosmetic',token}),403);
 f.purchased(token);f.states.get(token).quantity=2;
 await rejectsStatus(()=>f.service.verifyPurchase(f.owner,{productId:'supporter_cosmetic',token}),403);
 await rejectsStatus(()=>f.service.verifyPurchase(f.owner,{productId:'wrong',token}),400);
 await rejectsStatus(()=>f.service.verifyPurchase(f.owner,{productId:'supporter_cosmetic',token:'unrecognized-token'}),404);
});
test('durable ownership precedes acknowledgement; scheduler retries and revokes refunded purchases',async()=>{
 const f=fixture(),token='ack-retry-refund-token';f.purchased(token);f.failAck=true;
 const first=await f.service.verifyPurchase(f.owner,{productId:'supporter_cosmetic',token});assert.equal(first.supporter,true);assert.equal(first.acknowledged,false);
 f.failAck=false;f.time.at+=3601;await f.service.reconcile();assert.equal(f.DB.sql.prepare('SELECT acknowledged FROM store_purchases').get().acknowledged,1);
 f.purchased(token,1);await f.service.route('commerce/refresh',f.owner,{});assert.equal((await f.service.state(f.owner)).supporter,false);
 const newToken='repurchase-after-refund-token';f.purchased(newToken);await f.service.verifyPurchase(f.owner,{productId:'supporter_cosmetic',token:newToken});f.failGet=503;
 await f.service.route('commerce/refresh',f.owner,{});assert.equal((await f.service.state(f.owner)).supporter,true,'provider outage must not invent a refund');
 f.failGet=410;await f.service.route('commerce/refresh',f.owner,{});assert.equal((await f.service.state(f.owner)).supporter,false);
});
test('AES-GCM rejects changed token bytes or the wrong secret',()=>{
 const f=fixture(),sealed=sealToken('secret-receipt',f.env.PLAY_TOKEN_KEY);
 assert.throws(()=>unsealToken(sealed,'b'.repeat(64)));
 const bytes=Buffer.from(sealed,'base64url');bytes[30]^=1;assert.throws(()=>unsealToken(bytes.toString('base64url'),f.env.PLAY_TOKEN_KEY));
});
test('SSV validates exact raw query bytes, signing key and duplicate parameter rejection',async()=>{
 const f=fixture(),a=await f.begin('run1'),url=f.url(a.nonce);
 assert.equal(checkSsvSignature(url,keys).custom_data,a.nonce);
 assert.throws(()=>checkSsvSignature(url.replace('reward_amount=20','reward_amount=200'),keys));
 assert.throws(()=>checkSsvSignature(url.replace('key_id=77','key_id=78'),keys));
 assert.throws(()=>checkSsvSignature(url.replace('&signature=','&custom_data=another&signature='),keys));
 assert.throws(()=>checkSsvSignature(url+'&extra=1',keys));
});
test('signed SSV credits the wallet and revision once across replay and concurrent delivery',async()=>{
 const f=fixture(),a=await f.begin('run1');await Promise.all([1,2,3].map(()=>f.grant(a)));
 assert.equal(f.wallet().credits,170);assert.equal(f.wallet().verifiedAdCredits,20);
 assert.equal(f.DB.sql.prepare('SELECT revision FROM accounts WHERE id=?').get('alice').revision,1);
 assert.equal((await f.service.state(f.owner)).remaining,1);
 await rejectsStatus(()=>f.begin('run1'),409);
});
test('unfinished/unuploaded sortie, wrong owner, wrong reward/unit and out-of-window callback are refused',async()=>{
 const f=fixture();await rejectsStatus(()=>f.begin('unfinished'),409);
 await rejectsStatus(()=>f.service.beginAd(f.owner,{runId:'run1',seconds:10,kills:20}),409);
 const a=await f.begin('run1');
 for(const option of [{user:'bob'},{amount:'21'},{item:'gold'},{unit:'wrong'},{stamp:(f.time.at+1000)*1000}])await assert.rejects(()=>f.grant(a,option));
 assert.equal(f.wallet().credits,150);
});
test('no-fill/close consumes no successful quota; late valid callback still grants once',async()=>{
 const f=fixture(),a=await f.begin('run1');
 await f.service.route('commerce/ad-close',{id:'bob'},{nonce:a.nonce});assert.equal(f.DB.sql.prepare('SELECT closed FROM ad_attempts').get().closed,0);
 await f.service.route('commerce/ad-close',f.owner,{nonce:a.nonce});assert.equal((await f.service.state(f.owner)).remaining,2);
 f.time.at+=3600;await f.grant(a,{stamp:(f.time.at-3500)*1000});assert.equal(f.wallet().credits,170);
});
test('one reward per sortie and two per UTC attempt day are atomic, including multiple nonces',async()=>{
 const f=fixture(),a=await f.begin('run1');await f.service.route('commerce/ad-close',f.owner,{nonce:a.nonce});
 const a2=await f.begin('run1'),b=await f.begin('run2');await rejectsStatus(()=>f.begin('run3'),409);
 await f.grant(a);await f.grant(a2,{transaction:'same-sortie-different-ad'});await f.grant(b,{transaction:'txn2'});
 assert.equal(f.wallet().credits,190);assert.equal((await f.service.state(f.owner)).remaining,0);
 await rejectsStatus(()=>f.begin('run3'),409);
 f.time.at+=86400;const next=await f.begin('run3');await f.grant(next,{transaction:'txn3'});assert.equal(f.wallet().credits,210);
});
test('reward day follows signed completion across UTC midnight; old deliveries cannot exceed its cap',async()=>{
 const f=fixture();f.time.at=Math.floor(f.time.at/86400)*86400+86390;
 const a=await f.begin('run1');f.time.at+=30;await f.grant(a);
 assert.equal((await f.service.state(f.owner)).remaining,1);
 const b=await f.begin('run2');await f.grant(b,{transaction:'midnight-second'});assert.equal((await f.service.state(f.owner)).remaining,0);
 f.time.at+=86401;assert.equal((await f.grant(a,{stamp:(f.time.at-86401)*1000})).duplicate,true);
});
test('a revoked token cannot be resurrected by an older concurrent provider response',async()=>{
 const f=fixture(),token='revoked-token-final';f.purchased(token,1);
 await f.service.verifyPurchase(f.owner,{productId:'supporter_cosmetic',token});f.purchased(token,0);
 assert.equal((await f.service.verifyPurchase(f.owner,{productId:'supporter_cosmetic',token})).supporter,false);
});
test('stale cloud upload conflicts; choosing device progress reconciles verified reward exactly once',async()=>{
 const f=fixture(),a=await f.begin('run1');await f.grant(a);
 assert.equal((await f.call('cloud/write',{revision:0,profile:f.profile})).status,409);
 const device={...f.profile,credits:100};const result=await f.call('cloud/write',{revision:1,profile:device});assert.equal(result.status,200);assert.equal(result.body.verifiedAdCredits,20);
 assert.equal(f.wallet().credits,120);assert.equal(f.wallet().verifiedAdCredits,20);
 assert.equal((await f.call('cloud/write',{revision:2,profile:f.wallet()})).status,200);assert.equal(f.wallet().credits,120);
 assert.equal((await f.call('cloud/write',{revision:3,profile:{...f.wallet(),verifiedAdCredits:999}})).status,400);
 const legacy={...f.profile};delete legacy.verifiedAdCredits;assert.equal((await f.call('cloud/write',{revision:3,profile:legacy})).status,409);
});
test('account deletion cascades paid/reward records; recreated identity cannot claim old bound receipt',async()=>{
 const f=fixture(),token='deleted-account-bound-token';f.purchased(token);await f.service.verifyPurchase(f.owner,{productId:'supporter_cosmetic',token});await f.grant(await f.begin('run1'));
 assert.equal((await f.call('auth/delete',{username:'alice',key:f.key})).status,200);
 for(const table of ['store_purchases','ad_attempts','ad_grants'])assert.equal(f.DB.sql.prepare('SELECT COUNT(*) n FROM '+table).get().n,0);
 await rejectsStatus(()=>f.service.verifyPurchase({id:'bob'},{productId:'supporter_cosmetic',token}),403);
});
function jwt(payload,header={alg:'RS256',kid:'test-key'}){
 const value=[header,payload].map(p=>Buffer.from(JSON.stringify(p)).toString('base64url')).join('.');
 return value+'.'+sign('RSA-SHA256',Buffer.from(value),rsa.privateKey).toString('base64url');
}
test('RTDN requires signed Google issuer, audience, email, expiry and RS256',()=>{
 const f=fixture(),payload={iss:'https://accounts.google.com',aud:f.env.PLAY_RTDN_AUDIENCE,email:f.env.PLAY_RTDN_EMAIL,email_verified:true,iat:f.time.at,exp:f.time.at+3600};
 assert.equal(checkRtdnJwt(jwt(payload),{keys:[jwk]},payload.aud,payload.email,f.time.at).email,payload.email);
 for(const changes of [{iss:'evil'},{aud:'evil'},{email:'evil'},{email_verified:false},{exp:f.time.at-1},{iat:f.time.at+61}])assert.throws(()=>checkRtdnJwt(jwt({...payload,...changes}),{keys:[jwk]},payload.aud,payload.email,f.time.at));
 assert.throws(()=>checkRtdnJwt(jwt(payload,{alg:'none',kid:'test-key'}),{keys:[jwk]},payload.aud,payload.email,f.time.at));
});
test('authenticated RTDN re-queries Google for revocation and ignores spoofed content',async()=>{
 const f=fixture(),token='notification-token';f.purchased(token);await f.service.verifyPurchase(f.owner,{productId:'supporter_cosmetic',token});f.purchased(token,1);
 const payload={iss:'https://accounts.google.com',aud:f.env.PLAY_RTDN_AUDIENCE,email:f.env.PLAY_RTDN_EMAIL,email_verified:true,iat:f.time.at,exp:f.time.at+3600};
 const request=()=>new Request(f.env.PLAY_RTDN_AUDIENCE,{method:'POST',headers:{Authorization:'Bearer '+jwt(payload)},body:JSON.stringify({message:{data:Buffer.from(JSON.stringify({packageName:f.env.PLAY_PACKAGE,oneTimeProductNotification:{purchaseToken:token}})).toString('base64')}})});
 assert.equal((await f.service.rtdn(request())).ok,true);assert.equal((await f.service.state(f.owner)).supporter,false);
 await rejectsStatus(()=>f.service.rtdn(new Request(f.env.PLAY_RTDN_AUDIENCE,{method:'POST',body:'{}'})),401);
});
