const weaponParts=new Set(['gun_vulcan','missile_hawk','drone_wasp']);
const supportParts=new Set(['shield','repair','armor','sensor','capacitor','magnet','thruster']);
export function validModuleFleet(fleet,profile){
 if(!fleet||fleet.version!==1||!Array.isArray(fleet.owned)||fleet.owned.length>4096||!Number.isSafeInteger(fleet.serial)||fleet.serial<1)return false;
 if(!Array.isArray(profile.unlockedShips)||!profile.unlockedShips.includes(profile.selectedShip))return false;
 const owned=new Map();
 for(const p of fleet.owned){
  if(!p||typeof p.id!=='string'||!p.id.length||p.id.length>80||owned.has(p.id)||
    (!weaponParts.has(p.part)&&!supportParts.has(p.part))||!Number.isInteger(p.level)||p.level<1||p.level>40)return false;
  owned.set(p.id,p);
 }
 if(!fleet.loadouts||typeof fleet.loadouts!=='object'||Array.isArray(fleet.loadouts)||Object.keys(fleet.loadouts).length>3)return false;
 if(!Object.hasOwn(fleet.loadouts,String(profile.selectedShip)))return false;
 for(const [hull,loadout] of Object.entries(fleet.loadouts)){
  if(!['0','1','2'].includes(hull)||!profile.unlockedShips.includes(Number(hull))||!loadout||typeof loadout!=='object'||Array.isArray(loadout)||Object.keys(loadout).length>7)return false;
  const instances=new Set(),supports=new Set();
  for(const [mount,id] of Object.entries(loadout)){
   const p=owned.get(id);if(!p||instances.has(id))return false;
   instances.add(id);
   if(['W1','W2','W3','W4'].includes(mount)){if(!weaponParts.has(p.part))return false;}
   else if(['S1','S2','S3'].includes(mount)){if(!supportParts.has(p.part)||supports.has(p.part))return false;supports.add(p.part);}
   else return false;
  }
 }
 if(!fleet.airframeLevels||typeof fleet.airframeLevels!=='object'||Array.isArray(fleet.airframeLevels)||
  Object.entries(fleet.airframeLevels).some(([h,l])=>!['0','1','2'].includes(h)||!Number.isInteger(l)||l<1||l>40))return false;
 if(!Array.isArray(fleet.convertedGear)||fleet.convertedGear.length>8192||fleet.convertedGear.some(id=>!Number.isSafeInteger(id)||id<1))return false;
 return true;
}
