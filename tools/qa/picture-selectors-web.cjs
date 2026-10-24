const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','picture-selectors');fs.mkdirSync(out,{recursive:true});
const normalKey='flutter.shootingstar.profile.v1',devKey='flutter.shootingstar.developer.v1';
const button=(p,name)=>p.getByRole('button',typeof name==='string'?{name,exact:true}:{name}).last();
async function ready(p){for(let i=0;i<130;i++){
 const a=p.locator('flt-semantics-placeholder');if(await a.count())await a.evaluate(e=>e.click());
 if(await button(p,/^설정(?: 설정)?$/).count()||await button(p,/^테스트 메뉴 /).count())break;
 await p.waitForTimeout(120);
}await p.waitForLoadState('networkidle');}
async function click(p,l,min=20){const b=await reveal(p,l,min);await p.mouse.click(b.x+b.width/2,b.y+b.height/2);await p.waitForTimeout(350);}
async function select(p,label,current,next){await click(p,button(p,label+' '+current));const l=p.getByRole('menuitem',{name:next,exact:true}).last();
 for(let i=0;i<30;i++){const b=await l.boundingBox({timeout:100}).catch(()=>null),h=p.viewportSize().height;
  if(b&&b.y>=25&&b.y+b.height<h-15){await click(p,l);await p.waitForTimeout(200);return;}
  await p.mouse.move(p.viewportSize().width/2,h/2);await p.mouse.wheel(0,b&&b.y<25?-100:110);await p.waitForTimeout(60);
 }throw Error('dropdown unreachable '+next);}
const menu=(p,current,next)=>select(p,'테스트 메뉴',current,next);
async function storage(p,key){return p.evaluate(key=>localStorage.getItem(key),key);}
async function record(p){let raw=await storage(p,devKey);for(let i=0;i<3&&typeof raw==='string';i++)raw=JSON.parse(raw);return raw;}
async function three(p,names){const boxes=[];for(const name of names)boxes.push(await button(p,name).boundingBox());
 assert(boxes.every(Boolean));assert(Math.abs(boxes[0].y-boxes[1].y)<1&&Math.abs(boxes[1].y-boxes[2].y)<1,'not three columns');
 assert(boxes[2].x+boxes[2].width<=p.viewportSize().width+.5);return boxes;}
async function fixed(p,l){const b=await l.boundingBox();await p.mouse.move(b.x+b.width/2,b.y+b.height/2);await p.mouse.wheel(0,350);await p.waitForTimeout(100);assert.deepEqual(await l.boundingBox(),b);
 const cdp=await p.context().newCDPSession(p);const x=b.x+b.width/2,y=b.y+b.height/2;
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y}]});
 for(let i=1;i<4;i++)await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x,y:y-i*20}]});
 await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await p.waitForTimeout(150);
 assert.deepEqual(await l.boundingBox(),b);await cdp.detach();}
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'}),rows=[],errors=[];
 try{for(const [width,height] of [[320,568],[360,640],[390,844],[430,932]])for(const scale of [1,1.3]){
  const tag=width+'-'+scale;if(process.env.QA_ONLY&&tag!==process.env.QA_ONLY)continue;
  if(process.env.QA_SKIP&&process.env.QA_SKIP.split(',').includes(tag))continue;
  console.log('Picture selectors',tag);
  const c=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
  await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated picture selector QA"}'}));
  const p=await c.newPage();p.setDefaultTimeout(9000);
  p.on('pageerror',e=>errors.push({tag,error:e.message}));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push({tag,error:m.text()});});
  async function tab(name){await click(p,p.getByRole('checkbox',{name,exact:true}).last());}
  async function picked(name){const l=button(p,name);await click(p,l);const attrs=await l.evaluate(e=>({pressed:e.getAttribute('aria-pressed'),selected:e.getAttribute('aria-selected'),label:e.textContent}));
    return attrs;}
  try{
   await p.goto(scale===1?'http://127.0.0.1:8797/?ui=v10.0.15':'http://127.0.0.1:8799/?textScale=1.3');await ready(p);
   assert(await p.getByText('v10.0.15',{exact:true}).count());
   await click(p,button(p,/^설정(?: 설정)?$/));await click(p,p.getByRole('switch',{name:'음악·효과음',exact:true}));
   const before=await storage(p,normalKey);assert(before);
   const badge=button(p,/v10\.0\.15.*3초/),b=await badge.boundingBox();
   await p.mouse.move(b.x+b.width/2,b.y+b.height/2);await p.mouse.down();await p.waitForTimeout(3100);await p.mouse.up();await p.waitForTimeout(250);
   await p.locator('input[aria-label^="비밀번호"]').first().fill('0623');await click(p,button(p,'개발자 모드 시작'),72);
   await click(p,button(p,/^설정(?: 설정)?$/));await click(p,button(p,'테스트'),72);
   const weaponSlots=await three(p,['주무기 펄스 주포','주무기 유도 침','주무기 초승 파동검']);
   await picked('주무기 산탄 캐논');await p.screenshot({path:path.join(out,'weapons-'+tag+'.png')});
   await tab('기체');
   // Names come from the rendered three aircraft buttons, not a save mutation.
   const aircraft=p.getByRole('button',{name:/^비행기 /});const shipNames=await aircraft.allTextContents();
   assert.equal(shipNames.length,3);const shipLabel=await aircraft.nth(2).innerText();
   const ships3=[];for(let i=0;i<3;i++)ships3.push(await aircraft.nth(i).boundingBox());
   assert.equal(ships3[0].y,ships3[1].y);assert.equal(ships3[1].y,ships3[2].y);
   await picked(shipLabel);await p.screenshot({path:path.join(out,'aircraft-'+tag+'.png')});
   await tab('항로');const worldNames=await p.getByRole('button',{name:/^세계 /}).evaluateAll(es=>es.slice(0,3).map(e=>e.textContent));
   const worldSlots=await three(p,worldNames);await picked('세계 태양 용광로');
   await p.screenshot({path:path.join(out,'worlds-'+tag+'.png')});
   await tab('세부 항로');const routeNames=await p.getByRole('button',{name:/^항로 [123] /}).evaluateAll(es=>es.slice(0,3).map(e=>e.textContent));
   const routeSlots=await three(p,routeNames);const route9=p.getByRole('button',{name:/^항로 9 /}).last();
   await reveal(p,route9);await picked(await route9.innerText());
   await p.reload();await ready(p);let saved=await record(p);
   assert.equal(saved.progress.selectedStage,68);assert.equal(saved.progress.selectedShip,2);
   assert.equal(saved.progress.selectedArmament,4);
   assert.equal(saved.settings.ui.selectionTab,2);assert.equal(saved.settings.ui.stageTab,1);
   assert(await p.getByRole('checkbox',{name:'세부 항로',checked:true,exact:true}).count());
   await p.screenshot({path:path.join(out,'restored-route-'+tag+'.png')});
   await menu(p,'전투 / 무기·기체','전투 / 보스·편대');await tab('세계');await picked('세계 태양 용광로');
   await tab('교전');await select(p,'교전 시작','선택 항로 웨이브','세계 보스');await select(p,'보스 단계','1단계','3단계');
   await menu(p,'전투 / 보스·편대','전투 / 레벨·주포');
   await select(p,'전투 시작 레벨','1','6');await select(p,'영구 연구 단계','0','3');
   await p.reload();await ready(p);saved=await record(p);assert.equal(saved.settings.battle.level,6);assert.equal(saved.settings.battle.phase,2);
   await menu(p,'전투 / 레벨·주포','성장 / 영구 연구');await click(p,button(p,/^화력 1 /));
   assert.equal(await p.getByRole('button',{name:'연구 완료',exact:true}).count(),0);
   assert.equal(await button(p,/^다음 페이지/).count(),0);
   const title=await p.getByRole('heading',{name:'진화 연구',exact:true}).boundingBox();
   const complete=await p.getByText('연구 완료',{exact:true}).last().boundingBox();
   assert(complete.y+complete.height-title.y<260,'completed research content too tall');
   await p.screenshot({path:path.join(out,'compact-research-'+tag+'.png')});await click(p,button(p,'닫기'));
   await fixed(p,button(p,'테스트 메뉴 성장 / 영구 연구'));
   assert.equal(await storage(p,normalKey),before);
   await click(p,button(p,'Back'));await ready(p);await p.reload();await ready(p);assert(await storage(p,devKey));
   await click(p,button(p,/^설정(?: 설정)?$/));await click(p,button(p,'개발자 모드 종료 · 일반 사용자로 전환'));
   await p.reload();await ready(p);assert.equal(await storage(p,devKey),null);assert.equal(await storage(p,normalKey),before);
   const row={width,height,textScale:scale,weaponSlots,aircraftSlots:ships3,worldSlots,routeSlots,completedResearch:{title,complete},selectionRestored:true,battleRestored:true,normalSaveUnchanged:true,lockClearsMode:true};
   rows.push(row);fs.writeFileSync(path.join(out,'browser-'+tag+'.json'),JSON.stringify(row,null,2));
  }catch(e){await p.screenshot({path:path.join(out,'failure-'+tag+'.png')});fs.writeFileSync(path.join(out,'failure-'+tag+'.txt'),await p.locator('body').ariaSnapshot());console.log(JSON.stringify(errors));throw e;}
  finally{await c.close();}
 }
 assert.deepEqual(errors,[]);fs.writeFileSync(path.join(out,'browser-summary'+(process.env.QA_ONLY?'-'+process.env.QA_ONLY:'')+'.json'),JSON.stringify({version:'v10.0.15',rows,errors},null,2));console.log(JSON.stringify({passed:rows.length,errors}));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
