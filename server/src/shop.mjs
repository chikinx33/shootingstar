// Account-free Play receipt check (v12.13.0). The app keeps the ledger in its
// save and asks only "is this receipt real?"; nothing is stored here.
import {playAccessToken,CommerceError} from './commerce.mjs';

export const SHOP_PACKAGE='com.raviok.purrtectors';
export const SHOP_PRODUCTS=new Set(['purr_starter_pack','purr_growth_fund','purr_monthly_snacks','purr_ad_pass_30d','purr_supporter_frame']);
const fail=(status,message)=>{throw new CommerceError(status,message);};

export const shopEnabled=env=>env.SHOP_ENABLED==='true'&&env.PLAY_PACKAGE===SHOP_PACKAGE&&!!env.PLAY_SERVICE_ACCOUNT;

export async function verifyShopPurchase(env,data,{fetcher=fetch,clock}={}){
 if(!shopEnabled(env))fail(503,'구매 확인을 준비하고 있습니다. 결제되었다면 나중에 자동으로 지급됩니다.');
 const {productId,token}=data||{};
 if(!SHOP_PRODUCTS.has(productId)||typeof token!=='string'||token.length<10||token.length>4096)fail(400,'구매 정보를 다시 확인하세요.');
 const url=`https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${SHOP_PACKAGE}/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(token)}`;
 const response=await fetcher(url,{headers:{Authorization:`Bearer ${await playAccessToken(env,fetcher,clock)}`},signal:AbortSignal.timeout(8000)});
 if(response.status===404||response.status===410||response.status===400)return {state:'invalid'};
 if(!response.ok)fail(502,'구매 확인에 실패했습니다. 다음 실행 때 다시 확인합니다.');
 const purchase=await response.json();
 if(purchase.productId&&purchase.productId!==productId)return {state:'invalid'};
 const state=['purchased','revoked','pending'][purchase.purchaseState]??'invalid';
 return {state,consumed:purchase.consumptionState===1,acknowledged:purchase.acknowledgementState===1};
}
