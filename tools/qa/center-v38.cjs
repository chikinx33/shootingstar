// Rendered mobile checks for the shared alignment change; isolated QA origin.
const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.resolve('tools/qa/evidence/center-v38');
(async()=>{
  fs.mkdirSync(out,{recursive:true});
  const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
  const checks=[],errors=[];
  try{
    for(const [width,height] of [[320,568],[360,640],[390,844],[430,932]])for(const scale of [1,1.3]){
      const c=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
      await c.route('https://**',r=>r.abort());
      await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated layout QA"}'}));
      const p=await c.newPage();p.setDefaultTimeout(12000);
      p.on('pageerror',e=>errors.push(e.message));
      p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by|Fixed page item is too tall/.test(m.text()))errors.push(m.text());});
      async function load(mode,label){
        await p.goto(`http://127.0.0.1:8798/?mode=${mode}&scale=${scale}`);
        for(let i=0;i<75;i++){
          const placeholder=p.locator('flt-semantics-placeholder');
          if(await placeholder.count())await placeholder.evaluate(e=>e.click());
          if(await p.getByText(label,{exact:true}).count())break;
          await p.waitForTimeout(100);
        }
        await p.getByText(label,{exact:true}).first().waitFor();
        await p.waitForLoadState('networkidle');
      }
      async function center(locator,label){
        const b=await reveal(p,locator);
        assert(Math.abs(b.x+b.width/2-width/2)<1,`${width}/${scale} ${label}: ${JSON.stringify(b)}`);
        return b;
      }
      async function tap(locator){const b=await reveal(p,locator);await p.mouse.click(b.x+b.width/2,b.y+b.height/2);}
      await load('guild','함께하는 함대');
      await center(p.getByText('함께하는 함대',{exact:true}),'catalog title');
      await center(p.getByText('동료와 함께 성장하세요',{exact:true}),'section title');
      if(width===390&&scale===1)await p.screenshot({path:path.join(out,'guild-390.png')});
      const login=p.getByRole('button',{name:'계정 로그인 · 가입',exact:true});
      const loginBox=await center(login,'login');
      assert(loginBox.width<=264.5,'painted action widened');
      await tap(login);
      await p.getByText('계정',{exact:true}).first().waitFor();
      await center(p.getByText('온라인 서비스를 준비하고 있습니다.',{exact:true}),'account message');
      // Tight fixed page content still reaches its existing action via paging.
      await load('collection','항로 유물');
      await center(p.getByRole('button',{name:'유물 조사 · 탐사권 1',exact:true}),'investigation');
      await load('home','슈팅스타');
      await center(p.getByText('슈팅스타',{exact:true}),'lobby title');
      assert.equal(await p.getByText('v10.0.38',{exact:true}).count(),0,'lobby footer returned');
      await tap(p.getByRole('button',{name:'설정',exact:true}).last());
      await center(p.getByText('옵션',{exact:true}),'settings title');
      await p.getByRole('button',{name:'v10.0.38 · 3초 눌러 개발자 인증',exact:true}).waitFor();
      if(width===320&&scale===1.3)await p.screenshot({path:path.join(out,'settings-320-130.png')});
      await tap(p.getByRole('button',{name:'닫기',exact:true}).last());
      assert.equal(await p.evaluate(()=>document.documentElement.scrollHeight>innerHeight),false,'document scrolling');
      const nav=p.getByRole('button',{name:'출격',exact:true});
      const before=await nav.boundingBox();await p.mouse.wheel(0,400);
      assert.deepEqual(await nav.boundingBox(),before,'fixed lobby moved');
      await tap(p.getByRole('button',{name:'격납고',exact:true}));
      await center(p.getByText('출격 편성',{exact:true}),'hangar title');
      checks.push({width,height,scale,catalogTitle:true,sectionTitle:true,paintedAction:true,loginNavigation:true,collectionPaging:true,settingsTitle:true,settingsVersion:true,fixedLobby:true,lobbyTitle:true,hangarShortcut:true});
      await c.close();
      console.log(`passed ${width}/${scale}`);
    }
    assert.deepEqual(errors,[]);
    fs.writeFileSync(path.join(out,'report.json'),JSON.stringify({version:'v10.0.38',checks,errors},null,2));
  }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
