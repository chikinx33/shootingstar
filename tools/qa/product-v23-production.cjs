const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','product-v23');fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const errors=[],images=new Set(),audio=new Set(),bad=[];
 const c=await browser.newContext({viewport:{width:320,height:568},isMobile:true,hasTouch:true});
 await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated QA"}'}));
 const p=await c.newPage();p.setDefaultTimeout(12000);
 p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
 p.on('response',r=>{
  if(r.url().includes('/assets/')&&r.status()>=400)bad.push(r.url());
  if(/\.png(?:\?|$)/.test(r.url()))images.add(r.url());
  if(/\.ogg(?:\?|$)/.test(r.url()))audio.add(r.url());
 });
 try{
  await p.goto(process.env.QA_URL);
  for(let i=0;i<150;i++){
   const a=p.locator('flt-semantics-placeholder');if(await a.count())await a.evaluate(e=>e.click());
   if(await p.getByRole('button',{name:'성장',exact:true}).count())break;
   await p.waitForTimeout(100);
  }
  await p.waitForLoadState('networkidle');
  await p.getByText('v10.0.23',{exact:true}).waitFor();
  assert.equal([...images].filter(x=>x.includes('/enemy-')).length,0,'enemy payload should not block lobby');
  const bootImages=images.size;
  await p.getByRole('button',{name:/ · 출격$/}).first().click();
  const done=p.getByRole('button',{name:'비행 준비 완료',exact:true});
  const b=await reveal(p,done);await p.mouse.click(b.x+b.width/2,b.y+b.height/2);
  await p.getByRole('button',{name:'일시정지',exact:true}).waitFor();
  await p.getByLabel(/화면을 눌러 비행 시작/).waitFor();
  assert.equal([...images].filter(x=>x.includes('/enemy-')).length,11);
  const ultimate=await p.getByRole('button',{name:/^궁극기 충전/}).boundingBox();assert(ultimate);
  const x=60,y=Math.max(250,ultimate.y-90);
  await p.mouse.move(x,y);await p.mouse.down();await p.waitForTimeout(900);await p.mouse.up();
  await p.getByLabel(/다시 누르고 드래그해/).waitFor();
  await p.mouse.move(x,y);await p.mouse.down();await p.mouse.move(x+75,y-35,{steps:8});
  await p.waitForTimeout(800);await p.mouse.up();
  await p.getByLabel(/경험치를 모으세요/).waitFor();
  await p.screenshot({path:path.join(out,'coach-production-320.png')});
  await p.getByRole('button',{name:'일시정지',exact:true}).click();
  await p.getByRole('button',{name:'계속 비행',exact:true}).waitFor();
  assert([...audio].some(x=>x.includes('orbit-loop.ogg')),'ambient loop not requested');
  assert([...audio].some(x=>x.includes('weapon-pulse.ogg')),'weapon sound not requested');
  assert.deepEqual(bad,[]);assert.deepEqual(errors,[]);
  fs.writeFileSync(path.join(out,'production.json'),JSON.stringify({version:'v10.0.23',bootImages,
   enemyImagesAfterLaunch:11,coachHoldReleaseMove:true,audio:[...audio].map(x=>x.split('/').pop()),
   pause:true,errors,bad},null,2));
  console.log('production coaching, deferred art and audio passed');
 }catch(e){await p.screenshot({path:path.join(out,'production-failure.png')});fs.writeFileSync(path.join(out,'production-failure.json'),JSON.stringify({errors,bad,audio:[...audio],text:await p.locator('flt-semantics').allTextContents()},null,2));throw e;}
 finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
