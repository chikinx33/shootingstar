// Local-only posed fixture: real Flutter layout and TextScaler, never deployed.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const out=path.join(__dirname,'evidence','wing-phase3');
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const rows=[],errors=[];
 try {
  for(const [width,height] of [[320,568],[360,640],[390,844],[430,932]]) for(const scale of [1,1.3]) {
   const c=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
   await c.route('https://**',r=>r.abort());
   const p=await c.newPage();p.setDefaultTimeout(10000);
   p.on('pageerror',e=>errors.push(e.message));
   p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
   await p.goto(`http://127.0.0.1:8804/?scene=wing-phase3&textScale=${scale}`);
   for(let i=0;i<75;i++) {
    const placeholder=p.locator('flt-semantics-placeholder');
    if(await placeholder.count())await placeholder.evaluate(e=>e.click());
    if(await p.getByRole('button',{name:'궁극기 항성포 발사',exact:true}).count())break;
    await p.waitForTimeout(100);
   }
   await p.waitForLoadState('networkidle');
   const fire=p.getByRole('button',{name:'궁극기 항성포 발사',exact:true});
   const b=await fire.boundingBox();
   assert(b&&b.height>=72&&b.x>=0&&b.y>=0&&b.x+b.width<=width&&b.y+b.height<=height);
   // HUD text may be merged into the game semantics node; retain the actual
   // painted frame and full semantics for inspection rather than leaf lookup.
   const semantics=await p.locator('body').ariaSnapshot();
   fs.writeFileSync(path.join(out,`matrix-${width}-scale-${scale}.txt`),semantics);
   assert(semantics.includes('방패 역습 · 준비'));
   assert(semantics.includes('정면 돌파 · 준비'));
   await p.mouse.wheel(0,300);await p.waitForTimeout(100);
   assert.deepEqual(await fire.boundingBox(),b,'battle must not scroll with wheel');
   const session=await c.newCDPSession(p);
   await session.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:25,y:height-70}]});
   await session.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:25,y:height-240}]});
   await session.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
   await p.waitForTimeout(150);
   await fire.waitFor();
   assert.deepEqual(await fire.boundingBox(),b,'battle must not scroll with touch');
   assert.equal(await p.evaluate(()=>document.documentElement.scrollHeight>innerHeight),false);
   await p.screenshot({path:path.join(out,`matrix-ready-${width}-scale-${scale}.png`)});
   await p.touchscreen.tap(b.x+b.width/2,b.y+b.height/2);
   await p.getByRole('button',{name:'궁극기 항성포 발사 중',exact:true}).waitFor();
   await p.screenshot({path:path.join(out,`matrix-active-${width}-scale-${scale}.png`)});
   rows.push({width,height,textScale:scale,paintedActionMinimum72:true,twoSynergyLines:true,wheelAndTouchFixed:true,realButtonCast:true,posedFixture:true});
   await c.close();
  }
  assert.deepEqual(errors,[]);
  fs.writeFileSync(path.join(out,'browser-matrix.json'),JSON.stringify({version:'v10.0.4',rows,errors,scope:'Current source; isolated visual fixture; actual Flutter TextScaler; no production or saved-profile injection'},null,2));
  console.log(JSON.stringify({passed:rows.length,errors}));
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
