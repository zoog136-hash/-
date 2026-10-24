import { DATA } from './data.js';

export const STAT_NAMES = {STR:'힘', DEX:'민첩', CON:'체력', INT:'지능', WIS:'지혜', CHA:'매력'};
export const GRADES = {'일반':'#b6b9ba','고급':'#75be8c','희귀':'#70a9e2','영웅':'#dc766e','전설':'#b08be3','신화':'#dfc06d'};
const copy = value => JSON.parse(JSON.stringify(value));
export function createState(now = Date.now()) {
  const skills = copy(DATA.skills).map((s,i) => ({...s, learned:![3].includes(i), passive:i===4, mp:[60,20,80,90,0,30,35,50][i], cooldown: i===2 ? now+18000 : 0, cooldownSeconds:[8,12,18,20,0,8,12,10][i], description:[
    '마력을 응축한 구체를 날려 대상에게 피해를 줍니다.',
    '마법의 보호막으로 몸을 감싸 방어력을 높입니다.',
    '강한 충격을 가해 적의 움직임을 잠시 멈춥니다.',
    '적의 공격을 받아내고 반격할 기회를 만듭니다.',
    '갑옷의 방어 능력을 높입니다. 습득 시 항상 적용됩니다.',
    '생명의 기운으로 체력을 회복합니다.',
    '무기에 축복을 내려 전투 능력을 높입니다.',
    '세 발의 화살을 연속으로 발사합니다.'
  ][i]}));
  return {
    screen:'transform', categories:copy(DATA.categories), items:copy(DATA.items), equipmentCollections:copy(DATA.equipmentCollections), skills,
    player:{name:'황혼의 기사',job:'기사',level:80,hp:2310,maxHP:2850,mp:42,maxMP:420},
    currency:{adena:1245800,diamond:320}, stats:{STR:35,DEX:18,CON:22,INT:10,WIS:12,CHA:8}, points:3,
    draft:{STR:0,DEX:0,CON:0,INT:0,WIS:0,CHA:0}, selectedItem:'demo-dagger-free', selectedSkill:skills[1].id,
    cardTab:'cards', grade:'전체', ownedFilter:'전체', fusion:[], cardSearch:'', inventoryFilter:'전체', inventorySearch:'',
    collectionType:'equipment', selectedCollection:'demo-collection-01', collectionFilter:'전체', collectionSearch:'',
    skillFilter:'전체', skillSearch:'', equipmentPage:1, statGroup:'전체', statFavorites:[],
    forgeTarget:'demo-dagger-free', forgeScroll:'demo-scroll-weapon', forgeOutcome:'success', forgeBusy:false, forgeTransaction:0,
    fusionBusy:false, fusionTransaction:0, forgeLast:null, fusionLast:null,
    quickPage:0, quickslots:[['demo-potion',skills[1].id,skills[2].id,null,null],[skills[0].id,null,null,null,null]],
    storage:[{...copy(DATA.items[3]),id:'storage-shield',locked:false,count:1}], storageMode:'deposit',
    settings:{large:false,hit:false,sound:true,showNames:true,showCombat:true,brightness:100}, recipe:'potion', purchaseQuantity:1,
  };
}
export const category = (s,id=s.screen) => s.categories.find(c=>c.id===id);
export const cardById = (s,id) => s.categories.flatMap(c=>c.cards).find(c=>c.id===id);
export const itemById = (s,id) => s.items.find(i=>i.id===id && i.count>0);
export const skillById = (s,id) => s.skills.find(i=>i.id===id);
export const displayItem = item => `${['weapon','armor'].includes(item.type)?`+${item.enchant} `:''}${item.name}`;
export const spentPoints = s => Object.values(s.draft).reduce((a,b)=>a+b,0);
export const remainingPoints = s => s.points-spentPoints(s);
export const dirtyStats = s => spentPoints(s)>0;
export function adjustStat(s,key,delta) {
  if (!(key in s.draft) || ![1,-1].includes(delta)) return false;
  if (delta>0 && remainingPoints(s)<=0 || delta<0 && s.draft[key]<=0) return false;
  s.draft[key]+=delta; return true;
}
export function discardStats(s) { for (const k in s.draft) s.draft[k]=0; }
export function commitStats(s) {
  const spent=spentPoints(s); if(spent<=0 || spent>s.points) return false;
  for (const k in s.draft) s.stats[k]+=s.draft[k];
  s.points-=spent; discardStats(s); return true;
}
export function derivedStats(s,preview=false) {
  const x=Object.fromEntries(Object.keys(s.stats).map(k=>[k,s.stats[k]+(preview?s.draft[k]:0)]));
  return {attack:65+x.STR-35,hit:78+x.DEX-18,hp:2850+(x.CON-22)*35,mp:420+(x.WIS-12)*12,magic:18+x.INT-10,weight:6200+(x.CHA-8)*100};
}
export function applyCard(s,catId,id) {
  const c=category(s,catId), card=c?.cards.find(x=>x.id===id);
  if(!card?.owned || c.equipped_id===id || s.fusionBusy) return false;
  c.equipped_id=id; return true;
}
export function fusionAvailable(s,catId,id) {
  const card=category(s,catId)?.cards.find(c=>c.id===id);
  return !!card && card.owned && !card.locked && card.grade==='희귀' && card.spares>s.fusion.filter(x=>x===id).length;
}
export function addFusion(s,catId,id) {
  if(s.fusionBusy || s.fusion.length>=4 || !fusionAvailable(s,catId,id)) return false;
  s.fusion.push(id);return true;
}
export function autofillFusion(s,catId) {
  if(s.fusionBusy)return;
  s.fusion=[];
  for(const c of category(s,catId).cards) while(s.fusion.length<4 && fusionAvailable(s,catId,c.id)) s.fusion.push(c.id);
}
export function startFusion(s,catId) {
  if(s.fusionBusy || s.fusion.length!==4)return null;
  const c=category(s,catId), counts={}; if(!c)return null;
  for(const id of s.fusion) counts[id]=(counts[id]||0)+1;
  if(Object.entries(counts).some(([id,n])=>{const x=c.cards.find(z=>z.id===id);return !x?.owned||x.locked||x.grade!=='희귀'||x.spares<n;}))return null;
  s.fusionBusy=true;
  return {id:++s.fusionTransaction,catId,counts};
}
export function finishFusion(s,transaction) {
  if(!transaction || !s.fusionBusy || transaction.id!==s.fusionTransaction) return false;
  const c=category(s,transaction.catId);
  for(const [id,n] of Object.entries(transaction.counts)) c.cards.find(x=>x.id===id).spares-=n;
  const result=c.cards.find(x=>x.id===c.fusion_success_card_id);
  if(result.owned)result.spares++; else result.owned=true;
  c.selected_id=result.id; s.fusion=[];s.fusionBusy=false;s.fusionLast=result.id;return result;
}
export const cardCollectionComplete = (s,col) => col.requires.every(id=>cardById(s,id)?.owned);
export const normalizeName = name => name.replace(/\s*\(각인\)/g,'').trim();
export function eligibleItems(s,requirement) {
  return s.items.filter(i=>i.count>=requirement.count && normalizeName(i.name)===normalizeName(requirement.name) && i.enchant===requirement.enchant && !i.equipped && !i.locked);
}
export function registerItem(s,colId,slot,itemId) {
  const col=s.equipmentCollections.find(c=>c.id===colId), req=col?.requirements.find(r=>r.slot===slot);
  if(!req || col.registered.includes(slot))return false;
  const item=eligibleItems(s,req).find(i=>i.id===itemId); if(!item)return false;
  item.count-=req.count; s.items=s.items.filter(i=>i.count>0); col.registered.push(slot); return true;
}
export function toggleLock(s,id) {
  const item=itemById(s,id);if(!item || s.forgeBusy)return false;
  item.locked=!item.locked;return true;
}
export function useItem(s,id) {
  const item=itemById(s,id);if(!item || s.forgeBusy)return {ok:false,message:'지금은 사용할 수 없습니다.'};
  if(item.type==='potion') {
    if(s.player.hp>=s.player.maxHP)return {ok:false,message:'체력이 가득 찼습니다.'};
    item.count--;s.player.hp=Math.min(s.player.maxHP,s.player.hp+180);s.items=s.items.filter(i=>i.count>0);
    return {ok:true,message:'강력 HP 물약을 사용했습니다. HP +180'};
  }
  if(item.type==='scroll') {
    s.forgeScroll=id;s.forgeTarget=null;s.screen='forge';return {ok:true,message:'강화할 장비를 선택하세요.'};
  }
  if(['weapon','armor'].includes(item.type)) {
    const was=item.equipped;
    if(!was)for(const i of s.items)if(i.slot===item.slot)i.equipped=false;
    item.equipped=!was;return {ok:true,message:`${displayItem(item)} ${was?'장착 해제':'장착'} 완료`};
  }
  return {ok:false,message:'사용할 수 없는 아이템입니다.'};
}
export function compatibleScroll(s,item) {
  return s.items.find(i=>i.type==='scroll' && i.count>0 && (item.type==='weapon'?i.id==='demo-scroll-weapon':i.id==='demo-scroll-armor'));
}
export function selectForgeTarget(s,id) {
  const item=itemById(s,id);if(!item || item.locked || !['weapon','armor'].includes(item.type) || s.forgeBusy)return false;
  s.forgeTarget=id;s.forgeScroll=compatibleScroll(s,item)?.id||null;s.forgeLast=null;return true;
}
export function canForge(s) {
  const i=itemById(s,s.forgeTarget), scroll=itemById(s,s.forgeScroll);
  return !s.forgeBusy && !!i && !i.locked && ['weapon','armor'].includes(i.type) && !!scroll && compatibleScroll(s,i)?.id===scroll.id;
}
export function startForge(s) {
  if(!canForge(s))return null;
  s.forgeBusy=true;
  return {id:++s.forgeTransaction,target:s.forgeTarget,scroll:s.forgeScroll,outcome:s.forgeOutcome,before:itemById(s,s.forgeTarget).enchant};
}
export function finishForge(s,t) {
  if(!t || !s.forgeBusy || t.id!==s.forgeTransaction)return false;
  const item=itemById(s,t.target),scroll=itemById(s,t.scroll);
  if(!item || item.locked || !scroll){s.forgeBusy=false;return false;}
  scroll.count--;
  if(t.outcome==='success')item.enchant++;
  else if(t.outcome==='down')item.enchant=Math.max(0,item.enchant-1);
  s.items=s.items.filter(i=>i.count>0);
  s.forgeBusy=false;s.forgeLast={outcome:t.outcome,before:t.before,after:item.enchant,name:item.name,art:item.art};return s.forgeLast;
}
export function skillReason(s,skill,now=Date.now()) {
  if(skill.job!=='공용' && skill.job!==s.player.job)return `${skill.job} 전용`;
  if(!skill.learned)return '미습득';
  if(skill.passive)return '상시 적용';
  if(skill.cooldown>now)return `재사용 ${Math.ceil((skill.cooldown-now)/1000)}초`;
  if(s.player.mp<skill.mp)return 'MP 부족';
  return '사용 가능';
}
export function useSkill(s,id,now=Date.now()) {
  const sk=skillById(s,id);if(!sk)return false;
  if(skillReason(s,sk,now)!=='사용 가능')return false;
  s.player.mp-=sk.mp;sk.cooldown=now+sk.cooldownSeconds*1000;return true;
}
export function learnSkill(s,id) {
  const sk=skillById(s,id);
  if(!sk || sk.learned || sk.job!=='공용'&&sk.job!==s.player.job || s.currency.adena<120000)return false;
  s.currency.adena-=120000;sk.learned=true;return true;
}
export function registerQuickslot(s,id,slot) {
  const sk=skillById(s,id);if(!sk?.learned || sk.passive || sk.job!=='공용'&&sk.job!==s.player.job || slot<0 || slot>4)return false;
  s.quickslots[s.quickPage][slot]=id;return true;
}
export function transferStorage(s,id,mode,quantity) {
 if(s.forgeBusy||!['deposit','withdraw'].includes(mode))return false;
 const source=mode==='deposit'?s.items:s.storage,target=mode==='deposit'?s.storage:s.items;
 const index=source.findIndex(i=>i.id===id);if(index<0)return false;
 const item=source[index],amount=quantity===undefined?item.count:quantity;
 if(item.equipped||item.locked||!Number.isInteger(amount)||amount<1||amount>item.count)return false;
 const existing=target.find(i=>i.id===id);
 if(existing)existing.count+=amount;else target.push({...item,count:amount});
 item.count-=amount;if(!item.count)source.splice(index,1);return true;
}
export function purchase(s,id,amount=1) {
  if(!Number.isInteger(amount)||amount<1||amount>20)return false;
  const prices={'demo-potion':500,'demo-scroll-weapon':10000,'demo-scroll-armor':8000};
  if(!prices[id]||s.currency.adena<prices[id]*amount)return false;
  s.currency.adena-=prices[id]*amount;
  const item=itemById(s,id);if(item)item.count+=amount;else s.items.push({...copy(DATA.items.find(i=>i.id===id)),count:amount});
  return true;
}
export function craft(s,recipe,amount=1) {
 if(!Number.isInteger(amount)||amount<1||amount>20)return false;
 if(recipe==='potion') {
  if(s.currency.adena<1500*amount)return false;
  s.currency.adena-=1500*amount;
  const item=itemById(s,'demo-potion');if(item)item.count+=3*amount;else s.items.push({...copy(DATA.items.find(i=>i.id==='demo-potion')),count:3*amount});
  return true;
 }
 const weapon=itemById(s,'demo-scroll-weapon');
 if(recipe!=='armor-scroll'||!weapon||weapon.count<2*amount||s.currency.adena<5000*amount)return false;
 weapon.count-=2*amount;s.currency.adena-=5000*amount;
 const target=itemById(s,'demo-scroll-armor');if(target)target.count+=amount;else s.items.push({...copy(DATA.items.find(i=>i.id==='demo-scroll-armor')),count:amount});
 s.items=s.items.filter(i=>i.count>0);return true;
}
