const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
(async()=>{
 const out=path.resolve('tools/qa/evidence/lobby-v42');fs.mkdirSync(out,{recursive:true});
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const errors=[],menus=[];
 try{
  const c=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
  await c.route('https://**',r=>r.abort());
  await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated menu QA"}'}));
  const p=await c.newPage();p.setDefaultTimeout(12000);
  p.on('pageerror',e=>errors.push(e.message));
  p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
  await p.goto('http://127.0.0.1:8797/?v=10.0.42');
  for(let i=0;i<75;i++){
   const placeholder=p.locator('flt-semantics-placeholder');if(await placeholder.count())await placeholder.evaluate(e=>e.click());
   if(await p.getByRole('button',{name:'임무·출석',exact:true}).count())break;
   await p.waitForTimeout(150);
  }
  await p.waitForLoadState('networkidle');
  const hangar=p.getByRole('button',{name:'격납고',exact:true});
  assert.equal(await hangar.count(),1);
  const hb=await hangar.boundingBox(),chapter=await p.getByRole('button',{name:'챕터 선택',exact:true}).boundingBox();
  assert(hb.y>=chapter.y+chapter.height&&hb.x<195,'hangar must be in the left lobby column');
  await p.screenshot({path:path.join(out,'lobby-390.png')});
  const tap=async loc=>{const b=await reveal(p,loc);await p.mouse.click(b.x+b.width/2,b.y+b.height/2);};
  for(const [label,title] of [['임무·출석','함대 활동'],['시즌 보상','시즌 원정'],['순찰','함대 활동'],['길드','성간 길드'],['격납고','출격 편성']]){
   const button=p.getByRole('button',{name:label,exact:true});
   const b=await reveal(p,button);assert(b.width>=48&&b.height>=48,'tap target '+label);
   await tap(button);await p.getByText(title,{exact:true}).first().waitFor();
   if(label==='격납고')await tap(p.getByRole('button',{name:'출격',exact:true}));
   else await tap(p.getByRole('button',{name:'Back',exact:true}).first());
   await p.getByRole('button',{name:'임무·출석',exact:true}).waitFor();
   menus.push({label,title,tapTarget:b,navigation:true});
  }
  await p.setViewportSize({width:320,height:568});await p.waitForTimeout(400);
  for(const {label} of menus){const b=await reveal(p,p.getByRole('button',{name:label,exact:true}));assert(b.x>=0&&b.x+b.width<=320&&b.y+b.height<=568);}
  await p.mouse.move(310,550);await p.waitForTimeout(250);
  await p.screenshot({path:path.join(out,'lobby-320.png')});
  assert.deepEqual(errors,[]);
  const result={version:'v10.0.42',menus,topHangarRemoved:true,leftMenuHangar:true,widths:[390,320],errors};
  fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
