import {validModuleFleet} from './module_config.mjs';
// Pure validation: no ownership, money or progress is granted here.
const mounts={main:['cannon'],auxiliary:['turret','auxShield'],wings:['wing'],rear:['rear'],ground:['bomb'],armor:['armor','reinforce'],supportLeft:['repair','capacitor','ward'],supportRight:['repair','capacitor','ward'],supportRear:['repair','capacitor','ward']};
const petParts=['capacitor','repair','ward'];
export function validAircraft(config, profile, hull=profile.selectedShip){
 if(!config||config.version!==1||!config.parts||Array.isArray(config.parts)||typeof config.parts!=='object'||Object.keys(config.parts).length>9||config.parts.main!=='cannon')return false;
 if(!Number.isInteger(hull)||hull<0||hull>2||!profile.unlockedShips?.includes(hull))return false;
 const supports=[];
 for(const [mount,id] of Object.entries(config.parts)){
  if(!Object.hasOwn(mounts,mount)||!mounts[mount].includes(id))return false;
  if(mount.startsWith('support')){
   if(supports.includes(id)||!(profile.content?.petLevels?.[petParts.indexOf(id)]>0))return false;
   supports.push(id);
  }
 }
 return true;
}
export function validAircraftSnapshot(profile){
 if(profile.moduleFleet!==undefined)return validModuleFleet(profile.moduleFleet,profile);
 if(profile.aircraft===undefined)return true; // old saves migrate in the client
 if(!validAircraft(profile.aircraft,profile))return false;
 return !profile.hangarPresets || (Array.isArray(profile.hangarPresets)&&profile.hangarPresets.length<=6&&profile.hangarPresets.every(p=>!p||p.aircraft===undefined||validAircraft(p.aircraft,profile,p.ship)));
}
