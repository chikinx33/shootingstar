import {test} from 'node:test';
import assert from 'node:assert/strict';
import {validModuleFleet} from '../src/module_config.mjs';
const profile={selectedShip:0,unlockedShips:[0]};
const fleet=()=>({version:1,serial:4,owned:[{id:'p1',part:'gun_vulcan',level:3},{id:'p2',part:'shield',level:1},{id:'p3',part:'shield',level:4}],loadouts:{'0':{W1:'p1',S1:'p2'}},airframeLevels:{'0':1},convertedGear:[1]});
test('unified fleet validates ownership, mount compatibility, independent levels and nonduplicated supports',()=>{
 assert.equal(validModuleFleet(fleet(),profile),true);
 for(const mutate of [f=>f.loadouts[0].W2='p1',f=>f.loadouts[0].S2='p3',f=>f.loadouts[0].W2='p2',f=>f.loadouts[0].main='p1',f=>f.owned[0].level=100,f=>f.loadouts[1]={},f=>f.loadouts[0].W1='missing']){
  const f=fleet();mutate(f);assert.equal(validModuleFleet(f,profile),false);
 }
 const f=fleet();f.loadouts[0]={};assert.equal(validModuleFleet(f,profile),true);
});
