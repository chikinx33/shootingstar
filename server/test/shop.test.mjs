import test from 'node:test';
import assert from 'node:assert/strict';
import {generateKeyPairSync} from 'node:crypto';
import {verifyShopPurchase,shopEnabled} from '../src/shop.mjs';

const {privateKey}=generateKeyPairSync('rsa',{modulusLength:2048});
const env={SHOP_ENABLED:'true',PLAY_PACKAGE:'com.raviok.purrtectors',PLAY_SERVICE_ACCOUNT:JSON.stringify({client_email:'qa@example.iam.gserviceaccount.com',private_key:privateKey.export({type:'pkcs8',format:'pem'})})};
const fake=(purchase,status=200)=>async url=>{
 if(String(url).startsWith('https://oauth2.googleapis.com/'))return Response.json({access_token:'t',expires_in:3600});
 assert.match(String(url),/applications\/com\.raviok\.purrtectors\/purchases\/products\/purr_/);
 return status===200?Response.json(purchase):new Response('{}',{status});
};

test('disabled until the package and service account are set',async()=>{
 assert.equal(shopEnabled({}),false);
 await assert.rejects(verifyShopPurchase({},{productId:'purr_starter_pack',token:'x'.repeat(20)}),e=>e.status===503);
});

test('unknown products and bad tokens are rejected',async()=>{
 await assert.rejects(verifyShopPurchase(env,{productId:'gems_1000',token:'x'.repeat(20)},{fetcher:fake({})}),e=>e.status===400);
 await assert.rejects(verifyShopPurchase(env,{productId:'purr_ad_pass_30d',token:'short'},{fetcher:fake({})}),e=>e.status===400);
});

test('maps Google purchase states',async()=>{
 const check=p=>verifyShopPurchase(env,{productId:'purr_monthly_snacks',token:'t'.repeat(30)},{fetcher:fake(p)});
 assert.equal((await check({purchaseState:0,productId:'purr_monthly_snacks'})).state,'purchased');
 assert.equal((await check({purchaseState:1})).state,'revoked');
 assert.equal((await check({purchaseState:2})).state,'pending');
 assert.equal((await check({purchaseState:0,productId:'purr_starter_pack'})).state,'invalid');
});

test('an unknown token is invalid, a Google outage is a retry',async()=>{
 const token={productId:'purr_growth_fund',token:'u'.repeat(30)};
 assert.equal((await verifyShopPurchase(env,token,{fetcher:fake({},404)})).state,'invalid');
 await assert.rejects(verifyShopPurchase(env,token,{fetcher:fake({},500)}),e=>e.status===502);
});
