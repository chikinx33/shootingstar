// Real production entrypoint with an isolated, test-generated local save.
// No user browser storage, account, payment or ad request is used.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const root=path.resolve(__dirname,'../..');
const version=process.env.QA_VERSION||'10.0.33';
const out=path.join(__dirname,'evidence','balance-v33');
const raw=fs.readFileSync(path.join(root,'.local/balance-v33/finale-profile.json'),'utf8');
(async()=>{
  fs.mkdirSync(out,{recursive:true});
  const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
  const errors=[];let diagnosticPage;
  try{
    const c=await browser.newContext({viewport:{width:320,height:568},isMobile:true,hasTouch:true});
    await c.route('https://**',r=>r.abort());
    await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated finale QA"}'}));
    await c.addInitScript(({raw})=>{
      if(!sessionStorage.getItem('finale-seeded')){
        localStorage.setItem('flutter.shootingstar.profile.v1',JSON.stringify(raw));
        sessionStorage.setItem('finale-seeded','1');
      }
    },{raw});
    const p=await c.newPage();diagnosticPage=p;p.setDefaultTimeout(12000);
    p.on('pageerror',e=>errors.push(e.message));
    p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
    const button=n=>p.getByRole('button',{name:n,exact:true}).last();
    const click=async n=>{const b=await reveal(p,button(n));await p.mouse.click(b.x+b.width/2,b.y+b.height/2);await p.waitForTimeout(200);};
    const profile=()=>p.evaluate(()=>{const v=JSON.parse(localStorage.getItem('flutter.shootingstar.profile.v1'));return typeof v==='string'?JSON.parse(v):v;});
    await p.goto('http://127.0.0.1:8797/?v='+version);
    for(let i=0;i<120;i++){
      const a=p.locator('flt-semantics-placeholder');if(await a.count())await a.evaluate(e=>e.click());
      if(await button('성장').count()&&await p.getByText('v'+version,{exact:true}).count())break;
      await p.waitForTimeout(100);
    }
    await p.getByText('v'+version,{exact:true}).waitFor();
    await click('저장된 전투 이어하기');
    await click('이전 전투 이어하기');await click('계속 비행');
    await p.waitForFunction(()=>{
      let v=JSON.parse(localStorage.getItem('flutter.shootingstar.profile.v1'));
      if(typeof v==='string')v=JSON.parse(v);
      return v.campaignLoop===1;
    });
    const accessibility=await p.locator('body').ariaSnapshot();
    fs.writeFileSync(path.join(out,'result-accessibility.txt'),accessibility);
    assert(accessibility.includes('100개 항로 완주'));
    await p.waitForLoadState('networkidle');
    assert(accessibility.includes('CAMPAIGN COMPLETE'));
    const settled=await profile();
    assert.equal(settled.campaignLoop,1);assert.equal(settled.selectedStage,0);
    assert.equal(settled.clearedStages.length,100);assert(!settled._battle);
    const pager=p.getByRole('button',{name:/^다음 페이지/}).last();
    const pagerBox=await pager.boundingBox();await p.mouse.wheel(0,400);assert.deepEqual(await pager.boundingBox(),pagerBox);
    await p.screenshot({path:path.join(out,'campaign-complete-320.png')});
    await reveal(p,button('다음 회차 출격'));await p.screenshot({path:path.join(out,'next-cycle-action-320.png')});
    await click('다음 회차 출격');
    assert(!(await p.locator('body').ariaSnapshot()).includes('100개 항로 완주'));
    await click('일시정지');
    const next=await profile();assert.equal(next.campaignLoop,1);assert.equal(next.selectedStage,0);
    assert.equal(next.credits,settled.credits);assert.equal(next._battle?.runId==='finale-v33',false);
    await p.screenshot({path:path.join(out,'next-cycle-paused-320.png')});
    assert.deepEqual(errors,[]);
    fs.writeFileSync(path.join(out,'smoke.json'),JSON.stringify({version:'v'+version,
      productionEntrypoint:true,width:320,height:568,compiledVersionVisible:true,
      finalDestructionResume:true,campaignComplete:true,nextCycleStage0:true,
      lifetime100Preserved:true,rewardSettledOnce:true,fixedResultPages:true,
      apiIntercepted:true,errors},null,2));
    console.log('Finale/resume/settlement/next-cycle production web proof passed.');
  }catch(error){
    if(diagnosticPage){
      await diagnosticPage.screenshot({path:path.join(out,'failure.png')});
      fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:error.message,
        semantics:await diagnosticPage.locator('body').innerText(),
        accessibility:await diagnosticPage.locator('body').ariaSnapshot(),errors},null,2));
    }
    throw error;
  }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exit(1);});
