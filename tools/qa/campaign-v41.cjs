const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
(async()=>{
 const out=path.resolve('tools/qa/evidence/campaign-v41');fs.mkdirSync(out,{recursive:true});
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const errors=[],checks=[];
 try{
  for(const [width,height] of [[390,844],[320,568]]){
   const c=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
   await c.route('https://**',r=>r.abort());
   await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated campaign QA"}'}));
   await c.addInitScript(()=>localStorage.setItem('flutter.shootingstar.profile.v1',JSON.stringify(JSON.stringify({version:4,campaignVersion:1,selectedStage:13,clearedStages:Array.from({length:13},(_,i)=>i),onboarded:true,soundEnabled:false,reducedEffects:true,pilotLevel:9,pilotXp:147}))));
   const p=await c.newPage();p.setDefaultTimeout(12000);
   p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
   await p.goto('http://127.0.0.1:8797/?v=10.0.41');
   for(let i=0;i<75;i++){
    const ph=p.locator('flt-semantics-placeholder');if(await ph.count())await ph.evaluate(e=>e.click());
    if(await p.getByRole('button',{name:'챕터 선택',exact:true}).count())break;
    await p.waitForTimeout(150);
   }
   await p.waitForLoadState('networkidle');
   const tap=async loc=>{const b=await reveal(p,loc);await p.mouse.click(b.x+b.width/2,b.y+b.height/2);};
   await tap(p.getByRole('button',{name:'챕터 선택',exact:true}));
   await p.getByText('항로 선택',{exact:true}).waitFor();
   await p.waitForTimeout(400);
   const done=p.getByRole('button',{name:'선택 완료',exact:true});
   const before=await done.boundingBox();
   const first=p.getByRole('button',{name:/^2-1 ·/}).first();await reveal(p,first);
   await p.mouse.move(width*.5,height*.5);await p.mouse.wheel(0,-30);await p.waitForTimeout(180);
   if(width===390)await p.screenshot({path:path.join(out,'campaign-390.png')});
   const columns=[];
   for(const n of [1,2,3]){const b=await reveal(p,p.getByRole('button',{name:new RegExp('^2-'+n+' ·')}).first());columns.push(b);}
   assert(Math.abs(columns[0].y-columns[1].y)<1&&Math.abs(columns[1].y-columns[2].y)<1,'first row must share its baseline');
   assert(columns[0].x<columns[1].x&&columns[1].x<columns[2].x,'three route columns');
   assert(columns.every(b=>b.width<width/2&&b.height>=48),'compact accessible route cells');
   const locked=p.getByRole('button',{name:/^2-5 ·/}).first();await reveal(p,locked);assert(await locked.isDisabled(),'locked route enabled');
   if(width===320)await p.screenshot({path:path.join(out,'campaign-320.png')});
   assert.deepEqual(await done.boundingBox(),before,'list scrolling moved completion action');
   await tap(p.getByRole('button',{name:/^2-3 ·/}).first());
   await p.getByText('2-3 항로',{exact:true}).waitFor();
   await reveal(p,p.getByText(/3분 · 보스 .*위험도 13/).last());
   await tap(p.getByRole('button',{name:'이 항로 선택',exact:true}));
   await p.getByText('2-3 항로',{exact:true}).waitFor({state:'detached'});
   await tap(done);
   const saved=await p.evaluate(()=>{let s=localStorage.getItem('flutter.shootingstar.profile.v1');for(let i=0;i<3&&typeof s==='string';i++)s=JSON.parse(s);return s;});
   assert.equal(saved.selectedStage,12);assert.equal(saved.clearedStages.length,13);
   checks.push({width,height,columns,lockedRoute:true,detailMetadata:true,selectionSaved:true,progressPreserved:true,fixedCompletionAction:true});
   await c.close();
  }
  assert.deepEqual(errors,[]);const result={version:'v10.0.41',checks,errors};
  fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
