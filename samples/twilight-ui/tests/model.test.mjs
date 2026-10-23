import test from 'node:test';
import assert from 'node:assert/strict';
import * as model from '../dist/model.js';

// These assertions describe the standalone UI demo's state contract, not live-game rules.
// Tap selection, the five-second item label, focus, and hit areas belong to the UI.
const NOW = 1_800_000_000_000;
const fresh = () => model.createState(NOW);
const clone = value => structuredClone(value);
const item = (state, id) => model.itemById(state, id);
const skill = (state, name) => state.skills.find(entry => entry.name === name);
const collection = (state, id = 'demo-collection-01') =>
  state.equipmentCollections.find(entry => entry.id === id);

test('스탯: 배분은 미리보기에만 적용되고 취소하면 포인트와 능력치가 보존된다', () => {
  const state = fresh();
  const baseStats = clone(state.stats);
  const baseDerived = model.derivedStats(state);
  assert.equal(model.adjustStat(state, 'STR', 1), true);
  assert.equal(model.adjustStat(state, 'CON', 1), true);
  assert.equal(model.adjustStat(state, 'STR', 1), true);
  assert.equal(model.remainingPoints(state), 0);
  assert.equal(model.adjustStat(state, 'INT', 1), false);
  assert.equal(model.adjustStat(state, 'STR', -1), true);
  assert.equal(model.adjustStat(state, 'WIS', -1), false);
  assert.deepEqual(state.stats, baseStats);
  assert.equal(state.points, 3);
  assert.equal(model.remainingPoints(state), 1);
  assert.equal(model.derivedStats(state, true).attack, baseDerived.attack + 1);
  assert.equal(model.derivedStats(state, true).hp, baseDerived.hp + 35);

  model.discardStats(state);
  assert.equal(model.dirtyStats(state), false);
  assert.equal(model.remainingPoints(state), 3);
  assert.deepEqual(state.stats, baseStats);
  assert.deepEqual(model.derivedStats(state, true), baseDerived);
});

test('스탯: 확정은 배분한 만큼 한 번만 소비하고 중복 확정은 무효다', () => {
  const state = fresh();
  const before = clone(state.stats);
  model.adjustStat(state, 'STR', 1);
  model.adjustStat(state, 'CON', 1);
  assert.equal(model.commitStats(state), true);
  assert.deepEqual(state.stats, { ...before, STR: before.STR + 1, CON: before.CON + 1 });
  assert.equal(state.points, 1);
  assert.equal(model.dirtyStats(state), false);
  const committed = clone(state);
  assert.equal(model.commitStats(state), false);
  assert.deepEqual(state, committed);
});

test('장비 사용: 같은 슬롯은 교체하고 다른 슬롯과 수량은 보존한다', () => {
  const state = fresh();
  const counts = state.items.map(entry => [entry.id, entry.count]);
  assert.equal(model.useItem(state, 'demo-dagger-free').ok, true);
  assert.equal(item(state, 'demo-dagger-free').equipped, true);
  assert.equal(item(state, 'demo-dagger-equipped').equipped, false);
  assert.equal(state.items.filter(entry => entry.slot === 'weapon' && entry.equipped).length, 1);
  assert.equal(model.useItem(state, 'demo-armor-free').ok, true);
  assert.equal(item(state, 'demo-dagger-free').equipped, true);
  assert.equal(item(state, 'demo-armor-free').equipped, true);
  assert.equal(model.useItem(state, 'demo-dagger-free').ok, true);
  assert.equal(item(state, 'demo-dagger-free').equipped, false);
  assert.equal(item(state, 'demo-armor-free').equipped, true);
  assert.deepEqual(state.items.map(entry => [entry.id, entry.count]), counts);
});

test('소모품 사용: 물약은 HP 상한과 수량을 지키고 주문서는 강화 진입만 한다', () => {
  const state = fresh();
  const hp = state.player.hp;
  const count = item(state, 'demo-potion').count;
  assert.equal(model.useItem(state, 'demo-potion').ok, true);
  assert.equal(state.player.hp, hp + 180);
  assert.equal(item(state, 'demo-potion').count, count - 1);
  state.player.hp = state.player.maxHP - 25;
  assert.equal(model.useItem(state, 'demo-potion').ok, true);
  assert.equal(state.player.hp, state.player.maxHP);
  assert.equal(item(state, 'demo-potion').count, count - 2);
  assert.equal(model.useItem(state, 'demo-potion').ok, false);
  assert.equal(item(state, 'demo-potion').count, count - 2);
  item(state, 'demo-potion').count = 1;
  state.player.hp--;
  assert.equal(model.useItem(state, 'demo-potion').ok, true);
  assert.equal(item(state, 'demo-potion'), undefined);

  const scrolls = item(state, 'demo-scroll-armor').count;
  assert.equal(model.useItem(state, 'demo-scroll-armor').ok, true);
  assert.equal(state.screen, 'forge');
  assert.equal(state.forgeScroll, 'demo-scroll-armor');
  assert.equal(state.forgeTarget, null);
  assert.equal(item(state, 'demo-scroll-armor').count, scrolls);
});

test('컬렉션: 각인 이름은 합치되 +5와 +6은 구별하고 장착·잠금 실물은 제외한다', () => {
  const state = fresh();
  const blade = collection(state).requirements.find(entry => entry.slot === 'blade');
  const original = item(state, 'demo-dagger-free');
  state.items.push(
    { ...original, id: 'dagger-plus-six', enchant: 6 },
    { ...original, id: 'dagger-locked', locked: true },
    { ...original, id: 'dagger-engraved', name: '강철 단검 (각인)' },
  );
  assert.deepEqual(model.eligibleItems(state, blade).map(entry => entry.id).sort(),
    ['demo-dagger-free', 'dagger-engraved'].sort());
  assert.deepEqual(model.eligibleItems(state, { ...blade, enchant: 6 }).map(entry => entry.id),
    ['dagger-plus-six']);
  const before = clone(state);
  for (const id of ['dagger-plus-six', 'dagger-locked', 'demo-dagger-equipped']) {
    assert.equal(model.registerItem(state, collection(state).id, 'blade', id), false, id);
  }
  assert.deepEqual(state, before);
});

test('컬렉션: 선택한 동일 ID만 소비하고 이미 등록한 슬롯은 재소비하지 않는다', () => {
  const state = fresh();
  const col = collection(state);
  state.items.push({ ...item(state, 'demo-dagger-free'), id: 'dagger-second-copy' });
  assert.equal(model.registerItem(state, col.id, 'blade', 'dagger-second-copy'), true);
  assert.equal(item(state, 'dagger-second-copy'), undefined);
  assert.equal(item(state, 'demo-dagger-free').count, 1);
  assert.equal(item(state, 'demo-dagger-equipped').count, 1);
  assert.deepEqual(col.registered, ['blade']);
  const afterBlade = clone(state);
  assert.equal(model.registerItem(state, col.id, 'blade', 'demo-dagger-free'), false);
  assert.deepEqual(state, afterBlade);
  assert.equal(model.registerItem(state, col.id, 'body', 'demo-armor-free'), true);
  assert.equal(item(state, 'demo-armor-free'), undefined);
  assert.equal(col.requirements.every(req => col.registered.includes(req.slot)), true);
});

test('강화: 시작·완료 중복 클릭에도 주문서 하나와 강화 결과 한 번만 적용된다', () => {
  const state = fresh();
  const beforeCount = item(state, 'demo-scroll-weapon').count;
  const transaction = model.startForge(state);
  assert.ok(transaction);
  assert.equal(state.forgeBusy, true);
  assert.equal(model.startForge(state), null);
  assert.equal(item(state, 'demo-scroll-weapon').count, beforeCount);
  assert.equal(model.selectForgeTarget(state, 'demo-armor-free'), false);
  assert.equal(model.toggleLock(state, 'demo-dagger-free'), false);
  assert.equal(model.useItem(state, 'demo-dagger-free').ok, false);
  assert.equal(model.transferStorage(state, 'demo-dagger-free', 'deposit'), false);

  const result = model.finishForge(state, transaction);
  assert.equal(result.outcome, 'success');
  assert.equal(result.before, 5);
  assert.equal(result.after, 6);
  assert.equal(item(state, 'demo-scroll-weapon').count, beforeCount - 1);
  assert.equal(item(state, 'demo-dagger-free').enchant, 6);
  assert.equal(state.forgeBusy, false);
  const finished = clone(state);
  assert.equal(model.finishForge(state, transaction), false);
  assert.deepEqual(state, finished);
});

test('강화: 유지·하락·하한 결과와 다음 실행 중 오래된 완료 콜백을 처리한다', () => {
  for (const [outcome, after] of [['stay', 5], ['down', 4]]) {
    const state = fresh();
    state.forgeOutcome = outcome;
    const count = item(state, 'demo-scroll-weapon').count;
    const result = model.finishForge(state, model.startForge(state));
    assert.equal(result.after, after, outcome);
    assert.equal(item(state, 'demo-scroll-weapon').count, count - 1);
  }
  const state = fresh();
  item(state, 'demo-dagger-free').enchant = 0;
  state.forgeOutcome = 'down';
  const first = model.startForge(state);
  assert.equal(model.finishForge(state, first).after, 0);
  state.forgeOutcome = 'success';
  const second = model.startForge(state);
  assert.notEqual(second.id, first.id);
  const pending = clone(state);
  assert.equal(model.finishForge(state, first), false);
  assert.deepEqual(state, pending);
  assert.equal(model.finishForge(state, second).after, 1);
});

test('카드 재료: 중복 여분 4장만 선택하고 잠금·미보유·등급·수량 제한을 지킨다', () => {
  for (const catId of ['transform', 'doll', 'relic']) {
    const state = fresh();
    const cat = model.category(state, catId);
    const [lowGrade, , first, second, unowned] = cat.cards;
    assert.equal(model.addFusion(state, catId, lowGrade.id), false);
    assert.equal(model.addFusion(state, catId, unowned.id), false);
    second.locked = true;
    assert.equal(model.addFusion(state, catId, second.id), false);
    assert.equal(model.addFusion(state, catId, first.id), true);
    assert.equal(model.addFusion(state, catId, first.id), true);
    assert.equal(model.addFusion(state, catId, first.id), false);
    assert.equal(model.startFusion(state, catId), null);
    second.locked = false;
    assert.equal(model.addFusion(state, catId, second.id), true);
    assert.equal(model.addFusion(state, catId, second.id), true);
    assert.equal(model.addFusion(state, catId, second.id), false);
    assert.equal(state.fusion.length, 4);
    assert.equal(first.spares, 2);
    assert.equal(second.spares, 3);
  }
});

test('카드 합성: 첫 보유는 남기고 busy·완료 중복·재실행을 세 종류에서 보장한다', () => {
  for (const catId of ['transform', 'doll', 'relic']) {
    const state = fresh();
    const cat = model.category(state, catId);
    const firstMaterial = cat.cards[2];
    const secondMaterial = cat.cards[3];
    firstMaterial.spares = 4;
    secondMaterial.locked = true;
    model.autofillFusion(state, catId);
    assert.deepEqual(state.fusion, Array(4).fill(firstMaterial.id));
    const first = model.startFusion(state, catId);
    assert.ok(first);
    assert.equal(model.startFusion(state, catId), null);
    assert.equal(model.addFusion(state, catId, firstMaterial.id), false);
    assert.equal(model.applyCard(state, catId, cat.cards[0].id), false);
    model.autofillFusion(state, catId);
    assert.deepEqual(state.fusion, Array(4).fill(firstMaterial.id));
    assert.equal(firstMaterial.spares, 4);
    const result = model.finishFusion(state, first);
    assert.equal(result.id, cat.fusion_success_card_id);
    assert.equal(firstMaterial.spares, 0);
    assert.equal(firstMaterial.owned, true);
    assert.equal(cat.equipped_id, firstMaterial.id);
    assert.equal(result.owned, true);
    assert.equal(result.spares, 0);
    assert.equal(state.fusionBusy, false);
    const finished = clone(state);
    assert.equal(model.finishFusion(state, first), false);
    assert.deepEqual(state, finished);
    model.autofillFusion(state, catId);
    assert.equal(model.startFusion(state, catId), null);

    secondMaterial.locked = false;
    secondMaterial.spares = 4;
    model.autofillFusion(state, catId);
    const second = model.startFusion(state, catId);
    assert.notEqual(second.id, first.id);
    const pending = clone(state);
    assert.equal(model.finishFusion(state, first), false);
    assert.deepEqual(state, pending);
    assert.equal(model.finishFusion(state, second).id, result.id);
    assert.equal(result.spares, 1);
    assert.equal(secondMaterial.spares, 0);
    assert.equal(secondMaterial.owned, true);
  }
});

test('스킬 사용: 클래스·배움·패시브·MP·쿨다운을 구별하고 시간 만료 후 재사용한다', () => {
  const state = fresh();
  const blocked = [
    ['힐', '마법사 전용'], ['카운터 배리어', '미습득'],
    ['리덕션 아머', '상시 적용'], ['에너지 볼트', 'MP 부족'],
    ['쇼크 스턴', '재사용 18초'],
  ];
  for (const [name, reason] of blocked) {
    const sk = skill(state, name);
    const before = clone(state);
    assert.equal(model.skillReason(state, sk, NOW), reason);
    assert.equal(model.useSkill(state, sk.id, NOW), false, name);
    assert.deepEqual(state, before);
  }
  const shield = skill(state, '실드');
  assert.equal(model.useSkill(state, shield.id, NOW), true);
  assert.equal(state.player.mp, 22);
  assert.equal(shield.cooldown, NOW + 12_000);
  assert.equal(model.useSkill(state, shield.id, NOW + 11_999), false);
  assert.equal(state.player.mp, 22);
  assert.equal(model.useSkill(state, shield.id, NOW + 12_000), true);
  assert.equal(state.player.mp, 2);
  assert.equal(model.useSkill(state, shield.id, NOW + 24_000), false);
  assert.equal(state.player.mp, 2);
});

test('스킬 습득: 비용 부족과 타 클래스는 거절하고 습득 비용은 한 번만 낸다', () => {
  const state = fresh();
  const barrier = skill(state, '카운터 배리어');
  state.currency.adena = 119_999;
  assert.equal(model.learnSkill(state, barrier.id), false);
  assert.equal(barrier.learned, false);
  assert.equal(state.currency.adena, 119_999);
  state.currency.adena = 120_000;
  assert.equal(model.learnSkill(state, barrier.id), true);
  assert.equal(barrier.learned, true);
  assert.equal(state.currency.adena, 0);
  assert.equal(model.learnSkill(state, barrier.id), false);
  assert.equal(state.currency.adena, 0);
  const heal = skill(state, '힐');
  heal.learned = false;
  state.currency.adena = 200_000;
  assert.equal(model.learnSkill(state, heal.id), false);
  assert.equal(heal.learned, false);
  assert.equal(state.currency.adena, 200_000);
});

test('퀵슬롯: 해당 페이지에 배운 액티브만 넣고 MP·쿨다운은 등록을 막지 않는다', () => {
  const state = fresh();
  const shield = skill(state, '실드');
  assert.equal(model.registerQuickslot(state, shield.id, 4), true);
  assert.equal(state.quickslots[0][4], shield.id);
  const pageZero = clone(state.quickslots[0]);
  state.quickPage = 1;
  assert.equal(model.registerQuickslot(state, shield.id, 2), true);
  assert.equal(state.quickslots[1][2], shield.id);
  assert.deepEqual(state.quickslots[0], pageZero);
  const beforeInvalid = clone(state.quickslots);
  for (const name of ['리덕션 아머', '카운터 배리어', '힐']) {
    assert.equal(model.registerQuickslot(state, skill(state, name).id, 0), false, name);
  }
  assert.equal(model.registerQuickslot(state, shield.id, -1), false);
  assert.equal(model.registerQuickslot(state, shield.id, 5), false);
  assert.deepEqual(state.quickslots, beforeInvalid);
  const stun = skill(state, '쇼크 스턴');
  assert.equal(model.registerQuickslot(state, stun.id, 3), true);
  assert.equal(state.quickslots[1][3], stun.id);
});

test('창고: 장착·잠금은 제외하고 보관 중 재구매한 같은 ID를 회수할 때 합친다', () => {
  const state = fresh();
  const before = clone(state);
  assert.equal(model.transferStorage(state, 'demo-dagger-equipped', 'deposit'), false);
  assert.equal(model.transferStorage(state, 'demo-shield-locked', 'deposit'), false);
  assert.deepEqual(state, before);
  const count = item(state, 'demo-potion').count;
  const money = state.currency.adena;
  assert.equal(model.transferStorage(state, 'demo-potion', 'deposit'), true);
  assert.equal(item(state, 'demo-potion'), undefined);
  assert.equal(state.storage.find(entry => entry.id === 'demo-potion').count, count);
  assert.equal(state.currency.adena, money);
  assert.equal(model.purchase(state, 'demo-potion', 2), true);
  assert.equal(item(state, 'demo-potion').count, 2);
  const paid = state.currency.adena;
  assert.equal(model.transferStorage(state, 'demo-potion', 'withdraw'), true);
  assert.equal(item(state, 'demo-potion').count, count + 2);
  assert.equal(state.items.filter(entry => entry.id === 'demo-potion').length, 1);
  assert.equal(state.storage.some(entry => entry.id === 'demo-potion'), false);
  assert.equal(state.currency.adena, paid);
  assert.equal(model.transferStorage(state, 'demo-potion', 'withdraw'), false);
});

test('상점: 1~20 정수 수량과 총액을 검증하고 잔고 부족이면 부분 구매하지 않는다', () => {
  const state = fresh();
  const count = item(state, 'demo-potion').count;
  const money = state.currency.adena;
  assert.equal(model.purchase(state, 'demo-potion', 1), true);
  assert.equal(model.purchase(state, 'demo-potion', 20), true);
  assert.equal(item(state, 'demo-potion').count, count + 21);
  assert.equal(state.currency.adena, money - 21 * 500);
  const beforeInvalid = clone(state);
  for (const amount of [0, -1, 21, 1.5]) {
    assert.equal(model.purchase(state, 'demo-potion', amount), false, String(amount));
  }
  assert.equal(model.purchase(state, 'not-a-shop-item', 1), false);
  assert.deepEqual(state, beforeInvalid);
  state.currency.adena = 999;
  const insufficient = clone(state);
  assert.equal(model.purchase(state, 'demo-potion', 2), false);
  assert.deepEqual(state, insufficient);
  state.items = state.items.filter(entry => entry.id !== 'demo-potion');
  state.currency.adena = 1_500;
  assert.equal(model.purchase(state, 'demo-potion', 3), true);
  assert.equal(item(state, 'demo-potion').count, 3);
  assert.equal(state.currency.adena, 0);
});

test('수량 제작: 전체 재료가 부족하면 일부 소모하지 않고, 충분하면 한 번에 반영한다',()=>{
 const s=model.createState();const before=structuredClone(s);assert.equal(model.craft(s,'armor-scroll',7),false);assert.deepEqual(s,before);
 assert.equal(model.craft(s,'armor-scroll',2),true);assert.equal(model.itemById(s,'demo-scroll-weapon').count,8);assert.equal(model.itemById(s,'demo-scroll-armor').count,8);assert.equal(s.currency.adena,before.currency.adena-10000);
 assert.equal(model.craft(s,'potion',20),true);assert.equal(model.itemById(s,'demo-potion').count,144);
});
test('창고 수량: 선택 수량만 왕복하고 음수·분수·초과 수량은 보존한다',()=>{
 const s=model.createState();for(const q of [-1,0,.5,85]){const before=structuredClone(s);assert.equal(model.transferStorage(s,'demo-potion','deposit',q),false);assert.deepEqual(s,before);}
 assert.equal(model.transferStorage(s,'demo-potion','deposit',10),true);assert.equal(model.itemById(s,'demo-potion').count,74);assert.equal(s.storage.find(x=>x.id==='demo-potion').count,10);
 assert.equal(model.transferStorage(s,'demo-potion','withdraw',2),true);assert.equal(model.itemById(s,'demo-potion').count,76);assert.equal(s.storage.find(x=>x.id==='demo-potion').count,8);
});
