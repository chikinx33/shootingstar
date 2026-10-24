const {chromium}=require('playwright'),fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const version=process.env.QA_VERSION||'v10.0.26';
const out=path.join(__dirname,'evidence',version==='v10.0.26'?'completion-v26':'performance-'+version);fs.mkdirSync(out,{recursive:true});
const button=(p,n)=>p.getByRole('button',{name:n,exact:true}).last();
async function ready(p,n){for(let i=0;i<240;i++){const a=p.locator('flt-semantics-placeholder');if(await a.count())await a.evaluate(e=>e.click());if(n==='__account'?await p.getByText('온라인 계정 · 영구 진행 동기화',{exact:true}).count():n==='__guest'?await p.getByText('게스트 · 기기에 저장',{exact:true}).count():await button(p,n).count())return;await p.waitForTimeout(100);}throw Error('not ready '+n);}
async function click(p,n){const b=await reveal(p,button(p,n));await p.mouse.click(b.x+b.width/2,b.y+b.height/2);await p.waitForTimeout(250);}
async function field(p,name,value){const l=p.getByRole('textbox',{name,exact:true});const b=await reveal(p,l);await p.mouse.click(b.x+b.width/2,b.y+b.height/2);await p.keyboard.type(value);await p.keyboard.press('Tab');await p.waitForTimeout(150);}
async function fixed(p){assert.equal(await p.evaluate(()=>document.documentElement.scrollHeight>innerHeight),false);}
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'}),errors=[],matrix=[],calls=[],tokens=[];
 try{
  if(!process.env.STRESS_ONLY) {
   if(process.env.RESUME_UI&&fs.existsSync(path.join(out,'failure.json')))matrix.push(...JSON.parse(fs.readFileSync(path.join(out,'failure.json'))).matrix);
   for(const width of [320,360,390,430])for(const scale of [1,1.3]){
    if(matrix.some(r=>r.width===width&&r.scale===scale))continue;
    const user='q26_'+width+'_'+String(scale).replace('.','')+'_'+Date.now().toString(36).slice(-5);
    const c=await browser.newContext({viewport:{width,height:568},isMobile:true,hasTouch:true,permissions:['clipboard-read','clipboard-write']});
    await c.route('**/api/**',async r=>{
     const req=r.request(),url=new URL(req.url());assert.equal(url.hostname,'127.0.0.1');
     const response=await r.fetch({url:'http://127.0.0.1:8826'+url.pathname,headers:{...req.headers(),'x-client':'native'}});
     const body=await response.json();if(body.token)tokens.push(body.token);
     calls.push({path:url.pathname,status:response.status()});await r.fulfill({response});
    });
    const p=await c.newPage();p.setDefaultTimeout(12000);p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
    await p.goto(process.env.QA_URL+'/?user='+user+'&textScale='+scale);await ready(p,'__account');
    await click(p,'계정 영구 삭제');await reveal(p,button(p,'계정과 저장 영구 삭제'));assert.equal(await button(p,'계정과 저장 영구 삭제').isEnabled(),false);
    await p.screenshot({path:path.join(out,`delete-${width}-${scale}.png`)});await fixed(p);
    if(width===320&&scale===1.3){
     await field(p,'아이디 다시 입력',user);await field(p,'현재 비밀번호','qa-v26-password-only');
     await click(p,'계정과 저장 영구 삭제');await ready(p,'__guest');
     assert(await p.getByText('게스트 · 기기에 저장',{exact:true}).count()||await p.getByText('계정 삭제 완료 · 게스트로 시작',{exact:true}).count());
     const stored=await p.evaluate(()=>Object.fromEntries(Object.entries(localStorage).filter(([k])=>k.includes('shootingstar.profile'))));
     assert(!JSON.stringify(stored).includes('"_battle"'));assert(!JSON.stringify(stored).includes(user));
     await p.screenshot({path:path.join(out,'deleted-guest.png')});
    }else await click(p,'삭제 취소');
    await click(p,'저장·복구 도움말');await reveal(p,button(p,'진단 정보 복사'));await fixed(p);
    await click(p,'진단 정보 복사');const diagnostic=JSON.parse(await p.evaluate(()=>navigator.clipboard.readText()));
    assert.equal(diagnostic.version,version);for(const key of ['username','password','token','inventory','recoveryCode'])assert(!(key in diagnostic));
    await p.screenshot({path:path.join(out,`storage-${width}-${scale}.png`)});
    matrix.push({width,scale,deleteConfirmation:true,realServerDeletion:width===320&&scale===1.3,help:true,clipboard:true});console.log('matrix',width,scale);await c.close();
   }
   const c=await browser.newContext({viewport:{width:320,height:568},isMobile:true,hasTouch:true}),p=await c.newPage();
   await p.goto(process.env.QA_URL+'/?mode=world&textScale=1.3');await ready(p,'선택 완료');
   await p.waitForLoadState('networkidle');await p.screenshot({path:path.join(out,'world-badges.png')});await c.close();
   assert.deepEqual(errors,[]);assert(calls.some(c=>c.path==='/api/auth/delete'&&c.status===200));
   fs.writeFileSync(path.join(out,'summary.json'),JSON.stringify({version,matrix,calls,errors},null,2));
  }
  if(!process.env.UI_ONLY){
   const rows=[];
   for(const cpuRate of process.env.REDUCED_ONLY?[4]:[1,4]){
    const c=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
    await c.route('**/api/**',r=>r.abort());const p=await c.newPage();const session=await c.newCDPSession(p);await session.send('Emulation.setCPUThrottlingRate',{rate:cpuRate});
    p.on('pageerror',e=>errors.push(e.message));await p.goto(process.env.QA_URL+'/?mode=stress'+(process.env.REDUCED_ONLY?'&reduced=true':''));await ready(p,'일시정지');
    await p.waitForTimeout(3000);await p.evaluate(()=>{window.qaFrames=[];window.qaLast=performance.now();function tick(t){window.qaFrames.push(t-window.qaLast);window.qaLast=t;window.qaRaf=requestAnimationFrame(tick);}window.qaRaf=requestAnimationFrame(tick);});
    const samples=[],started=Date.now();
    for(let i=0;i<24;i++){
     const node=p.locator('[aria-label^="QA_STATE "]').last();const label=await node.count()?await node.getAttribute('aria-label'):await p.getByText(/^QA_STATE /).last().textContent();const state=JSON.parse(label.slice(9));samples.push(state);
     assert(state.checkpointBytes<2*1024*1024);assert(state.enemies<=260);assert(state.shots<2500);assert(!state.paused);if(state.finished)break;
     if(i%6===5)console.log('stress sample',cpuRate,i,state.elapsed,state.enemies,state.shots);await p.waitForTimeout(5000);
    }
    const metrics=await p.evaluate(()=>{cancelAnimationFrame(window.qaRaf);const a=window.qaFrames.slice(1).sort((a,b)=>a-b),q=n=>a[Math.floor((a.length-1)*n)]??0;return {frames:a.length,p50:q(.5),p95:q(.95),p99:q(.99),max:a.at(-1),heapBytes:performance.memory?.usedJSHeapSize};});
    const before=await p.evaluate(()=>localStorage.getItem('flutter.shootingstar.profile.v1'));assert.equal(before,null,'stress fixture must not save the normal profile');
    await p.screenshot({path:path.join(out,`stress-cpu${cpuRate}${process.env.REDUCED_ONLY?'-reduced':''}.png`)});rows.push({cpuRate,realSeconds:(Date.now()-started)/1000,metrics,samples});console.log('stress',cpuRate,JSON.stringify(metrics));await c.close();
   }
   assert.deepEqual(errors,[]);fs.writeFileSync(path.join(out,process.env.REDUCED_ONLY?'performance-reduced.json':'performance.json'),JSON.stringify({version,reducedEffects:!!process.env.REDUCED_ONLY,scope:'Desktop headless Chrome, synthetic dense encounter; CPU throttle is not physical mobile proof',rows,errors},null,2));
  }
 }catch(e){fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:e.message,matrix,calls,errors},null,2));throw e;}
 finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
