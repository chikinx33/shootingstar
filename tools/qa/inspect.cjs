const {chromium}=require('playwright');
const path=require('path');
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const page=await browser.newPage({viewport:{width:1280,height:900},deviceScaleFactor:1});
 page.on('pageerror',e=>console.log('PAGEERROR',e.message));
 page.on('console',m=>{if(m.type()==='error')console.log('CONSOLE',m.text());});
 await page.goto('http://127.0.0.1:8787');
 await page.waitForTimeout(8000);
 await page.screenshot({path:path.join(__dirname,'home-desktop.png')});
 console.log((await page.locator('body').innerText()).slice(0,6000));
 console.log('SEMANTICS',await page.locator('flt-semantics-placeholder').count());
 if(await page.locator('flt-semantics-placeholder').count())await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
 await page.waitForTimeout(1500);
 console.log('BODY',await page.locator('body').innerText());
 await page.screenshot({path:path.join(__dirname,'home-accessible.png')});
 await browser.close();
})();
