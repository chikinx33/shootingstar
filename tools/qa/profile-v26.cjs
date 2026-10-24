// Local-only CPU diagnosis. No API requests or persistent game writes.
const {chromium}=require('playwright'),fs=require('fs');
(async()=>{const b=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
try{const c=await b.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true}),p=await c.newPage();await c.route('**/api/**',r=>r.abort());
const s=await c.newCDPSession(p);await s.send('Emulation.setCPUThrottlingRate',{rate:4});await p.goto('http://127.0.0.1:8799/?mode=stress');
for(let i=0;i<150;i++){const a=p.locator('flt-semantics-placeholder');if(await a.count())await a.evaluate(e=>e.click());if(await p.getByRole('button',{name:'일시정지',exact:true}).count())break;await p.waitForTimeout(100);}
await s.send('Profiler.enable');await s.send('Profiler.start');await p.waitForTimeout(12000);const {profile}=await s.send('Profiler.stop');
fs.writeFileSync('.local/complete-v26/dense.cpuprofile',JSON.stringify(profile));
const lines=fs.readFileSync('build/qa-v26/main.dart.js','utf8').split('\n');
const top=profile.nodes.filter(n=>n.hitCount).sort((a,b)=>b.hitCount-a.hitCount).slice(0,22).map(n=>({hits:n.hitCount,name:n.callFrame.functionName,line:n.callFrame.lineNumber,column:n.callFrame.columnNumber,url:n.callFrame.url.includes('main.dart')?'main.dart.js':n.callFrame.url,code:n.callFrame.url.includes('main.dart')?lines[n.callFrame.lineNumber]?.slice(Math.max(0,n.callFrame.columnNumber-50),n.callFrame.columnNumber+170):''}));
fs.writeFileSync('.local/complete-v26/cpu-top.json',JSON.stringify(top,null,2));console.log(top);
}finally{await b.close();}})().catch(e=>{console.error(e);process.exit(1)});
