const {chromium}=require('playwright');
const fs=require('fs');
(async()=>{
const b=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
const c=await b.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.fulfill({status:401,body:'{}'}));
const p=await c.newPage();await p.goto('http://127.0.0.1:8797/?ui=menu-v8');
for(let n=0;n<160;n++){if(await p.locator('flt-semantics-placeholder').count())await p.locator('flt-semantics-placeholder').evaluate(e=>e.click());if(await p.getByRole('button',{name:'성장',exact:true}).count())break;await p.waitForTimeout(250);}
fs.mkdirSync('tools/qa/evidence/menu-v8',{recursive:true});
for(const [name,label]of [['main',null],['supply','보급'],['growth','성장']]){
if(label)await p.getByRole('button',{name:label,exact:true}).click();await p.waitForTimeout(500);
await p.screenshot({path:'tools/qa/evidence/menu-v8/probe-'+name+'.png'});
}await b.close();
})();
