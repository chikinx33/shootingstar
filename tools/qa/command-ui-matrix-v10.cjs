// Full existing assertions, one independent browser/process/output per condition.
const {spawn}=require('child_process'),fs=require('fs'),path=require('path'),assert=require('assert');
const root=path.resolve(__dirname,'../..'),out=path.join(__dirname,'evidence/command-ui-20261017');
const cases=[320,360,390,430].flatMap(width=>[1,1.3].map(scale=>({width,scale,id:`v10-${width}-scale-${scale}`})));
const queue=[...cases],failures=[];
async function worker(){while(queue.length){const row=queue.shift();console.log('command mobile case',row.id);
 const log=fs.createWriteStream(path.join(root,'.local',row.id+'-command.log'));
 const child=spawn(process.execPath,[path.join(__dirname,'command-ui-20261017.cjs')],{
  cwd:root,env:{...process.env,QA_WIDTH:String(row.width),QA_SCALE:String(row.scale),QA_CASE:row.id,QA_FINAL_LABELS:'0'},stdio:['ignore','pipe','pipe']});
 child.stdout.pipe(log,{end:false});child.stderr.pipe(log,{end:false});
 const code=await new Promise((resolve,reject)=>{child.on('exit',resolve);child.on('error',reject)});log.end();
 if(code!==0)failures.push({case:row.id,code});else console.log('command mobile passed',row.id);
}}
(async()=>{
 await Promise.all(Array.from({length:4},()=>worker()));assert.deepEqual(failures,[],'inspect per-case logs');
 const rows=[],errors=[];
 for(const row of cases){const result=JSON.parse(fs.readFileSync(path.join(out,row.id,'browser-result.json')));assert.equal(result.rows.length,1);rows.push({...result.rows[0],evidenceDirectory:row.id});errors.push(...result.errors);}
 assert.equal(new Set(rows.map(r=>r.width+'/'+r.scale)).size,8);assert.deepEqual(errors,[]);
 fs.writeFileSync(path.join(out,'browser-result.json'),JSON.stringify({rows,errors,scope:'Final V10 release web. Full guild/preset/research/chapter assertions in independent Chrome processes for each of eight mobile size/scale conditions; four workers, isolated guest state and API stubs.'},null,2));
 console.log(JSON.stringify({passed:rows.length,errors}));
})().catch(e=>{console.error(e);process.exitCode=1});
