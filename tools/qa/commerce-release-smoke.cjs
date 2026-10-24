const {chromium}=require('playwright'),fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','commerce-v29');
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const errors=[],calls=[];
 try{
  const c=await browser.newContext({viewport:{width:320,height:568},isMobile:true,hasTouch:true});
  await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>{calls.push(new URL(r.request().url()).pathname);return r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated release preview"}'});});
  const p=await c.newPage();p.setDefaultTimeout(12000);p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
  await p.goto('http://127.0.0.1:8797/?v=10.0.29');
  for(let i=0;i<120;i++){const a=p.locator('flt-semantics-placeholder');if(await a.count())await a.evaluate(e=>e.click());if(await p.getByRole('button',{name:/^계정 ·/}).count())break;await p.waitForTimeout(100);}
  await p.getByText('v10.0.29',{exact:true}).waitFor();await p.getByRole('button',{name:/^계정 ·/}).first().click();
  await p.getByText('계정 저장',{exact:true}).waitFor();
  await p.waitForTimeout(250);
  fs.writeFileSync(path.join(out,'release-account-buttons.json'),JSON.stringify(await p.getByRole('button').evaluateAll(els=>els.map(e=>({label:e.getAttribute('aria-label'),text:e.textContent}))),null,2));
  const entry=p.getByRole('button',{name:'후원 외형·선택형 보상 안내',exact:true});await reveal(p,entry);await entry.click();
  await p.getByText('잔광 후원 외형',{exact:true}).waitFor();await p.waitForLoadState('networkidle');
  await reveal(p,p.getByRole('button',{name:'기본 외형과 비교',exact:true}));
  await p.screenshot({path:path.join(out,'release-preview-320.png')});
  await p.getByRole('button',{name:'기본 외형과 비교',exact:true}).click();await reveal(p,p.getByRole('button',{name:'후원 외형 미리보기',exact:true}));
  await reveal(p,p.getByText('선택형 추가 보상',{exact:true}));assert.equal(await p.getByRole('button',{name:/구매/}).count(),0);assert.deepEqual(errors,[]);assert(!calls.some(v=>v.includes('commerce/purchase')||v.includes('commerce/ad-begin')));
  fs.writeFileSync(path.join(out,'release-smoke.json'),JSON.stringify({version:'v10.0.29',productionEntrypoint:true,accountToPreview:true,toggle:true,noCheckoutOrAdRequest:true,apiIntercepted:true,errors},null,2));
 }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exit(1);});
