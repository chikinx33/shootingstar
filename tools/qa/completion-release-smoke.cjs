const {chromium}=require('playwright'),fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const version=process.env.QA_VERSION||'10.0.32',out=path.join(__dirname,'evidence','completion-v30');
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'}),errors=[];
 try{
  const c=await browser.newContext({viewport:{width:320,height:568},isMobile:true,hasTouch:true});await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated final verification"}'}));
  const p=await c.newPage();p.setDefaultTimeout(12000);p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
  const button=n=>p.getByRole('button',{name:new RegExp('^(?:선택 중 · )?'+n+'(?:$|[\\n ·])')}).last();
  const click=async n=>{const b=await reveal(p,button(n));await p.mouse.click(b.x+b.width/2,b.y+b.height/2);await p.waitForTimeout(200);};
  await p.goto('http://127.0.0.1:8797/?v='+version);
  for(let i=0;i<120;i++){const a=p.locator('flt-semantics-placeholder');if(await a.count())await a.evaluate(e=>e.click());if(await button('설정').count()&&await p.getByText('v'+version,{exact:true}).count())break;await p.waitForTimeout(100);}
  await p.getByText('v'+version,{exact:true}).waitFor();await click('설정');await button('조작').waitFor();await p.waitForLoadState('networkidle');await p.screenshot({path:path.join(out,'release-settings-320.png')});
  await click('조작');await p.getByText('조작·음향',{exact:true}).waitFor();await p.screenshot({path:path.join(out,'release-controls-320.png')});await click('짧게 움직이기');await click('왼쪽');
  const state=await p.evaluate(()=>{let v=JSON.parse(localStorage.getItem('flutter.shootingstar.profile.v1'));return typeof v==='string'?JSON.parse(v):v;});assert.equal(state.controls.sensitivity,2);assert.equal(state.controls.leftActions,true);assert.equal(state.credits,150);assert.deepEqual(errors,[]);
  fs.writeFileSync(path.join(out,'release-smoke.json'),JSON.stringify({version:'v'+version,productionEntrypoint:true,compiledVersionVisible:true,settingsToControls:true,controlsPersist:true,baseProgressUnchanged:true,apiIntercepted:true,errors},null,2));
 }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exit(1);});
