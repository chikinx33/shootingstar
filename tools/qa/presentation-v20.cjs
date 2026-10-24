const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const out=path.join(__dirname,'evidence','presentation-v20');fs.mkdirSync(out,{recursive:true});
const button=(p,n)=>p.getByRole('button',{name:typeof n==='string'?new RegExp('^'+n+'(?: '+n+')?$'):n}).last();
async function click(p,n){const l=button(p,n);await l.waitFor();const b=await l.boundingBox();assert(b&&b.y>=0&&b.y+b.height<=p.viewportSize().height+.5,'unreachable '+n);await p.mouse.click(b.x+b.width/2,b.y+b.height/2);}
async function state(p){let l=p.locator('[aria-label^="QA_STATE "]').last();let s;if(await l.count())s=await l.getAttribute('aria-label');else s=await p.getByText(/^QA_STATE /).last().textContent();return JSON.parse(s.slice(s.indexOf('{')));}
async function until(p,test,timeout=9000){const started=Date.now();let last;while(Date.now()-started<timeout){try{last=await state(p);if(test(last))return last;}catch{}await p.waitForTimeout(50);}throw Error('state timeout '+JSON.stringify(last));}
async function ready(p,scene){for(let i=0;i<140;i++){const a=p.locator('flt-semantics-placeholder');if(await a.count())await a.evaluate(e=>e.click());if(await button(p,scene==='reward'?'보상 수령':'연출 시작').count()){await p.waitForTimeout(350);return;}await p.waitForTimeout(100);}throw Error('not ready '+scene);}
(async()=>{const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'}),rows=[],errors=[];
try{for(const [width,height]of [[320,568],[360,640],[390,844],[430,932]])for(const scale of[1,1.3]){
 const tag=width+'-'+scale;if(process.env.QA_ONLY&&tag!==process.env.QA_ONLY)continue;if(process.env.QA_RESUME&&fs.existsSync(path.join(out,'row-'+tag+'.json'))){rows.push(JSON.parse(fs.readFileSync(path.join(out,'row-'+tag+'.json'),'utf8')));console.log('verified earlier '+tag);continue;}console.log('start '+tag);
 const record=false; // Sequence PNGs avoid optional Playwright ffmpeg installation.
 const c=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true,...(record?{recordVideo:{dir:path.join(out,'raw-video'),size:{width,height}}}:{})});
 await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{}'}));
 const p=await c.newPage();p.setDefaultTimeout(6000);p.on('pageerror',e=>errors.push({tag,error:e.message}));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by|Bad state:|No element/.test(m.text()))errors.push({tag,error:m.text()});});
 const row={width,height,textScale:scale};
 try{
  await p.goto('http://127.0.0.1:8799/?scene=magnet&textScale='+scale);await ready(p,'magnet');await click(p,'연출 시작');
  row.magnetInFlight=await until(p,s=>s.motes>0&&s.choices===0);await p.waitForTimeout(200);await p.screenshot({path:path.join(out,'magnet-flight-'+tag+'.png')});
  row.magnetDelivered=await until(p,s=>!s.collecting&&s.choices>0);assert.equal(row.magnetDelivered.motes,0);assert.equal(row.magnetDelivered.level,2);assert.equal(row.magnetDelivered.xp,100);
  await p.waitForTimeout(350);await p.screenshot({path:path.join(out,'upgrade-slots-'+tag+'.png')});
  const choice=button(p,/^집속 펄스/);const box=await choice.boundingBox();assert(box&&box.x>=0&&box.y>=0&&box.y+box.height<=height+.5);await p.mouse.click(box.x+box.width/2,box.y+box.height/2);await p.waitForTimeout(400);assert((await state(p)).level>=3);
  await p.goto('http://127.0.0.1:8799/?scene=boss&textScale='+scale);await ready(p,'boss');await click(p,'연출 시작');
  row.shaking=await until(p,s=>s.time>=.75);assert.equal(row.shaking.finished,false);await p.screenshot({path:path.join(out,'boss-shaking-'+tag+'.png')});
  row.breakup=await until(p,s=>s.time>=2.02);assert.equal(row.breakup.finished,false);await p.screenshot({path:path.join(out,'boss-breakup-'+tag+'.png')});
  row.clear=await until(p,s=>s.time>=2.85);assert.equal(row.clear.finished,false);await p.screenshot({path:path.join(out,'boss-clear-'+tag+'.png')});
  row.departing=await until(p,s=>s.time>=4.25);assert.equal(row.departing.finished,false);await p.screenshot({path:path.join(out,'hero-departure-'+tag+'.png')});
  row.result=await until(p,s=>s.finished);assert(row.result.time>=5.35);assert(row.result.heroY<0);await p.waitForTimeout(150);await p.screenshot({path:path.join(out,'result-'+tag+'.png')});
  await p.goto('http://127.0.0.1:8799/?scene=reward&textScale='+scale);await ready(p,'reward');
  await click(p,'보상 수령');await button(p,'확인').waitFor();await p.waitForTimeout(400);await p.screenshot({path:path.join(out,'reward-reveal-'+tag+'.png')});await click(p,'확인');await p.waitForTimeout(330);await p.screenshot({path:path.join(out,'reward-transfer-'+tag+'.png')});assert(await p.getByText(/^QA_STATE /).count());
  const rewardState=JSON.parse((await p.getByText(/^QA_STATE /).textContent()).slice(9));assert.equal(rewardState.credits,1577);assert.equal(rewardState.claims,1);row.reward=rewardState;
  await p.waitForTimeout(1300);await click(p,'장비 구매');await button(p,'확인').waitFor();await p.waitForTimeout(400);await p.screenshot({path:path.join(out,'purchase-reveal-'+tag+'.png')});await click(p,'확인');await p.waitForTimeout(330);await p.screenshot({path:path.join(out,'purchase-transfer-'+tag+'.png')});
  const bought=JSON.parse((await p.getByText(/^QA_STATE /).textContent()).slice(9));assert.equal(bought.purchases,1);assert.equal(bought.inventory,rewardState.inventory+1);assert.equal(bought.keys,rewardState.keys-1);row.purchase=bought;
  rows.push(row);fs.writeFileSync(path.join(out,'row-'+tag+'.json'),JSON.stringify(row,null,2));console.log('passed '+tag);
 }catch(e){await p.screenshot({path:path.join(out,'failure-'+tag+'.png')});fs.writeFileSync(path.join(out,'failure-'+tag+'.txt'),await p.locator('body').ariaSnapshot());throw e;}
 finally{const video=p.video();await c.close();if(video)await video.saveAs(path.join(out,'sequence-'+tag+'.webm'));}
 }assert.deepEqual(errors,[]);fs.writeFileSync(path.join(out,'summary'+(process.env.QA_ONLY?'-'+process.env.QA_ONLY:'')+'.json'),JSON.stringify({version:'v10.0.20',rows,errors},null,2));console.log('passed '+rows.length+' mobile conditions');
}finally{await browser.close();}})().catch(e=>{console.error(e);process.exit(1);});
