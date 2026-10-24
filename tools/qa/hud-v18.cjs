const {chromium}=require('playwright');const fs=require('fs'),path=require('path'),assert=require('assert');
const out=path.join(__dirname,'evidence','hud-v18');fs.mkdirSync(out,{recursive:true});
const btn=(p,n)=>p.getByRole('button',{name:typeof n==='string'?new RegExp('^'+n+'(?: '+n+')?$'):n}).last();
async function ready(p){for(let i=0;i<160;i++){const a=p.locator('flt-semantics-placeholder');if(await a.count())await a.evaluate(e=>e.click());if(await btn(p,'일시정지').count()){await p.waitForTimeout(550);return;}await p.waitForTimeout(100);}throw Error('battle not ready');}
async function click(p,n){const l=btn(p,n),b=await l.boundingBox();assert(b&&b.y>=0&&b.y+b.height<=p.viewportSize().height+.5,'unreachable '+n);await p.mouse.click(b.x+b.width/2,b.y+b.height/2);await p.waitForTimeout(180);}
async function region(p,n){let l=p.locator('[aria-label="'+n+'"]').last();if(!await l.count())l=p.getByRole('group',{name:n,exact:true}).last();if(!await l.count())l=p.getByText(n,{exact:true}).last();return l;}
(async()=>{const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'}),rows=[],errors=[];
try{for(const [width,height] of [[320,568],[360,640],[390,844],[430,932]])for(const scale of [1,1.3]){
const tag=width+'-'+scale;if(process.env.QA_ONLY&&tag!==process.env.QA_ONLY)continue;console.log(tag);
const c=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{}'}));
const p=await c.newPage();p.setDefaultTimeout(7000);p.on('pageerror',e=>errors.push({tag,error:e.message,stack:e.stack}));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by|Bad state:|No element/.test(m.text()))errors.push({tag,error:m.text()});});
try{
 await p.goto('http://127.0.0.1:8799/?scene=hud&world=99&textScale='+scale);await ready(p);await p.waitForTimeout(250);
 const hud=await (await region(p,'전투 HUD')).boundingBox(),field=await (await region(p,'전투 영역')).boundingBox();
 assert(hud&&field);assert(hud.height<=(scale===1?190:215),'HUD too tall '+JSON.stringify(hud));assert(field.y>=hud.y+hud.height-.5);assert(field.height>height*.5,'playfield should exceed half the screen');
 assert((await btn(p,'일시정지').boundingBox()).height>=48);assert((await btn(p,'전투 정보').boundingBox()).height>=48);
 await p.screenshot({path:path.join(out,'battle-'+tag+'.png')});
 await click(p,'전투 정보');assert(await p.getByRole('heading',{name:'전투 정보',exact:true}).count());
 const times=await p.getByText(/\d\d:\d\d \/ \d\d:\d\d/).allTextContents();await p.waitForTimeout(400);assert.deepEqual(await p.getByText(/\d\d:\d\d \/ \d\d:\d\d/).allTextContents(),times);
 await p.screenshot({path:path.join(out,'info-'+tag+'.png')});await click(p,'전투 정보 닫기');
 await click(p,'일시정지');await btn(p,'계속 비행').waitFor();await click(p,'계속 비행');
 const cdp=await c.newCDPSession(p),x=width/2,y=field.y+field.height*.7;
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y}]});await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:x+30,y:y-30}]});await p.waitForTimeout(200);await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await cdp.detach();
 // The boss warning and health bar must stay above the real, resized field.
 await p.goto('http://127.0.0.1:8799/?scene=boss&world=99&phase=1&textScale='+scale);await ready(p);await p.waitForTimeout(200);
 const bossHud=await (await region(p,'전투 HUD')).boundingBox(),bossField=await (await region(p,'전투 영역')).boundingBox();assert(bossField.y>=bossHud.y+bossHud.height-.5);assert(bossField.height>height*.45);
 await p.screenshot({path:path.join(out,'boss-'+tag+'.png')});
 const row={width,height,textScale:scale,hud,field,bossHud,bossField,detailsPauseResume:true,pauseAndTouch:true};rows.push(row);fs.writeFileSync(path.join(out,'row-'+tag+'.json'),JSON.stringify(row,null,2));
}catch(e){await p.screenshot({path:path.join(out,'failure-'+tag+'.png')});fs.writeFileSync(path.join(out,'failure-'+tag+'.txt'),await p.locator('body').ariaSnapshot());throw e;}finally{await c.close();}
}assert.deepEqual(errors,[]);fs.writeFileSync(path.join(out,'summary'+(process.env.QA_ONLY?'-'+process.env.QA_ONLY:'')+'.json'),JSON.stringify({version:'v10.0.18',rows,errors},null,2));console.log('passed',rows.length);
}finally{await browser.close();}})().catch(e=>{console.error(e);process.exit(1);});
