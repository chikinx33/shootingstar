const {chromium}=require('playwright'),fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','completion-v25');fs.mkdirSync(out,{recursive:true});
const button=(p,n)=>p.getByRole('button',typeof n==='string'?{name:n,exact:true}:{name:n}).last();
async function ready(p){for(let i=0;i<150;i++){const a=p.locator('flt-semantics-placeholder');if(await a.count())await a.evaluate(e=>e.click());if(await button(p,'선택 완료').count()||await p.getByRole('button',{name:/출격 기록 상세$/}).count())break;await p.waitForTimeout(100);}await p.waitForLoadState('networkidle');}
async function click(p,n){const b=await reveal(p,n);await p.mouse.click(b.x+b.width/2,b.y+b.height/2);await p.waitForTimeout(400);}
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'}),errors=[],matrix=process.env.WORLDS_ONLY?JSON.parse(fs.readFileSync(path.join(out,'failure.json'),'utf8')).matrix:[],worlds=[];
 try{
  if(!process.env.WORLDS_ONLY) for(const width of [320,360,390,430])for(const scale of [1,1.3]){
   const c=await browser.newContext({viewport:{width,height:568},isMobile:true,hasTouch:true});
   await c.route('**/api/**',r=>r.fulfill({status:401,contentType:'application/json',body:'{}'}));
   const p=await c.newPage();p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});p.setDefaultTimeout(10000);
   await p.goto(process.env.QA_URL+'/?textScale='+scale);await ready(p);
   const before=await p.evaluate(()=>localStorage.getItem('flutter.shootingstar.profile.v1'));
   await p.screenshot({path:path.join(out,`records-${width}-${scale}.png`)});
   await click(p,p.getByRole('button',{name:/출격 기록 상세$/}).first());
   await reveal(p,button(p,'영구 연구 보기'));
   await p.screenshot({path:path.join(out,`next-step-${width}-${scale}.png`)});
   await click(p,button(p,'영구 연구 보기'));
   await p.getByText('영구 연구',{exact:true}).first().waitFor();
   assert.equal(await p.evaluate(()=>localStorage.getItem('flutter.shootingstar.profile.v1')),before);
   assert.equal(await p.evaluate(()=>document.documentElement.scrollHeight>innerHeight),false);
   matrix.push({width,scale,history:true,detail:true,realResearchNavigation:true,noSpend:true});console.log('matrix',width,scale);await c.close();
  }
  const c=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
  const p=await c.newPage();p.setDefaultTimeout(10000);p.on('pageerror',e=>errors.push(e.message));
  for(let world=0;world<10;world++){
   await p.goto(process.env.QA_URL+'/?mode=world&world='+world);await ready(p);
   await click(p,button(p,new RegExp('^(?:선택 중 · )?'+(world+1)+'-1 ·')));
   await reveal(p,button(p,'이 항로 선택'));
   await p.screenshot({path:path.join(out,`briefing-${world}.png`)});
   worlds.push(world);console.log('briefing',world);
  }
  await c.close();assert.deepEqual(errors,[]);
  fs.writeFileSync(path.join(out,'summary.json'),JSON.stringify({version:'v10.0.25',matrix,worlds,errors},null,2));
 }catch(e){fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:e.message,errors,matrix,worlds},null,2));throw e;}
 finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
