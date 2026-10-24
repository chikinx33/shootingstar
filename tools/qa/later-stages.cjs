// Continue the real save produced by full-flow.cjs; do not grant test-only upgrades.
const {chromium}=require('playwright');const fs=require('fs');const path=require('path');const assert=require('assert');
const out=path.join(__dirname,'evidence');
(async()=>{
const prior=JSON.parse(fs.readFileSync(path.join(out,'result.json'),'utf8'));
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
const page=await browser.newPage({viewport:{width:1100,height:860}});const errors=[];
page.on('pageerror',e=>errors.push(e.message));await page.route('https://**',r=>r.abort());
await page.addInitScript(value=>{if(location.hostname==='127.0.0.1'&&!localStorage.getItem('flutter.shootingstar.profile.v1'))localStorage.setItem('flutter.shootingstar.profile.v1',value);},JSON.stringify(prior.profile));
await page.clock.install();await page.goto('http://127.0.0.1:8787');await page.waitForTimeout(4500);await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());await page.waitForTimeout(250);await page.clock.pauseAt(new Date());
const results=[];const directions=['a','w','d','d','s','s','a','a','w','w','d','s'];
for(const [index,name] of [[1,'적색 성운'],[2,'공허의 왕관']]){
  if(await page.getByRole('tab',{name:'출격',exact:true}).count())await page.getByRole('tab',{name:'출격',exact:true}).click();
  await page.clock.runFor(200);await page.getByRole('button',{name:new RegExp('^'+name+' 항로 선택')}).click();await page.clock.runFor(200);
  await page.getByRole('button',{name:name+' · 출격',exact:true}).click();await page.clock.runFor(500);
  let choices=0,result='';
  for(let i=0;i<330;i++){
    const snap=await page.locator('body').ariaSnapshot();
    if(snap.includes('집을 지켜 냈다냥!')||snap.includes('다음엔 꼭 이긴다냥')){result=snap;break;}
    if(snap.includes('진화의 갈림길')){await page.getByRole('button').filter({hasNotText:'일시정지'}).first().click();await page.clock.runFor(100);choices++;}
    await page.keyboard.down(directions[i%directions.length]);await page.clock.runFor(1000);await page.keyboard.up(directions[i%directions.length]);
    if(i===30)await page.screenshot({path:path.join(out,`stage-${index+1}-combat.png`)});
    if(i%50===0)console.log(name,'step',i);
  }
  console.log('STAGE_RESULT',name,result);assert(result.includes('집을 지켜 냈다냥!'),name+' should be beatable with normal input');
  await page.screenshot({path:path.join(out,`stage-${index+1}-victory.png`)});results.push({name,choices,result});
  await page.getByRole('button',{name:'격납고로 귀환',exact:true}).click();await page.clock.runFor(500);
}
assert.deepEqual(errors,[]);console.log('PASS both later stages through UI');
fs.writeFileSync(path.join(out,'later-stages.json'),JSON.stringify({results,errors,saved:await page.evaluate(()=>localStorage.getItem('flutter.shootingstar.profile.v1'))},null,2));await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
