// Local web visual/interaction QA. Fresh isolated guests; external writes blocked.
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert');
const out = process.env.QA_EVIDENCE_DIR || path.join(__dirname, 'evidence', 'ui-contract-20261017');
const base = process.env.SURVIVOR_STYLE_URL || 'http://127.0.0.1:8797';
const fixtures = process.env.SURVIVOR_FIXTURE_URL || 'http://127.0.0.1:8798';
const key = 'flutter.shootingstar.profile.v1';
const {reveal}=require('./web-ui-navigation.cjs');
fs.mkdirSync(out, { recursive: true });

(async () => {
  let browser;
  const errors = [], rows = [];
  async function open(url, width, height) {
    // Release CanvasKit GPU contexts between scenarios on Windows Chrome.
    if (browser) await browser.close();
    browser = await chromium.launch({ headless: true,
      executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe' });
    const context = await browser.newContext({ viewport: { width, height },
      isMobile: width < 500, hasTouch: true });
    await context.route('**/api/**', r => r.fulfill({ status: 401,
      contentType: 'application/json', body: '{"error":"isolated UI QA"}' }));
    await context.route('https://**', r => r.abort());
    const page = await context.newPage();
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', m => {
      if (/EXCEPTION CAUGHT|overflowed by/.test(m.text())) errors.push(m.text());
    });
    await page.goto(url);
    await page.waitForTimeout(850);
    await semantics(page);
    return { page, context };
  }
  async function semantics(page) {
    for(let attempt=0;attempt<160;attempt++) {
      if(await page.locator('flt-semantics-placeholder').count())
        await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
      if(await page.locator('flt-semantics [role="button"],flt-semantics[role="button"]').count()) {
        await page.waitForTimeout(250);return;
      }
      await page.waitForTimeout(250);
    }
    throw Error('Flutter game semantics did not become ready');
  }
  async function shot(page, name) {
    await page.screenshot({ path: path.join(out, name + '.png') });
  }
  async function click(page, label) {
    const button = page.getByRole('button', { name: label, exact: true });
    await reveal(page,button);
    await button.click();
    await page.waitForTimeout(220);
  }
  async function state(page) {
    return page.evaluate(key => {
      let value = localStorage.getItem(key);
      for (let i = 0; i < 3 && typeof value === 'string'; i++) value = JSON.parse(value);
      return value;
    }, key);
  }
  async function actions(page, labels) {
    const bounds = [];
    for (const label of labels) {
      const locator = page.getByRole('button', { name: label, exact: true });
      const expectedHeight = /계속 비행|다시 출격/.test(label) ? 72 : 64;
      const box=await reveal(page,locator,expectedHeight);
      assert(box && box.height >= expectedHeight, `${label}: painted/tap height ${box?.height}`);
      assert(box.width <= 264.1 && box.width / box.height <= 4.25,
        `${label}: banner-shaped ${JSON.stringify(box)}`);
      const viewport = page.viewportSize();
      assert(box.x >= 15 && box.x + box.width <= viewport.width - 15);
      assert(box.y >= -1 && box.y + box.height <= viewport.height + 1,
        `${label}: cannot scroll fully into view`);
      bounds.push({ label, ...box });
    }
    return bounds;
  }
  try {
    for (const [width, height] of [[320, 568], [360, 640], [390, 844], [430, 932]]) {
      console.log('menus', width);
      const { page, context } = await open(base, width, height);
      const launch = await page.getByRole('button', { name: '잔광 외곽 1-1 · 출격', exact: true }).boundingBox();
      assert(launch.height >= 72 && launch.width <= 264.1 && launch.y + launch.height < height - 88);
      await shot(page, `home-${width}`);
      await click(page, '성장'); await shot(page, `growth-${width}`);
      await page.mouse.move(width * .5, height * .65);
      await page.mouse.wheel(0, 550); await page.waitForTimeout(200);
      await shot(page, `inventory-${width}`);
      await click(page, '진화'); await shot(page, `talents-${width}`);
      await click(page, '보급'); await click(page, '장비 보급 열기');
      const saved = await state(page);
      assert.equal(saved.content.gearKeys, 0);
      assert.equal(saved.content.inventory.length, 7);
      await shot(page, `supply-${width}`);
      await page.reload(); await page.waitForTimeout(750); await semantics(page);
      const restored = await state(page);
      assert.deepEqual(restored.content.inventory, saved.content.inventory);
      assert.equal(restored.credits, saved.credits);
      assert.equal(restored.content.gearKeys, 0);
      rows.push({ name: `menus-${width}`, launch, savedAndReloaded: true });
      await context.close();

      for (const scale of [1, 1.3]) {
        console.log('pause/result', width, scale);
        const { page, context } = await open(fixtures + `/?scene=pause&textScale=${scale}`, width, height);
        const paused = await actions(page, ['계속 비행', '전투 통계', '귀환 · 현재 보상 정산']);
        // Restore top of decision scroll for a full-screen visual comparison.
        while(await page.getByRole('button',{name:/^이전 페이지/}).count() && await page.getByRole('button',{name:/^이전 페이지/}).isEnabled()) await click(page,'이전 페이지');
        await shot(page, `pause-${width}-scale-${scale}`);
        await click(page, '전투 통계');
        await click(page, '통계 닫기');
        await reveal(page,page.getByRole('button',{name:'계속 비행',exact:true}));
        await click(page, '계속 비행');
        assert.equal(await page.getByText('계속 비행', { exact: true }).count(), 0);
        await click(page, '일시정지');
        await click(page, '귀환 · 현재 보상 정산');
        const result = await actions(page, ['전투 통계', '다시 출격', '성장 정비 · 귀환']);
        await shot(page, `result-actions-${width}-scale-${scale}`);
        while(await page.getByRole('button',{name:/^이전 페이지/}).count() && await page.getByRole('button',{name:/^이전 페이지/}).isEnabled()) await click(page,'이전 페이지');
        await shot(page, `result-${width}-scale-${scale}`);
        const settled = await state(page);
        await click(page, '전투 통계'); await click(page, '통계 닫기');
        assert.deepEqual(await state(page), settled, 'statistics must not settle twice');
        rows.push({ name: `decisions-${width}-scale-${scale}`, paused, result,
          resumeWorks: true, statisticsDoNotSettleTwice: true });
        await context.close();
      }
    }
    for (const [width, height] of [[320, 568], [360, 640], [390, 844], [430, 932]]) {
      console.log('scaled menus', width);
      const { page, context } = await open(fixtures + '/?scene=menus&textScale=1.3', width, height);
      await shot(page, `home-${width}-scale-1.3`);
      await click(page, '성장'); await shot(page, `growth-${width}-scale-1.3`);
      await click(page, '진화'); await shot(page, `talents-${width}-scale-1.3`);
      await click(page, '도전'); await click(page, '일일 순환 도전 · 교환소');
      const dailyAction = page.getByRole('button', { name: '정찰 도전 시작', exact: true });
      await reveal(page,dailyAction,72);
      const daily = await dailyAction.boundingBox();
      assert(daily.height >= 72 && daily.width <= 264.1);
      await shot(page, `daily-${width}-scale-1.3`);
      rows.push({ name: `scaled-menus-${width}`, scale: 1.3, daily });
      await context.close();
    }
    const { page, context } = await open(base, 1280, 900);
    await shot(page, 'desktop-portrait'); await context.close();
    rows.push({ name: 'desktop-1280x900' });
    assert.deepEqual(errors, []);
    fs.writeFileSync(path.join(out, 'browser-result.json'), JSON.stringify({ base, fixtures, rows, errors,
      scope: 'Chrome release Flutter Web; isolated guests, scaled/paused fixtures only; no Android/production deployment' }, null, 2));
    console.log(JSON.stringify({ passed: rows.length, errors }, null, 2));
  } finally { if (browser) await browser.close(); }
})().catch(e => { console.error(e); process.exit(1); });
