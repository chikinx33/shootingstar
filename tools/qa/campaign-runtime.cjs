const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const out=path.join(__dirname,'evidence','campaign-v5');
const base=process.env.CAMPAIGN_RUNTIME_URL||'http://127.0.0.1:8794';
const prefix=process.env.CAMPAIGN_RUNTIME_URL?'public':'worker';
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 try{
  const page=await browser.newPage({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto(base);await page.waitForTimeout(2500);
  await Promise.race([page.locator('flt-semantics-placeholder').waitFor(),page.getByRole('tab',{name:'출격',exact:true}).waitFor()]);
  if(await page.locator('flt-semantics-placeholder').count())await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
  await page.getByRole('button',{name:'잔광 외곽 1-1 · 출격',exact:true}).click();
  await page.getByRole('button',{name:'비행 준비 완료',exact:true}).click();
  await page.waitForTimeout(900);await page.keyboard.down('d');await page.waitForTimeout(500);await page.keyboard.up('d');
  await page.screenshot({path:path.join(out,`${prefix}-real-battle.png`)});
  await page.getByRole('button',{name:'일시정지',exact:true}).click();
  await page.getByRole('button',{name:'귀환 · 현재 보상 정산',exact:true}).click();await page.waitForTimeout(300);
  assert((await page.locator('body').innerText()).includes('다음엔 꼭 이긴다냥'));
  const health=await page.evaluate(()=>fetch('/api/health').then(r=>r.json()));assert(health.ok);assert.equal(health.version,'5.0.0');
  if(process.env.CAMPAIGN_RUNTIME_URL){
   const verification=await page.evaluate(async()=>{
    const stamp=Date.now();
    const versionResponse=await fetch(`/version.json?verify=${stamp}`,{cache:'no-store',headers:{'Cache-Control':'no-cache'}});
    const jsResponse=await fetch(`/main.dart.js?verify=${stamp}`,{cache:'no-store',headers:{'Cache-Control':'no-cache'}});
    const digest=await crypto.subtle.digest('SHA-256',await jsResponse.arrayBuffer());
    return {version:await versionResponse.json(),httpStatus:{version:versionResponse.status,javascript:jsResponse.status},publicJsSha256:Array.from(new Uint8Array(digest),b=>b.toString(16).padStart(2,'0')).join('')};
   });
   verification.localJsSha256=require('crypto').createHash('sha256').update(fs.readFileSync(path.join(__dirname,'../../build/web/main.dart.js'))).digest('hex');
   assert.equal(verification.version.version,'5.0.0');assert.equal(verification.version.build_number,'13');
   assert.equal(verification.httpStatus.version,200);assert.equal(verification.httpStatus.javascript,200);
   assert.equal(verification.publicJsSha256,verification.localJsSha256);
   const deploymentLog=fs.readFileSync(path.join(out,'deployment.txt'),'utf8');
   fs.writeFileSync(path.join(out,'deployment.json'),JSON.stringify({url:base,checkedAt:new Date().toISOString(),workerVersionId:deploymentLog.match(/Current Version ID: ([a-f0-9-]+)/)?.[1],...verification,health,databaseMigrationRun:false},null,2));
  }
  assert.deepEqual(errors,[]);
  fs.writeFileSync(path.join(out,`${prefix}-runtime.json`),JSON.stringify({url:base,checkedAt:new Date().toISOString(),health,errors,scope:'Real release entrypoint and Cloudflare Worker/D1, fresh isolated guest, no API mocking or injected battle state'},null,2));
  console.log('PASS real Worker guest startup, onboarding, launch, movement, return and health; errors=0');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
