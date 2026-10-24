const {chromium}=require('playwright');const fs=require('fs');
(async()=>{
 const b=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const p=await b.newPage({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
 await p.goto('http://127.0.0.1:8791');await p.locator('flt-semantics-placeholder').evaluate(e=>e.click());
 await p.getByRole('button',{name:'설정',exact:true}).click();await p.waitForTimeout(1000);
 await p.screenshot({path:'tools/qa/evidence/visual-v6/settings-settled.png'});
 console.log(await p.getByRole('button',{name:'완료',exact:true}).evaluate(el=>{
   const r=el.getBoundingClientRect();return {target:el.outerHTML,rect:r.toJSON(),atPoint:document.elementsFromPoint(r.x+r.width/2,r.y+r.height/2).map(e=>e.outerHTML.slice(0,500))};
 }));
 fs.writeFileSync('tools/qa/evidence/visual-v6/dialog-dom.txt',await p.locator('body').innerHTML());
 const box=await p.getByRole('button',{name:'완료',exact:true}).boundingBox();
 await p.touchscreen.tap(box.x+box.width/2,box.y+box.height/2);await p.waitForTimeout(500);
 console.log('Touch closed:',!(await p.getByText('비행 설정',{exact:true}).count()));
 await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
