extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Selected alchemy output -> the existing source use owner. No catalog rename,
## native flag conversion, regrant or live temporary ownership is performed.
const C = preload("res://scripts/equipment523/common.gd")
const Native = preload("res://scripts/equipment523/native_catalog.gd")
const Legacy = preload("res://scripts/equipment523/alchemy_pending_migration.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const Use = preload("res://scripts/loot/patch523_item_use.gd")
const HELD = preload("res://scripts/quests/quest_held_use238.gd")
const LOG = "source_alchemy_item_uses"
const KINDS = ["source_timed_buff", "source_mp_dice", "guaranteed_bag", "source_weighted_bag", "mixed_rewards_bag"]
var _candidate: Dictionary = {}
var _busy: bool = false
var blocked: bool = false

func authorizes(staged: Dictionary) -> bool:
	return not _candidate.is_empty() and Native.same(_candidate,staged)

static func _fail(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason}

static func _whole(value: Variant, minimum: int = 1) -> int:
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)!=floorf(float(value)) or value<minimum or value>9007199254740991: return -1
	return int(value)

static func _stamp(world: Node) -> String:
	return JSON.stringify([world.inventory,world.item_instances,world.consumable_service.export_state(),world.active_item_buffs,world.item_use_cooldowns,world.gold,world.hp,world.mp,str(world.rng.seed),str(world.rng.state),world.equipment523.store.sha256,D.pack_identity()],"",true,true).sha256_text()

static func _is_alchemy(physical: Dictionary) -> bool:
	var proof: Variant=physical.get("equipment523_last_processing")
	return proof is Dictionary and proof.get("kind")=="alchemy"

static func _equipment_output(physical: Dictionary) -> bool:
	var record: Variant=physical.get("record")
	if not record is Dictionary: return false
	var source_id: int=_whole(record.get("source_item_class_id"))
	return source_id>0 and D.equipment(D.definition_id(str(source_id)).get("native_record",{}))

func after_load() -> void:
	_candidate.clear();_busy=false;blocked=false

static func prepare(world: Node, physical_id: String) -> Dictionary:
	var entry: Variant=world.item_instances.get(physical_id)
	if not entry is Dictionary or not _is_alchemy(entry): return _fail("연금 결과의 실제 개체를 선택하세요")
	if world.equipment523.save_blocked or world.quest_service.save_blocked or world.hp<=0 or not world._patch523_item_allowed(): return _fail("현재 저장·생존·사용 조건에서 연금 결과를 보존합니다")
	if entry.has("quest_reward_receipt") or entry.has("quest_source_input_receipt"): return _fail("다른 소유자의 원본 영수증은 해당 소비 계약에서 보존합니다")
	for field: Variant in entry:
		if field not in Legacy.LEGACY_PHYSICAL_FIELDS: return _fail("미확인 물리 개체 필드를 보존합니다")
	var record: Variant=entry.get("record")
	var proof: Variant=entry.get("equipment523_last_processing")
	if not record is Dictionary or not proof is Dictionary: return _fail("연금 결과의 원본 기록이 없습니다")
	var store: Variant=world.equipment523.store
	if store.pack.get("source_sha256")!=C.SOURCE_SHA or store.sha256.is_empty() or proof.get("source_sha256")!=C.SOURCE_SHA or proof.get("consumer_data_sha256")!=store.sha256: return _fail("지급 당시 연금 원본 팩과 현재 팩이 다릅니다 · 개체 보존")
	for key: Variant in proof:
		if key not in ["kind","source_sha256","consumer_data_sha256","result_id","recipe_type"]: return _fail("미확인 연금 출처 필드를 보존합니다")
	var result_id: int=_whole(proof.get("result_id"))
	var row: Dictionary=C.find(store.pack,"AlchemyResult",result_id)
	var recipe_id: int=_whole(row.get("RecipeTypeID"))
	var original: int=_whole(row.get("Amount"))
	var item_id: int=_whole(row.get("ItemClassID"))
	var bless: int=_whole(row.get("BlessCode"))
	var remaining: int=_whole(entry.get("source_reward_quantity",1))
	if row.is_empty() or recipe_id not in [63,113] or C.find(store.pack,"AlchemyRecipeType",recipe_id).get("IsEnabled")!=true or _whole(row.get("Probability"))<1 or _whole(row.get("ServerLimitSetID"),0)!=0 or _whole(row.get("Enchant"),0)!=0 or original<1 or remaining<1 or remaining>original or bless not in [1,2,3]: return _fail("원본 연금 결과·수량·서비스·강화 조건 미지원 · 개체 보존")
	if proof.has("recipe_type") and _whole(proof.recipe_type)!=recipe_id: return _fail("원본 연금 제조법 불일치")
	var definition: Dictionary=D.definition_id(str(item_id))
	var source: Dictionary=C.item(store.pack,item_id).get("raw",{})
	var canonical: Dictionary=D.variant_item(definition.get("native_record",{}),bless)
	if source.is_empty() or source.get("TestItem")!=false or definition.get("original_item")!=source or canonical.is_empty() or D.equipment(canonical): return _fail("정확한 일반 비장비 원본 정체가 필요합니다")
	if record.get("source_m_native_item")==true:
		if Native.resolve(store.pack,record).is_empty() or not D.matches(record,canonical) or entry.get("name")!=canonical.get("name"): return _fail("현재 원본 비장비 정체 불일치")
	else:
		# Old output ownership is authenticated in its own namespace. The source
		# record stays unchanged; canonical is solely an isolated effect input.
		for key: Variant in record:
			if key not in Legacy.LEGACY_RECORD_FIELDS: return _fail("미확인 기존 연금 기록 보존")
		for key: String in Legacy.LEGACY_RECORD_FIELDS:
			if not record.has(key): return _fail("기존 연금 지급 기록 누락")
		if record.get("source")!="lineagem_current523" or record.get("source_snapshot")!="current523" or NATIVE_FIELDS.full(record).get("source_original_item")!=true or record.get("sourceId")!="m523:item:"+str(item_id) or _whole(record.get("source_item_class_id"))!=item_id or _whole(record.get("source_bless_code_id"))!=bless or _whole(record.get("source_reward_id"))!=result_id or _whole(record.get("source_reward_quantity"))!=remaining or record.get("desc")!=Legacy.LEGACY_DESCRIPTION: return _fail("기존 연금 결과의 불변 지급 증명 불일치")
		if entry.get("name")!="[원본보상]"+str(C.item(store.pack,item_id).get("name","")) or record.get("name")!=entry.get("name"): return _fail("기존 연금 개체의 소지 키 불일치")
		if record.get("bless_state")!={1:"normal",2:"blessed",3:"cursed"}[bless] or record.get("blessed")!=(bless==2): return _fail("기존 연금 기록의 축복 표시 불일치")
	if entry.has("sourceId") and entry.sourceId!=record.get("sourceId"): return _fail("물리 개체와 지급 기록의 원본 ID 불일치")
	if _whole(entry.get("source_bless_code"))!=bless or _whole(entry.get("level"),0)!=0 or entry.get("element")!="" or _whole(entry.get("element_level"),0)!=0 or entry.get("bless_state")!={1:"normal",2:"blessed",3:"cursed"}[bless]: return _fail("연금 결과의 축복·강화·속성 상태 불일치")
	var key: String=str(entry.name)
	if world._item_locked(key,physical_id) or world._item_locked(key,"") or entry.get("locked",false)!=false or entry.get("equipped",false)!=false: return _fail("잠금·장착된 연금 결과는 보존합니다")
	for field: String in ["equipment523","source_smelt"]:
		if entry.has(field) and (not entry[field] is Dictionary or not entry[field].is_empty()): return _fail("이후 가공된 연금 결과는 해당 가공 소유자에서 보존합니다")
	var total: int=0
	for held: Variant in world.item_instances.values():
		if not held is Dictionary: return _fail("기존 물리 소지 기록 형식 보존")
		if held.get("name")!=key: continue
		var quantity: int=_whole(held.get("source_reward_quantity",1))
		if quantity<1 or total>9007199254740991-quantity: return _fail("공동 소지 수량 오류")
		total+=quantity
	if _whole(world.inventory.get(key))!=total: return _fail("물리 잔량과 인벤토리 합계가 다릅니다 · 개체 보존")
	var state: Dictionary=world.consumable_service.export_state()
	var journal: Variant=state.get(LOG,{})
	if not journal is Dictionary: return _fail("기존 연금 사용 영수증 형식 보존")
	var previous: Variant=journal.get(physical_id,{})
	if not previous is Dictionary: return _fail("기존 연금 개체 사용 영수증 형식 보존")
	var original_record: Dictionary=record.duplicate(true)
	# This field is the processing owner's mutable remaining count. The source
	# Amount and this immutable receipt retain the original grant separately.
	if original_record.has("source_reward_quantity"): original_record.source_reward_quantity=original
	var receipt: Dictionary={"schema":1,"physical_id":physical_id,"source_sha256":C.SOURCE_SHA,"consumer_data_sha256":store.sha256,"item_pack_sha256":D.pack_identity().get("sha256"),"result_id":result_id,"recipe_type":recipe_id,"item_class_id":item_id,"bless_raw":bless,"original_quantity":original,"processing_proof":proof.duplicate(true),"original_record":original_record}
	var used: int=original-remaining
	if previous.is_empty():
		if used!=0: return _fail("기존 부분 소비의 원본 사용 영수증 없음 · 잔량 보존")
	else:
		var expected: Dictionary=receipt.duplicate(true);expected["used_quantity"]=used
		if not Native.same(previous,expected): return _fail("연금 결과의 최초 지급량·사용 장부 불일치")
	canonical=Use.action_record(world,canonical)
	if NATIVE_FIELDS.full(canonical).get("source_use_spec",{}).get("kind") not in KINDS: return _fail("이 연금 결과의 효과 소유자 연결은 별도입니다 · 개체 보존")
	var problem: String=Use.eligibility(world,canonical)
	if not problem.is_empty(): return _fail(problem)
	return {"ok":true,"physical_id":physical_id,"inventory_key":key,"quantity":remaining,"receipt":receipt,"used":used,"record":canonical,"stamp":_stamp(world)}

static func stage_processing_uses(world: Node, spent: Dictionary, inventory: Dictionary, instances: Dictionary) -> Dictionary:
	var state: Dictionary=world.consumable_service.export_state()
	var journal: Variant=state.get(LOG,{})
	if not journal is Dictionary: return _fail("기존 연금 사용 영수증 형식 보존")
	journal=journal.duplicate(true)
	var changed: bool=false
	for id: String in spent:
		if not journal.has(id): continue
		var amount: int=_whole(spent[id])
		var basis: Dictionary=prepare(world,id)
		if amount<1 or not basis.get("ok",false) or amount>int(basis.quantity): return _fail("선택 연금 재료의 사용 장부·잔량 불일치")
		var remaining: int=int(basis.quantity)-amount
		if remaining==0:
			if instances.has(id): return _fail("선택 연금 재료의 소진 후보 불일치")
		else:
			var expected: Dictionary=world.item_instances[id].duplicate(true)
			expected.source_reward_quantity=remaining
			if expected.record.has("source_reward_quantity"): expected.record.source_reward_quantity=remaining
			if not Native.same(instances.get(id),expected): return _fail("선택 연금 재료의 물리 잔량 후보 불일치")
		var total: int=0
		for physical: Variant in instances.values():
			if not physical is Dictionary: return _fail("물리 소지 기록 형식 보존")
			if physical.get("name")!=basis.inventory_key: continue
			var quantity: int=_whole(physical.get("source_reward_quantity",1))
			if quantity<1 or total>9007199254740991-quantity: return _fail("연금 재료 공동 잔량 오류")
			total+=quantity
		if _whole(inventory.get(basis.inventory_key,0),0)!=total: return _fail("연금 재료 인벤토리·물리 잔량 불일치")
		var receipt: Dictionary=basis.receipt.duplicate(true)
		receipt["used_quantity"]=int(basis.used)+amount;journal[id]=receipt;changed=true
	if changed: state[LOG]=journal
	return {"ok":true,"changed":changed,"state":state}

class HudView extends RefCounted:
	var host: Node
	func show_message(message: String) -> void: host.hud.show_message(message)
	func append_log(message: String) -> void: host.hud.append_log(message)
	func refresh_inventory(_candidate_inventory: Dictionary) -> void: host.hud.refresh_inventory(host.inventory)
	func is_card_reveal_busy() -> bool: return host.hud.has_method("is_card_reveal_busy") and host.hud.is_card_reveal_busy()

class View extends HELD.View:
	var use_owner: RefCounted
	var basis: Dictionary
	func _save_game(_quiet: bool, overrides: Dictionary) -> Error:
		return use_owner.commit_view(self,overrides)

func commit_view(view: Node, overrides: Dictionary) -> Error:
	var world: Node=view.host
	if view.committed or blocked or _stamp(world)!=view.basis.stamp: return ERR_INVALID_DATA
	var fresh: Dictionary=prepare(world,str(view.basis.physical_id))
	if not fresh.get("ok",false) or not Native.same(fresh,view.basis): return ERR_INVALID_DATA
	for field: String in overrides:
		if field not in ["inventory","item_instances","gold","mp","active_item_buffs","item_use_cooldowns"]: return ERR_INVALID_PARAMETER
	var proposed: Variant=overrides.get("inventory")
	var virtual_key: String=str(view.canonical.name)
	if not proposed is Dictionary or _whole(proposed.get(virtual_key,0),0)!=int(view.basis.quantity)-1: return ERR_INVALID_DATA
	var inventory: Dictionary=world.inventory.duplicate(true)
	var instances: Dictionary=world.item_instances.duplicate(true)
	var id: String=str(view.basis.physical_id)
	var key: String=str(view.basis.inventory_key)
	var remaining: int=int(view.basis.quantity)-1
	inventory[key]=int(inventory[key])-1
	if inventory[key]==0: inventory.erase(key)
	if remaining==0: instances.erase(id)
	else:
		instances[id].source_reward_quantity=remaining
		if instances[id].record.has("source_reward_quantity"): instances[id].record.source_reward_quantity=remaining
	var keys: Dictionary={}
	for name_value: String in view.initial_inventory: keys[name_value]=true
	for name_value: String in proposed: keys[name_value]=true
	for name_value: String in keys:
		if name_value==virtual_key: continue
		var before: int=_whole(view.initial_inventory.get(name_value,0),0)
		var after: int=_whole(proposed.get(name_value,0),0)
		if before<0 or after<before: return ERR_INVALID_DATA
		var delta: int=after-before
		if delta==0: continue
		if name_value==key: return ERR_INVALID_DATA
		var current: int=_whole(inventory.get(name_value,0),0)
		if current<0 or current>9007199254740991-delta: return ERR_INVALID_DATA
		inventory[name_value]=current+delta
	var proposed_instances: Variant=overrides.get("item_instances",view.initial_instances)
	if not proposed_instances is Dictionary: return ERR_INVALID_DATA
	for physical_id: String in view.initial_instances:
		if not Native.same(proposed_instances.get(physical_id),view.initial_instances[physical_id]): return ERR_INVALID_DATA
	for physical_id: String in proposed_instances:
		if view.initial_instances.has(physical_id): continue
		if instances.has(physical_id) or not proposed_instances[physical_id] is Dictionary: return ERR_INVALID_DATA
		var item: Dictionary=proposed_instances[physical_id]
		if item.has("quest_reward_receipt") or item.has("quest_source_input_receipt"): return ERR_INVALID_DATA
		instances[physical_id]=item.duplicate(true)
	var state: Dictionary=world.consumable_service.export_state()
	var journal: Dictionary=state.get(LOG,{}).duplicate(true)
	var receipt: Dictionary=view.basis.receipt.duplicate(true)
	receipt["used_quantity"]=int(view.basis.used)+1;journal[id]=receipt;state[LOG]=journal
	var payload: Dictionary={"inventory":inventory,"item_instances":instances,"consumable_state":state,"patch523_transaction_rng":{"schema":1,"seed":str(view.rng.seed),"state":str(view.rng.state)}}
	for field: String in ["active_item_buffs","item_use_cooldowns"]:
		if overrides.has(field):
			if not overrides[field] is Dictionary: return ERR_INVALID_DATA
			payload[field]=overrides[field].duplicate(true)
	if payload.has("active_item_buffs"):
		# Evaluate the existing cap formulas against the candidate buff map.
		# Never install a live buff temporarily just to evaluate its vitals.
		payload["hp"]=mini(world.hp,world._effective_max_hp(-1,payload.active_item_buffs))
		payload["mp"]=mini(world.mp,world._effective_max_mp(payload.active_item_buffs))
	if overrides.has("gold"):
		var gold: int=_whole(overrides.gold,0)
		if gold<world.gold: return ERR_INVALID_DATA
		payload["gold"]=gold
	if overrides.has("mp"):
		var mp: int=_whole(overrides.mp,0)
		if mp<world.mp or mp>world._effective_max_mp(payload.get("active_item_buffs")): return ERR_INVALID_DATA
		payload["mp"]=mp
	_candidate=payload.duplicate(true)
	var path: String=world.save_path();var before_sha: String=FileAccess.get_sha256(path)
	var saved: Error=world._save_game(true,payload)
	_candidate.clear()
	if saved!=OK:
		# The shared writer already confirms its entire save after an uncertain
		# response. Do not fall back to a subset comparison of our own payload.
		if FileAccess.get_sha256(path)!=before_sha or not world.patch523_owner_state_problem.is_empty():
			blocked=true;view.uncertain=true;world.equipment523.save_blocked=true
		return saved
	world.inventory=inventory;world.item_instances=instances
	world.consumable_service.import_state(state)
	if payload.has("gold"): world.gold=int(payload.gold)
	if payload.has("hp"): world.hp=int(payload.hp)
	if payload.has("mp"): world.mp=int(payload.mp)
	if payload.has("active_item_buffs"): world.active_item_buffs=payload.active_item_buffs
	if payload.has("item_use_cooldowns"): world.item_use_cooldowns=payload.item_use_cooldowns
	world.rng.seed=view.rng.seed;world.rng.state=view.rng.state
	world.deferred_save.cancel();view.committed=true
	return OK

func try_use(world: Node, item_name: String, physical_id: String) -> bool:
	var physical: Variant=world.item_instances.get(physical_id)
	if physical_id.is_empty():
		for value: Variant in world.item_instances.values():
			if value is Dictionary and value.get("name")==item_name and _is_alchemy(value) and not _equipment_output(value):
				world.hud.show_message("연금 결과의 실제 개체를 선택하세요 · 묶음 잔량 보존");return true
		return false
	if not physical is Dictionary or not _is_alchemy(physical): return false
	# Equipment remains with the existing adoption/equipment owner and its
	# original selected-slot handling; this adapter owns non-equipment uses.
	if _equipment_output(physical): return false
	if physical.get("name")!=item_name:
		world.hud.show_message("선택한 연금 개체와 표시된 소지 키가 다릅니다 · 아이템 보존");return true
	if _busy or blocked:
		world.hud.show_message("연금 결과 사용 중 또는 저장 결과 미확정 · 다시 불러오기 필요");return true
	var basis: Dictionary=prepare(world,physical_id)
	if not basis.get("ok",false): world.hud.show_message(str(basis.reason));return true
	_busy=true
	var view: View=View.new()
	view.use_owner=self;view.basis=basis;view.host=world;view.canonical=basis.record
	view.hud=HudView.new();view.hud.host=world
	view.inventory=world.inventory.duplicate(true);view.inventory[str(view.canonical.name)]=int(basis.quantity)
	view.item_instances=world.item_instances.duplicate(true)
	view.initial_inventory=view.inventory.duplicate(true);view.initial_instances=view.item_instances.duplicate(true)
	view.active_item_buffs=world.active_item_buffs.duplicate(true);view.item_use_cooldowns=world.item_use_cooldowns.duplicate(true)
	view.gold=world.gold;view.hp=world.hp;view.mp=world.mp;view.rng.seed=world.rng.seed;view.rng.state=world.rng.state
	Use.try_use(view,view.canonical)
	view.free();_busy=false
	return true
