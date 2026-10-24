const {chromium}=require('playwright');
const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=process.env.QA_EVIDENCE_DIR||path.join(__dirname,'evidence','catalog-fixed-ui-20261017');
fs.mkdirSync(out,{recursive:true});
const key='flutter.shootingstar.profile.v1';
(async()=>{
  let browser;
  const rows=[],errors=[];let last;
  const button=(p,name)=>p.getByRole('button',{name,exact:true});
  async function click(p,name,height=20){const l=button(p,name).first();await reveal(p,l,height);await l.click();await p.waitForTimeout(220);}
  async function chip(p,name){const l=p.getByRole('checkbox',{name,exact:true});await reveal(p,l);await l.click();await p.waitForTimeout(200);}
  async function semantics(p) {
    for(let attempt=0;attempt<160;attempt++) {
      if(await p.locator('flt-semantics-placeholder').count())
        await p.locator('flt-semantics-placeholder').evaluate(e=>e.click());
      if(await p.locator('flt-semantics [role="button"],flt-semantics[role="button"]').count()) {
        await p.waitForTimeout(250);return;
      }
      await p.waitForTimeout(250);
    }
    throw Error('Flutter game semantics did not become ready');
  }
  async function saved(p){return p.evaluate(key=>{let s=localStorage.getItem(key);for(let i=0;i<3&&typeof s==='string';i++)s=JSON.parse(s);return s;},key);}
  async function reload(p){await p.reload();await p.waitForTimeout(850);await semantics(p);}
  async function shot(p,name){await p.waitForTimeout(200);await p.screenshot({path:path.join(out,name+'.png')});}
  async function bounds(p,names){return Promise.all(names.map(async name=>({name,...await button(p,name).boundingBox()})));}
  async function stationary(p,names,at){
    const before=await bounds(p,names);
    await p.mouse.move(at.x,at.y);await p.mouse.wheel(0,500);await p.waitForTimeout(160);
    await p.mouse.wheel(0,-500);await p.waitForTimeout(160);
    const cdp=await p.context().newCDPSession(p);
    await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:at.x,y:at.y}]});
    for(let i=1;i<=4;i++)await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:at.x,y:at.y-i*25}]});
    await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await p.waitForTimeout(250);
    const after=await bounds(p,names);
    assert.deepEqual(after,before,'fixed UI moved after wheel/touch '+JSON.stringify({before,after}));return before;
  }
  async function measure(p,name,primary=true){const b=await reveal(p,button(p,name).first(),primary?72:64);
    assert(b.width<=264.2&&b.width/b.height<=4.25,JSON.stringify({name,...b}));return{name,...b};}
  async function listHeader(p,title,item){
    const h=p.getByText(title,{exact:true}).last(),before=await h.boundingBox();
    await p.mouse.move(p.viewportSize().width*.55,p.viewportSize().height*.7);await p.mouse.wheel(0,180);await p.waitForTimeout(200);
    assert.deepEqual(await h.boundingBox(),before,'list moved fixed header');
    if(item)await reveal(p,button(p,item).first(),72);return before;
  }
  try{
    for(const [width,height]of [[320,568],[360,640],[390,844],[430,932]])for(const scale of [1,1.3]){
      console.log('catalog fixed',width,scale);
      if(browser)await browser.close();
      browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
      const c=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
      await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{"error":"isolated QA"}'}));
      const p=await c.newPage();last=p;
      p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
      await p.goto(scale===1?'http://127.0.0.1:8797/?ui=catalog-fixed':`http://127.0.0.1:8798/?scene=menus&textScale=${scale}`);
      await p.waitForTimeout(900);await semantics(p);
      const tag=`${width}-scale-${scale}`,measured=[];
      const lobbyNames=['잔광 외곽 1-1 · 출격','임무·출석','시즌 보상','순찰','길드','비행 가이드','45초 훈련'];
      const before=await saved(p);
      const lobby=await stationary(p,lobbyNames,{x:width*.5,y:height*.47});
      for(const b of lobby){assert(b.height>=48);assert(b.x>=0&&b.x+b.width<=width+.1);assert(b.y>=0&&b.y+b.height<=height+.1);}
      assert.deepEqual(await saved(p),before);await shot(p,`lobby-${tag}`);
      // One real UI claim creates the guest save. Fixture resources remain isolated.
      await click(p,'보급');await click(p,'장비 보급 열기',72);await click(p,'확인',72);
      let s=await saved(p);s.onboarded=true;s.soundEnabled=false;s.credits=7000;
      s.content.seasonXp=2000;s.content.collections.keys=2;s.content.collections.dust=3;
      s.content.mail=[{id:'fixed-ui-mail',title:'오래 보관한 원정 지원 보상',credits:70,plans:3,food:15,gearKeys:1,techKeys:1,eggs:1,claimed:false}];
      s.hangarPresets[0]={name:'보존할 편성',ship:0,pilot:0,armament:0,equipment:0,gearIds:[1,2,3,4,5,6],techIds:[],pet:0,assistPets:[]};
      const ids=s.content.inventory.map(g=>g.id),gearState=JSON.stringify(s.content.inventory);
      await p.evaluate(({key,s})=>localStorage.setItem(key,JSON.stringify(JSON.stringify(s))),{key,s});await reload(p);
      assert.equal(JSON.stringify((await saved(p)).content.inventory),gearState);
      await click(p,'보급');await shot(p,`shop-${tag}`);
      await listHeader(p,'함대 보급','테크 보급 열기');await shot(p,`shop-tech-${tag}`);
      await chip(p,'교환');await shot(p,`exchange-${tag}`);
      measured.push(await measure(p,'먹이 교환'));
      const food=s.content.petFood,credits=s.credits;
      await click(p,'먹이 교환',72);s=await saved(p);
      assert.equal(s.credits,credits-60);assert.equal(s.content.petFood,food+30);
      const once=JSON.stringify(s);await click(p,'확인',72);assert.equal(JSON.stringify(await saved(p)),once);
      await click(p,'출격');await click(p,'시즌 보상');
      await shot(p,`season-${tag}`);await listHeader(p,'항성 원정','2단계 보상 수령');
      measured.push(await measure(p,'1단계 보상 수령'));
      await click(p,'1단계 보상 수령',72);s=await saved(p);assert(s.content.seasonClaims.includes(1));
      await shot(p,`season-reward-${tag}`);await click(p,'확인',72);
      assert(await button(p,'1단계 보상 수령').isDisabled());
      await chip(p,'임무');await shot(p,`season-missions-${tag}`);
      await chip(p,'우편');await shot(p,`mail-${tag}`);
      await listHeader(p,'보상 우편','우편 보상 받기');measured.push(await measure(p,'우편 보상 받기'));
      const mailCredits=(await saved(p)).credits;
      await click(p,'우편 보상 받기',72);s=await saved(p);assert.equal(s.credits,mailCredits+70);assert(s.content.mail[0].claimed);
      await shot(p,`mail-receipt-${tag}`);await click(p,'확인',72);assert.equal((await saved(p)).credits,mailCredits+70);
      assert(await button(p,'우편 보상 받기').isDisabled());
      await reload(p);await click(p,'성장');await chip(p,'관리');await click(p,'수집품 0/12');
      await shot(p,`collection-investigation-${tag}`);
      measured.push(await measure(p,'유물 조사 · 탐사권 1'));
      const fixedNames=['유물 조사 · 탐사권 1'];
      const inv=await button(p,fixedNames[0]).boundingBox();await stationary(p,fixedNames,{x:width*.5,y:Math.max(240,inv.y-30)});
      await click(p,'유물 조사 · 탐사권 1',72);s=await saved(p);assert.equal(s.content.collections.keys,1);assert.equal(s.content.collections.shards[0],3);
      await shot(p,`collection-receipt-${tag}`);await click(p,'확인',72);
      await chip(p,'세트');await shot(p,`collection-sets-${tag}`);await listHeader(p,'항로 유물');
      await chip(p,'보관함');await shot(p,`collection-storage-${tag}`);await listHeader(p,'항로 유물');
      const detail=button(p,'초신성 프리즘 상세').last();await reveal(p,detail,64);await detail.click();await p.waitForTimeout(200);
      await shot(p,`collection-detail-${tag}`);
      measured.push(await measure(p,'조각 제작 · 가루 3',false));await click(p,'조각 제작 · 가루 3',64);
      await shot(p,`collection-craft-confirm-${tag}`);await click(p,'취소',64);
      assert.equal((await saved(p)).content.collections.dust,3);
      await click(p,'조각 제작 · 가루 3',64);await click(p,'가루 3개 사용',72);
      s=await saved(p);assert.equal(s.content.collections.dust,0);assert.equal(s.content.collections.shards[0],4);
      await reload(p);s=await saved(p);
      assert.deepEqual(s.content.inventory.map(g=>g.id),ids);assert.deepEqual(s.content.equippedGear,[1,2,3,4,5,6]);
      assert.equal(s.hangarPresets[0].name,'보존할 편성');assert(s.content.mail[0].claimed);assert(s.content.seasonClaims.includes(1));assert.equal(s.content.collections.shards[0],4);
      rows.push({width,height,scale,lobby,measured,noLobbyWheelOrTouchScroll:true,fixedListHeaders:true,
        investigationFixedPages:true,exchangeClaimOnce:true,seasonClaimOnce:true,mailClaimOnce:true,
        collectionCraftCancelAndConfirm:true,savedIdsAndLoadoutRestored:true});
      await c.close();
    }
    assert.deepEqual(errors,[]);
    fs.writeFileSync(path.join(out,'browser-result.json'),JSON.stringify({rows,errors,scope:'Local release Flutter web; isolated guests; 130% Flutter TextScaler, wheel and CDP touch. Model eligibility resources seeded only in isolated guest storage; actual UI claims/costs/reload verified.'},null,2));
    console.log(JSON.stringify({passed:rows.length,errors}));
  }catch(e){if(last&&!last.isClosed()){await shot(last,'failure');fs.writeFileSync(path.join(out,'failure-semantics.txt'),await last.locator('body').innerText());}throw e;}
  finally{if(browser)await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
