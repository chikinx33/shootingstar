const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','command-ui-20261017',process.env.QA_CASE||'');
fs.mkdirSync(out,{recursive:true});
const key='flutter.shootingstar.profile.v1';
const finalLabels=process.env.QA_FINAL_LABELS==='1';
(async()=>{
  let browser;
  const rows=[],errors=[];let last;
  const button=(p,name)=>p.getByRole('button',{name,exact:true});
  async function click(p,name,min=20){const l=button(p,name).first();await reveal(p,l,min);await l.click();await p.waitForTimeout(360);}
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
    const v=p.viewportSize(),x=v.width*.45,y=v.height*.46;
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
  try{
    for(const [width,height]of [[320,568],[360,640],[390,844],[430,932]])for(const scale of [1,1.3]){
      if(process.env.QA_WIDTH&&width!==+process.env.QA_WIDTH)continue;
      if(process.env.QA_SCALE&&scale!==+process.env.QA_SCALE)continue;
      console.log('command UI',width,scale);
      // Recycle the browser between conditions, not the app or its save.
      // Long CanvasKit suites otherwise retain old headless graphics contexts.
      if(browser)await browser.close();
      browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
      const c=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
      let auth=false,joined=false,coins=20,checked=0,fail=false,revision=1;
      const requests=[];
      await c.route('https://**',r=>r.abort());
      // All online writes are intercepted: no real accounts, guilds, or messages.
      await c.route('**/api/**',async r=>{
        const endpoint=new URL(r.request().url()).pathname.replace('/api/','');requests.push(endpoint);
        let status=200,body={};
        if(endpoint==='auth/me'){
          if(!auth){status=401;body={error:'isolated guest'};}
          else body={account:{id:'command-ui-qa',nickname:'QA'},profile:null,revision,updatedAt:1};
        }else if(endpoint==='cloud/write')body={revision:++revision,updatedAt:1};
        else if(endpoint==='cloud/read')body={revision,updatedAt:1};
        else if(endpoint.startsWith('guild/')){
          const action=endpoint.split('/')[1];
          if(fail&&action==='state'){status=503;body={error:'QA connection interrupted'};}
          else{
            if(['create','join'].includes(action))joined=true;
            if(action==='leave')joined=false;
            if(action==='checkin'){coins+=10;checked=1;}
            if(action==='donate'||action==='shop')coins-=10;
            body={guild:joined?{name:'별빛 원정대',id:'QA1234',xp:400}:null,
              directory:[{name:'모집 함대',id:'QA0001',members:3}],user:{coins,checkday:checked},day:1,
              week:'QA 주간',damage:100000,attempts:1,members:Array.from({length:20},(_,i)=>({name:`길드원 ${i+1}`})),
              rewards:action==='raid'?[{id:'qa-raid',credits:100}]:action==='shop'?[{id:'qa-supply',food:30,plans:2}]:[]};
          }
        }else{status=401;body={error:'isolated QA'};}
        await r.fulfill({status,contentType:'application/json',body:JSON.stringify(body)});
      });
      const p=await c.newPage();last=p;
      p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
      await p.goto(scale===1?'http://127.0.0.1:8797/?ui=command-ui':`http://127.0.0.1:8798/?scene=menus&online=1&textScale=${scale}`);await ready(p);
      const tag=`${width}-scale-${scale}`,measured=[];
      await click(p,'길드');await reveal(p,button(p,'계정 로그인 · 가입'),72);
      await stationary(p,button(p,'계정 로그인 · 가입'));await shot(p,`guild-guest-${tag}`);
      await reload(p);await click(p,'보급');await click(p,'장비 보급 열기',72);await click(p,'확인',72);
      let s=await saved(p);s.onboarded=true;s.soundEnabled=false;s.credits=10000;s.clearedStages=[0];
      const inventory=JSON.stringify(s.content.inventory),equipped=JSON.stringify(s.content.equippedGear);
      await p.evaluate(({key,s})=>localStorage.setItem(key,JSON.stringify(JSON.stringify(s))),{key,s});await reload(p);
      await click(p,'격납고');await click(p,'편성 저장·불러오기',64);await shot(p,`presets-empty-${tag}`);
      await fixedHeader(p,'출격 구성');
      await click(p,'현재 구성 저장',72);await shot(p,`preset-name-${tag}`);
      const field=p.getByRole('textbox',{name:'구성 이름',exact:true});await input(p,field,'보존 편성');
      measured.push(await measure(p,'저장'));await stationary(p,field);await click(p,'저장',72);
      s=await saved(p);assert.equal(s.hangarPresets[0].name,'보존 편성');await shot(p,`presets-saved-${tag}`);
      // A floating save notice is allowed to finish before seeking another item.
      await p.waitForTimeout(4300);
      if(finalLabels){
        measured.push(await measure(p,'현재 구성 덮어쓰기',false));
        measured.push(await measure(p,'구성 확인 · 적용'));
        await shot(p,`final-preset-labels-${tag}`);
        await click(p,'현재 구성 덮어쓰기',64);await shot(p,`final-preset-overwrite-${tag}`);
        await click(p,'취소',64);assert.equal((await saved(p)).hangarPresets[0].name,'보존 편성');
        await click(p,'구성 확인 · 적용',72);await shot(p,`final-preset-confirm-${tag}`);
        await reveal(p,button(p,'이 구성 적용'),72);await stationary(p,button(p,'이 구성 적용'));
        await click(p,'이 구성 적용',72);
        await reload(p);await click(p,'진화');await shot(p,`final-research-${tag}`);
        await click(p,'화력 1단계 연구',72);assert.equal((await saved(p)).attackLevel,1);
        await chip(p,'선체');await shot(p,`final-research-hull-${tag}`);
        await chip(p,'회수');await shot(p,`final-research-magnet-${tag}`);
        await reload(p);await click(p,'챕터 선택');await shot(p,`final-chapters-${tag}`);
        const stage=p.getByRole('button',{name:/^1-2 ·/}).first();await reveal(p,stage,88);await stage.click();await p.waitForTimeout(360);
        await shot(p,`final-chapter-detail-${tag}`);await click(p,'이 항로 선택',72);await click(p,'선택 완료',64);
        await reload(p);s=await saved(p);assert.equal(s.selectedStage,1);assert.equal(s.attackLevel,1);
        assert.equal(s.hangarPresets[0].name,'보존 편성');
        assert.equal(JSON.stringify(s.content.inventory),inventory);assert.equal(JSON.stringify(s.content.equippedGear),equipped);
        rows.push({width,height,scale,measured,finalPresetSaveOverwriteCancelApplyAndReload:true,
          guildGuestAndResearchChapterVisuals:true,fixedPageWheelAndTouch:true,inventoryAndEquippedIdsPreserved:true,
          scope:'Final shorter preset display labels. Full signed guild, all research branches, rename/delete and integration matrix remains recorded in browser-result.json; their UI source is unchanged.'});
        await c.close();continue;
      }
      await click(p,'구성 확인 · 적용',72);await shot(p,`preset-apply-${tag}`);
      await reveal(p,button(p,'이 구성 적용'),72);await stationary(p,button(p,'이 구성 적용'));
      await click(p,'적용 취소',64);assert.equal(JSON.stringify((await saved(p)).content.equippedGear),equipped);
      await click(p,'구성 확인 · 적용',72);await click(p,'이 구성 적용',72);await p.waitForTimeout(4300);
      await click(p,'이름 변경',64);await input(p,field,'새 편성');await click(p,'저장',72);
      assert.equal((await saved(p)).hangarPresets[0].name,'새 편성');
      await click(p,'삭제',64);await shot(p,`preset-delete-${tag}`);await click(p,'취소',64);assert((await saved(p)).hangarPresets[0]);
      await reload(p);await click(p,'진화');await shot(p,`research-attack-${tag}`);
      await fixedHeader(p,'진화 연구');measured.push(await measure(p,'화력 1단계 연구'));
      const credits=(await saved(p)).credits;
      await click(p,'화력 1단계 연구',72);s=await saved(p);assert.equal(s.attackLevel,1);assert.equal(s.credits,credits-80);
      await chip(p,'선체');await shot(p,`research-hull-${tag}`);await click(p,'선체 1단계 연구',72);
      await chip(p,'회수');await shot(p,`research-magnet-${tag}`);await click(p,'회수 1단계 연구',72);
      await click(p,'무기 진화 도감',48);await shot(p,`research-guide-${tag}`);await click(p,'Back',48);
      await reload(p);await click(p,'챕터 선택');await shot(p,`chapters-${tag}`);
      await fixedHeader(p,'항로 선택');
      const stage=p.getByRole('button',{name:/^1-2 ·/}).first();await reveal(p,stage,88);await stage.click();await p.waitForTimeout(360);
      await shot(p,`chapter-detail-${tag}`);measured.push(await measure(p,'이 항로 선택'));
      await stationary(p,button(p,'이 항로 선택'));await click(p,'이 항로 선택',72);assert.equal((await saved(p)).selectedStage,1);
      assert(await p.getByRole('button',{name:/^1-3 ·/}).first().isDisabled());await click(p,'선택 완료',64);
      auth=true;await reload(p);await click(p,'길드');await shot(p,`guild-forms-${tag}`);
      const name=p.getByRole('textbox',{name:'새 길드 이름',exact:true});await input(p,name,'별빛 원정대');
      await reveal(p,button(p,'길드 창설'),72);await stationary(p,button(p,'길드 창설'));await click(p,'길드 창설',72);
      assert(joined);await shot(p,`guild-overview-${tag}`);measured.push(await measure(p,'출석 · 코인 +10'));
      await stationary(p,button(p,'출석 · 코인 +10'));await click(p,'출석 · 코인 +10',72);assert.equal(coins,30);assert.equal(requests.filter(x=>x==='guild/checkin').length,1);
      await reveal(p,button(p,'오늘 출석 완료'));assert(await button(p,'오늘 출석 완료').isDisabled());
      await click(p,'기여 · 코인 10',64);assert.equal(coins,20);
      await chip(p,'토벌');await shot(p,`guild-raid-${tag}`);await reveal(p,button(p,'토벌 보상 우편 수령'),72);
      await stationary(p,button(p,'토벌 보상 우편 수령'));await click(p,'토벌 보상 우편 수령',72);await click(p,'토벌 보상 우편 수령',72);
      assert.equal((await saved(p)).content.mail.filter(m=>m.id==='qa-raid').length,1);
      await chip(p,'보급');await shot(p,`guild-supply-${tag}`);await click(p,'길드 코인 10 · 우편 지급',72);
      assert.equal((await saved(p)).content.mail.filter(m=>m.id==='qa-supply').length,1);assert.equal(coins,10);
      await chip(p,'길드원');await shot(p,`guild-members-${tag}`);await fixedHeader(p,'함께하는 함대');
      await chip(p,'현황');await click(p,'길드 탈퇴',64);await shot(p,`guild-leave-${tag}`);await click(p,'취소',64);assert(joined);
      await click(p,'길드 탈퇴',64);await click(p,'탈퇴',72);assert(!joined);
      await chip(p,'모집');await shot(p,`guild-directory-${tag}`);await click(p,'모집 함대 가입',72);assert(joined);
      fail=true;await click(p,'길드 새로고침');await shot(p,`guild-error-${tag}`);await reveal(p,button(p,'서버 다시 연결'),64);
      await stationary(p,button(p,'서버 다시 연결'));fail=false;await click(p,'서버 다시 연결',64);
      await reload(p);s=await saved(p);
      assert.equal(s.hangarPresets[0].name,'새 편성');assert.equal(s.selectedStage,1);
      assert.equal(s.attackLevel,1);assert.equal(s.hullLevel,1);assert.equal(s.magnetLevel,1);
      assert.equal(JSON.stringify(s.content.inventory),inventory);assert.equal(JSON.stringify(s.content.equippedGear),equipped);
      assert.equal(s.content.mail.filter(m=>m.id==='qa-raid').length,1);
      rows.push({width,height,scale,measured,fixedDetailWheelAndTouch:true,fixedListHeaders:true,
        presetSaveRenameApplyCancelDeleteCancel:true,researchThreeBranches:true,chapterLockAndSelection:true,
        guildFormsAttendanceDonationRaidSupplyMemberListLeaveCancelAndJoin:true,connectionRetry:true,
        saveReloadAndInventoryIdsPreserved:true,onlineTransport:'isolated local API stubs',requests});
      await c.close();
    }
    assert.equal(new Set(rows.map(r=>r.width+'/'+r.scale)).size,rows.length);
    assert.deepEqual(errors,[]);fs.writeFileSync(path.join(out,finalLabels?'final-labels-browser-result.json':'browser-result.json'),JSON.stringify({rows,errors,scope:'Flutter release web; four mobile sizes; actual TextScaler 1/1.3; isolated contexts and local API interception.'},null,2));
    console.log(JSON.stringify({passed:rows.length,errors}));
  }catch(e){if(last&&!last.isClosed()){await shot(last,'failure');fs.writeFileSync(path.join(out,'failure-semantics.txt'),await last.locator('body').innerText());}throw e;}
  finally{if(browser)await browser.close();}
})();
