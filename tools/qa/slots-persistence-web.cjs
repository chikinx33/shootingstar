const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','slots-persistence');fs.mkdirSync(out,{recursive:true});
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
  console.log('Persistent slots',tag);
  const c=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
  await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated slots QA"}'}));
  const p=await c.newPage();p.setDefaultTimeout(9000);
  p.on('pageerror',e=>errors.push({tag,error:e.message}));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push({tag,error:m.text()});});
  try{
   await p.goto(scale===1?'http://127.0.0.1:8797/?ui=v10.0.14':'http://127.0.0.1:8799/?textScale=1.3');await ready(p);
   assert(await p.getByText('v10.0.14',{exact:true}).count());
   await click(p,button(p,'보급'));
   const normalSlots=await three(p,['장비 보급 상세','테크 보급 상세','펫 구조 상세']);
   await p.screenshot({path:path.join(out,'normal-supply-'+tag+'.png')});
   if(tag==='390-1'){
    await click(p,button(p,'장비 보급 상세'));await click(p,button(p,'장비 보급 열기'),72);
    await click(p,button(p,'확인'),72);await click(p,button(p,'닫기'));
   }
   await click(p,button(p,/^설정(?: 설정)?$/));await click(p,p.getByRole('switch',{name:'음악·효과음',exact:true}));
   const before=await storage(p,normalKey);assert(before);await p.waitForTimeout(100);
   const badge=button(p,/v10\.0\.14.*3초/),b=await badge.boundingBox();
   await p.mouse.move(b.x+b.width/2,b.y+b.height/2);await p.mouse.down();await p.waitForTimeout(3100);await p.mouse.up();await p.waitForTimeout(250);
   await p.locator('input[aria-label^="비밀번호"]').first().fill('0623');await click(p,button(p,'개발자 모드 시작'),72);
   await click(p,button(p,/^설정(?: 설정)?$/));await click(p,button(p,'테스트'),72);
   await menu(p,'전투 / 무기·기체','전투 / 레벨·주포');
   await select(p,'전투 시작 레벨','1','6');await select(p,'연사 R','0','2');
   await menu(p,'전투 / 레벨·주포','전투 / 보스·편대');
   await select(p,'세계','잔광 외곽','태양 용광로');
   await select(p,'교전 시작','선택 항로 웨이브','세계 보스');await select(p,'보스 단계','1단계','3단계');
   let saved=await record(p);assert.equal(saved.progress.selectedStage,60);assert.equal(saved.settings.battle.level,6);assert.equal(saved.settings.battle.rate,2);
   await p.reload();await ready(p);
   assert(await button(p,'테스트 메뉴 전투 / 보스·편대').count());assert(await button(p,'세계 태양 용광로').count());
   saved=await record(p);assert.equal(saved.settings.battle.phase,2);assert.equal(saved.settings.battle.scene,1);
   await menu(p,'전투 / 보스·편대','전투 / 레벨·주포');
   assert(await button(p,'전투 시작 레벨 6').count());assert(await button(p,'연사 R 2').count());
   await menu(p,'전투 / 레벨·주포','콘텐츠 / 보급');
   const testSlots=await three(p,['장비 보급 상세','테크 보급 상세','펫 구조 상세']);
   await fixed(p,button(p,'테스트 메뉴 콘텐츠 / 보급'));
   await p.screenshot({path:path.join(out,'test-supply-'+tag+'.png')});
   await p.getByRole('checkbox',{name:'교환',exact:true}).click();await p.waitForTimeout(250);
   await p.reload();await ready(p);assert(await p.getByRole('checkbox',{name:'교환',checked:true,exact:true}).count());
   const exchangeSlots=await three(p,['먹이 교환 상세','설계도 교환 상세','장비 보급권 교환 상세']);
   if(tag==='390-1')await p.screenshot({path:path.join(out,'restored-exchange.png')});
   assert.equal(await storage(p,normalKey),before);
   await click(p,button(p,'Back'));await ready(p);assert(await storage(p,devKey));
   await p.reload();await ready(p);assert(await storage(p,devKey),'back must not disable developer mode');
   await click(p,button(p,/^설정(?: 설정)?$/));await click(p,button(p,'개발자 모드 종료 · 일반 사용자로 전환'));
   await p.reload();await ready(p);assert.equal(await storage(p,devKey),null);assert.equal(await storage(p,normalKey),before);
   await click(p,button(p,/^설정(?: 설정)?$/));assert.equal(await button(p,'테스트').count(),0);
   const row={width,height,textScale:scale,normalSlots,testSlots,exchangeSlots,reloadRestoresBattleAndMenu:true,reloadRestoresSupplyTab:true,backKeepsMode:true,explicitLockClearsMode:true,normalSaveUnchanged:true};
   rows.push(row);fs.writeFileSync(path.join(out,'browser-'+tag+'.json'),JSON.stringify(row,null,2));
  }catch(e){await p.screenshot({path:path.join(out,'failure-'+tag+'.png')});fs.writeFileSync(path.join(out,'failure-'+tag+'.txt'),await p.locator('body').ariaSnapshot());console.log(JSON.stringify(errors));throw e;}
  finally{await c.close();}
 }
 assert.deepEqual(errors,[]);fs.writeFileSync(path.join(out,'browser-summary.json'),JSON.stringify({version:'v10.0.14',rows,errors},null,2));console.log(JSON.stringify({passed:rows.length,errors}));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
