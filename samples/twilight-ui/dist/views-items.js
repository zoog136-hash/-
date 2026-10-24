import * as M from './model.js';
import { DATA } from './data.js';
import { itemSlot, btn, iconBtn, icon, image, line, pill, empty, tabs, chips, search, grade, number, esc } from './helpers.js';

const itemName = item => M.normalizeName(item.name);
const itemLabel = item => M.displayItem({ ...item, name: itemName(item) });
const catalogItem = id => DATA.items.find(item => item.id === id);
const blanks = count => Array.from({ length: Math.max(0, count) }, () =>
  '<div class="item-slot empty" aria-hidden="true"></div>').join('');

function slot(item, action, selected = false, disabled = false) {
  return itemSlot({ ...item, name: itemName(item) }, action, selected)
    .replace('<button ', `<button type="button" ${disabled ? 'disabled ' : ''}`);
}

function staticSlot(item) {
  return `<div class="item-slot ${item.equipped ? 'equipped' : ''}" title="${esc(itemLabel(item))}" style="--grade:${grade(item.grade)}">
    ${image(item.art, itemLabel(item))}
    ${['weapon', 'armor'].includes(item.type) ? `<span class="item-enchant">+${item.enchant}</span>` : ''}
    ${item.count > 1 ? `<span class="item-count">${number(item.count)}</span>` : ''}
    ${item.equipped ? '<span class="item-mark">E</span>' : ''}
  </div>`;
}

const typeLabel = item => ({ weapon: '무기', armor: item.slot === 'shield' ? '방패' : '갑옷', potion: '회복 물약', scroll: '강화 주문서' })[item.type] || '아이템';
const itemInstruction = item => item.type === 'potion' ? '두 번 누르면 HP를 회복합니다.'
  : item.type === 'scroll' ? '두 번 누르면 강화할 장비를 선택합니다.'
    : `두 번 누르면 ${item.equipped ? '장착을 해제' : '장착'}합니다.`;

export function renderInventory(s){
 const held=s.items.filter(x=>x.count>0),items=held.filter(x=>(s.inventoryFilter==='전체'||s.inventoryFilter==='장비'&&['weapon','armor'].includes(x.type)||s.inventoryFilter==='소모품'&&['potion','scroll'].includes(x.type)||s.inventoryFilter==='장착 중'&&x.equipped)&&M.displayItem(x).includes(s.inventorySearch));
 const selected=M.itemById(s,s.selectedItem);
 return `<div class="bag-container">${chips(['전체','장비','소모품','장착 중'],s.inventoryFilter,'inventory-filter')}<div class="inventory-grid" aria-label="가방 아이템 슬롯">${items.map(x=>itemSlot(x,'select-item',s.selectedItem===x.id)).join('')}${blanks(32-items.length).replaceAll('<div class="item-slot empty" aria-hidden="true"></div>','<button class="item-slot empty" data-action="clear-item" aria-label="빈 슬롯 · 선택 해제"></button>')}</div><div class="bag-selected" role="status">${selected?M.displayItem(selected):'아이템을 선택하세요'}</div><div class="inventory-status"><span>무게 24.8%</span><span>${held.length} / 32</span></div><div class="bag-actions">${btn('정렬','sort-inventory')}${btn('잠금','lock-item',{disabled:!selected})}${btn('상세','item-detail',{disabled:!selected,class:'blue'})}</div><div class="bag-search">${search('inventorySearch',s.inventorySearch,'이름 검색')}</div><small class="bag-hint">한 번 선택 · 두 번 사용 / 장착</small></div>`;
}
export function renderForge(s){
 const target=M.itemById(s,s.forgeTarget),scroll=M.itemById(s,s.forgeScroll),targets=s.items.filter(x=>x.count>0&&['weapon','armor'].includes(x.type));
 return `<div class="enchant-layout"><section class="enchant-main"><h3>강화할 아이템을 선택해 주세요.</h3><div class="enchant-slots"><div><span>주문서</span><div class="enchant-slot">${scroll?image(scroll.art,scroll.name):'＋'}</div><small>보유 ${scroll?.count||0}장</small></div><span class="enchant-plus">＋</span><div><span>강화 대상</span><div class="enchant-slot">${target?image(target.art,target.name):'＋'}</div><small>${target?'+'+target.enchant+' '+M.normalizeName(target.name):'미선택'}</small></div></div><div class="enchant-values">${line('현재 강화',target?'+'+target.enchant:'—')}${line('성공 후',target?'+'+(target.enchant+1):'—')}${line('소모 재료',scroll?M.normalizeName(scroll.name)+' 1장':'주문서 없음')}</div><div class="enchant-demo"><label for="forge-outcome">시연 결과</label><select name="forgeOutcome" id="forge-outcome">${[['success','성공'],['keep','유지'],['down','하락']].map(([v,n])=>`<option value="${v}" ${s.forgeOutcome===v?'selected':''}>${n}</option>`).join('')}</select><small>실제 확률과 무관한 예시</small></div>${btn('강화','confirm-forge',{class:'primary',disabled:!M.canForge(s)})}</section><section class="enchant-bag"><h3>보유 장비</h3><div class="inventory-grid">${targets.map(x=>`<div class="forge-item ${x.locked?'locked':''}">${itemSlot(x,'forge-target',x.id===s.forgeTarget)}</div>`).join('')}${blanks(20-targets.length)}</div><p class="hint">잠긴 장비는 선택할 수 없습니다.</p></section></div>`;
}
export function renderCraft(s){
 const all=[{id:'potion',item:catalogItem('demo-potion'),count:3,adena:1500},{id:'armor-scroll',item:catalogItem('demo-scroll-armor'),count:1,adena:5000}],recipes=all.filter(x=>!s.craftFilter||s.craftFilter==='all'||s.craftFilter===x.id),selected=recipes.find(x=>x.id===s.recipe)||recipes[0],q=s.craftQuantity||1,needs=selected.id==='armor-scroll',stock=M.itemById(s,'demo-scroll-weapon')?.count||0,ready=s.currency.adena>=selected.adena*q&&(!needs||stock>=q*2);
 return `<div class="craft-layout"><aside class="craft-categories">${[['all','전체'],['potion','회복 물약'],['armor-scroll','강화 주문서']].map(([id,n])=>btn(n,'craft-filter',{id,class:(s.craftFilter||'all')===id?'primary':'quiet'})).join('')}</aside><section class="craft-list"><h3>제작 리스트</h3>${recipes.map(x=>`<button class="recipe-row ${x.id===selected.id?'selected':''}" data-action="recipe" data-id="${x.id}">${image(x.item.art,x.item.name)}<span>${M.normalizeName(x.item.name)}<small>${x.count}개</small></span></button>`).join('')}</section><section class="craft-detail"><h3>제작 아이템</h3><div class="craft-result">${image(selected.item.art,selected.item.name)}<div><strong>${M.normalizeName(selected.item.name)}</strong><small>완성 수량 ${selected.count*q}</small></div><div class="quantity-stepper">${btn('−','craft-quantity',{id:'-1',disabled:q<=1})}<b>${q}</b>${btn('＋','craft-quantity',{id:'1',disabled:q>=20})}</div></div><h3>필요 재료</h3><div class="craft-materials">${needs?`<div>${image(catalogItem('demo-scroll-weapon').art)}<span>무기 마법 주문서<small class="${stock<q*2?'error':''}">${stock} / ${q*2}</small></span></div>`:''}<div>${icon('coin')}<span>아데나<small>${number(s.currency.adena)} / ${number(selected.adena*q)}</small></span></div></div><div class="craft-bottom"><span class="hint">예시 제작식</span>${btn('제작','confirm-craft',{id:selected.id,class:'primary',disabled:!ready})}</div></section></div>`;
}
export function renderStorage(s){
 const deposit=s.storageMode!=='withdraw',source=deposit?s.items:s.storage,selected=source.find(x=>x.id===s.storageSelected&&x.count>0),q=Math.min(selected?.count||1,s.transferQuantity||1);
 const pane=(items,mode)=>`<div class="inventory-grid">${items.filter(x=>x.count>0).map(x=>`<div class="storage-item" data-mode="${mode}">${itemSlot(x,'storage-select',selected?.id===x.id&&deposit===(mode==='deposit'))}</div>`).join('')}${blanks(24-items.length)}</div>`;
 return `<div class="warehouse"><section class="warehouse-stock"><h3>개인 창고 <small>${s.storage.length} / 100</small></h3>${pane(s.storage,'withdraw')}</section><section class="warehouse-transfer">${tabs([['deposit','맡기기'],['withdraw','찾기']],s.storageMode,'storage-mode')}<div class="warehouse-emblem">${image('assets/ui/shop.png')}<span>창고지기</span></div><div class="warehouse-selected">${selected?`${image(selected.art,selected.name)}<strong>${M.displayItem(selected)}</strong><span>보유 ${selected.count}개</span>`:'이동할 아이템을 선택하세요.'}</div><div class="quantity-stepper">${btn('−','transfer-quantity',{id:'-1',disabled:q<=1})}<b>${q}</b>${btn('＋','transfer-quantity',{id:'1',disabled:!selected||q>=selected.count})}</div><div class="quantity-presets">${[1,10,100].map(n=>btn(String(n),'transfer-preset',{id:String(n),disabled:!selected||selected.count<n})).join('')}</div>${btn(deposit?'맡기기':'찾기','storage-transfer',{id:selected?.id||'',class:'primary',disabled:!selected||selected.equipped||selected.locked})}<p class="hint">장착 중·잠금 장비는 이동할 수 없습니다.</p></section><section class="warehouse-bag"><h3>소지품 <small>${s.items.length} / 32</small></h3>${pane(s.items,'deposit')}</section></div>`;
}
export function renderShop(s){
 const products=[['demo-potion',500],['demo-scroll-weapon',10000],['demo-scroll-armor',8000]].filter(([id])=>!s.shopFilter||s.shopFilter==='전체'||s.shopFilter==='회복'&&id==='demo-potion'||s.shopFilter==='주문서'&&id!=='demo-potion');
 return `<div class="shop-content">${chips(['전체','회복','주문서'],s.shopFilter||'전체','shop-filter')}<div class="shop-shelves"><aside class="shop-feature"><h3>아데나 상점</h3>${image('assets/ui/shop.png')}<span>모험 준비</span><p>회복 물약 · 강화 주문서</p><div>${icon('coin')} ${number(s.currency.adena)}</div></aside><section class="shop-grid">${products.map(([id,price])=>{const item=catalogItem(id);return `<article class="shop-card"><h3>${M.normalizeName(item.name)}</h3>${image(item.art,item.name)}<span class="shop-stock">보유 ${M.itemById(s,id)?.count||0}개</span><div class="shop-price">${icon('coin')} ${number(price)}</div>${btn('구매','purchase-dialog',{id,class:'primary',disabled:s.currency.adena<price})}</article>`;}).join('')}</section></div><p class="hint">가격은 UI 시연용입니다.</p></div>`;
}
export function renderSettings(s){
 const tab=s.settingTab||'environment';
 const toggle=(id,label)=>`<button class="toggle ${s.settings[id]?'on':''}" data-action="toggle-setting" data-id="${id}" role="switch" aria-checked="${!!s.settings[id]}" aria-label="${label}">${s.settings[id]?'ON':'OFF'}</button>`;
 const row=(name,description,control)=>`<div class="setting-row"><div><h3>${name}</h3><p>${description}</p></div>${control}</div>`;
 const sound=(id,label,v)=>`<label class="range-setting"><span>${label}</span><input type="range" min="0" max="100" value="${s.settings[id]??v}" name="${id}" aria-label="${label}"><output>${s.settings[id]??v}</output></label>`;
 let body='';
 if(tab==='environment')body=`<div class="settings-column">${sound('music','배경음',47)}${sound('ambient','환경음',39)}${sound('effects','효과음',36)}</div><div class="settings-column">${row('전체 소리','사운드 출력',toggle('sound','전체 소리'))}${row('그래픽','화면 밝기',`<input type="range" name="brightness" min="60" max="120" value="${s.settings.brightness||100}" aria-label="화면 밝기">`)}${row('화면','가로 화면 유지','<span class="gold">1280 × 720</span>')}</div>`;
 if(tab==='controls')body=`<div class="settings-column">${row('입력 영역 표시','실제 버튼 사각형을 표시합니다.',`<button class="toggle ${s.settings.hit?'on':''}" data-action="toggle-hit" role="switch" aria-checked="${s.settings.hit}" aria-label="입력 영역 표시">${s.settings.hit?'ON':'OFF'}</button>`)}${row('가방 조작','한 번 선택 · 두 번 사용 / 장착','<span class="gold">사용</span>')}${row('드래그','이동·스크롤 시 사용하지 않음','<span class="gold">사용</span>')}</div><div class="settings-column"><p class="notice">표시 비율 <b id="scale-readout"></b><br>입력 영역은 화면 크기에 맞춰 함께 변환됩니다.</p>${row('화면 초기화','시연 데이터와 설정을 처음으로 되돌립니다.',btn('초기화','reset-sample',{class:'danger'}))}</div>`;
 if(tab==='display')body=`<div class="settings-column">${row('이름 표시','월드 캐릭터 이름',toggle('showNames','캐릭터 이름 표시'))}${row('전투 표시','자동 전투 버튼',toggle('showCombat','전투 버튼 표시'))}</div><div class="settings-column">${row('배경 밝기','맵의 표시 밝기',`<input type="range" name="brightness" min="60" max="120" value="${s.settings.brightness||100}" aria-label="배경 밝기">`)}</div>`;
 if(tab==='info')body=`<div class="settings-column">${row('TWILIGHT','리니지M 화면 구조를 참고한 독립 UI 샘플','<span>v2.0</span>')}${row('샘플 데이터','새로고침하면 초기화됩니다.',btn('초기화','reset-sample'))}${row('스킬 아이콘','기존 TWILIGHT Game-icons 대체 자산',btn('출처','asset-credits'))}</div><div class="settings-column"><p class="notice">본게임 저장·계정과 연결되지 않습니다.<br>아이템·능력치·제작 비용·합성 및 강화 결과는 시연값입니다.</p><a href="review.html" target="_blank">레퍼런스 · 실행 캡처 · 검증 기록 보기</a></div>`;
 return `<div class="settings-content">${tabs([['controls','조작'],['environment','환경'],['display','출력'],['info','정보']],tab,'setting-tab')}<div class="settings-grid">${body}</div></div>`;
}
