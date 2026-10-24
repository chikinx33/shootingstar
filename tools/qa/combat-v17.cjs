const {chromium}=require('playwright');const fs=require('fs'),path=require('path'),assert=require('assert');
const out=path.join(__dirname,'evidence','combat-v17');fs.mkdirSync(out,{recursive:true});
const {reveal}=require('./web-ui-navigation.cjs');
async function ready(p){for(let i=0;i<150;i++){const a=p.locator('flt-semantics-placeholder');if(await a.count())await a.evaluate(e=>e.click());if(await p.getByRole('button',{name:'일시정지',exact:true}).count())return;await p.waitForTimeout(100);}throw Error('battle not ready');}
async function click(p,name){const l=p.getByRole('button',{name,exact:true}).last(),b=await reveal(p,l);await p.mouse.click(b.x+b.width/2,b.y+b.height/2);}
(async()=>{const b=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'}),rows=[],errors=[];
try{for(const item of [
 ['pulse','weapons','pulse'],['rail','weapons','revolver'],['shotgun','weapons','shotgun'],
 ['stress','stress','pulse'],
 ['skills','skills','pulse'],['evolution','evolution','pulse'],
 ['shield','shield','pulse'],['assault','assault','pulse'],
 ['boss-0','boss','pulse'],['boss-2','boss','pulse',20,2],['boss-7','boss','pulse',70,1],
 ['heal','heal','pulse'],['magnet','magnet','pulse'],
]){
 const [tag,scene,weapon,world=0,phase=0]=item;if(process.env.QA_ONLY&&tag!==process.env.QA_ONLY)continue;console.log(tag);
 const c=await b.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
 await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{}'}));
 const p=await c.newPage();p.on('pageerror',e=>errors.push({tag,error:e.message}));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by|Bad state:|No element|Unhandled exception/.test(m.text()))errors.push({tag,error:m.text()});});
 try{
 await p.goto((process.env.QA_BATTLE_URL||'http://127.0.0.1:8799/')+'?textScale=1&scene='+scene+'&weapon='+weapon+'&world='+world+'&phase='+phase);await ready(p);await p.waitForTimeout(850);
 await p.screenshot({path:path.join(out,tag+'-a.png')});
 if(tag==='pulse'){await click(p,'궁극기 항성포 발사');await p.waitForTimeout(200);await p.screenshot({path:path.join(out,'ultimate.png')});}
 const timing=await p.evaluate(()=>new Promise(resolve=>{const samples=[];let prev=performance.now();function frame(t){samples.push(t-prev);prev=t;if(samples.length>=90)resolve(samples);else requestAnimationFrame(frame);}requestAnimationFrame(frame);}));
 await p.screenshot({path:path.join(out,tag+'-b.png')});
 let pausedResumed=false,finished=false;
 if(await p.getByRole('button',{name:'일시정지',exact:true}).isEnabled()){await click(p,'일시정지');await p.getByRole('button',{name:'계속 비행',exact:true}).waitFor();await click(p,'계속 비행');pausedResumed=true;}else {assert(await p.getByRole('button',{name:'성장 정비 · 귀환',exact:true}).count());finished=true;}
 const avg=timing.reduce((a,b)=>a+b,0)/timing.length;timing.sort((a,b)=>a-b);
 rows.push({tag,scene,weapon,world,phase,browserRafFps:1000/avg,p95Ms:timing[Math.floor(timing.length*.95)],pausedResumed,finished});
 }catch(e){await p.screenshot({path:path.join(out,'failure-'+tag+'.png')});fs.writeFileSync(path.join(out,'failure-'+tag+'.txt'),await p.locator('body').ariaSnapshot());throw e;}finally{await c.close();}
}
assert.deepEqual(errors,[]);fs.writeFileSync(path.join(out,(process.env.QA_ONLY?'summary-'+process.env.QA_ONLY+'.json':'summary.json')),JSON.stringify({version:'v10.0.17',rows,errors,note:'Isolated fixture uses the real GameEngine/BattleScreen; browser RAF timing is not a mobile hardware FPS guarantee.'},null,2));console.log('passed',rows.length);
}finally{await b.close();}})().catch(e=>{console.error(e);process.exit(1);});
