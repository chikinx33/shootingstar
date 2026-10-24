const {chromium}=require('playwright');const fs=require('fs');const path=require('path');const assert=require('assert');
(async()=>{
const prior=JSON.parse(fs.readFileSync(path.join(__dirname,'evidence/result.json'),'utf8'));
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
const page=await browser.newPage({viewport:{width:1280,height:1000}});const errors=[];page.on('pageerror',e=>errors.push(e.message));
await page.addInitScript(value=>{if(location.hostname==='127.0.0.1'&&!localStorage.getItem('flutter.shootingstar.profile.v1'))localStorage.setItem('flutter.shootingstar.profile.v1',value);},JSON.stringify(prior.profile));
await page.goto('http://127.0.0.1:8787');await page.waitForTimeout(3000);await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());await page.waitForTimeout(200);
await page.getByRole('tab',{name:'격납고',exact:true}).click();await page.waitForTimeout(250);
await page.getByRole('button',{name:'200 C · 해금',exact:true}).click();await page.waitForTimeout(250);
await page.getByText('과충전 코어').click();await page.waitForTimeout(200);
await page.mouse.move(900,770);await page.mouse.wheel(0,580);await page.waitForTimeout(300);
await page.getByRole('button',{name:'80 C',exact:true}).first().click();await page.waitForTimeout(300);
const value=await page.evaluate(()=>JSON.parse(JSON.parse(localStorage.getItem('flutter.shootingstar.profile.v1'))));
assert.equal(value.selectedShip,1);assert(value.unlockedShips.includes(1));assert.equal(value.equipment,1);assert.equal(value.attackLevel,1);assert.equal(value.credits,JSON.parse(prior.profile).credits-280);
await page.screenshot({path:path.join(__dirname,'evidence/economy.png')});
await page.reload();await page.waitForTimeout(2000);assert.deepEqual(await page.evaluate(()=>JSON.parse(JSON.parse(localStorage.getItem('flutter.shootingstar.profile.v1')))),value);
assert.deepEqual(errors,[]);console.log('PASS actual unlock, select ship, module, permanent purchase, cost deduction and reload',value);await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
