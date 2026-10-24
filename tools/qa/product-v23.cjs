// Changed-screen integration test; separate in-memory profiles and no API writes.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','product-v23');fs.mkdirSync(out,{recursive:true});
const button=(p,name)=>p.getByRole('button',typeof name==='string'?{name,exact:true}:{name}).last();
async function ready(p){
 for(let i=0;i<150;i++){
  const a=p.locator('flt-semantics-placeholder');if(await a.count())await a.evaluate(e=>e.click());
  if(await button(p,'성장').count()||await button(p,'일시정지').count())break;
  await p.waitForTimeout(100);
 }
 await p.waitForLoadState('networkidle');
}
async function click(p,l){const b=await reveal(p,l);await p.mouse.click(b.x+b.width/2,b.y+b.height/2);await p.waitForTimeout(400);}
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const errors=[],rows=[],worlds=[];
 try{
  for(const [width,height] of [[320,568],[360,640],[390,844],[430,932]])for(const scale of [1,1.3]){
   const c=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
   await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated QA"}'}));
   const p=await c.newPage();p.setDefaultTimeout(8000);
   p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
   await p.goto(process.env.QA_URL+'/?textScale='+scale);await ready(p);
   const beforeSave=await p.evaluate(()=>localStorage.getItem('flutter.shootingstar.profile.v1'));
   await p.getByText('v10.0.23',{exact:true}).waitFor();
   assert.equal(await p.evaluate(()=>document.documentElement.scrollHeight>innerHeight),false);
   await click(p,button(p,'격납고'));
   const header=p.getByText('출격 편성',{exact:true});await header.waitFor();
   const b=await header.boundingBox();await p.mouse.wheel(0,400);await p.waitForTimeout(100);assert.deepEqual(await header.boundingBox(),b);
   await p.screenshot({path:path.join(out,`hangar-${width}-${scale}.png`)});
   await click(p,button(p,'주무기 선택·강화'));
   const first=button(p,'펄스 주포 소유·성장 상세');await first.waitFor();
   await p.screenshot({path:path.join(out,`weapons-${width}-${scale}.png`)});
   await click(p,first);await p.getByText('펄스 주포',{exact:true}).last().waitFor();
   await click(p,button(p,'닫기'));
   assert.equal(await p.evaluate(()=>localStorage.getItem('flutter.shootingstar.profile.v1')),beforeSave,'preview must not persist progress');
   rows.push({width,height,textScale:scale,preparationFixed:true,weaponDetail:true,preserveSave:true});
   console.log('matrix',width,scale);await c.close();
  }
  const c=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
  const p=await c.newPage();p.setDefaultTimeout(8000);p.on('pageerror',e=>errors.push(e.message));
  for(let world=0;world<10;world++){
   await p.goto(process.env.QA_URL+'/?world='+world);await ready(p);
   await p.screenshot({path:path.join(out,`world-${world}.png`)});
   worlds.push(world);
  }
  await c.close();assert.deepEqual(errors,[]);
  fs.writeFileSync(path.join(out,'summary.json'),JSON.stringify({version:'v10.0.23',rows,worlds,errors},null,2));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
