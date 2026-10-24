// Production widgets on an isolated QA origin; actual SDK paths stay disabled.
const {chromium}=require('playwright'),fs=require('fs'),path=require('path'),assert=require('assert');
const {reveal}=require('./web-ui-navigation.cjs');
const out=path.join(__dirname,'evidence','commerce-v29');fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'}),matrix=[],errors=[];
 try{
  for(const width of [320,360,390,430])for(const scale of [1,1.3]){
   const context=await browser.newContext({viewport:{width,height:568},isMobile:true,hasTouch:true});
   await context.route('**/api/**',r=>r.abort());await context.route('https://**',r=>r.abort());
   const p=await context.newPage();p.setDefaultTimeout(12000);
   p.on('pageerror',e=>errors.push(e.message));p.on('console',m=>{if(/EXCEPTION CAUGHT|overflowed by/.test(m.text()))errors.push(m.text());});
   await p.goto(process.env.QA_URL+'/?scale='+scale);
   for(let i=0;i<120;i++){const a=p.locator('flt-semantics-placeholder');if(await a.count())await a.evaluate(e=>e.click());if(await p.getByRole('button',{name:'기본 외형과 비교',exact:true}).count())break;await p.waitForTimeout(100);}
   await p.waitForLoadState('networkidle');
   const compare=p.getByRole('button',{name:'기본 외형과 비교',exact:true});const box=await reveal(p,compare);
   assert(box.height>=64,'painted secondary control keeps minimum height');
   await p.screenshot({path:path.join(out,`preview-${width}-${scale}.png`)});
   await compare.click();await reveal(p,p.getByRole('button',{name:'후원 외형 미리보기',exact:true}));
   await p.getByRole('button',{name:'후원 외형 미리보기',exact:true}).click();
   await reveal(p,p.getByText('선택형 추가 보상',{exact:true}));
   const explanation=p.getByText(/^광고 완료·서버 확인 후 20 C/);await reveal(p,explanation);
   assert.equal(await p.evaluate(()=>document.documentElement.scrollHeight>innerHeight),false);
   const before=await explanation.boundingBox();await p.mouse.wheel(0,600);assert.deepEqual(await explanation.boundingBox(),before);
   const touch=await context.newCDPSession(p);await touch.send('Input.synthesizeScrollGesture',{x:width/2,y:300,yDistance:-220,speed:600,gestureSourceType:'touch'});assert.deepEqual(await explanation.boundingBox(),before);
   assert.equal(await p.getByRole('button',{name:/구매/}).count(),0,'unconfigured web has no checkout');
   await p.screenshot({path:path.join(out,`reward-${width}-${scale}.png`)});
   matrix.push({width,scale,fixedPages:true,previewToggle:true,noCheckout:true,wheelAndTouchDoNotScroll:true});await context.close();console.log('mobile',width,scale);
  }
  assert.deepEqual(errors,[]);fs.writeFileSync(path.join(out,'summary.json'),JSON.stringify({version:'v10.0.29',scope:'isolated original Flutter widgets; no native SDK or production writes',matrix,errors},null,2));
 }catch(error){fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify({error:error.message,matrix,errors},null,2));throw error;}
 finally{await browser.close();}
})().catch(error=>{console.error(error);process.exit(1);});
