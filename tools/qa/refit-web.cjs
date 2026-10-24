const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','refit-v16');fs.mkdirSync(out,{recursive:true});
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
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'}),rows=[],errors=[],assets=new Set();
 async function shot(p,name){await p.screenshot({path:path.join(out,name+'.png')});}
 try{for(const [width,height] of [[320,568],[360,640],[390,844],[430,932]])for(const scale of [1,1.3]){
  const tag=width+'-'+scale;if(process.env.QA_ONLY&&tag!==process.env.QA_ONLY)continue;
  if(process.env.QA_SKIP&&process.env.QA_SKIP.split(',').includes(tag))continue;
  console.log('Refit v16',tag);
  const c=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
  await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated refit QA"}'}));
  const p=await c.newPage();p.setDefaultTimeout(10000);
  p.on('pageerror',e=>errors.push({tag,error:e.message}));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push({tag,error:m.text()});});
  p.on('response',r=>{if(r.url().includes('/refit_v16/')&&r.url().endsWith('.png'))assets.add(r.url().split('/').pop());if(r.url().includes('/assets/')&&r.status()>=400)errors.push({tag,error:'asset '+r.status()+' '+r.url()});});
  try{
   await p.goto(scale===1?'http://127.0.0.1:8797/?ui=v10.0.16':'http://127.0.0.1:8799/?textScale=1.3');await ready(p);
   assert(await p.getByText('v10.0.16',{exact:true}).count());
   // Establish normal preferences and shop clocks through the actual UI.
   await click(p,button(p,'보급'));await click(p,button(p,'출격'));
   await click(p,button(p,/^설정(?: 설정)?$/));await click(p,p.getByRole('switch',{name:'음악·효과음',exact:true}));await click(p,button(p,'닫기'));
   const before=await storage(p,normalKey);assert(before);
   const launch=button(p,/ · 출격$/),craft=button(p,/ · 기체 선택$/);
   const controls=[launch,button(p,'45초 훈련'),button(p,'비행 가이드'),button(p,'임무·출석'),button(p,'시즌 보상'),button(p,'순찰'),button(p,'길드'),button(p,'챕터 선택')];
   const boxes=await Promise.all(controls.map(l=>l.boundingBox()));
   for(let i=0;i<boxes.length;i++){const b=boxes[i];assert(b&&b.x>=0&&b.y>=0&&b.x+b.width<=width+.5&&b.y+b.height<=height+.5);
    assert(b.height>=48-.5);for(let j=0;j<i;j++){const a=boxes[j];assert(b.x>=a.x+a.width-.5||a.x>=b.x+b.width-.5||b.y>=a.y+a.height-.5||a.y>=b.y+b.height-.5,'overlapping controls');}}
   const hero=await craft.boundingBox();assert(hero.height>=80&&hero.width<=248.5,'hero should be readable and bounded');
   assert.equal(await p.locator('flt-semantics-scroll-overflow').count(),0);await fixed(p,launch);
   await shot(p,'lobby-'+tag);
   await click(p,craft);const ships=p.getByRole('button',{name:/^(오로라|벡터|모노리스) /});
   assert.equal(await ships.count(),3);const shipNames=await ships.allTextContents();const shipSlots=await three(p,shipNames);
   await shot(p,'fleet-'+tag);await click(p,button(p,'Back'));
   await click(p,button(p,'보급'));const supplySlots=await three(p,['장비 보급 상세','테크 보급 상세','펫 구조 상세']);if(tag==='390-1'||tag==='320-1.3')await shot(p,'supply-'+tag);
   await click(p,button(p,'장비 보급 상세'));if(tag==='390-1'||tag==='320-1.3')await shot(p,'supply-detail-'+tag);await click(p,button(p,'닫기'));
   await click(p,button(p,'출격'));await click(p,button(p,'진화'));if(tag==='390-1')await shot(p,'research-'+tag);await click(p,button(p,'출격'));
   assert.equal(await storage(p,normalKey),before,'visual navigation changed normal save');
   await p.reload();await ready(p);assert.equal(await storage(p,normalKey),before);
   let battle=false;
   if(tag==='390-1'){
     await click(p,button(p,/ · 출격$/),72);
     await click(p,button(p,'비행 준비 완료'),72);
     await button(p,'일시정지').waitFor();await p.waitForTimeout(1000);
     await shot(p,'actual-battle-390');await click(p,button(p,'일시정지'));
     await click(p,button(p,'계속 비행'),72);
     await p.touchscreen.tap(width*.55,height*.7);await p.waitForTimeout(300);
     await click(p,button(p,'일시정지'));await shot(p,'pause-390');
     await p.reload();await ready(p);battle=true;
   }
   const row={width,height,textScale:scale,controls:boxes,hero,shipSlots,supplySlots,normalSaveUnchanged:true,reloadPreserved:true,wheelAndTouchFixed:true,actualBattle:battle};
   rows.push(row);fs.writeFileSync(path.join(out,'browser-'+tag+'.json'),JSON.stringify(row,null,2));
  }catch(e){await shot(p,'failure-'+tag);fs.writeFileSync(path.join(out,'failure-'+tag+'.txt'),await p.locator('body').ariaSnapshot());console.log(JSON.stringify(errors));throw e;}
  finally{await c.close();}
 }
 assert.deepEqual(errors,[]);assert.equal(assets.size,8,'new PNG assets must be loaded');
 fs.writeFileSync(path.join(out,'run'+(process.env.QA_ONLY?'-'+process.env.QA_ONLY:'')+'.json'),JSON.stringify({version:'v10.0.16',rows,errors,newAssets:[...assets]},null,2));console.log(JSON.stringify({passed:rows.length,errors,newAssets:assets.size}));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
