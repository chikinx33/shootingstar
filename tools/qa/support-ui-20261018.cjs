const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','support-ui-20261018');fs.mkdirSync(out,{recursive:true});
const key='flutter.shootingstar.profile.v1';
(async()=>{
  const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
  const rows=[],errors=[];let last;
  const button=(p,name)=>p.getByRole('button',{name,exact:true});
  async function click(p,name,min=20){const l=button(p,name).first();const b=await reveal(p,l,min);await p.mouse.click(b.x+b.width/2,b.y+b.height/2);await p.waitForTimeout(360);}
  async function chip(p,name){const l=p.getByRole('checkbox',{name,exact:true});await l.click();await p.waitForTimeout(360);}
  async function ready(p){for(let i=0;i<160;i++){
    if(await p.locator('flt-semantics-placeholder').count())await p.locator('flt-semantics-placeholder').evaluate(e=>e.click());
    if(await p.locator('flt-semantics [role="button"],flt-semantics[role="button"]').count()){await p.waitForTimeout(350);return;}
    await p.waitForTimeout(250);
  }throw Error('Flutter semantics timeout');}
  async function input(p,field,value){await reveal(p,field);await field.click();await p.waitForTimeout(300);await field.fill(value);await p.waitForTimeout(350);}
  async function reload(p){await p.reload();await ready(p);}
  async function saved(p){return p.evaluate(key=>{let s=localStorage.getItem(key);for(let i=0;i<3&&typeof s==='string';i++)s=JSON.parse(s);return s;},key);}
  async function shot(p,name){await p.waitForTimeout(220);await p.screenshot({path:path.join(out,name+'.png')});}
  async function measure(p,name,primary=true){const b=await reveal(p,button(p,name).first(),primary?72:64);
    assert(b.width<=264.2&&b.width/b.height<=4.25,JSON.stringify({name,...b}));return{name,...b};}
  async function stationary(p,locator){const before=await locator.boundingBox();assert(before);
    const v=p.viewportSize(),x=v.width*.5;const footer=await p.getByRole('button',{name:/^다음 페이지/}).last().boundingBox({timeout:100}).catch(()=>null);const y=footer?footer.y+footer.height/2:v.height-48;
    await p.mouse.move(x,y);await p.mouse.wheel(0,450);await p.waitForTimeout(180);
    const mid=await locator.boundingBox();assert.deepEqual(mid,before,'non-list wheel moved content');
    const cdp=await p.context().newCDPSession(p);
    await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y}]});
    for(let i=1;i<=4;i++)await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x,y:y-i*25}]});
    await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await p.waitForTimeout(220);
    assert.deepEqual(await locator.boundingBox(),before,'non-list touch moved content');await cdp.detach();return before;
  }
  async function fixedHeader(p,title){const h=p.getByText(title,{exact:true}).last(),before=await h.boundingBox();
    const list=await p.locator('flt-semantics:has(> flt-semantics-scroll-overflow)').last().boundingBox();assert(list,'actual item viewport missing');
    await p.mouse.move(list.x+list.width*.6,list.y+list.height*.6);await p.mouse.wheel(0,180);await p.waitForTimeout(250);
    assert.deepEqual(await h.boundingBox(),before,'list moved header');return before;
  }

  async function choice(p,title){const item=p.getByRole('button',{name:new RegExp('^'+title+'(?:\\s|$)')});const b=await reveal(p,item,88);await p.mouse.click(b.x+b.width/2,b.y+b.height/2);await p.waitForTimeout(350);}
  const field=(p,label)=>p.locator(`input[aria-label^="${label}"],textarea[aria-label^="${label}"]`).first();
  async function toggle(p,label){
    let target=p.getByRole('switch',{name:new RegExp('^'+label)}).first();
    if(!await target.count())target=p.getByRole('checkbox',{name:new RegExp('^'+label)}).first();
    if(!await target.count())target=p.getByRole('switch',{checked:false}).first();
    const b=await reveal(p,target);await p.mouse.click(b.x+b.width/2,b.y+b.height/2);await p.waitForTimeout(250);
  }
  function stateIds(s){return JSON.stringify({inventory:s.content.inventory,equipped:s.content.equippedGear,presets:s.hangarPresets,credits:s.credits,food:s.content.petFood});}
  try{
    for(const [width,height]of [[320,568],[360,640],[390,844],[430,932]])for(const scale of [1,1.3]){
      if(process.env.QA_WIDTH&&width!==+process.env.QA_WIDTH)continue;
      if(process.env.QA_SCALE&&scale!==+process.env.QA_SCALE)continue;
      console.log('support UI',width,scale);
      const context=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
      let auth=false,cloud=null,revision=1,conflictNext=false,failNext=false;
      const requests=[];
      await context.route('https://**',r=>r.abort());
      await context.route('**/api/**',async r=>{
        const endpoint=new URL(r.request().url()).pathname.replace('/api/','');requests.push(endpoint);
        const data=r.request().postDataJSON()||{};let body={},status=200;
        if(endpoint==='auth/me'){
          if(!auth){status=401;body={error:'isolated guest'};}
          else body={account:{id:'support-ui-qa',username:'ui_qa',nickname:'검증 조종사'},profile:cloud,revision,updatedAt:1};
        }else if(endpoint==='auth/challenge')body={salt:'0123456789abcdef0123456789abcdef'};
        else if(['auth/register','auth/login','auth/recover'].includes(endpoint)){
          auth=true;body={account:{id:'support-ui-qa',username:data.username,nickname:data.nickname||'검증 조종사'},
            profile:cloud,revision,updatedAt:1,...(endpoint==='auth/register'?{recoveryCode:'0123456789abcdef0123456789abcdef0123456789abcdef'}:{})};
        }else if(endpoint==='auth/logout'||endpoint==='auth/logout-all'){auth=false;body={ok:true};}
        else if(endpoint.startsWith('cloud/')){
          if(failNext){failNext=false;status=503;body={error:'검증용 연결 실패'};}
          else if(conflictNext){conflictNext=false;status=409;body={error:'저장 충돌',profile:cloud,revision:++revision,updatedAt:1};}
          else if(endpoint==='cloud/write'){cloud=JSON.parse(JSON.stringify(data.profile));body={revision:++revision,updatedAt:1};}
          else body={profile:cloud,revision,updatedAt:1};
        }else{status=401;body={error:'isolated QA'};}
        await r.fulfill({status,contentType:'application/json',body:JSON.stringify(body)});
      });
      const p=await context.newPage();last=p;
      p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
      await p.goto(scale===1?'http://127.0.0.1:8797/?ui=support-ui':`http://127.0.0.1:8798/?scene=menus&online=1&textScale=${scale}`);await ready(p);
      const tag=`${width}-scale-${scale}`,measured=[];
      await click(p,'보급');await click(p,'장비 보급 열기',72);await click(p,'확인',72);
      let s=await saved(p);s.onboarded=true;s.soundEnabled=false;s.reducedEffects=false;s.volume=.5;s.credits=6000;
      s.hangarPresets[0]={name:'유지할 편성',ship:0,pilot:0,armament:0,equipment:0,gearIds:[...s.content.equippedGear],techIds:[],pet:0,assistPets:[]};
      await p.evaluate(({key,s})=>localStorage.setItem(key,JSON.stringify(JSON.stringify(s))),{key,s});await reload(p);
      const original=stateIds(await saved(p));
      await click(p,'설정');await shot(p,`settings-${tag}`);await stationary(p,button(p,'음량 높이기').first());
      await toggle(p,'음악·효과음');assert.equal((await saved(p)).soundEnabled,true);
      await click(p,'음량 높이기',48);assert(Math.abs((await saved(p)).volume-.6)<.001);
      await toggle(p,'시각 효과 줄이기');assert.equal((await saved(p)).reducedEffects,true);await shot(p,`settings-effects-${tag}`);
      measured.push(await measure(p,'오픈소스 라이선스',false));await click(p,'오픈소스 라이선스',64);
      await shot(p,`licenses-${tag}`);await fixedHeader(p,'오픈소스');
      const license=p.getByRole('button',{name:/라이선스 열기$/}).first();await reveal(p,license,64);await license.click();await p.waitForTimeout(350);
      await shot(p,`license-detail-${tag}`);await stationary(p,button(p,'닫기').last());await click(p,'닫기',48);await click(p,'Back',48);
      measured.push(await measure(p,'완료'));await click(p,'완료',72);
      await click(p,'설정');await click(p,'계정 · 클라우드 저장',64);
      await shot(p,`account-login-${tag}`);await reveal(p,button(p,'로그인'),72);await stationary(p,button(p,'로그인'));
      await chip(p,'가입');await shot(p,`account-register-${tag}`);
      await chip(p,'복구');await shot(p,`account-recover-${tag}`);
      await chip(p,'로그인');await click(p,'로그인',72);
      await shot(p,`account-validation-${tag}`);assert(!requests.includes('auth/login'));
      await input(p,field(p,'아이디'),'ui_qa');await input(p,field(p,'비밀번호'),'qa-password-only-123');
      cloud=JSON.parse(JSON.stringify(await saved(p)));measured.push(await measure(p,'로그인'));
      await shot(p,`account-input-${tag}`);await click(p,'로그인',72);await p.waitForTimeout(500);
      await reveal(p,button(p,'지금 동기화'),72);await shot(p,`account-signed-${tag}`);
      assert(requests.includes('auth/login'));assert.equal(stateIds(await saved(p)),original);
      failNext=true;await click(p,'지금 동기화',72);await shot(p,`account-retry-${tag}`);
      await click(p,'지금 동기화',72);
      conflictNext=true;await click(p,'지금 동기화',72);
      await shot(p,`account-conflict-${tag}`);await choice(p,'서버 진행 사용');
      await shot(p,`account-conflict-confirm-${tag}`);await stationary(p,button(p,'닫기').last());
      await click(p,'취소',64);assert.equal(stateIds(await saved(p)),original);
      await choice(p,'이 기기 진행 저장');await click(p,'선택한 진행 사용',72);
      assert.equal(stateIds(await saved(p)),original);
      assert(await p.evaluate(()=>Object.keys(localStorage).some(k=>k.includes('online.backup.conflict-device'))));
      assert(await p.evaluate(()=>Object.keys(localStorage).some(k=>k.includes('online.backup.conflict-cloud'))));
      // Registration and recovery use actual UI/client code on one representative
      // case; all sizes cover their forms and widget tests cover their bindings.
      if(width===390&&scale===1.3){
        await click(p,'로그아웃 · 게스트로 돌아가기',64);
        await chip(p,'가입');await input(p,field(p,'아이디'),'ui_qa');await input(p,field(p,'닉네임'),'검증 조종사');
        await input(p,field(p,'비밀번호'),'qa-password-only-123');
        cloud=JSON.parse(JSON.stringify(await saved(p)));await click(p,'현재 진행으로 계정 만들기',72);
        await reveal(p,button(p,'별도로 보관했습니다'),64);await shot(p,`account-recovery-code-${tag}`);await click(p,'별도로 보관했습니다',64);
        await click(p,'로그아웃 · 게스트로 돌아가기',64);await chip(p,'복구');
        await input(p,field(p,'아이디'),'ui_qa');await input(p,field(p,'48자리 복구 코드'),'0123456789abcdef0123456789abcdef0123456789abcdef');
        await input(p,field(p,'새 비밀번호'),'qa-new-password-123');
        cloud=JSON.parse(JSON.stringify(await saved(p)));await click(p,'계정 복구',72);await reveal(p,button(p,'지금 동기화'),72);
        assert(requests.includes('auth/register')&&requests.includes('auth/recover'));
      }
      await click(p,'모든 기기 로그아웃',64);assert(!auth);await click(p,'Back',48);await click(p,'완료',72);
      assert.equal(stateIds(await saved(p)),original);
      await click(p,'비행 가이드');await shot(p,`guide-${tag}`);await stationary(p,button(p,'닫기').last());
      for(const [i,title]of ['01 이동','02 전방위 방어','03 보급과 진화','04 잔광을 남기세요'].entries()){
        await reveal(p,p.getByRole('heading',{name:title,exact:true}).last());await shot(p,`guide-step-${i+1}-${tag}`);
      }
      measured.push(await measure(p,'비행 준비 완료'));await click(p,'비행 준비 완료',72);assert.equal(stateIds(await saved(p)),original);
      await click(p,'진화');await click(p,'무기 진화 도감',48);await shot(p,`codex-${tag}`);await fixedHeader(p,'진화 도감');
      for(const label of ['펄스 블래스터','요격 드론','태양 기뢰','전격 기뢰','구급 요격대']){
        await click(p,`${label} 진화 상세`,64);await shot(p,`codex-${label}-${tag}`);
        await stationary(p,button(p,'닫기').last());await click(p,'도감으로',64);
      }
      await chip(p,'보조');await shot(p,`codex-passive-${tag}`);await click(p,'고밀도 탄약 진화 상세',64);
      await shot(p,`codex-passive-detail-${tag}`);await click(p,'도감으로',64);
      assert.equal(stateIds(await saved(p)),original);
      await reload(p);s=await saved(p);assert.equal(stateIds(s),original);
      assert.equal(s.soundEnabled,true);assert.equal(s.reducedEffects,true);assert(Math.abs(s.volume-.6)<.001);
      rows.push({width,height,scale,measured,fixedWheelAndTouch:true,licensePackageListAndFixedFullText:true,
        loginRegisterRecoveryForms:true,loginValidationAndActualLocalClient:true,conflictCancelAndDeviceConfirmWithBackups:true,
        settingsSavedAndRestored:true,guideFourStepsAndCompletion:true,codexWeaponFusionAndPassiveReadOnly:true,
        inventoryEquipmentPresetsAndBalancesPreserved:true,representativeRegisterRecovery:width===390&&scale===1.3,
        requests,transport:'All account/cloud requests intercepted locally; no real account writes.'});
      await context.close();
    }
    assert.deepEqual(errors,[]);fs.writeFileSync(path.join(out,'browser-result.json'),JSON.stringify({rows,errors,scope:'Local release web, isolated guests, actual TextScaler 1/1.3; wheel and CDP touch; account/cloud transport stubs.'},null,2));console.log(JSON.stringify({passed:rows.length,errors}));
  }catch(e){if(last&&!last.isClosed()){await shot(last,'failure');fs.writeFileSync(path.join(out,'failure-semantics.txt'),await last.locator('body').innerText());}throw e;}
  finally{await browser.close();}
})();
