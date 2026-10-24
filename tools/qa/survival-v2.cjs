const {chromium}=require('playwright');
const fs=require('fs');const path=require('path');const assert=require('assert');
const out=path.join(__dirname,'evidence','survival-v2');fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 try {
 const page=await browser.newPage({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
 const errors=[],failed=[];page.on('pageerror',e=>errors.push(e.message));page.on('response',r=>{if(r.status()>=400)failed.push(r.status()+' '+r.url());});
 await page.route('https://**',r=>r.abort());await page.clock.install();
 await page.goto('http://127.0.0.1:8787');await page.waitForTimeout(4000);
 await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());await page.waitForTimeout(300);
 await page.screenshot({path:path.join(out,'01-home-mobile.png')});
 for(const [name,file] of [['장비','02-equipment'],['도전','03-challenges'],['도감','04-evolutions']]){
  await page.getByRole('tab',{name,exact:true}).click();await page.waitForTimeout(200);await page.screenshot({path:path.join(out,file+'.png')});
 }
 await page.getByRole('tab',{name:'출격',exact:true}).click();await page.waitForTimeout(200);
 await page.getByRole('button',{name:'잔광 외곽 · 출격',exact:true}).click();
 await page.getByRole('button',{name:'비행 준비 완료',exact:true}).click();await page.waitForTimeout(600);
 await page.clock.pauseAt(new Date(await page.evaluate(() => Date.now()) + 100));
 const cdp=await page.context().newCDPSession(page);
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:195,y:480}]});
 await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:245,y:440}]});await page.clock.runFor(400);
 await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
 const directions=['d','s','a','w'];let choices=0;let ended=false;let captured=false;
 for(let i=0;i<(process.argv.includes('--full')?600:50);i++){
  let text=await page.locator('body').innerText();
  if(text.includes('집을 지켜 냈다냥!')||text.includes('다음엔 꼭 이긴다냥')){ended=true;break;}
  if(text.includes('스킬 선택')){
   if(choices===0) await page.screenshot({path:path.join(out,'05-skill-choice.png')});
   const buttons=page.getByRole('button').filter({hasNotText:'일시정지'});
   const count=await buttons.count();let index=0,best=-1;
   for(let k=0;k<count;k++){
    const label=await buttons.nth(k).innerText();
    const score= label.includes('EVO')?100:label.includes('펄스 블래스터')?90:label.includes('고밀도 탄약')?85:label.includes('플라스마')?80:label.includes('궤도 수호자')?75:label.includes('추적 로켓')?70:label.includes('장갑 증폭기')?60:label.includes('회수 자기장')?55:10;
    if(score>best){best=score;index=k;}
   }
   await buttons.nth(index).click();await page.clock.runFor(80);choices++;
  }
  await page.keyboard.down(directions[Math.floor(i/3)%4]);await page.clock.runFor(2200);await page.keyboard.up(directions[Math.floor(i/3)%4]);
  if(i>25 && !captured && !(await page.locator('body').innerText()).includes('스킬 선택')){await page.screenshot({path:path.join(out,'06-horde-mobile.png')});captured=true;}
  if(i===40)await page.screenshot({path:path.join(out,'07-horde-mobile-later.png')});
  if(i%20===0)console.log('PROGRESS',i,'choices',choices,text.match(/\d\d:\d\d \/ \d\d:\d\d/)?.[0]);
 }
 if(!ended){
  await page.getByRole('button',{name:'일시정지',exact:true}).click();await page.clock.runFor(100);
  const paused=await page.locator('body').ariaSnapshot();await page.clock.runFor(2000);assert.equal((await page.locator('body').ariaSnapshot()).match(/\d\d:\d\d \/ \d\d:\d\d/)[0],paused.match(/\d\d:\d\d \/ \d\d:\d\d/)[0],'pause freezes clock');
  await page.getByRole('button',{name:'귀환 · 현재 보상 정산',exact:true}).click();await page.clock.runFor(100);ended=true;
 }
 assert(ended);assert(choices>0);await page.screenshot({path:path.join(out,'08-result.png')});
 const result=await page.locator('body').innerText();
 const save=await page.evaluate(()=>localStorage.getItem('flutter.shootingstar.profile.v1'));
 await page.clock.runFor(1000);assert.equal(await page.evaluate(()=>localStorage.getItem('flutter.shootingstar.profile.v1')),save);
 await page.getByRole('button',{name:'격납고로 귀환',exact:true}).click();await page.clock.runFor(400);
 await page.getByRole('tab',{name:'장비',exact:true}).click();await page.clock.runFor(100);await page.screenshot({path:path.join(out,'09-earned-equipment.png')});
 await page.clock.resume();await page.reload();await page.waitForTimeout(2500);
 assert.equal(await page.evaluate(()=>localStorage.getItem('flutter.shootingstar.profile.v1')),save);
 assert.deepEqual(errors,[]);assert.deepEqual(failed,[]);
 fs.writeFileSync(path.join(out,'result.json'),JSON.stringify({choices,ended,captured,version:2,mode:process.argv.includes('--full')?'full':'smoke-and-return',result,profile:JSON.parse(save),errors,failed},null,2));
 console.log('PASS',JSON.stringify({choices,result,errors,failed}));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});

