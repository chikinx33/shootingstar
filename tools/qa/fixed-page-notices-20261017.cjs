const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','catalog-fixed-ui-20261017');
const key='flutter.shootingstar.profile.v1';
(async()=>{
 const b=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const rows=[],errors=[];let last;
 async function ready(p){for(let n=0;n<160;n++){
  if(await p.locator('flt-semantics-placeholder').count())await p.locator('flt-semantics-placeholder').evaluate(e=>e.click());
  if(await p.locator('flt-semantics[role=button],flt-semantics [role=button]').count()){await p.waitForTimeout(250);return;}
  await p.waitForTimeout(250);
 }throw Error('Game not ready');}
 const button=(p,name)=>p.getByRole('button',{name,exact:true});
 async function click(p,name,h=20){const l=button(p,name).first();await reveal(p,l,h);await l.click();await p.waitForTimeout(200);}
 async function chip(p,name){await p.getByRole('checkbox',{name,exact:true}).click();await p.waitForTimeout(250);}
 async function saved(p){return p.evaluate(key=>{let s=localStorage.getItem(key);for(let i=0;i<3&&typeof s==='string';i++)s=JSON.parse(s);return s;},key);}
 async function counter(p){const matches=[...(await p.locator('body').ariaSnapshot()).matchAll(/(\d+) \/ (\d+)/g)];assert(matches.length);return matches.at(-1)[0];}
 async function physicalPage(p){const before=await counter(p);
  const previous=button(p,'이전 페이지'),next=button(p,'다음 페이지');
  const l=await previous.isEnabled()?previous:next,box=await l.boundingBox();
  assert(box.height>=48&&box.y+box.height<=p.viewportSize().height+.2);
  await p.touchscreen.tap(box.x+box.width/2,box.y+box.height/2);await p.waitForTimeout(200);
  const after=await counter(p);assert.notEqual(before,after,'Physical touch must navigate while growth notice is active');return{before,after,box};}
 try{for(const [width,height]of [[320,568],[360,640],[390,844],[430,932]]){
  console.log('notice touch',width);
  const c=await b.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
  await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.fulfill({status:401,body:'{}'}));
  const p=await c.newPage();last=p;p.on('pageerror',e=>errors.push(e.message));
  p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
  await p.goto('http://127.0.0.1:8798/?scene=menus&textScale=1.3');await ready(p);
  await click(p,'보급');await click(p,'장비 보급 열기',72);await click(p,'확인',72);
  let s=await saved(p);s.credits=5000;s.blueprints=100;s.content.inventory[0].rank=2;
  s.content.petFood=500;s.content.petLevels[0]=5;s.content.petRanks[0]=1;s.content.petShards[0]=10;
  s.content.petBond.favor[0]=50;
  await p.evaluate(({key,s})=>localStorage.setItem(key,JSON.stringify(JSON.stringify(s))),{key,s});await p.reload();await ready(p);
  await click(p,'성장');await click(p,'고급 장비 성장 · 정련·융합');
  await click(p,'정밀 조정 · 150 C + 설계도 3',72);
  assert.equal((await saved(p)).content.advancedEquipment.entries[0].refinement,1);
  const gear=await physicalPage(p);
  await p.waitForTimeout(200);await p.screenshot({path:path.join(out,`notice-gear-${width}-scale-1.3.png`)});
  await click(p,'Back');await chip(p,'펫');await click(p,'각성·호감도 · 50 / 300');
  await click(p,'먹이 10 선물 · 호감도 +10',72);
  assert.equal((await saved(p)).content.petBond.favor[0],60);
  const pet=await physicalPage(p);
  await p.waitForTimeout(200);await p.screenshot({path:path.join(out,`notice-pet-${width}-scale-1.3.png`)});
  rows.push({width,height,scale:1.3,gear,pet,physicalPageTouchDuringNotice:true});await c.close();
 }
 assert.deepEqual(errors,[]);fs.writeFileSync(path.join(out,'notice-touch-result.json'),JSON.stringify({rows,errors},null,2));
 console.log(JSON.stringify({passed:rows.length,errors}));
 }catch(e){if(last&&!last.isClosed())await last.screenshot({path:path.join(out,'notice-failure.png')});throw e;}
 finally{await b.close();}
})().catch(e=>{console.error(e);process.exit(1);});
