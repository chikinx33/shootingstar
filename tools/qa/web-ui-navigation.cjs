// Seek fixed pages through their visible controls; wheel only actual item lists.
async function reveal(page, locator, minHeight = 20) {
  const bounds = async () => {
    const box = await locator.boundingBox({timeout:100}).catch(()=>null);
    const h=page.viewportSize().height;
    if(!box)return null;
    // List children may have semantic bounds underneath a fixed bottom bar.
    // Require the painted control to fit its actual list viewport as well.
    const clip=await locator.evaluate(e=>{
      for(let a=e.parentElement;a;a=a.parentElement){
        if([...a.children].some(c=>c.tagName.toLowerCase()==='flt-semantics-scroll-overflow')){
          const r=a.getBoundingClientRect();return {top:r.top,bottom:r.bottom};
        }
      }return null;
    });
    const top=clip?Math.max(0,clip.top):0,bottom=clip?Math.min(h,clip.bottom):h;
    return box.height>=minHeight-.3 && box.y>=top-.2 && box.y+box.height<=bottom+.5 ? box:null;
  };
  let box=await bounds(); if(box)return box;
  for(const label of ['이전 페이지','다음 페이지']) {
    for(let i=0;i<60;i++) {
      const control=page.getByRole('button',{name:new RegExp('^'+label)}).last();
      if(!await control.count() || !await control.isEnabled())break;
      const controlBox=await control.boundingBox();
      if(!controlBox)break;
      await page.mouse.click(controlBox.x+controlBox.width/2,controlBox.y+controlBox.height/2);await page.waitForTimeout(100);
      box=await bounds();if(box)return box;
    }
  }
  // A modal or fixed detail screen must never fall back to wheel navigation.
  if(await page.getByRole('button',{name:/^다음 페이지/}).count())
    throw Error('Unreachable fixed-page control: '+locator);
  // Lazy item nodes disappear outside their viewport. Start from the first
  // item before seeking a missing node, including when the prior action ended
  // at the last reward tier.
  if(!await locator.count()) {
    const list=await page.locator('flt-semantics:has(> flt-semantics-scroll-overflow)').last().boundingBox({timeout:100}).catch(()=>null);
    await page.mouse.move(list ? list.x+list.width*.55:page.viewportSize().width*.55,
      list ? list.y+list.height*.55:page.viewportSize().height*.7);
    await page.mouse.wheel(0,-30000);await page.waitForTimeout(200);
  }
  for(let i=0;i<90;i++) {
    const raw=await locator.boundingBox({timeout:100}).catch(()=>null),h=page.viewportSize().height;
    const list=await page.locator('flt-semantics:has(> flt-semantics-scroll-overflow)').last().boundingBox({timeout:100}).catch(()=>null);
    await page.mouse.move(list ? list.x+list.width*.55:page.viewportSize().width*.55,
      list ? list.y+list.height*.55:h*.7);
    await page.mouse.wheel(0,raw && raw.y<(list ? list.y+list.height*.35:h*.35)?-150:160);
    await page.waitForTimeout(70);box=await bounds();if(box)return box;
  }
  throw Error('Unreachable list control: '+locator);
}
module.exports={reveal};
