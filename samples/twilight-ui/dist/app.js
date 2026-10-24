import { DATA } from './data.js';
import * as M from './model.js';
import {esc,number,grade,screenInfo,icon,btn,iconBtn,image,line,pill,empty,tabs,chips,search,itemSlot} from './helpers.js';
import {renderCards,renderCollection} from './views-cards.js';
import {renderCharacter,renderStats,renderSkills} from './views-character.js';
import {renderInventory,renderForge,renderCraft,renderStorage,renderShop,renderSettings} from './views-items.js';
let s=M.createState();s.screen=new URLSearchParams(location.search).get('screen')||'world';
const $=q=>document.querySelector(q);
let modal=null,previousFocus=null,toastTimer=null,lastTap={id:null,time:0};
function render(){
 const focus=document.activeElement?.dataset?.action,focusId=document.activeElement?.dataset?.id;
 document.body.classList.toggle('touch-debug',s.settings.hit);
 const title=screenInfo[s.screen]||['아덴 대륙'];
 $('#app').innerHTML=`<div class="world-scene" data-action="world-tap" aria-label="기란 마을 게임 화면"></div>
 <div class="hud"><button class="player-summary" data-action="navigate" data-id="character"><b class="level">${s.player.level}</b><span><small>${s.player.name}</small><span class="hp bar"><i style="width:${s.player.hp/s.player.maxHP*100}%"></i><em>${number(s.player.hp)} / ${number(s.player.maxHP)}</em></span><span class="mp bar"><i style="width:${s.player.mp/s.player.maxMP*100}%"></i><em>${s.player.mp} / ${s.player.maxMP}</em></span><small class="combat">AC −82　 MR 126　 SP 18</small></span></button><div class="hud-money">${icon('coin')} ${number(s.currency.adena)} <span class="diamond">◆ ${s.currency.diamond}</span></div><nav class="hud-tools" aria-label="게임 HUD">${[['shop','shop'],['inventory','bag'],['skills','skill'],['character','shield'],['menu','menu']].map(([id,art])=>`<button data-action="navigate" data-id="${id}" aria-label="${screenInfo[id][0]}">${image('assets/ui/'+art+'.png')}<small>${screenInfo[id][0]}</small></button>`).join('')}</nav></div>
 <div class="world-location">기란 마을 <small>Safety Zone</small></div><div class="world-name">황혼의 기사</div><div class="joystick"><i></i></div><div class="attack-controls"><button data-action="auto-toggle" class="auto-button ${s.auto?'active':''}">AUTO</button><button data-action="attack" class="attack-button" aria-label="공격">${image('assets/ui/sword.png')}</button></div>
 <div class="bottom-hud"><span class="exp">Lv.${s.player.level}　EXP 71.24%</span><div class="quick-slots">${s.quickslots[s.quickPage].map((id,i)=>quickslot(id,i)).join('')}<button class="quick-page" data-action="quick-page" aria-label="퀵슬롯 페이지">${s.quickPage+1} / 2</button></div><button class="debug-shortcut" data-action="navigate" data-id="settings">설정</button></div>
 ${s.screen==='world'?'':s.screen==='menu'?renderMenu():`<section class="game-window window-${s.screen}" aria-label="${title[0]}"><header class="window-heading"><h1>${title[0]}</h1><span class="window-currency">${icon('coin')} ${number(s.currency.adena)}</span>${iconBtn('close','navigate','창 닫기','data-id="world"')}</header><div id="screen" class="screen-body">${renderScreen()}</div><div class="sample-note">TWILIGHT · 시연 데이터</div></section>`}`;
 document.title=`${title[0]} · TWILIGHT`;
 document.querySelector('.world-name').style.display=s.settings.showNames?'':'none';document.querySelector('.attack-controls').style.display=s.settings.showCombat?'':'none';document.querySelector('.world-scene').style.filter=`brightness(${(s.settings.brightness||100)/100})`;if(document.querySelector('#scale-readout'))document.querySelector('#scale-readout').textContent=Math.round(Math.min(document.documentElement.clientWidth/1280,document.documentElement.clientHeight/720)*100)+'%';
 if(focus){const target=[...document.querySelectorAll('#app [data-action]')].find(el=>el.dataset.action===focus&&el.dataset.id===focusId);target?.focus({preventScroll:true});}
}
function renderScreen(){
 if(['transform','doll','relic'].includes(s.screen))return renderCards(s);
 return ({collection:renderCollection,inventory:renderInventory,character:renderCharacter,stats:renderStats,skills:renderSkills,forge:renderForge,craft:renderCraft,storage:renderStorage,shop:renderShop,settings:renderSettings}[s.screen]||renderMenu)(s);
}
function renderMenu(){
 const ids=['transform','doll','relic','collection','character','stats','inventory','skills','forge','craft','storage','shop','settings'];
 const arts={transform:'cards/t03.png',doll:'cards/d03.png',relic:'cards/r03.png',collection:'ui/shield.png',character:'ui/shield.png',stats:'ui/heal.png',inventory:'ui/bag.png',skills:'ui/skill.png',forge:'items/weapon_scroll.png',craft:'items/armor_scroll.png',storage:'items/steel_armor.png',shop:'ui/shop.png',settings:'ui/settings.png'};
 return `<section class="full-menu" aria-label="전체 메뉴"><header><span>전체 메뉴</span>${iconBtn('close','navigate','메뉴 닫기','data-id="world"')}</header><div class="menu-grid">${ids.map(id=>`<button class="menu-cell" data-action="navigate" data-id="${id}">${image('assets/'+arts[id])}<span>${screenInfo[id][0]}</span></button>`).join('')}</div><footer>TWILIGHT <span>UI SAMPLE</span></footer></section>`;
}
function quickslot(id,i){
 const item=M.itemById(s,id),sk=M.skillById(s,id),thing=item||sk,reason=sk?M.skillReason(s,sk):'';
 return `<button class="quick-slot ${thing?'filled':''}" data-action="quick-use" data-id="${id||''}" aria-label="${thing?thing.name+' 빠른 사용':'빈 퀵슬롯 '+(i+1)}"><span class="keycap">${i+1}</span>${thing?image(item?.art||sk.icon,thing.name):icon('plus')}<small>${thing?thing.name:'등록'}</small>${item?`<span class="item-count">${item.count}</span>`:sk&&reason!=='사용 가능'?`<span class="quick-unavailable" data-quick-status="${sk.id}">${reason.startsWith('재사용')?'대기':'MP'}</span>`:''}</button>`;
}
function toast(message,duration=3200,color=''){const t=$('#toast');t.textContent=message;t.style.color=color;t.classList.add('show');clearTimeout(toastTimer);toastTimer=setTimeout(()=>t.classList.remove('show'),duration);}
function openModal(title,body,buttons=[],options={}){if(!modal)previousFocus=document.activeElement;modal={title,body,buttons,...options};drawModal();$('#app').inert=true;requestAnimationFrame(()=>$('#modal-root .modal')?.focus());}
function drawModal(){if(!modal)return;$('#modal-root').innerHTML=`<div class="modal-backdrop"><section class="modal ${modal.class||''}" role="dialog" aria-modal="true" aria-labelledby="modal-title" tabindex="-1"><header class="modal-heading"><h2 id="modal-title">${modal.title}</h2>${!modal.busy?iconBtn('close','close-modal','닫기'):''}</header><div class="modal-body">${modal.body}</div>${modal.buttons.length?`<footer class="modal-actions">${modal.buttons.map((b,i)=>btn(b.text,'modal-choice',{class:b.class||'secondary',id:String(i),disabled:b.disabled})).join('')}</footer>`:''}</section></div>`;}
function closeModal(force=false){if(modal?.busy&&!force)return;modal=null;$('#modal-root').innerHTML='';$('#app').inert=false;previousFocus?.isConnected&&previousFocus.focus();}
function confirm(title,body,onConfirm,label='확인',options={}){openModal(title,body,[{text:'취소',class:'danger',action:()=>closeModal()},{text:label,class:'blue',action:()=>{closeModal();onConfirm();}}],options);}
function navigate(screen){
 if(!screenInfo[screen]||s.forgeBusy||s.fusionBusy)return;
 const go=()=>{s.screen=screen;s.cardTab='cards';s.grade='전체';s.ownedFilter='전체';s.cardSearch='';s.fusion=[];lastTap={id:null,time:0};render();window.scrollTo({top:0,behavior:'instant'});};
 if(s.screen==='stats'&&screen!=='stats'&&M.dirtyStats(s)){confirm('배분을 취소할까요?','<p>아직 확정하지 않은 스탯 배분이 있습니다. 화면을 나가면 이번 배분이 취소됩니다.</p>',()=>{M.discardStats(s);go();},'취소하고 이동');return;}go();
}
function showItemDetail(id=s.selectedItem){
 const item=M.itemById(s,id);if(!item)return;s.selectedItem=id;
 openModal('아이템 상세',`<div class="item-detail-head">${image(item.art,item.name)}<div><span class="eyebrow" style="color:${grade(item.grade)}">${item.grade}</span><h3>${M.displayItem(item)}</h3><span class="muted">${item.equipped?'장착 중':item.locked?'잠긴 아이템':'보유 중'}</span></div></div><div class="item-options">${line('수량',item.count+'개')}${line('분류',{weapon:'무기',armor:'방어구',potion:'회복 물약',scroll:'강화 주문서'}[item.type])}${['weapon','armor'].includes(item.type)?line(item.type==='weapon'?'추가 대미지':'방어 보너스','+'+item.enchant):''}${line('잠금',item.locked?'설정됨':'해제됨')}</div><p class="hint">${item.type==='scroll'?'주문서를 사용하면 강화할 장비를 선택합니다.':item.type==='potion'?'체력을 180 회복합니다.':'장착 상태를 변경하거나 강화창으로 이동할 수 있습니다.'}</p>`,[{text:item.locked?'잠금 해제':'잠금',action:()=>{M.toggleLock(s,id);closeModal();render();showItemDetail(id);}},...(['weapon','armor'].includes(item.type)?[{text:'강화',action:()=>{if(item.locked){toast('잠금을 먼저 해제해 주세요.');return;}closeModal();M.selectForgeTarget(s,id);navigate('forge');}}]:[]),{text:item.equipped?'장착 해제':['weapon','armor'].includes(item.type)?'장착하기':'사용하기',class:'primary',action:()=>{closeModal();const r=M.useItem(s,id);render();toast(r.message);}}],{class:'item-modal'});
}
function showCollectionCandidates(slot){
 const col=s.equipmentCollections.find(c=>c.id===s.selectedCollection),req=col?.requirements.find(r=>r.slot===slot);if(!req)return;const items=M.eligibleItems(s,req);
 openModal('등록할 장비 선택',`<p><b>+${req.enchant} ${req.name}</b> 1개가 필요합니다.</p>${items.length?`<div class="stack">${items.map(i=>`<button class="material-card" data-action="register-item" data-id="${i.id}" data-slot="${slot}" data-collection="${col.id}">${image(i.art,i.name)}<span><b>${M.displayItem(i)}</b><small>미장착 · 잠금 해제 · 등록 가능</small></span>${icon('next')}</button>`).join('')}</div>`:empty('조건에 맞는 장비가 없습니다.','강화 단계가 같고, 장착 및 잠금이 해제된 장비만 등록할 수 있습니다.')}`,[{text:'닫기',action:()=>closeModal()}]);
}
function showDetailedStats(){
 const rows=[['공격','근거리 대미지',M.derivedStats(s).attack],['공격','근거리 명중',M.derivedStats(s).hit],['공격','마법 대미지',M.derivedStats(s).magic],['방어','AC','−82'],['방어','대미지 리덕션','8'],['저항','마법 방어력','126%'],['저항','스턴 내성','15%'],['회복','HP 회복','25'],['회복','MP 회복','12'],['속도','공격 속도','+125%'],['속도','이동 속도','+15%']];
 const list=rows.filter(([g,n])=>s.statGroup==='전체'||s.statGroup===g||s.statGroup==='즐겨찾기'&&s.statFavorites.includes(n));
 openModal('상세 능력치',`${chips(['전체','공격','방어','저항','회복','속도','즐겨찾기'],s.statGroup,'stat-group')}<div class="detail-stats">${list.map(([g,n,v])=>`<div class="detail-stat"><button class="icon-button ${s.statFavorites.includes(n)?'gold':''}" data-action="stat-favorite" data-id="${n}" aria-label="${n} 즐겨찾기" aria-pressed="${s.statFavorites.includes(n)}">${icon('star')}</button><span>${n}<small>${g}</small></span><b>${v}</b></div>`).join('')||empty('즐겨찾는 능력치가 없습니다.','별을 눌러 자주 보는 능력치를 모아보세요.')}</div>`,[{text:'닫기',action:()=>closeModal()}],{class:'wide-modal'});
}
function confirmForge(){
 if(!M.canForge(s))return;const item=M.itemById(s,s.forgeTarget),scroll=M.itemById(s,s.forgeScroll),result={success:`+${item.enchant+1} 강화 성공`,keep:`+${item.enchant} 유지`,down:`+${Math.max(0,item.enchant-1)} 하락`}[s.forgeOutcome];
 confirm('강화를 진행할까요?',`<div class="item-detail-head">${image(item.art,item.name)}<div><h3>${M.displayItem(item)}</h3><p class="muted">${item.equipped?'현재 장착 중인 장비입니다.':'가방에 있는 장비입니다.'}</p></div></div>${line('소모 재료',scroll.name+' 1장')}${line('선택한 시연 결과',result)}<div class="notice">주문서 1장이 소모됩니다. ${s.forgeOutcome==='down'?'이번 시연에서는 강화 단계가 1 내려갑니다.':'결과는 선택한 시연 설정대로 표시됩니다.'}</div>`,()=>{
 const t=M.startForge(s);if(!t){toast('장비와 주문서 상태를 다시 확인해 주세요.');return;}
 openModal('장비를 강화하고 있습니다',`<div class="processing">${icon('forge')}<p>새로운 힘을 새기는 중…</p><div class="progress-track"><i></i></div></div>`,[],{busy:true,class:'flow-modal'});
 setTimeout(()=>{const result=M.finishForge(s,t);closeModal(true);render();if(!result){toast('강화를 완료하지 못했습니다.');return;}openModal(result.outcome==='success'?'강화 성공':result.outcome==='down'?'강화 단계 하락':'강화 단계 유지',`<div class="fusion-result"><span class="eyebrow">SAMPLE RESULT</span>${image(result.art,result.name)}<h3>+${result.after} ${result.name}</h3><p>+${result.before} → +${result.after}</p><small>주문서 1장을 사용했습니다.</small></div>`,[{text:'확인',class:'primary',action:()=>closeModal()}],{class:'flow-modal'});},900);
 },'강화 진행',{class:'flow-modal'});
}
function confirmFusion(){
 const c=M.category(s);if(s.fusion.length!==4)return;const counts={};for(const id of s.fusion)counts[id]=(counts[id]||0)+1;
 confirm('카드를 합성할까요?',`<p>선택한 중복 카드 4장을 소모합니다.</p>${Object.entries(counts).map(([id,n])=>line(M.cardById(s,id).name,n+'장')).join('')}<div class="notice">이번 시연에서는 영웅 카드를 획득합니다. 보유한 첫 카드는 남습니다.</div>`,()=>{
 const t=M.startFusion(s,c.id);if(!t){toast('합성 재료를 다시 선택해 주세요.');return;}
 openModal('새로운 힘이 깨어납니다',`<div class="processing">${icon('relic')}<p>카드의 힘을 모으는 중…</p><div class="progress-track"><i></i></div></div>`,[],{busy:true,class:'flow-modal'});
 setTimeout(()=>{const card=M.finishFusion(s,t);closeModal(true);render();if(!card)return;openModal('영웅 카드 획득',`<div class="fusion-result" style="--grade:${grade(card.grade)}"><span class="eyebrow">SAMPLE RESULT · HERO</span>${image(card.art,card.name)}<h2>${card.name}</h2><p>새로운 컬렉션을 확인해 보세요.</p></div>`,[{text:'확인',action:()=>closeModal()},{text:'컬렉션 보기',class:'primary',action:()=>{closeModal();s.cardTab='collection';render();}}],{class:'flow-modal'});},1000);
 },'4장 소모하고 합성',{class:'flow-modal'});
}
function showPurchase(id){
 const item=DATA.items.find(i=>i.id===id),price={'demo-potion':500,'demo-scroll-weapon':10000,'demo-scroll-armor':8000}[id],total=price*s.purchaseQuantity;
 openModal('물품 구매',`<div class="item-detail-head">${image(item.art,item.name)}<h3>${item.name}</h3></div><div class="purchase-control">${iconBtn('minus','purchase-minus','구매 수량 줄이기',`data-id="${id}" ${s.purchaseQuantity<=1?'disabled':''}`)}<b>${s.purchaseQuantity}</b>${iconBtn('plus','purchase-plus','구매 수량 늘리기',`data-id="${id}" ${s.purchaseQuantity>=20?'disabled':''}`)}</div>${line('합계',number(total)+' 아데나')}${line('보유 아데나',number(s.currency.adena))}`,[{text:'취소',action:()=>closeModal()},{text:'구매',class:'primary',disabled:total>s.currency.adena,action:()=>{if(M.purchase(s,id,s.purchaseQuantity)){closeModal();render();toast('구매 완료 · 가방에 보관했습니다.');}}}]);
}
function onAction(action,id,el){switch(action){
 case 'navigate':navigate(id);break;
 case 'world-tap':toast('기란 마을 · UI 시연 화면');break;
 case 'auto-toggle':s.auto=!s.auto;render();break;
 case 'attack':toast('공격 · UI 시연');break;
 case 'craft-filter':s.craftFilter=id;s.recipe=id==='all'?'potion':id;s.craftQuantity=1;render();break;
 case 'shop-filter':s.shopFilter=id;render();break;
 case 'storage-select':s.storageMode=el.closest('[data-mode]')?.dataset.mode||s.storageMode;s.storageSelected=id;s.transferQuantity=1;render();break;
 case 'transfer-quantity':s.transferQuantity=Math.max(1,(s.transferQuantity||1)+Number(id));render();break;
 case 'transfer-preset':s.transferQuantity=Number(id);render();break;
 case 'setting-tab':s.settingTab=id;render();break;
 case 'toggle-sound':s.settings.sound=!s.settings.sound;render();break;
 case 'toggle-setting':s.settings[id]=!s.settings[id];render();break;
 case 'craft-quantity':s.craftQuantity=Math.min(20,Math.max(1,(s.craftQuantity||1)+Number(id)));render();break;
 case 'close-modal':closeModal();break;
 case 'modal-choice':{const c=modal?.buttons[Number(id)];if(c&&!c.disabled)c.action();break;}
 case 'help':openModal('TWILIGHT UI 샘플',`<p>13개의 세부창과 선택·확인·결과 흐름을 체험할 수 있습니다.</p><div class="notice"><b>메뉴 전체가 버튼입니다.</b><p>아이콘, 이름, 주변 여백을 모두 누를 수 있습니다. 설정에서 터치 영역을 표시해 보세요.</p></div><p><b>가방</b> · 한 번 누르면 선택, 두 번 누르면 사용 또는 장착.</p><p><b>스탯</b> · + / −로 조정한 뒤 확정.</p><p><b>합성 · 강화 · 컬렉션</b> · 마지막 확인 후 재료 소모.</p><p class="hint">예시 데이터는 새로고침하거나 설정에서 초기화할 수 있습니다.</p>`,[{text:'체험하기',class:'primary',action:()=>closeModal()}]);break;
 case 'card-tab':s.cardTab=id;s.fusion=[];if(id==='collection'){s.collectionFilter='전체';s.collectionSearch='';s.selectedCollection=M.category(s).collections[0].id;}render();break;
 case 'select-card':M.category(s).selected_id=id;render();break;
 case 'grade':s.grade=id;render();break;
 case 'owned-filter':s.ownedFilter=['전체','보유','미보유'].includes(id)?id:'전체';render();break;
 case 'apply-card':{const c=M.category(s),card=M.cardById(s,id);confirm(`${c.label}을 적용할까요?`,`<div class="item-detail-head">${image(card.art,card.name)}<div><h3>${card.name}</h3><p>${card.grade} ${c.label}</p></div></div>`,()=>{if(M.applyCard(s,c.id,id)){render();toast(`${card.name} 적용 완료`);}},'적용');break;}
 case 'related-collection':s.cardTab='collection';s.collectionFilter='전체';s.collectionSearch='';s.selectedCollection=M.category(s).collections.find(c=>c.requires.includes(id))?.id;render();break;
 case 'open-card':{const c=s.categories.find(c=>c.cards.some(x=>x.id===id));s.screen=c.id;s.cardTab='cards';s.grade='전체';s.ownedFilter='전체';s.cardSearch='';c.selected_id=id;render();break;}
 case 'add-fusion':M.addFusion(s,s.screen,id);render();break;
 case 'remove-fusion':s.fusion.splice(Number(id),1);render();break;
 case 'auto-fusion':M.autofillFusion(s,s.screen);render();break;
 case 'confirm-fusion':confirmFusion();break;
 case 'collection-type':s.collectionType=id;s.collectionFilter='전체';s.collectionSearch='';s.selectedCollection=(id==='equipment'?s.equipmentCollections:M.category(s,id).collections)[0].id;render();break;
 case 'collection-filter':s.collectionFilter=id;render();break;
 case 'select-requirement':s.selectedCollection=el.dataset.collection;s.selectedRequirement=id;render();break;
 case 'select-collection':s.selectedCollection=id;render();break;
 case 'favorite-collection':{const c=[...s.equipmentCollections,...s.categories.flatMap(c=>c.collections)].find(c=>c.id===id);if(c)c.favorite=!c.favorite;render();break;}
 case 'collection-candidates':if(el.dataset.collection)s.selectedCollection=el.dataset.collection;showCollectionCandidates(id);break;
 case 'register-item':{const item=M.itemById(s,id),colId=el.dataset.collection,slot=el.dataset.slot;closeModal();confirm('장비를 등록할까요?',`<div class="item-detail-head">${image(item.art,item.name)}<div><h3>${M.displayItem(item)}</h3><p>이 장비 1개가 소모됩니다.</p></div></div><div class="notice">등록한 장비는 가방에서 사라집니다.</div>`,()=>{if(M.registerItem(s,colId,slot,id)){render();toast('컬렉션 등록이 완료되었습니다.');}else toast('등록 조건이 변경되었습니다. 재료를 확인해 주세요.');},'소모하고 등록');break;}
 case 'clear-item':s.selectedItem=null;lastTap={id:null,time:0};render();break;
 case 'select-item':{const now=performance.now();s.selectedItem=id;const double=lastTap.id===id&&now-lastTap.time<350;lastTap={id:double?null:id,time:now};if(double){const r=M.useItem(s,id);render();toast(r.message);}else{render();toast(M.displayItem(M.itemById(s,id)),5000,grade(M.itemById(s,id).grade));}break;}
 case 'item-detail':showItemDetail();break;
 case 'lock-item':M.toggleLock(s,s.selectedItem);render();toast(M.itemById(s,s.selectedItem)?.locked?'아이템을 잠갔습니다.':'잠금을 해제했습니다.');break;
 case 'inventory-filter':s.inventoryFilter=id;lastTap={id:null,time:0};render();break;
 case 'sort-inventory':s.items.sort((a,b)=>a.name.localeCompare(b.name,'ko')||b.enchant-a.enchant);render();toast('이름순으로 정렬했습니다.');break;
 case 'equipment-slot':if(id==='empty'){navigate('inventory');toast('가방에서 장비를 선택해 장착하세요.');}else showItemDetail(id);break;
 case 'equipment-page':s.equipmentPage=Number(id);render();break;
 case 'detail-stats':showDetailedStats();break;
 case 'stat-group':s.statGroup=id;showDetailedStats();break;
 case 'stat-favorite':s.statFavorites=s.statFavorites.includes(id)?s.statFavorites.filter(x=>x!==id):[...s.statFavorites,id];showDetailedStats();break;
 case 'stat-plus':M.adjustStat(s,id,1);render();break;
 case 'stat-minus':M.adjustStat(s,id,-1);render();break;
 case 'reset-draft':M.discardStats(s);render();break;
 case 'confirm-stats':confirm('스탯 배분을 확정할까요?',`${Object.entries(s.draft).filter(([,v])=>v).map(([k,v])=>line(`${M.STAT_NAMES[k]} (${k})`,`${s.stats[k]} → ${s.stats[k]+v}`)).join('')}<p class="notice">${M.spentPoints(s)} 포인트를 사용합니다.</p>`,()=>{if(M.commitStats(s)){s.player.maxHP=M.derivedStats(s).hp;s.player.maxMP=M.derivedStats(s).mp;render();toast('능력치 배분이 확정되었습니다.');}},'확정');break;
 case 'select-skill':s.selectedSkill=id;render();break;
 case 'skill-filter':s.skillFilter=id;render();break;
 case 'use-skill':{const sk=M.skillById(s,id),ok=M.useSkill(s,id);render();toast(ok?`${sk.name} 사용 · MP ${sk.mp} 소모`:M.skillReason(s,sk));break;}
 case 'restore-mp':s.player.mp=s.player.maxMP;render();toast('시연 MP를 모두 회복했습니다.');break;
 case 'learn-skill':{const sk=M.skillById(s,id);confirm('스킬을 배울까요?',`<div class="item-detail-head">${image(sk.icon,sk.name)}<h3>${sk.name}</h3></div>${line('필요 아데나','120,000')}`,()=>{if(M.learnSkill(s,id)){render();toast(`${sk.name} 습득 완료`);}else toast('습득 조건이나 아데나를 확인해 주세요.');},'배우기');break;}
 case 'quick-register':openModal('퀵슬롯 선택',`<p>${M.skillById(s,id).name}을 등록할 위치를 선택하세요.</p><div class="slot-picker">${s.quickslots[s.quickPage].map((x,i)=>`<button class="quick-slot" data-action="set-quick" data-id="${id}" data-slot="${i}"><b>${i+1}</b><small>${M.skillById(s,x)?.name||M.itemById(s,x)?.name||'비어 있음'}</small></button>`).join('')}</div><p class="hint">${s.quickPage+1}페이지 · 기존 등록은 선택한 스킬로 교체됩니다.</p>`,[{text:'취소',action:()=>closeModal()}]);break;
 case 'set-quick':if(M.registerQuickslot(s,id,Number(el.dataset.slot))){closeModal();render();toast('퀵슬롯에 등록했습니다.');}break;
 case 'quick-page':s.quickPage=(s.quickPage+1)%2;render();break;
 case 'quick-use':if(!id){navigate('skills');toast('스킬을 선택한 뒤 퀵슬롯 등록을 눌러주세요.');}else if(M.itemById(s,id)){const r=M.useItem(s,id);render();toast(r.message);}else if(M.skillById(s,id))onAction('use-skill',id,el);else toast('사용할 아이템이 없습니다.');break;
 case 'forge-target':M.selectForgeTarget(s,id);render();break;
 case 'confirm-forge':confirmForge();break;
 case 'recipe':s.recipe=id;s.craftQuantity=1;render();break;
 case 'confirm-craft':{const recipe=id||s.recipe,q=s.craftQuantity||1;s.recipe=recipe;confirm('제작할까요?',`<p>${recipe==='potion'?number(1500*q)+' 아데나로 강력 HP 물약 '+q*3+'개를 만듭니다.':'무기 마법 주문서 '+q*2+'장과 '+number(5000*q)+' 아데나를 소모해 갑옷 마법 주문서 '+q+'장을 만듭니다.'}</p>`,()=>{if(M.craft(s,recipe,q)){render();toast('제작 완료 · 가방에 보관했습니다.');}else toast('제작 재료가 부족합니다.');},'제작');break;}
 case 'storage-mode':s.storageMode=id;s.storageSelected=null;s.transferQuantity=1;render();break;
 case 'storage-transfer':{const item=(s.storageMode==='deposit'?s.items:s.storage).find(i=>i.id===id),mode=s.storageMode;if(!item)return;const q=Math.min(item.count,s.transferQuantity||1);confirm(mode==='deposit'?'창고에 맡길까요?':'가방으로 찾을까요?',`<div class="item-detail-head">${image(item.art,item.name)}<div><h3>${M.displayItem(item)}</h3><p>${q}개 / 보유 ${item.count}개</p></div></div>`,()=>{if(M.transferStorage(s,id,mode,q)){s.storageSelected=null;s.transferQuantity=1;render();toast(mode==='deposit'?'창고에 보관했습니다.':'가방으로 옮겼습니다.');}},mode==='deposit'?'맡기기':'찾기');break;}
 case 'purchase-dialog':s.purchaseQuantity=1;showPurchase(id);break;
 case 'purchase-minus':s.purchaseQuantity=Math.max(1,s.purchaseQuantity-1);showPurchase(id);break;
 case 'purchase-plus':s.purchaseQuantity=Math.min(20,s.purchaseQuantity+1);showPurchase(id);break;
 case 'toggle-large':s.settings.large=!s.settings.large;render();break;
 case 'toggle-hit':s.settings.hit=!s.settings.hit;render();break;
 case 'reset-sample':confirm('샘플을 처음으로 되돌릴까요?','<p>이 샘플에서 변경한 카드, 장비, 재화와 스탯을 모두 초기화합니다.</p>',()=>{s=M.createState();lastTap={id:null,time:0};render();toast('샘플을 초기화했습니다.');},'초기화');break;
 case 'asset-credits':openModal('스킬 아이콘 출처',`<p>Game-icons 기반 TWILIGHT 대체 아이콘 · CC BY 3.0</p><div class="credits-list">${DATA.skills.map(sk=>`<p><b>${sk.name}</b><br>${sk.attribution.author} · <a href="https://github.com/game-icons/icons/blob/82d948812bfe3f269ef8f731dcdb07b08160edc4/${sk.attribution.source}" target="_blank" rel="noopener noreferrer">${sk.attribution.source}</a></p>`).join('')}</div><p class="hint">원본 아이콘에 색상과 테두리 등을 적용한 기존 저장소 파일을 사용했습니다.</p>`,[{text:'닫기',action:()=>closeModal()}]);break;
}}

let pointerStart=null,suppressClickUntil=0;
document.addEventListener('pointerdown',e=>{pointerStart={x:e.clientX,y:e.clientY};});
document.addEventListener('pointerup',()=>{pointerStart=null;});
document.addEventListener('pointercancel',()=>{pointerStart=null;});
document.addEventListener('pointermove',e=>{if(pointerStart&&Math.hypot(e.clientX-pointerStart.x,e.clientY-pointerStart.y)>7){suppressClickUntil=performance.now()+400;lastTap={id:null,time:0};}},true);
document.addEventListener('scroll',()=>{lastTap={id:null,time:0};},true);
document.addEventListener('click',event=>{const el=event.target.closest('[data-action]');if(el&&['select-item','select-card','select-skill','storage-select'].includes(el.dataset.action)&&performance.now()<suppressClickUntil){event.preventDefault();return;}if(!el||el.disabled||el.closest('[inert]'))return;onAction(el.dataset.action,el.dataset.id,el);});
document.addEventListener('change',event=>{if(event.target.name==='forgeOutcome'){s.forgeOutcome=event.target.value;render();}});
function applySearch(event){const key=event.target.name;if(['music','ambient','effects','brightness'].includes(key)){s.settings[key]=Number(event.target.value);const output=event.target.parentElement.querySelector('output');if(output)output.textContent=event.target.value;if(key==='brightness')document.querySelector('.world-scene').style.filter=`brightness(${s.settings[key]/100})`;return;}if(!['cardSearch','inventorySearch','collectionSearch','skillSearch'].includes(key))return;s[key]=event.target.value;if(event.isComposing||event.target.dataset.composing==='true')return;const pos=event.target.selectionStart;$('#screen').innerHTML=renderScreen();const input=document.querySelector(`[name="${key}"]`);input?.focus();try{input?.setSelectionRange(pos,pos);}catch{}}
document.addEventListener('input',applySearch);
document.addEventListener('compositionstart',event=>{if(event.target.matches?.('input[type="search"]'))event.target.dataset.composing='true';});
document.addEventListener('compositionend',event=>{if(event.target.matches?.('input[type="search"]')){delete event.target.dataset.composing;applySearch(event);}});
document.addEventListener('keydown',event=>{if(event.key==='Escape'){if(modal)closeModal();else if(s.screen!=='world')navigate('world');}if(event.key==='Tab'&&modal){const list=[...document.querySelectorAll('.modal button:not([disabled]),.modal a,.modal input,.modal select')];if(!list.length){event.preventDefault();return;}const first=list[0],last=list.at(-1);if(event.shiftKey&&(document.activeElement===first||document.activeElement.classList.contains('modal'))){event.preventDefault();last.focus();}else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first.focus();}}});
setInterval(()=>{document.querySelectorAll('[data-skill-status]').forEach(el=>{const sk=M.skillById(s,el.dataset.skillStatus);if(sk)el.textContent=M.skillReason(s,sk);});document.querySelectorAll('[data-quick-status]').forEach(el=>{const sk=M.skillById(s,el.dataset.quickStatus),reason=M.skillReason(s,sk);if(reason==='사용 가능')el.remove();else el.textContent=reason.startsWith('재사용')?'대기':'MP';});if(s.screen==='skills'&&!modal){const button=document.querySelector('[data-action="use-skill"]');if(button){const sk=M.skillById(s,button.dataset.id);button.disabled=!sk||M.skillReason(s,sk)!=='사용 가능';}}},1000);
render();

function resizeStage(){const scale=Math.min(document.documentElement.clientWidth/1280,document.documentElement.clientHeight/720);document.documentElement.style.setProperty('--stage-scale',scale);document.documentElement.style.setProperty('--display-scale',scale);}
addEventListener('resize',resizeStage);resizeStage();
