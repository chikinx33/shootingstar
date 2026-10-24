import {test} from 'node:test';
import assert from 'node:assert/strict';
import {validAircraftSnapshot} from '../src/aircraft_config.mjs';
const base=()=>({selectedShip:0,unlockedShips:[0],content:{petLevels:[1,0,0]},aircraft:{version:1,parts:{main:'cannon',auxiliary:'turret',supportLeft:'capacitor'}}});
test('modular cloud snapshot accepts legacy and preserves only owned compatible parts',()=>{
 assert.equal(validAircraftSnapshot({}),true);
 assert.equal(validAircraftSnapshot(base()),true);
 for(const change of [p=>delete p.aircraft.parts.main,p=>p.aircraft.parts.main='bomb',p=>p.aircraft.parts.supportRight='capacitor',p=>p.aircraft.parts.supportRear='ward',p=>p.aircraft.parts.cheat='turret',p=>p.selectedShip=2,p=>p.aircraft.version=2]){
  const p=base();change(p);assert.equal(validAircraftSnapshot(p),false);
 }
 const p=base();p.content.petLevels=[1,1,1];p.unlockedShips=[0,1,2];p.selectedShip=2;p.aircraft.parts.supportRear='ward';
 p.hangarPresets=[{ship:1,aircraft:{version:1,parts:{main:'cannon',ground:'bomb'}}}];
 const before=structuredClone(p);assert.equal(validAircraftSnapshot(p),true);assert.deepEqual(p,before);
 p.hangarPresets[0].aircraft.parts.ground='turret';assert.equal(validAircraftSnapshot(p),false);
});
