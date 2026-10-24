const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','menu-v8');fs.mkdirSync(out,{recursive:true});
const key='flutter.shootingstar.profile.v1';
(async()=>{
 let browser;
 const rows=[],errors=[];let last;
 const button=(p,name)=>p.getByRole('button',{name,exact:true}).first();
 async function click(p,name,min=20){const b=await reveal(p,button(p,name),min);await p.mouse.click(b.x+b.width/2,b.y+b.height/2);await p.waitForTimeout(250);return b;}
 async function chip(p,name){const l=p.getByRole('checkbox',{name,exact:true}).first();const b=await l.boundingBox();assert(b);await p.mouse.click(b.x+b.width/2,b.y+b.height/2);await p.waitForTimeout(250);}
 async function ready(p){for(let n=0;n<160;n++){
   if(await p.locator('flt-semantics-placeholder').count())await p.locator('flt-semantics-placeholder').evaluate(e=>e.click());
   if(await button(p,'성장').count()){await p.waitForTimeout(300);return;}await p.waitForTimeout(250);
 }throw Error('Flutter initialization timed out');}
 async function saved(p){return p.evaluate(key=>{let s=localStorage.getItem(key);for(let n=0;n<3&&typeof s==='string';n++)s=JSON.parse(s);return s;},key);}
 async function shot(p,name){await p.waitForTimeout(200);await p.screenshot({path:path.join(out,name+'.png')});}
 async function stationary(p,locators){const before=await Promise.all(locators.map(l=>l.boundingBox()));
   assert(before.every(Boolean));const v=p.viewportSize(),x=v.width/2,y=v.height-110;
   await p.mouse.move(x,y);await p.mouse.wheel(0,450);await p.waitForTimeout(160);
   const cdp=await p.context().newCDPSession(p);await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y}]});
   for(let i=1;i<=4;i++)await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x,y:y-i*20}]});
   await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await p.waitForTimeout(160);await cdp.detach();
   assert.deepEqual(await Promise.all(locators.map(l=>l.boundingBox())),before,'non-list UI moved');return before;
 }
 async function measure(p,name,primary=true){const b=await reveal(p,button(p,name),primary?72:64);assert(b.width<=264.2&&b.width/b.height<=4.25);return{name,...b};}
 const identity=s=>JSON.stringify({ids:s.content.inventory.map(g=>g.id),equipped:s.content.equippedGear,presets:s.hangarPresets,stage:s.selectedStage});
 try{
 for(const [width,height]of [[320,568],[360,640],[390,844],[430,932]])for(const scale of [1,1.3]){
   if(process.env.QA_WIDTH&&width!==+process.env.QA_WIDTH)continue;
   if(process.env.QA_SCALE&&scale!==+process.env.QA_SCALE)continue;
   console.log('menu v8',width,scale);
   if(browser)await browser.close();
   browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
   const c=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
   await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated visual QA"}'}));
   const p=await c.newPage();last=p;p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
   await p.goto(scale===1?'http://127.0.0.1:8797/?ui=menu-v8':`http://127.0.0.1:8798/?scene=menus&textScale=${scale}`);await ready(p);
   // Create a real guest save via UI before seeding only local test resources.
   await click(p,'보급');await click(p,'장비 보급 열기',72);await click(p,'확인',72);
   let s=await saved(p);s.onboarded=true;s.credits=7000;s.blueprints=100;s.content.gearKeys=3;s.content.techKeys=2;s.content.petEggs=1;
   s.hangarPresets[0]={name:'비주얼 개편 보존',ship:0,pilot:0,armament:0,equipment:0,gearIds:[...s.content.equippedGear],techIds:[],pet:0,assistPets:[]};
   await p.evaluate(({key,s})=>localStorage.setItem(key,JSON.stringify(JSON.stringify(s))),{key,s});await p.reload();await ready(p);
   const initial=identity(await saved(p)),tag=`${width}-scale-${scale}`,measurements=[];
   const launch=p.getByRole('button',{name:/ · 출격$/}).first();
   const controls=[launch,...['45초 훈련','비행 가이드','임무·출석','시즌 보상','순찰','길드'].map(n=>button(p,n))];
   const lobby=await stationary(p,controls);
   for(const b of lobby){assert(b.x>=0&&b.y>=0&&b.x+b.width<=width+.2&&b.y+b.height<=height+.2);}
   assert.equal(await p.locator('flt-semantics-scroll-overflow').count(),0,'lobby has a scroll viewport');
   await shot(p,`main-${tag}`);
   if(width===390&&scale===1.3){
     const original=await saved(p);
     for(const ship of [1,2]){
       const variant={...original,selectedShip:ship,unlockedShips:[0,1,2]};
       await p.evaluate(({key,s})=>localStorage.setItem(key,JSON.stringify(JSON.stringify(s))),{key,s:variant});await p.reload();await ready(p);
       await shot(p,`ship-${ship}-${tag}`);await click(p,'성장');await shot(p,`ship-${ship}-growth-${tag}`);
     }
     await p.evaluate(({key,s})=>localStorage.setItem(key,JSON.stringify(JSON.stringify(s))),{key,s:original});await p.reload();await ready(p);
   }
   await click(p,'성장');await shot(p,`growth-${tag}`);
   assert.equal(await p.locator('flt-semantics-scroll-overflow').count(),0,'equipment overview must not scroll');
   await stationary(p,[p.getByRole('checkbox',{name:'장착',exact:true})]);
   const hero=p.getByRole('img',{name:'오로라 장착 기체',exact:true});
   assert(await hero.count(),'first equipment page must show the ship');
   const heroBox=await hero.boundingBox();assert(heroBox&&heroBox.y>=0&&heroBox.y+heroBox.height<=height);
   const slot=p.getByRole('button',{name:/^주무장 /}).first();const slotBox=await reveal(p,slot,48);await p.mouse.click(slotBox.x+slotBox.width/2,slotBox.y+slotBox.height/2);await p.waitForTimeout(250);
   await shot(p,`equipment-detail-${tag}`);await stationary(p,[button(p,'장비 상세 닫기')]);await click(p,'장비 상세 닫기',48);
   await chip(p,'보관');await shot(p,`inventory-${tag}`);
   const sort=button(p,'등급순'),before=await sort.boundingBox();
   const list=await p.locator('flt-semantics:has(> flt-semantics-scroll-overflow)').last().boundingBox();assert(list);
   await p.mouse.move(list.x+list.width*.5,list.y+list.height*.6);await p.mouse.wheel(0,280);await p.waitForTimeout(180);assert.deepEqual(await sort.boundingBox(),before);
   await chip(p,'관리');await shot(p,`management-${tag}`);
   measurements.push(await measure(p,'고급 장비 성장 · 정련·융합',false));await click(p,'고급 장비 성장 · 정련·융합',64);await shot(p,`advanced-${tag}`);await click(p,'Back',48);
   await click(p,'수집품 0/12',64);await shot(p,`collection-${tag}`);await click(p,'Back',48);
   assert.equal(identity(await saved(p)),initial,'browsing changed IDs or presets');
   await click(p,'보급');await shot(p,`supply-${tag}`);
   measurements.push(await measure(p,'장비 보급 열기'));
   const beforeClaim=await saved(p),oldIds=beforeClaim.content.inventory.map(g=>g.id);
   await click(p,'장비 보급 열기',72);s=await saved(p);assert.equal(s.content.inventory.length,oldIds.length+1);assert.equal(s.content.gearKeys,beforeClaim.content.gearKeys-1);
   const earned=s.content.inventory.at(-1).id,once=JSON.stringify(s);await shot(p,`reward-${tag}`);await click(p,'확인',72);assert.equal(JSON.stringify(await saved(p)),once);
   await reveal(p,button(p,'테크 보급 열기'),72);await shot(p,`supply-tech-${tag}`);await click(p,'테크 보급 열기',72);await click(p,'확인',72);
   await reveal(p,button(p,'펫 구조하기'),72);await shot(p,`supply-pet-${tag}`);await click(p,'펫 구조하기',72);await click(p,'확인',72);
   await chip(p,'교환');await shot(p,`exchange-${tag}`);const exchange=await saved(p);
   await click(p,'먹이 교환',72);s=await saved(p);assert.equal(s.credits,exchange.credits-60);assert.equal(s.content.petFood,exchange.content.petFood+30);await click(p,'확인',72);
   await p.reload();await ready(p);s=await saved(p);
   assert.deepEqual(s.content.inventory.map(g=>g.id),[...oldIds,earned]);assert.deepEqual(s.content.equippedGear,beforeClaim.content.equippedGear);assert.equal(s.hangarPresets[0].name,'비주얼 개편 보존');
   rows.push({width,height,scale,lobby,measurements,noNonListWheelOrTouchScroll:true,
     equipmentOverviewAndManagementFixed:true,inventoryListHeaderFixed:true,threeSupplyClaimsAndExchange:true,
     inventoryIdsEquippedPresetsPreserved:true,rewardDismissDoesNotGrantAgain:true,actualTextScaler:true});
   await c.close();
 }
 assert.deepEqual(errors,[]);fs.writeFileSync(path.join(out,'browser-result.json'),JSON.stringify({rows,errors,scope:'Fresh isolated mobile Chrome guests; real TextScaler, pointer/wheel/touch; external API blocked.'},null,2));console.log(JSON.stringify({passed:rows.length,errors}));
 }catch(e){if(last&&!last.isClosed()){await shot(last,'failure');fs.writeFileSync(path.join(out,'failure-semantics.txt'),await last.locator('body').innerText());}throw e;}
 finally{if(browser)await browser.close();}
})();
