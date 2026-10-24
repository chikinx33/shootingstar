// Real local UI flows in isolated guests, with optional text-scale fixtures.
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path'), assert = require('assert');
const out = path.join(__dirname, 'evidence', 'content-ui-contract-20261017');
fs.mkdirSync(out, { recursive: true });
const key = 'flutter.shootingstar.profile.v1';
(async () => {
  const browser = await chromium.launch({ headless: true,
    executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe' });
  const rows = [], errors = []; let last;
  const button = (p, name) => p.getByRole('button', { name, exact: true });
  async function open(width, height, scale) {
    const c = await browser.newContext({ viewport: { width, height }, isMobile: true, hasTouch: true });
    await c.route('https://**', r => r.abort());
    await c.route('**/api/**', r => r.fulfill({ status: 401, contentType: 'application/json', body: '{"error":"isolated QA"}' }));
    const p = await c.newPage(); last = p;
    p.on('pageerror', e => errors.push(e.message));
    p.on('console', m => { if (/EXCEPTION CAUGHT|overflowed by/.test(m.text())) errors.push(m.text()); });
    await p.goto(scale === 1 ? 'http://127.0.0.1:8797/?ui=content-contract'
      : `http://127.0.0.1:8798/?scene=menus&textScale=${scale}`);
    await p.waitForTimeout(850); await semantics(p); return { c, p };
  }
  async function semantics(p) {
    for(let attempt=0;attempt<160;attempt++) {
      if(await p.locator('flt-semantics-placeholder').count())
        await p.locator('flt-semantics-placeholder').evaluate(e=>e.click());
      if(await p.locator('flt-semantics [role="button"],flt-semantics[role="button"]').count()) {
        await p.waitForTimeout(250);return;
      }
      await p.waitForTimeout(250);
    }
    throw Error('Flutter game semantics did not become ready');
  }
  async function reload(p) { await p.reload(); await p.waitForTimeout(750); await semantics(p); }
  async function saved(p) { return p.evaluate(key => {
    let v = localStorage.getItem(key); for (let i = 0; i < 3 && typeof v === 'string'; i++) v = JSON.parse(v); return v;
  }, key); }
  async function seed(p, state) {
    await p.evaluate(({ key, state }) => localStorage.setItem(key, JSON.stringify(JSON.stringify(state))), { key, state });
    await reload(p);
  }
  const {reveal}=require('./web-ui-navigation.cjs');
  async function click(p, name, minHeight = 20) {
    const l = button(p, name).first(); await reveal(p, l, minHeight); await l.click(); await p.waitForTimeout(350);
  }
  async function chip(p, name) {
    const l = p.getByRole('checkbox', { name, exact: true }); await reveal(p, l); await l.click(); await p.waitForTimeout(350);
  }
  async function top(p) {
    await p.mouse.move(p.viewportSize().width * .55, p.viewportSize().height * .65);
    await p.mouse.wheel(0, -20000); await p.waitForTimeout(180);
  }
  async function shot(p, name) { await p.screenshot({ path: path.join(out, name + '.png') }); }
  async function measure(p, name, primary) {
    const box = await reveal(p, button(p, name).first(), primary ? 72 : 64);
    assert(box.width <= 264.1 && box.width / box.height <= 4.25, JSON.stringify({ name, box }));
    return { name, ...box };
  }
  try {
    for (const [width, height] of [[320,568], [360,640], [390,844], [430,932]]) {
      for (const scale of [1,1.3]) {
        console.log('content UI', width, scale);
        const { c, p } = await open(width, height, scale);
        const tag = `${width}-scale-${scale}`, measured = [];
        // Claim through the actual UI before seeding prerequisites for later flows.
        await click(p, '임무·출석'); await chip(p, '출석');
        await click(p, '오늘 출석 보상 받기', 72);
        let s = await saved(p); assert.equal(s.journal?.signIns ?? s.content.journal.signIns, 1);
        const credited = s.credits; await shot(p, `attendance-reward-${tag}`);
        measured.push(await measure(p, '확인', true));
        await click(p, '확인', 72); assert.equal((await saved(p)).credits, credited);
        s = await saved(p); s.onboarded = true; s.soundEnabled = false; s.credits = 7000; s.blueprints = 100;
        s.content.petFood = 500; s.content.petLevels = [5,0,0]; s.content.petRanks = [1,0,0]; s.content.petShards = [10,0,0];
        for (const id of [7,8]) s.content.inventory.push({ id, spec: 0, rank: 0, level: 0, locked: false, spentCredits: 0, spentPlans: 0 });
        s.content.mail = [{ id:'ui-proof-mail', title:'함대 보급 보고', credits:70, plans:3, food:15, gearKeys:1, techKeys:1, eggs:1, claimed:false }];
        s.hangarPresets[0] = { name:'보존할 편성', ship:0, pilot:0, armament:0, equipment:0, gearIds:[1,2,3,4,5,6], techIds:[], pet:0, assistPets:[] };
        for (const k of ['advancedProgressionVersion','advancedEquipment','dailyChallenge','petBond']) delete s.content[k];
        const originalIds = s.content.inventory.map(g => g.id);
        await seed(p, s); s = await saved(p);
        assert.deepEqual(s.content.inventory.map(g => g.id), originalIds);
        assert.equal(s.hangarPresets[0].name, '보존할 편성');
        s.content.petBond.favor[0] = 50; s.content.dailyChallenge.tokens = 16; await seed(p, s);

        await click(p, '성장');
        const gear = p.getByRole('button', { name:/^주무장 .* 레벨 0/ }).first();
        await reveal(p, gear); await gear.click(); await p.waitForTimeout(350);
        await shot(p, `gear-detail-${tag}`);
        measured.push(await measure(p, '장비 강화', true));
        await click(p, '장비 강화', 72); s = await saved(p);
        assert.equal(s.content.inventory.find(g => g.id === 1).level, 1);
        const upgradedCredits = s.credits;
        await click(p, '동일 장비 3개 합성', 72); await shot(p, `gear-merge-confirm-${tag}`);
        measured.push(await measure(p, '합성 확정', true));
        await click(p, '취소', 64);
        s = await saved(p); assert.deepEqual(s.content.inventory.map(g => g.id), originalIds);
        assert.equal(s.credits, upgradedCredits); await click(p, '장비 상세 닫기');

        // The rank prerequisite is a declared isolated UI fixture, not earned progression.
        s = await saved(p); s.content.inventory.find(g => g.id === 1).rank = 2;
        await seed(p, s); await click(p, '성장'); await chip(p, '관리'); await click(p, '고급 장비 성장 · 정련·융합');
        await shot(p, `advanced-detail-${tag}`);
        measured.push(await measure(p, '정밀 조정 · 150 C + 설계도 3', true));
        await click(p, '정밀 조정 · 150 C + 설계도 3', 72);
        assert.equal((await saved(p)).content.advancedEquipment.entries[0].refinement, 1);
        await click(p, '정밀 성장 초기화 · 자원·융합 재료 반환', 64);
        await shot(p, `advanced-reset-confirm-${tag}`);
        measured.push(await measure(p, '정밀 성장만 초기화', true)); await click(p, '취소', 64);
        assert.equal((await saved(p)).content.advancedEquipment.entries[0].refinement, 1);
        await reload(p); await click(p, '성장');

        await chip(p, '펫'); await click(p, '각성·호감도 · 50 / 300');
        await shot(p, `pet-bond-${tag}`);
        measured.push(await measure(p, '먹이 10 선물 · 호감도 +10', true));
        await click(p, '먹이 10 선물 · 호감도 +10', 72);
        await click(p, '펫 각성 1단계 · 100 C', 72); s = await saved(p);
        assert.equal(s.content.petBond.favor[0], 60); assert.equal(s.content.petBond.awakening[0], 1);
        assert.equal(s.content.petFood, 470); assert.equal(s.content.petShards[0], 9);
        const skill = p.getByRole('button', { name:/^신속 동행/ });
        await reveal(p, skill, 88); await skill.click(); await p.waitForTimeout(350);
        assert.equal((await saved(p)).content.petBond.skills[0], 1);
        await shot(p, `pet-skills-${tag}`);
        await click(p, '각성 재료 반환·초기화', 64); await shot(p, `pet-reset-confirm-${tag}`);
        measured.push(await measure(p, '각성 초기화', true)); await click(p, '취소', 64);
        await reload(p); s = await saved(p);
        assert.equal(s.content.petBond.awakening[0], 1); assert.equal(s.content.petBond.skills[0], 1);

        await click(p, '도전'); await click(p, '일일 순환 도전 · 교환소');
        await shot(p, `daily-${tag}`);
        measured.push(await measure(p, '정찰 도전 시작', true));
        await click(p, '정찰 도전 시작', 72); await click(p, '일시정지');
        await click(p, '도전 중단 · 토큰 보상 없음', 64); await click(p, '도전 목록으로', 64);
        assert.equal((await saved(p)).content.dailyChallenge.tokens, 16);
        await top(p); await chip(p, '토큰 교환소');
        await shot(p, `exchange-${tag}`);
        await click(p, '토큰 8 · 교환', 72); await shot(p, `exchange-reward-${tag}`);
        s = await saved(p); assert.equal(s.content.dailyChallenge.tokens, 8); assert.equal(s.content.dailyChallenge.purchases[2], 1);
        await click(p, '보상 닫기');
        assert(await button(p, '토큰 8 · 교환').isDisabled());

        await reload(p); await click(p, '시즌 보상'); await chip(p, '우편');
        await click(p, '우편 보상 받기', 72); await shot(p, `mail-reward-${tag}`);
        s = await saved(p); assert(s.content.mail.find(m => m.id === 'ui-proof-mail').claimed);
        const once = s.credits; measured.push(await measure(p, '확인', true));
        await shot(p, `mail-reward-actions-${tag}`); await click(p, '확인', 72);
        assert.equal((await saved(p)).credits, once);
        await reload(p); s = await saved(p);
        assert.deepEqual(s.content.inventory.map(g => g.id), originalIds);
        assert.deepEqual(s.content.equippedGear, [1,2,3,4,5,6]);
        assert.equal(s.hangarPresets[0].name, '보존할 편성');
        assert.equal(s.content.petBond.favor[0], 60); assert.equal(s.content.petBond.awakening[0], 1);
        assert.equal(s.content.dailyChallenge.purchases[2], 1);
        rows.push({ width, height, scale, measured, legacySaveAndIdsPreserved:true,
          gearUpgradeAndMergeCancel:true, advancedRefineAndResetCancel:true, petGiftAwakenSkillCancelReload:true,
          realDailyLaunchAndAbandon:true, exchangeLimitAndReceipt:true, attendanceAndMailClaimOnce:true });
        await c.close();
      }
    }
    assert.deepEqual(errors, []);
    fs.writeFileSync(path.join(out, 'browser-result.json'), JSON.stringify({ rows, errors,
      scope:'Local Chrome release web. Old saves/materials/favor/mail/tokens seeded in isolated guests only; actual model/UI claims and real battle launch. No production writes, Android or APK execution.' }, null, 2));
    console.log(JSON.stringify({ passed:rows.length, errors }, null, 2));
  } catch (e) {
    if (last && !last.isClosed()) { await shot(last, 'failure'); fs.writeFileSync(path.join(out, 'failure-semantics.txt'), await last.locator('body').innerText()); }
    throw e;
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exit(1); });
