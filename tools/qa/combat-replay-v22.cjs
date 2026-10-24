const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','combat-replay-v22');fs.mkdirSync(out,{recursive:true});
const button=(p,n)=>p.getByRole('button',{name:typeof n==='string'?new RegExp('^'+n+'(?: '+n+')?$'):n}).last();
async function ready(p,n){for(let i=0;i<160;i++){const a=p.locator('flt-semantics-placeholder');if(await a.count())await a.evaluate(e=>e.click());if(await button(p,n).count()){await p.waitForTimeout(250);return;}await p.waitForTimeout(100);}throw Error('not ready '+n);}
async function click(p,n,list=false){const l=button(p,n);let b;if(list)b=await reveal(p,l);else{await l.waitFor();b=await l.boundingBox();if(!b||b.y<0||b.y+b.height>p.viewportSize().height+.5)b=await reveal(p,l);}await p.mouse.click(b.x+b.width/2,b.y+b.height/2);}
async function state(p){const l=p.locator('[aria-label^="QA_STATE "]').last();const text=await l.count()?await l.getAttribute('aria-label'):await p.getByText(/^QA_STATE /).last().textContent();return JSON.parse(text.slice(9));}
async function waitState(p,check){for(let i=0;i<100;i++){const s=await state(p);if(check(s))return s;await p.waitForTimeout(40);}throw Error('Replay condition missing: '+JSON.stringify(await state(p)));}
(async()=>{const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'}),rows=[],errors=[];
try{for(const [width,height]of [[320,568],[360,640],[390,844],[430,932]])for(const scale of[1,1.3]){
 const tag=width+'-'+scale;if(process.env.QA_ONLY&&tag!==process.env.QA_ONLY)continue;
 if(process.env.QA_RESUME&&fs.existsSync(path.join(out,'row-'+tag+'.json'))){rows.push(JSON.parse(fs.readFileSync(path.join(out,'row-'+tag+'.json'),'utf8')));continue;}
 console.log('start '+tag);const c=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
 await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{}'}));
 const p=await c.newPage();p.setDefaultTimeout(8000);p.on('pageerror',e=>errors.push({tag,error:e.message}));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by|Bad state:|No element/.test(m.text()))errors.push({tag,error:m.text()});});
 const row={width,height,textScale:scale,replays:[]};
 try{
  await p.goto('http://127.0.0.1:8799/?textScale='+scale);await ready(p,'연출 바로 재현');await click(p,'연출 바로 재현');await p.waitForTimeout(250);
  await p.mouse.move(width/2,height-20);await p.waitForTimeout(180);await p.screenshot({path:path.join(out,'launcher-'+tag+'.png')});
  for(const [kind,label,check]of [
    ['damage','피격',s=>s.hit],['evolution','스킬 진화',s=>s.evolution],
    ['ultimate','궁극기',s=>s.ultimate],['shieldCounter','방패 역습',s=>s.block&&s.counter]]){
    await click(p,new RegExp('^'+label+' 바로 재현'),true);
    await button(p,'테스트로 돌아가기').waitFor();
    const s=await waitState(p,check);await p.screenshot({path:path.join(out,kind+'-'+tag+'.png')});
    assert(!s.paused);if(kind==='damage')assert(s.hp<s.maxHp&&s.hp>0);
    if(kind==='evolution')assert(s.evolved.includes('missile'));
    if(kind==='ultimate'){assert(s.ultimateRemaining>0);await p.waitForTimeout(350);await p.screenshot({path:path.join(out,'ultimate-beam-'+tag+'.png')});}
    if(kind==='shieldCounter'){await p.waitForTimeout(180);await p.screenshot({path:path.join(out,'shield-counter-volley-'+tag+'.png')});}
    if(kind==='damage'){
      await click(p,'다시 재현');await waitState(p,s=>s.active&&!s.hit);
      await waitState(p,check);row.restart=true;
    }
    row.replays.push({kind,state:s});
    await click(p,'테스트로 돌아가기');await button(p,/^자석 흡수 바로 재현/).waitFor();
  }
  rows.push(row);fs.writeFileSync(path.join(out,'row-'+tag+'.json'),JSON.stringify(row,null,2));console.log('passed '+tag);
 }catch(e){await p.screenshot({path:path.join(out,'failure-'+tag+'.png')});fs.writeFileSync(path.join(out,'failure-'+tag+'.txt'),await p.locator('body').ariaSnapshot());throw e;}finally{await c.close();}
}assert.deepEqual(errors,[]);fs.writeFileSync(path.join(out,'summary'+(process.env.QA_ONLY?'-'+process.env.QA_ONLY:'')+'.json'),JSON.stringify({version:'v10.0.22',rows,errors},null,2));console.log('passed '+rows.length+' conditions');
}finally{await browser.close();}})().catch(e=>{console.error(e);process.exit(1);});
