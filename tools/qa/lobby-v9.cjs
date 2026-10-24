// Isolated mobile browser acceptance. Never attaches to or clears user storage.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','lobby-v9');fs.mkdirSync(out,{recursive:true});
const key='flutter.shootingstar.profile.v1';
(async()=>{
 let browser;
 const rows=[],errors=[],diagnostics=[];let last;
 const button=(p,n)=>p.getByRole('button',{name:n,exact:true}).first();
 async function ready(p){for(let n=0;n<160;n++){
   if(await p.locator('flt-semantics-placeholder').count())await p.locator('flt-semantics-placeholder').evaluate(e=>e.click());
   if(await button(p,'성장').count()){await p.waitForTimeout(350);return;}await p.waitForTimeout(250);
 }throw Error('Flutter initialization timed out');}
 async function click(p,n){const l=button(p,n),b=await reveal(p,l);assert(b,n);
   const v=p.viewportSize();assert(b.x>=-.2&&b.y>=-.2&&b.x+b.width<=v.width+.2&&b.y+b.height<=v.height+.2,n+' outside viewport');
   await p.mouse.click(b.x+b.width/2,b.y+b.height/2);await p.waitForTimeout(250);return b;}
 async function saved(p){return p.evaluate(key=>{let s=localStorage.getItem(key);for(let i=0;i<3&&typeof s==='string';i++)s=JSON.parse(s);return s;},key);}
 const identity=s=>JSON.stringify({credits:s.credits,plans:s.blueprints,stage:s.selectedStage,ship:s.selectedShip,
   content:s.content,presets:s.hangarPresets,collections:s.collections,mail:s.mail});
 async function shot(p,name){await p.screenshot({path:path.join(out,name+'.png')});}
 try{
 for(const [width,height]of [[320,568],[360,640],[390,844],[430,932]])for(const scale of [1,1.3]){
   if(process.env.QA_WIDTH&&width!==+process.env.QA_WIDTH)continue;
   if(process.env.QA_SCALE&&scale!==+process.env.QA_SCALE)continue;
   console.log('lobby v9',width,scale);
   browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
   const c=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
   await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated QA"}'}));
   const p=await c.newPage();last=p;
   p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{diagnostics.push({width,scale,type:m.type(),text:m.text()});if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
   p.on('requestfailed',r=>diagnostics.push({width,scale,failed:r.url(),reason:r.failure()}));
   await p.goto(scale===1?'http://127.0.0.1:8797/?ui=lobby-v9':`http://127.0.0.1:8798/?scene=menus&textScale=${scale}`);await ready(p);
   // Establish an actual save, including an earned gear ID, before reloading it.
   await click(p,'보급');await click(p,'장비 보급 열기');await click(p,'확인');
   let s=await saved(p);s.onboarded=true;s.credits=7000;s.blueprints=100;
   s.hangarPresets[0]={name:'기존 편성 보존',ship:0,pilot:0,armament:0,equipment:0,gearIds:[...s.content.equippedGear],techIds:[],pet:0,assistPets:[]};
   await p.evaluate(({key,s})=>localStorage.setItem(key,JSON.stringify(JSON.stringify(s))),{key,s});await p.reload();await ready(p);
   const initial=identity(await saved(p)),tag=`${width}-scale-${scale}`;
   const launch=p.getByRole('button',{name:/ · 출격$/}).first();
   const controls=[launch,...['45초 훈련','비행 가이드','임무·출석','시즌 보상','순찰','길드','보급','성장','출격','도전','진화'].map(n=>button(p,n))];
   const before=await Promise.all(controls.map(l=>l.boundingBox()));assert(before.every(Boolean));
   for(const b of before)assert(b.x>=-.2&&b.y>=-.2&&b.x+b.width<=width+.2&&b.y+b.height<=height+.2,'clipped lobby control');
   assert(before[0].height>=72&&before[0].width<=264.2&&before[0].width/before[0].height<=4.25,'painted launch dimensions');
   const hero=await p.getByRole('img',{name:'오로라',exact:true}).boundingBox();assert(hero&&hero.width>=110&&hero.height>=110,'ship must remain prominent at mobile sizes');
   assert.equal(await p.locator('flt-semantics-scroll-overflow').count(),0,'lobby scroll viewport');
   assert.equal(await p.evaluate(()=>document.documentElement.scrollHeight>innerHeight||document.documentElement.scrollWidth>innerWidth),false);
   await p.mouse.move(width/2,height*.5);await p.mouse.wheel(0,500);await p.waitForTimeout(150);
   const cdp=await c.newCDPSession(p),x=width*.5,y=height*.55;
   await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y}]});
   for(let i=1;i<=4;i++)await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x,y:y-i*20}]});
   await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await cdp.detach();await p.waitForTimeout(150);
   assert.deepEqual(await Promise.all(controls.map(l=>l.boundingBox())),before,'non-list UI moved');
   await shot(p,`main-${tag}`);
   const routes=[];
   for(const name of ['임무·출석','시즌 보상','순찰','길드','성장','보급','도전','진화']){
     await click(p,name);await p.waitForTimeout(200);
     if(width===390&&scale===1.3)await shot(p,`route-${routes.length}-${tag}`);
     assert.equal(identity(await saved(p)),initial,'navigation changed saved progress: '+name);
     routes.push(name);
     if(await button(p,'Back').count())await click(p,'Back');else await click(p,'출격');
     await launch.waitFor({state:'visible',timeout:5000});
   }
   await p.reload();await ready(p);
   assert.equal(identity(await saved(p)),initial,'reload changed inventory or progress');
   if(width===390&&scale===1.3){const original=await saved(p);
     for(const ship of [1,2]){const variant={...original,selectedShip:ship,unlockedShips:[0,1,2]};
       await p.evaluate(({key,s})=>localStorage.setItem(key,JSON.stringify(JSON.stringify(s))),{key,s:variant});await p.reload();await ready(p);await shot(p,`ship-${ship}-${tag}`);}
   }
   rows.push({width,height,scale,controls:before,hero,routes,noNonListScroll:true,wheelAndTouchStationary:true,
     earnedInventoryEquippedPresetCurrencyPreserved:true,realFlutterTextScaler:true});await c.close();await browser.close();
 }
 assert.deepEqual(errors,[]);fs.writeFileSync(path.join(out,'browser-result.json'),JSON.stringify({rows,errors,diagnostics,
   scope:'Fresh isolated mobile Chrome guests; actual TextScaler, pointer, wheel and touch; no user browser storage attached.'},null,2));
 console.log(JSON.stringify({passed:rows.length,errors}));
 }catch(e){fs.writeFileSync(path.join(out,'failure-diagnostics.json'),JSON.stringify({errors,diagnostics},null,2));if(last&&!last.isClosed()){await shot(last,'failure');fs.writeFileSync(path.join(out,'failure-semantics.txt'),await last.locator('body').innerText());}throw e;}
 finally{if(browser)await browser.close();}
})();
