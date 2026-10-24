// Real lobby -> actual battle -> pause/resume; isolated mobile browser storage.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=process.env.QA_EVIDENCE_DIR||path.join(__dirname,'evidence','game-v10');fs.mkdirSync(out,{recursive:true});
const version=fs.readFileSync(path.join(__dirname,'../../pubspec.yaml'),'utf8').match(/^version: (.+)$/m)[1].trim().split('+')[0];
const key='flutter.shootingstar.profile.v1';
(async()=>{
 let browser,last;const rows=[],errors=[],requests=new Set(),diagnostics=[];
 const button=(p,n)=>p.getByRole('button',{name:n,exact:true}).first();
 async function ready(p,kind='menus'){
  for(let n=0;n<200;n++){
   if(await p.locator('flt-semantics-placeholder').count())await p.locator('flt-semantics-placeholder').evaluate(e=>e.click());
   if(await button(p,kind==='menus'?'성장':'일시정지').count()){await p.waitForTimeout(250);return;}
   await p.waitForTimeout(200);
  }throw Error('Flutter initialization timeout: '+p.url());
 }
 async function click(p,n){const l=button(p,n),b=await reveal(p,l);assert(b,n);
  const v=p.viewportSize();assert(b.x>=-.2&&b.y>=-.2&&b.x+b.width<=v.width+.2&&b.y+b.height<=v.height+.2,n+' clipped');
  await p.mouse.click(b.x+b.width/2,b.y+b.height/2);await p.waitForTimeout(250);return b;
 }
 async function saved(p){return p.evaluate(key=>{let s=localStorage.getItem(key);for(let i=0;i<3&&typeof s==='string';i++)s=JSON.parse(s);return s;},key);}
 const identity=s=>JSON.stringify({stage:s.selectedStage,ship:s.selectedShip,content:s.content,presets:s.hangarPresets,collections:s.collections,mail:s.mail});
 async function shot(p,n){await p.screenshot({path:path.join(out,n+'.png')});}
 async function noScroll(p,controls){
  const before=await Promise.all(controls.map(l=>l.boundingBox()));
  assert.equal(await p.locator('flt-semantics-scroll-overflow').count(),0,'non-list scroll viewport');
  assert.equal(await p.evaluate(()=>document.documentElement.scrollHeight>innerHeight||document.documentElement.scrollWidth>innerWidth),false);
  const v=p.viewportSize();await p.mouse.move(v.width*.5,v.height*.55);await p.mouse.wheel(0,400);await p.waitForTimeout(100);
  const cdp=await p.context().newCDPSession(p),x=v.width*.5,y=v.height*.65;
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y}]});
  for(let i=1;i<=4;i++)await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x,y:y-i*20}]});
  await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await cdp.detach();await p.waitForTimeout(100);
  assert.deepEqual(await Promise.all(controls.map(l=>l.boundingBox())),before,'non-list controls moved');
  return before;
 }
 async function context(width,height,scale){
  browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
  const c=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
  await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated QA"}'}));
  const p=await c.newPage();last=p;
  p.on('request',r=>{if(r.url().includes('/assets/'))requests.add(r.url());});
  p.on('pageerror',e=>errors.push({width,scale,error:e.stack||e.message}));
  p.on('requestfailed',r=>diagnostics.push({url:r.url(),failure:r.failure()}));
  p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push({width,scale,error:m.text()});if(m.type()==='error')diagnostics.push(m.text());});
  return {c,p};
 }
 try{
 for(const [width,height]of [[320,568],[360,640],[390,844],[430,932]])for(const scale of [1,1.3]){
  if(process.env.QA_WIDTH&&width!==+process.env.QA_WIDTH)continue;if(process.env.QA_SCALE&&scale!==+process.env.QA_SCALE)continue;
  console.log('game v10 actual',width,scale);const {c,p}=await context(width,height,scale),tag=`${width}-scale-${scale}`;
  await p.goto(scale===1?'http://127.0.0.1:8797/?ui=game-v10':`http://127.0.0.1:8798/?scene=menus&textScale=${scale}`);await ready(p);
  const footer=p.getByText('v'+version,{exact:true});
  const footerBox=await footer.boundingBox();assert(footerBox&&footerBox.y+footerBox.height<=height+.1,'version footer clipped');
  assert(footerBox.y>height-65,'version must be at the bottom of the lobby');
  await noScroll(p,[footer,button(p,'성장'),button(p,'보급')]);
  // Earn an inventory item through the real UI before preserving that save.
  await click(p,'보급');await click(p,'장비 보급 열기');await click(p,'확인');
  let s=await saved(p);s.onboarded=true;s.credits=7000;s.blueprints=100;
  s.hangarPresets[0]={name:'기존 편성 보존',ship:0,pilot:0,armament:0,equipment:0,gearIds:[...s.content.equippedGear],techIds:[],pet:0,assistPets:[]};
  await p.evaluate(({key,s})=>localStorage.setItem(key,JSON.stringify(JSON.stringify(s))),{key,s});await p.reload();await ready(p);
  const initial=identity(await saved(p));
  const launch=p.getByRole('button',{name:/ · 출격$/}).first(),launchBox=await launch.boundingBox();
  assert(launchBox&&launchBox.height>=72&&launchBox.width<=264.2);
  await noScroll(p,[launch,button(p,'성장'),button(p,'보급')]);await shot(p,'main-'+tag);
  await click(p,'보급');await shot(p,'supply-'+tag);await click(p,'성장');await shot(p,'growth-'+tag);await click(p,'출격');
  // This launches the shipped production GameEngine, not an art fixture.
  await p.mouse.click(launchBox.x+launchBox.width/2,launchBox.y+launchBox.height/2);await ready(p,'battle');await p.waitForTimeout(2300);
  await shot(p,'actual-battle-'+tag);
  const pauseBox=await click(p,'일시정지');assert(pauseBox.width>=48&&pauseBox.height>=48,'pause touch area');
  const pauseControls=['전투 통계','계속 비행','귀환 · 현재 보상 정산'].map(n=>button(p,n));
  await shot(p,'pause-'+tag);
  const pauseBounds=[];
  for(const l of pauseControls){await reveal(p,l);pauseBounds.push((await noScroll(p,[l]))[0]);}
  assert(pauseBounds[1].height>=72&&pauseBounds[1].width<=264.2,'resume painted dimensions');
  await shot(p,'pause-return-page-'+tag);await click(p,'계속 비행');
  const cdp=await c.newCDPSession(p),x=width*.5,y=height*.66;
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y}]});
  for(let i=1;i<=6;i++)await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:x+40*i/6,y:y-55*i/6}]});
  await p.waitForTimeout(300);await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await cdp.detach();
  await shot(p,'actual-after-touch-'+tag);assert.equal(await p.locator('flt-semantics-scroll-overflow').count(),0);
  assert.equal(identity(await saved(p)),initial,'entering battle changed persistent inventory');
  await p.reload();await ready(p);assert.equal(identity(await saved(p)),initial,'reload changed persistent inventory/presets');
  rows.push({width,height,scale,version,footerBox,actualLobbyToBattle:true,pauseResumeAndTouch:true,pauseBounds,noNonListScroll:true,saveIdentityPreserved:true,actualFlutterTextScaler:true});
  await c.close();await browser.close();
 }
 if(!process.env.QA_WIDTH||process.env.QA_FIXTURES==='1'){
  // Posed fixtures provide visual coverage, not evidence of earned progress.
  for(const [scene,query]of [['art-v10','&pet=0'],['choices',''],['boss','&stage=39&ship=1&pet=1'],['boss','&stage=69&ship=2&pet=2']]){
   const {c,p}=await context(390,844,1.3);await p.goto(`http://127.0.0.1:8798/?scene=${scene}&textScale=1.3${query}`);
   if(scene==='choices'){for(let i=0;i<200;i++){if(await p.locator('flt-semantics-placeholder').count())await p.locator('flt-semantics-placeholder').evaluate(e=>e.click());if(await p.getByText('펄스 블래스터',{exact:false}).count())break;await p.waitForTimeout(200);}}
   else await ready(p,'battle');
   await p.waitForTimeout(900);await shot(p,'fixture-'+scene+query.replace(/[^a-z0-9]/g,'-'));await c.close();await browser.close();
  }
 }
 const legacy=[...requests].filter(u=>/toon_v7|menu_v8|raster_v6|survival_enemy|survival_boss|ruined_city_ground|cloud_layer/.test(u));
 assert.deepEqual(legacy,[],'legacy graphics still fetched');assert.deepEqual(errors,[]);
 fs.writeFileSync(path.join(out,'browser-result.json'),JSON.stringify({rows,errors,legacyRequests:legacy,assetRequests:[...requests],diagnostics,
  scope:'Fresh isolated mobile Chrome; actual lobby launch, real GameEngine, pause/resume/touch, no user storage attached. Extra fixture images are explicitly posed.'},null,2));
 console.log(JSON.stringify({passed:rows.length,errors,legacyRequests:legacy}));
 }catch(e){fs.writeFileSync(path.join(out,'failure-diagnostics.json'),JSON.stringify({errors,diagnostics},null,2));if(last&&!last.isClosed()){await shot(last,'failure');fs.writeFileSync(path.join(out,'failure-semantics.txt'),await last.locator('body').innerText());}throw e;}
 finally{if(browser)await browser.close();}
})();
