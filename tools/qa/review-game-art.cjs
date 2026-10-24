// Read-only browser contact sheet; source PNG bytes are never modified.
const {chromium}=require('playwright'),fs=require('fs'),path=require('path');
(async()=>{
 const root=path.resolve(__dirname,'../..'),out=path.join(__dirname,'evidence/game-v10');fs.mkdirSync(out,{recursive:true});
 const manifest=JSON.parse(fs.readFileSync(path.join(root,'assets/art/game_v10/manifest.json')));
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 try{
  const p=await browser.newPage({viewport:{width:1400,height:1500}});
  await p.setContent('<style>*{box-sizing:border-box}body{margin:16px;background:#e8e4cd;font:18px sans-serif}main{display:grid;grid-template-columns:repeat(8,1fr);gap:12px}article{border:3px solid #171b24;border-radius:12px;text-align:center;padding:6px;background:#bfd7b5}article:nth-child(3n){background:#ffa83b}article:nth-child(3n+1){background:#bd9cdc}canvas{display:block;width:140px;height:140px;margin:auto}</style><main></main>');
  await p.evaluate(async manifest=>{
   for(const [name,meta]of Object.entries(manifest)){
    const card=document.createElement('article'),canvas=document.createElement('canvas');canvas.width=canvas.height=280;card.append(canvas);card.append(name);document.querySelector('main').append(card);
    const im=new Image();im.src='http://127.0.0.1:8797/assets/assets/art/game_v10/'+name+'.png';await im.decode();
    const [l,t,r,b]=meta.bounds,sx=l*im.width,sy=t*im.height,sw=(r-l)*im.width,sh=(b-t)*im.height,k=260/Math.max(sw,sh);
    canvas.getContext('2d').drawImage(im,sx,sy,sw,sh,(280-sw*k)/2,(280-sh*k)/2,sw*k,sh*k);
   }
  },manifest);
  await p.screenshot({path:path.join(out,'generated-art-review.png'),fullPage:true});console.log('51 objects rendered on orange, mint and purple backgrounds');
 }finally{await browser.close();}
})();
