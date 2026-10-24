const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','compact-v17');fs.mkdirSync(out,{recursive:true});
const key='flutter.shootingstar.profile.v1';
const button=(p,name)=>p.getByRole('button',typeof name==='string'?{name:new RegExp('^'+name.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')+'(?: '+name.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')+')?$')}:{name}).last();
async function ready(p){for(let i=0;i<150;i++){
 const a=p.locator('flt-semantics-placeholder');if(await a.count())await a.evaluate(e=>e.click());
 if(await button(p,/^설정(?: 설정)?$/).count()||await button(p,'일시정지').count())break;
 await p.waitForTimeout(100);
}await p.waitForLoadState('networkidle');if(!await button(p,/^설정(?: 설정)?$/).count())throw Error('Flutter startup did not finish');}
async function click(p,l,min=20){const b=await reveal(p,l,min);await p.mouse.click(b.x+b.width/2,b.y+b.height/2);await p.waitForTimeout(220);return b;}
async function chip(p,n){await click(p,p.getByRole('checkbox',{name:n,exact:true}).last());}
async function raw(p){return p.evaluate(k=>localStorage.getItem(k),key);}
async function saved(p){let s=await raw(p);for(let i=0;i<3&&typeof s==='string';i++)s=JSON.parse(s);return s;}
async function shot(p,n){await p.screenshot({path:path.join(out,n+'.png')});}
async function fixed(p,l){const before=await l.boundingBox();await p.mouse.move(before.x+before.width/2,before.y+10);await p.mouse.wheel(0,400);await p.waitForTimeout(100);assert.deepEqual(await l.boundingBox(),before);
 const cdp=await p.context().newCDPSession(p),x=before.x+before.width/2,y=before.y+before.height/2;
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y}]});await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x,y:y-50}]});await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await cdp.detach();await p.waitForTimeout(100);assert.deepEqual(await l.boundingBox(),before);}
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'}),rows=[],errors=[];
 try{for(const [width,height] of [[320,568],[360,640],[390,844],[430,932]])for(const scale of [1,1.3]){
 const tag=width+'-'+scale;if(process.env.QA_ONLY&&tag!==process.env.QA_ONLY)continue;if(process.env.QA_SKIP&&process.env.QA_SKIP.split(',').includes(tag))continue;console.log(tag);
 const c=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
 await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated QA"}'}));
 const p=await c.newPage();p.setDefaultTimeout(6000);p.on('pageerror',e=>errors.push({tag,error:e.message,stack:e.stack}));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push({tag,error:m.text()});});
 const base=scale===1?'http://127.0.0.1:8797/':'http://127.0.0.1:8799/';
 try{
 await p.goto(base+'?ui=v10.0.17&textScale='+scale);await ready(p);assert(await p.getByText('v10.0.17',{exact:true}).count());
 await shot(p,'lobby-'+tag);await click(p,button(p,/^설정(?: 설정)?$/));await click(p,p.getByRole('switch',{name:'음악·효과음',exact:true}));await click(p,button(p,'닫기'));await click(p,button(p,'보급'));
 let s=await saved(p);assert(s);s.onboarded=true;s.soundEnabled=false;s.credits=7000;s.blueprints=100;s.content.petLevels=[3,0,0];s.content.petRanks=[1,0,0];s.content.petFood=500;
 const originalIds=s.content.inventory.map(g=>g.id);
 for(const id of [10,11,12])s.content.inventory.push({id,spec:3,rank:0,level:0,locked:false,spentCredits:0,spentPlans:0});
 await p.evaluate(({key,s})=>localStorage.setItem(key,JSON.stringify(JSON.stringify(s))),{key,s});await p.reload();await ready(p);
 await click(p,button(p,'성장')); const beforeBrowse=await raw(p);
 await chip(p,'펫');await click(p,button(p,/^루미 · 돌격형 /));await shot(p,'pet-'+tag);
 for(let i=0;i<8;i++){const n=button(p,/^다음 페이지/);if(!await n.count()||!await n.isEnabled())break;await click(p,n);}await shot(p,'pet-last-'+tag);await click(p,button(p,'닫기'));
 await chip(p,'테크');await click(p,button(p,/^관통 증폭기 /));await shot(p,'tech-'+tag);assert.equal(await button(p,'부품 장착').count(),0);await click(p,button(p,'닫기'));
 await chip(p,'장비');await chip(p,'관리');await click(p,button(p,/^수집품 \d+\/12$/));await chip(p,'보관함');
 await click(p,button(p,/^초신성 프리즘 Lv/));await click(p,button(p,'초신성 프리즘 상세'));await shot(p,'relic-'+tag);assert.equal(await button(p,'조각 분해 · 1개 → 가루 1').count(),0);assert.equal(await button(p,'강화 초기화 · 조각 반환').count(),0);await click(p,button(p,'유물 상세 닫기'));await click(p,button(p,'닫기'));await click(p,button(p,'Back'));
 await click(p,button(p,'출격'));await click(p,button(p,'보급'));await click(p,button(p,'장비 보급 상세'));await shot(p,'supply-'+tag);await click(p,button(p,'닫기'));
 assert.equal(await raw(p),beforeBrowse,'read-only browsing changed normal save');
 await p.reload();await ready(p);assert.equal(await raw(p),beforeBrowse,'reload changed normal save');
 const row={width,height,scale,petTechRelic:true,normalSavePreserved:true};
 rows.push(row);fs.writeFileSync(path.join(out,'secondary-row-'+tag+'.json'),JSON.stringify(row,null,2));
 }catch(e){await shot(p,'failure-'+tag);fs.writeFileSync(path.join(out,'failure-'+tag+'.txt'),await p.locator('body').ariaSnapshot());console.log(errors);throw e;}finally{await c.close();}
 }
 assert.deepEqual(errors,[]);fs.writeFileSync(path.join(out,'secondary-run'+(process.env.QA_ONLY?'-'+process.env.QA_ONLY:'')+'.json'),JSON.stringify({version:'v10.0.17',rows,errors},null,2));console.log('passed',rows.length);
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
