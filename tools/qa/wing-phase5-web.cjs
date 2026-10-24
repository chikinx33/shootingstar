const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','wing-phase5');
const production=process.argv.includes('--production');
const key='flutter.shootingstar.profile.v1';
const saved=p=>p.evaluate(key=>{let v=localStorage.getItem(key);for(let i=0;i<3&&typeof v==='string';i++)v=JSON.parse(v);return v;},key);
async function ready(p){for(let i=0;i<100;i++){
 const placeholder=p.locator('flt-semantics-placeholder');if(await placeholder.count())await placeholder.evaluate(e=>e.click());
 if(await p.getByRole('button',{name:'일시정지',exact:true}).count()||await p.getByRole('button',{name:'성장',exact:true}).count())break;
 await p.waitForTimeout(100);
}await p.waitForLoadState('networkidle');}
async function click(p,name,min=48){const l=p.getByRole('button',{name,exact:typeof name==='string'});
 const b=await reveal(p,l,min);assert(b&&b.height>=min-.3);await p.touchscreen.tap(b.x+b.width/2,b.y+b.height/2);await p.waitForTimeout(150);}
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const rows=[],errors=[];fs.mkdirSync(out,{recursive:true});
 const cases=production?[[390,844,1,'kunai','군집 유도']]:[
 [320,568,1,'kunai','관통 유도'],[320,568,1.3,'katana','부채 파동'],
 [360,640,1,'bat','돌파 타격'],[360,640,1.3,'lightchaser','십자 참격'],
 [390,844,1,'void','응축 공허'],[390,844,1.3,'disorder','영혼 방출'],
 [430,932,1,'lance','암창 집중'],[430,932,1.3,'void','이동 공허']];
 try{
 for(const [width,height,scale,weapon,branch]of cases){
  const c=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
  await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated test"}'}));
  if(production){
   const input=JSON.parse(fs.readFileSync(path.join(__dirname,'evidence','wing-phase4','production-input.json'),'utf8'));
   input.armamentCollection={pulse:0,kunai:4};input.selectedArmament=1;input.onboarded=true;
   input.content.inventory.find(g=>g.id===input.content.equippedGear[1]).rank=1;
   const core=input.content.inventory.find(g=>g.id===input.content.equippedGear[2]);core.spec=5;core.rank=1;
   input.content.techStock[0][2]=1;input.content.equippedTech=[0];
   await c.addInitScript(({key,input})=>{if(!localStorage.getItem(key))localStorage.setItem(key,JSON.stringify(JSON.stringify(input)));},{key,input});
  }
  const p=await c.newPage();p.setDefaultTimeout(12000);
  p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
  const tag=production?'production-390':`${weapon}-${width}-scale-${scale}`;
  await p.goto(production?'http://127.0.0.1:8797/?ui=v10.0.6':`http://127.0.0.1:8804/?scene=wing-phase5&weapon=${weapon}&textScale=${scale}`);await ready(p);
  let before;
  if(production){
   assert(await p.getByText('v10.0.6',{exact:true}).count());before=await saved(p);
   await click(p,/ · 출격$/,72);await p.getByRole('button',{name:'일시정지',exact:true}).waitFor();
   // Earn the first level through actual combat and XP collection. Only waiting
   // is accelerated; there is no runtime injection or guaranteed drop fixture.
   await p.clock.install();
   let choice=false;
   for(let i=0;i<220;i++){
    if(await p.getByRole('button',{name:new RegExp('^'+branch)}).count()){choice=true;break;}
    const direction=i%24<18?'ArrowUp':'ArrowDown';
    await p.keyboard.down(direction);await p.clock.runFor(250);
    await p.keyboard.up(direction);
    if(await p.getByRole('button',{name:'다시 출격',exact:true}).count())break;
   }
   assert(choice,'Real combat must offer the first branch');
   await p.clock.resume();await p.waitForTimeout(150);
  }
  const choice=p.getByRole('button',{name:new RegExp('^'+branch)});
  const box=await reveal(p,choice,88);assert(box.height>=88);
  await p.screenshot({path:path.join(out,`${tag}-choices.png`)});
  await p.touchscreen.tap(box.x+box.width/2,box.y+box.height/2);await p.waitForTimeout(700);
  const active=await p.locator('body').ariaSnapshot();assert(active.includes('주포 특화 · '+branch));
  await p.screenshot({path:path.join(out,`${tag}-active.png`)});
  await click(p,'일시정지');await click(p,'전투 통계',64);
  await p.getByRole('tab',{name:'현재 빌드',exact:true}).click();await p.waitForTimeout(450);
  const stats=await p.locator('body').ariaSnapshot();
  assert(stats.includes('발사 분기 · '+branch));assert(stats.includes('정밀 연계 · 활성'));assert(stats.includes('순환 방호 · 활성'));
  fs.writeFileSync(path.join(out,`${tag}-statistics.txt`),stats);
  await p.screenshot({path:path.join(out,`${tag}-statistics.png`)});
  if(production){
   const after=await saved(p);assert.deepEqual(after.armamentCollection,before.armamentCollection);assert.equal(after.selectedArmament,1);
   assert(!JSON.stringify(after).includes('needleSwarm'),'Run branch must never enter saved profile');
  }
  rows.push({width,height,textScale:scale,weapon,branch,branchCardHeight:box.height,actualChoiceAndCombat:true,precisionAndCycleLinksVisible:true,productionEntrypoint:production,posedFixture:!production});
  await c.close();
 }
 assert.deepEqual(errors,[]);fs.writeFileSync(path.join(out,production?'production-browser.json':'browser-matrix.json'),JSON.stringify({version:'v10.0.6',rows,errors,scope:production?'Production entrypoint; isolated equipped gear/ownership input; first branch earned through real combat, virtual time only':'Current-source local visual fixture; actual TextScaler; seven new weapon families'},null,2));
 console.log(JSON.stringify({passed:rows.length,production,errors}));
 }catch(e){for(const c of browser.contexts())for(const p of c.pages()){
  await p.screenshot({path:path.join(out,'failure.png')}).catch(()=>{});
  fs.writeFileSync(path.join(out,'failure.txt'),await p.locator('body').ariaSnapshot().catch(()=>''));
 }throw e;
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
