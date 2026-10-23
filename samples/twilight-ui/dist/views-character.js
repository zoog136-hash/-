import * as M from './model.js';
import { btn, iconBtn, image, line, pill, empty, tabs, chips, search, grade, number, esc } from './helpers.js';

// Keep the two equipment pages consistent with the existing TWILIGHT layout.
// The sample's armor/offhand inventory keys are "armor" and "shield".
const EQUIPMENT_PAGES = [
  [['helmet','투구'],['weapon','무기'],['armor','갑옷'],['boots','신발'],
   ['necklace','목걸이'],['shield','방패'],['cloak','망토'],['gloves','장갑'],
   ['tshirt','티셔츠'],['belt','벨트'],['ring1','반지 I'],['ring2','반지 II']],
  [['pants','하의'],['shoulder','견갑'],['earring1','귀걸이 I'],['earring2','귀걸이 II'],
   ['seal1','인장 I'],['seal2','인장 II'],['gaiters','각반'],['bracelet','팔찌'],
   ['badge','휘장'],['crystal','수정'],['catalyst','카탈리스트'],['rune','룬']],
];
const CHARACTER_TABS = [['character','장비 · 전투 정보'],['stats','스탯 배분']];
const PREVIEW_FIELDS = [['attack','근거리 대미지'],['hit','명중'],['hp','최대 HP'],['mp','최대 MP'],['magic','마법 대미지'],['weight','소지 무게']];
const SKILL_FILTERS = ['전체','습득','미습득','패시브'];
const LEARN_COST = 120000; // Matches the sample model's learnSkill condition.

function equipmentSlot(s, slot, label) {
  const item = s.items.find(i => i.equipped && i.count > 0 && i.slot === slot && ['weapon','armor'].includes(i.type));
  const selected = !!item && s.selectedItem === item.id;
  const name = item ? M.displayItem(item) : '미장착';
  return `<button type="button" class="equipment-slot ${selected ? 'selected' : ''} ${item ? 'equipped' : 'empty'}"
    data-action="equipment-slot" data-id="${esc(item?.id || 'empty')}" data-slot="${esc(slot)}"
    aria-label="${esc(`${label}: ${name}. 장비 보기`)}" aria-pressed="${selected}"
    ${item ? `style="--grade:${grade(item.grade)}"` : ''}>
    ${item ? image(item.art, item.name) : '<span class="muted" aria-hidden="true">—</span>'}
    <span>${esc(label)}</span>
    ${item ? `<span class="item-enchant">+${number(item.enchant)}</span>` : ''}
  </button>`;
}

export function renderCharacter(s){
 const page=s.equipmentPage===2?2:1;
 return `<div class="character-content">${tabs([['character','장비 정보'],['stats','스탯 정보']],'character','navigate')}<div class="character-name">${s.player.name}<small>Lv.${s.player.level} ${s.player.job}</small></div><div class="paperdoll"><div class="equipment-side">${EQUIPMENT_PAGES[page-1].slice(0,6).map(([k,n])=>equipmentSlot(s,k,n)).join('')}</div><div class="character-display"><div class="character-sprite" role="img" aria-label="기사 첫 대기 프레임"></div></div><div class="equipment-side">${EQUIPMENT_PAGES[page-1].slice(6).map(([k,n])=>equipmentSlot(s,k,n)).join('')}</div></div><footer class="paperdoll-footer">${btn('1 SET','equipment-page',{id:'1',class:page===1?'primary':''})}${btn('2 SET','equipment-page',{id:'2',class:page===2?'primary':''})}${btn('상세 정보','detail-stats',{class:'blue'})}</footer><div class="combat-strip">근거리 ${M.derivedStats(s).attack}　명중 ${M.derivedStats(s).hit}　AC −82</div></div>`;
}
export function renderStats(s){
 const after=M.derivedStats(s,true),before=M.derivedStats(s),remaining=M.remainingPoints(s),spent=M.spentPoints(s);
 return `<div class="allocation-layout"><aside class="allocation-nav">${btn('스탯 배분','navigate',{id:'stats',class:'primary'})}${btn('장비 정보','navigate',{id:'character'})}${btn('상세 능력치','detail-stats',{class:'quiet'})}<p class="hint">확정 전 변경 내용은 임시 배분입니다.</p></aside><section class="allocation-table"><div class="stat-points">남은 포인트 <b>${remaining}</b></div><div class="stats-table">${['STR','INT','DEX','WIS','CON','CHA'].map(k=>`<div class="stat-cell"><div><span>${k} <small>${M.STAT_NAMES[k]}</small></span><b>${s.stats[k]+s.draft[k]}</b>${s.draft[k]?'<em>+'+s.draft[k]+'</em>':''}</div><div class="stat-adjust">${iconBtn('minus','stat-minus',M.STAT_NAMES[k]+' 임시 배분 감소',`data-id="${k}" ${!s.draft[k]?'disabled':''}`)}${iconBtn('plus','stat-plus',M.STAT_NAMES[k]+' 1 증가',`data-id="${k}" ${!remaining?'disabled':''}`)}</div></div>`).join('')}</div><div class="row stat-confirm">${btn('배분 취소','reset-draft',{disabled:!spent})}${btn('스탯 결정 ('+spent+')','confirm-stats',{class:'primary',disabled:!spent})}</div></section><aside class="allocation-preview"><h3>능력치 변경 미리보기</h3><div class="spread"><span>항목</span><small>현재 → 확정 후</small></div>${PREVIEW_FIELDS.map(([k,n])=>line(n,before[k]+' → '+after[k])).join('')}<p class="hint">이 샘플의 예시 능력치 계산입니다.</p>${btn('상세 능력치','detail-stats',{class:'blue'})}</aside></div>`;
}
function skillStatus(s, skill, now) {
  const text = M.skillReason(s, skill, now);
  const tone = text === '사용 가능' || text === '상시 적용' ? 'success' : text === 'MP 부족' ? 'error' : 'muted';
  return `<span class="skill-state ${tone}" data-skill-status="${esc(skill.id)}">${esc(text)}</span>`;
}

function renderSkillDetail(s, skill, now) {
  if (!skill) return `<aside class="detail-panel" aria-label="스킬 상세">${empty('표시할 스킬이 없습니다', '검색어나 필터를 변경해 주세요.')}</aside>`;
  const compatible = skill.job === '공용' || skill.job === s.player.job;
  const reason = M.skillReason(s, skill, now);
  const canLearn = !skill.learned && compatible && s.currency.adena >= LEARN_COST;
  const canUse = reason === '사용 가능';
  const canRegister = skill.learned && !skill.passive && compatible;
  let explanation = '';
  if (!compatible) explanation = `현재 직업은 ${esc(s.player.job)}입니다. 이 스킬은 ${esc(skill.job)} 전용입니다.`;
  else if (!skill.learned) explanation = s.currency.adena >= LEARN_COST ? '습득하면 사용하거나 퀵슬롯에 등록할 수 있습니다.' : '습득에 필요한 아데나가 부족합니다.';
  else if (skill.passive) explanation = '습득한 패시브 스킬입니다. 별도로 사용하거나 퀵슬롯에 등록하지 않습니다.';
  else explanation = '사용 가능 여부는 현재 MP와 재사용 대기시간에 따라 바뀝니다.';
  return `<aside class="detail-panel" aria-label="선택한 스킬 상세">
    <div class="skill-preview">
      ${image(skill.icon, skill.name)}
      ${pill(`${esc(skill.job)} · ${skill.passive ? '패시브' : '액티브'}`)}
    </div>
    <h2 class="detail-name">${esc(skill.name)}</h2>
    <p class="detail-subtitle">${esc(skill.description)}</p>
    <div class="effect-list">
      ${line('습득 상태', skill.learned ? '습득 완료' : '미습득')}
      ${line('필요 MP', skill.passive ? '없음' : number(skill.mp))}
      ${line('재사용 대기', skill.passive ? '없음' : `${number(skill.cooldownSeconds)}초`)}
      ${!skill.learned ? line('습득 비용', `${number(LEARN_COST)} 아데나`) : ''}
    </div>
    <div class="stack">
      <div id="selected-skill-status">${skillStatus(s, skill, now)}</div>
      <p class="hint">${explanation}</p>
    </div>
    <div class="detail-actions">
      ${btn(skill.learned ? '습득 완료' : '스킬 습득', 'learn-skill', {id:skill.id, class:skill.learned ? 'quiet' : 'primary', disabled:!canLearn})}
      ${btn(skill.passive ? '상시 적용' : '스킬 사용', 'use-skill', {id:skill.id, class:'primary', icon:'skills', disabled:!canUse, extra:'aria-describedby="selected-skill-status"'})}
      ${btn('퀵슬롯 등록', 'quick-register', {id:skill.id, icon:'plus', disabled:!canRegister})}
    </div>
  </aside>`;
}

export function renderSkills(s){
 const now=Date.now(),filter=s.skillFilter||'전체',visible=s.skills.filter(x=>(filter==='전체'||filter==='습득'&&x.learned||filter==='미습득'&&!x.learned||filter==='패시브'&&x.passive)&&matchesSkill(x,s.skillSearch));
 const selected=visible.find(x=>x.id===s.selectedSkill)||visible[0];
 return `<div class="skill-book"><aside class="skill-filter-rail">${SKILL_FILTERS.map(n=>`<button class="grade-filter ${n===filter?'active':''}" data-action="skill-filter" data-id="${n}">${n}</button>`).join('')}<div class="skill-mp">MP ${s.player.mp} / ${s.player.maxMP}</div>${btn('MP 회복 · 시연','restore-mp',{class:'quiet'})}</aside><section class="skill-catalog"><div class="skill-search">${search('skillSearch',s.skillSearch,'스킬 이름 검색')}</div><div class="skill-grid">${visible.map(x=>`<button class="skill-icon ${selected?.id===x.id?'selected':''} ${!x.learned?'unlearned':''}" data-action="select-skill" data-id="${x.id}" aria-label="${x.name}, ${M.skillReason(s,x,now)}">${image(x.icon,x.name)}<span>${x.name}</span><small>${x.passive?'P':!x.learned?'미습득':x.job!=='공용'&&x.job!==s.player.job?'직업 제한':''}</small></button>`).join('')}${Array.from({length:Math.max(0,20-visible.length)},()=>'<div class="skill-empty"></div>').join('')}</div></section><aside class="skill-detail-dock">${renderSkillDetail(s,selected,now)}</aside></div>`;
}
function matchesSkill(x,q){return !q||[x.name,x.job,x.description].join(' ').includes(q);}
