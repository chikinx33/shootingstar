const {chromium}=require('playwright');const fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','slow-replay-v21');fs.mkdirSync(out,{recursive:true});
const button=(p,n)=>p.getByRole('button',{name:typeof n==='string'?new RegExp('^'+n+'(?: '+n+')?$'):n}).last();
async function ready(p,n){for(let i=0;i<160;i++){const a=p.locator('flt-semantics-placeholder');if(await a.count())await a.evaluate(e=>e.click());if(await button(p,n).count()){await p.waitForTimeout(250);return;}await p.waitForTimeout(100);}throw Error('not ready '+n);}
async function click(p,n){const l=button(p,n);await l.waitFor();let b=await l.boundingBox();if(!b||b.y<0||b.y+b.height>p.viewportSize().height+.5)b=await reveal(p,l);await p.mouse.click(b.x+b.width/2,b.y+b.height/2);}
async function state(p){const l=p.locator('[aria-label^="QA_STATE "]').last();const text=await l.count()?await l.getAttribute('aria-label'):await p.getByText(/^QA_STATE /).last().textContent();return JSON.parse(text.slice(9));}
(async()=>{const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'}),rows=[],errors=[];
try{for(const [width,height]of [[320,568],[360,640],[390,844],[430,932]])for(const scale of[1,1.3]){
 const tag=width+'-'+scale;if(process.env.QA_ONLY&&tag!==process.env.QA_ONLY)continue;
 if(process.env.QA_RESUME&&fs.existsSync(path.join(out,'row-'+tag+'.json'))){rows.push(JSON.parse(fs.readFileSync(path.join(out,'row-'+tag+'.json'),'utf8')));continue;}
 console.log('start '+tag);const c=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
 await c.route('https://**',r=>r.abort());await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{}'}));
 const p=await c.newPage();p.setDefaultTimeout(8000);p.on('pageerror',e=>errors.push({tag,error:e.message}));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by|Bad state:|No element/.test(m.text()))errors.push({tag,error:m.text()});});
 const row={width,height,textScale:scale};
 try{
  await p.goto('http://127.0.0.1:8799/?scene=flight&textScale='+scale);await ready(p,'일시정지');
  const a=await state(p);await p.waitForTimeout(700);const b=await state(p);row.idleDelta=b.elapsed-a.elapsed;assert(row.idleDelta>.015&&row.idleDelta<.07,'idle clock '+row.idleDelta);
  await p.screenshot({path:path.join(out,'slow-'+tag+'.png')});
  const field=p.getByText('전투 영역',{exact:true}).last();const bb=await field.boundingBox();assert(bb);const x=width*.5,y=bb.y+(height-bb.y)*.6;
  const cdp=await c.newCDPSession(p);await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y}]});
  await p.waitForTimeout(70);const heldStart=await state(p);await p.waitForTimeout(700);const heldEnd=await state(p);row.heldDelta=heldEnd.elapsed-heldStart.elapsed;assert(row.heldDelta>.4,'hold clock '+row.heldDelta);assert(row.heldDelta/row.idleDelta>10);
  await p.screenshot({path:path.join(out,'held-'+tag+'.png')});await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await p.waitForTimeout(60);
  const upStart=await state(p);await p.waitForTimeout(700);row.releasedDelta=(await state(p)).elapsed-upStart.elapsed;assert(row.releasedDelta<row.heldDelta*.13);
  await cdp.detach();await click(p,'일시정지');await button(p,'계속 비행').waitFor();const paused=await state(p);await p.waitForTimeout(250);assert.equal((await state(p)).elapsed,paused.elapsed);await click(p,'계속 비행');
  await p.goto('http://127.0.0.1:8799/?scene=lab&textScale='+scale);await ready(p,'연출 바로 재현');await click(p,'연출 바로 재현');await p.waitForTimeout(250);
  await p.mouse.move(width/2,height-20);await p.waitForTimeout(180);await p.screenshot({path:path.join(out,'launcher-'+tag+'.png')});
  for(const [kind,label]of [['magnet','자석 흡수'],['boss','보스 클리어'],['reward','보상 수령'],['purchase','구매 연출']]){
    await click(p,new RegExp('^'+label+' 바로 재현'));if(kind==='magnet'||kind==='boss')await button(p,'테스트로 돌아가기').waitFor();
    if(kind==='magnet'){
      await p.waitForTimeout(300);await p.screenshot({path:path.join(out,'magnet-'+tag+'.png')});
      await button(p,/^집속 펄스/).waitFor({timeout:4000});await p.waitForTimeout(280);await p.screenshot({path:path.join(out,'magnet-choice-'+tag+'.png')});
    }else if(kind==='boss'){
      await p.waitForTimeout(800);await p.screenshot({path:path.join(out,'boss-burst-'+tag+'.png')});
      await p.waitForTimeout(2200);await p.screenshot({path:path.join(out,'boss-clear-'+tag+'.png')});
      await p.getByRole('group',{name:/CHAPTER COMPLETE.*항로를 밝혔습니다/}).first().waitFor({timeout:5000});assert.equal(await button(p,'일시정지').isEnabled(),false);await p.screenshot({path:path.join(out,'boss-result-'+tag+'.png')});
    }else{
      await button(p,'보상 닫기').waitFor();await p.waitForTimeout(350);await p.screenshot({path:path.join(out,kind+'-receipt-'+tag+'.png')});
      await click(p,'확인');await p.waitForTimeout(300);await p.screenshot({path:path.join(out,kind+'-transfer-'+tag+'.png')});
      await p.waitForTimeout(1000);
    }
    await click(p,'테스트로 돌아가기');await p.waitForTimeout(250);await button(p,/^자석 흡수 바로 재현/).waitFor();
  }
  row.replays=['magnet','boss','reward','purchase'];row.pause=true;rows.push(row);fs.writeFileSync(path.join(out,'row-'+tag+'.json'),JSON.stringify(row,null,2));console.log('passed '+tag);
 }catch(e){await p.screenshot({path:path.join(out,'failure-'+tag+'.png')});fs.writeFileSync(path.join(out,'failure-'+tag+'.txt'),await p.locator('body').ariaSnapshot());throw e;}finally{await c.close();}
}assert.deepEqual(errors,[]);fs.writeFileSync(path.join(out,'summary'+(process.env.QA_ONLY?'-'+process.env.QA_ONLY:'')+'.json'),JSON.stringify({version:'v10.0.21',rows,errors},null,2));console.log('passed '+rows.length+' conditions');
}finally{await browser.close();}})().catch(e=>{console.error(e);process.exit(1);});
