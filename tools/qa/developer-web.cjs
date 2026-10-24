// Actual release/130% preview UI, isolated browser storage and blocked API writes.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','developer-lab');
const key='flutter.shootingstar.profile.v1', version='v10.0.13';
fs.mkdirSync(out,{recursive:true});
const button=(p,name)=>p.getByRole('button',name==='설정'?{name:/^설정(?: 설정)?$/}:{name,exact:true}).last();
async function ready(p){
  for(let i=0;i<100;i++){
    const placeholder=p.locator('flt-semantics-placeholder');
    if(await placeholder.count())await placeholder.evaluate(e=>e.click());
    if(await button(p,'설정').count())break;
    await p.waitForTimeout(120);
  }
  await p.waitForLoadState('networkidle');
  assert(await button(p,'설정').count(),'Flutter did not finish loading');
}
async function click(p,locator,min=20){const b=await reveal(p,locator,min);await p.mouse.click(b.x+b.width/2,b.y+b.height/2);await p.waitForTimeout(350);}
async function shot(p,name){await p.screenshot({path:path.join(out,name+'.png')});}
async function stored(p){return p.evaluate(key=>localStorage.getItem(key),key);}
async function stationary(p,locator){
 const a=await locator.boundingBox(),x=a.x+a.width/2,y=a.y+a.height/2;
 await p.mouse.move(x,y);await p.mouse.wheel(0,300);await p.waitForTimeout(100);assert.deepEqual(await locator.boundingBox(),a);
 if(process.env.QA_TOUCH){
  const cdp=await p.context().newCDPSession(p);
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y}]});
  for(let i=1;i<=4;i++)await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x,y:y-i*20}]});
  await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await p.waitForTimeout(150);
  assert.deepEqual(await locator.boundingBox(),a,'fixed board moved after touch drag');await cdp.detach();
 }
}
async function selectMenu(p,current,next){
 return selectField(p,'테스트 메뉴',current,next);
}
async function selectField(p,label,current,next){
 await click(p,button(p,label+' '+current));
 // Only dropdown menu options scroll, never the fixed test form.
 const option=p.getByRole('menuitem',{name:next,exact:true}).last();
 for(let i=0;i<25;i++){
   const b=await option.boundingBox({timeout:100}).catch(()=>null),h=p.viewportSize().height;
   if(b&&b.y>=40&&b.y+b.height<h-20){await click(p,option);await p.waitForTimeout(250);return;}
   await p.mouse.move(p.viewportSize().width/2,h/2);await p.mouse.wheel(0,b&&b.y<40?-120:120);await p.waitForTimeout(70);
 }
 throw Error('Dropdown option not reachable: '+next);
}
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const rows=[],errors=[];
 try{
  for(const [width,height] of [[320,568],[360,640],[390,844],[430,932]])for(const scale of [1,1.3]){
   const tag=width+'-'+scale;if(process.env.QA_ONLY&&tag!==process.env.QA_ONLY)continue;
   if(process.env.QA_SKIP&&process.env.QA_SKIP.split(',').includes(tag))continue;
   console.log('Developer UI',tag);
   const context=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
   await context.route('https://**',r=>r.abort());
   await context.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated developer QA"}'}));
   const p=await context.newPage();p.setDefaultTimeout(8000);
   p.on('pageerror',e=>errors.push({tag,error:e.message}));
   p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push({tag,error:m.text()});});
   try{
    await p.goto(scale===1?'http://127.0.0.1:8797/?ui='+version:'http://127.0.0.1:8799/?textScale=1.3');await ready(p);
    assert(await p.getByText(version,{exact:true}).count());
    await click(p,button(p,'설정'));
    await click(p,button(p,'음량 높이기'));await p.waitForTimeout(150);
    const before=await stored(p);assert(before);
    assert.equal(await p.getByRole('button',{name:/^다음 페이지/}).count(),0,'options must have one board');
    await stationary(p,p.getByRole('button',{name:/v10\.0\.13.*3초/}).first());
    await shot(p,'options-'+tag);
    const badge=p.getByRole('button',{name:/v10\.0\.13.*3초/}).first();
    const b=await badge.boundingBox();assert(b&&b.height>=48);
    await p.mouse.move(b.x+b.width/2,b.y+b.height/2);await p.mouse.down();
    await p.waitForTimeout(3100);await p.mouse.up();await p.waitForTimeout(250);
    assert(await p.getByRole('heading',{name:'개발자 인증',exact:true}).count());
    const input=p.locator('input[aria-label^="비밀번호"],textarea[aria-label^="비밀번호"]').first();
    await input.fill('0623');
    await click(p,button(p,'개발자 모드 시작'),72);await p.waitForTimeout(250);
    await click(p,button(p,'설정'));
    assert(await button(p,'개발자 모드 종료 · 일반 사용자로 전환').count());
    assert.equal(await p.getByRole('button',{name:/^다음 페이지/}).count(),0);
    await shot(p,'developer-options-'+tag);
    await click(p,button(p,'테스트'),72);
    fs.writeFileSync(path.join(out,'panel-current.txt'),await p.locator('body').ariaSnapshot());
    assert(await p.getByRole('button',{name:/테스트 메뉴/}).count());
    assert(await button(p,'테스트 출격').count());
    await shot(p,'test-panel-'+tag);
    await stationary(p,p.getByRole('button',{name:/테스트 메뉴/}).first());
    if(width===390&&scale===1){
      fs.writeFileSync(path.join(out,'test-panel-dom.txt'),await p.locator('body').ariaSnapshot());
      await selectMenu(p,'전투 / 무기·기체','성장 / 보스 장비');
      assert((await p.locator('body').ariaSnapshot()).includes('전용 장비 회수'));
      await shot(p,'boss-gear-panel');
      await selectMenu(p,'성장 / 보스 장비','전투 / 보스·편대');
      await selectField(p,'세계','잔광 외곽','태양 용광로');
      await selectField(p,'교전 시작','선택 항로 웨이브','세계 보스');
      await selectField(p,'보스 단계','1단계','3단계');
      await shot(p,'encounter-panel');
      await click(p,button(p,'테스트 출격'),72);
      await button(p,'일시정지').waitFor();
      await p.waitForTimeout(750);
      assert((await p.locator('body').ariaSnapshot()).includes('TEST ·'));
      fs.writeFileSync(path.join(out,'boss-battle-dom.txt'),await p.locator('body').ariaSnapshot());
      await click(p,button(p,'일시정지'));
      await shot(p,'test-battle-paused');
      await click(p,button(p,'귀환 · 현재 보상 정산'));
      // The battle's exit button can show a confirmation/finished panel.
      if(await button(p,'테스트 출격').count()===0){
        const back=button(p,'성장 정비 · 귀환');if(await back.count())await click(p,back);
      }
      await selectMenu(p,'전투 / 보스·편대','전투 / 성능·연출');
      await click(p,p.getByRole('switch',{name:'무적',exact:true}));
      await click(p,button(p,'성능 스테이지 선택'),64);
      await click(p,button(p,'테스트 출격'),72);
      await button(p,'일시정지').waitFor();await p.waitForTimeout(750);
      const metrics=await p.locator('body').ariaSnapshot();
      const fps=+(metrics.match(/TEST · (\d+) FPS/)||[])[1];assert(fps>0,'live FPS missing');
      fs.writeFileSync(path.join(out,'performance-dom.txt'),metrics);
      await click(p,button(p,'일시정지'));await shot(p,'performance-paused');
      await click(p,button(p,'귀환 · 현재 보상 정산'));
      await click(p,button(p,'성장 정비 · 귀환'));
    }
    if(!await button(p,'개발자 모드 종료 · 일반 사용자로 전환').count())throw Error('Lab exit missing');
    await click(p,button(p,'개발자 모드 종료 · 일반 사용자로 전환'));
    await ready(p);
    assert.equal(await stored(p),before,'developer operations changed normal storage');
    await click(p,button(p,'설정'));
    assert.equal(await button(p,'테스트').count(),0,'normal mode retained developer access');
    await click(p,button(p,'닫기'));
    await p.reload();await ready(p);
    assert.equal(await stored(p),before,'reload changed normal storage');
    rows.push({width,height,textScale:scale,optionsOneBoard:true,holdAndPin:true,testPanel:true,lockRestoresNormal:true,normalStorageUnchanged:true,wheelFixed:true,touchFixed:!!process.env.QA_TOUCH});
    fs.writeFileSync(path.join(out,'browser-'+tag+'.json'),JSON.stringify(rows.at(-1),null,2));
   }catch(error){
    fs.writeFileSync(path.join(out,'failure-errors-'+tag+'.json'),JSON.stringify(errors,null,2));
    await shot(p,'failure-'+tag);fs.writeFileSync(path.join(out,'failure-'+tag+'.txt'),await p.locator('body').ariaSnapshot());throw error;
   }finally{await context.close();}
  }
  assert.deepEqual(errors,[]);
  fs.writeFileSync(path.join(out,'browser-summary.json'),JSON.stringify({version,rows,errors},null,2));
  console.log(JSON.stringify({passed:rows.length,errors}));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
