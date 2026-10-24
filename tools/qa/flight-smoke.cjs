const { chromium } = require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const out=path.join(__dirname,'evidence','flight-v6.1');
const base=process.env.VISUAL_BASE_URL||'http://127.0.0.1:8791';
const prefix=process.env.VISUAL_BASE_URL?'public-':'';
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 try{
  const page=await browser.newPage({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
  const errors=[],assets=new Set();page.on('pageerror',e=>errors.push(e.message));
  page.on('response',r=>{if(r.url().includes('/raster_v6/')&&r.url().endsWith('.png')) {assert.equal(r.status(),200);assets.add(r.url().split('/').pop());}});
  await page.goto(base);
  await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
  await page.getByRole('tab',{name:'출격',exact:true}).waitFor();
  await page.waitForTimeout(800);
  await page.screenshot({path:path.join(out,prefix+'home.png')});
  await page.getByRole('button',{name:'설정',exact:true}).click();
  await page.mouse.move(5, 820);
  await page.getByText('비행 설정',{exact:true}).waitFor();
  await page.waitForTimeout(600);
  await page.screenshot({path:path.join(out,prefix+'settings.png')});
  // Flutter's semantic overlay forwards real taps to the canvas. Playwright's
  // DOM hit-test check can misclassify that overlay as an intercepting element.
  const done=await page.getByRole('button',{name:'완료',exact:true}).boundingBox();
  await page.touchscreen.tap(done.x+done.width/2,done.y+done.height/2);
  await page.getByText('비행 설정',{exact:true}).waitFor({state:'hidden'});
  await page.getByRole('button',{name:'잔광 외곽 1-1 · 출격',exact:true}).click();
  await page.getByRole('button',{name:'비행 준비 완료',exact:true}).click();
  await page.waitForTimeout(3500);
  await page.screenshot({path:path.join(out,prefix+'battle.png')});
  await page.mouse.move(200,500);await page.mouse.down();await page.mouse.move(235,525);await page.waitForTimeout(250);
  await page.screenshot({path:path.join(out,prefix+'touch-controls.png')});await page.mouse.up();
  await page.getByRole('button',{name:'일시정지',exact:true}).click();
  await page.screenshot({path:path.join(out,prefix+'pause.png')});
  await page.getByRole('button',{name:'귀환 · 현재 보상 정산',exact:true}).click();
  await page.getByText('다음 궤적을 향해',{exact:true}).waitFor();
  await page.screenshot({path:path.join(out,prefix+'result.png')});
  assert.equal(assets.size,7);assert.deepEqual(errors,[]);
  if(process.env.VISUAL_BASE_URL){
   const proof=await page.evaluate(async()=>{
    const stamp=Date.now();
    const options={cache:'no-store',headers:{'Cache-Control':'no-cache'}};
    const version=await fetch('/version.json?verify='+stamp,options).then(r=>r.json());
    const health=await fetch('/api/health?verify='+stamp,options).then(r=>r.json());
    const response=await fetch('/main.dart.js?verify='+stamp,options);
    const hash=await crypto.subtle.digest('SHA-256',await response.arrayBuffer());
    return {version,health,httpStatus:response.status,publicJsSha256:Array.from(new Uint8Array(hash),x=>x.toString(16).padStart(2,'0')).join('')};
   });
   const build=JSON.parse(fs.readFileSync(path.join(out,'build-hashes.json'),'utf8'));
   assert.equal(proof.version.version,'6.1.0');assert.equal(proof.version.build_number,'15');
   assert.deepEqual(proof.health,{ok:true,version:'6.1.0',storage:'D1'});
   assert.equal(proof.httpStatus,200);assert.equal(proof.publicJsSha256,build.releaseJsSha256);
   const deploy=fs.readFileSync(path.join(out,'deployment.txt'),'utf8');
   fs.writeFileSync(path.join(out,'deployment.json'),JSON.stringify({url:base,checkedAt:new Date().toISOString(),workerVersionId:deploy.match(/Current Version ID: ([a-f0-9-]+)/)?.[1],...proof,localJsSha256:build.releaseJsSha256,assets:[...assets],databaseMigrationRun:false},null,2));
  }
  fs.writeFileSync(path.join(out,prefix+'smoke.json'),JSON.stringify({url:base,assets:[...assets],errors,scope:'Standard release, fresh guest, settings/onboarding/battle/touch/pause/result at 390x844'},null,2));
  console.log('PASS standard release: 7 atlases loaded, menus and battle; errors=0');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
