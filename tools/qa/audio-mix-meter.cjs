// Observational taps directly after each application GainNode. The original
// audible output stays connected. Summed window peaks are a conservative bound,
// not a recording of the phase-aligned hardware mix or a listening assessment.
function installMeter(){
 const Native=window.AudioContext, contexts=[],media=new Set(),events=[],samples=[],taps=new Map();
 window.AudioContext=new Proxy(Native,{construct(T,args){const c=Reflect.construct(T,args);contexts.push(c);return c;}});
 const source=Native.prototype.createMediaElementSource,gain=Native.prototype.createGain;
 Native.prototype.createMediaElementSource=function(el){media.add(el);taps.set(this,{el,analyser:null,gain:null});return source.call(this,el);};
 Native.prototype.createGain=function(){const n=gain.call(this),tap=taps.get(this);if(tap){const a=this.createAnalyser();a.fftSize=4096;n.connect(a);tap.analyser=a;tap.gain=n;}return n;};
 const event=(kind,el)=>events.push({kind,file:el.src.split('/').pop(),at:performance.now(),position:el.currentTime,duration:Number.isFinite(el.duration)?el.duration:0,loop:el.loop});
 const play=HTMLMediaElement.prototype.play,pause=HTMLMediaElement.prototype.pause;
 HTMLMediaElement.prototype.play=function(){return play.call(this).then(v=>{event('play',this);return v;});};
 HTMLMediaElement.prototype.pause=function(){if(!this.paused&&!this.ended&&this.currentTime>.005)event('interrupt',this);return pause.call(this);};
 const buf=new Float32Array(4096);
 const measure=a=>{a.getFloatTimeDomainData(buf);let sum=0,peak=0;for(const x of buf){sum+=x*x;peak=Math.max(peak,Math.abs(x));}return {rms:Math.sqrt(sum/buf.length),peak};};
 let mark=performance.now();
 const timer=setInterval(()=>{
  const voices=[];for(const [,t] of taps){if(t.analyser&&!t.el.paused&&!t.el.ended)voices.push({file:t.el.src.split('/').pop(),loop:t.el.loop,gain:t.gain.gain.value,...measure(t.analyser)});}
  samples.push({at:performance.now()-mark,peakUpperBound:voices.reduce((s,v)=>s+v.peak,0),voices});if(samples.length>6000)samples.shift();
 },40);
 window.mixReport=()=>({events,samples,contexts:contexts.length,applicationMedia:[...media].filter(e=>!e.paused&&!e.ended).map(e=>({file:e.src.split('/').pop(),loop:e.loop,time:e.currentTime})),scope:'direct post-gain analysers; sum of simultaneous window peaks is a conservative bound, not phase-aligned mixed output'});
 window.mixMark=()=>{samples.length=0;events.length=0;mark=performance.now();};
 window.mixStop=()=>clearInterval(timer);
}
module.exports={installMeter};
