extends RefCounted
## Reuses exact PR238 modules; quest eligibility and receipts remain quest-owned.
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const USE = preload("res://scripts/loot/patch523_item_use.gd")
const GRANTS = preload("res://scripts/loot/patch523_item_inventory.gd")
const OWN = preload("res://scripts/quests/quest_reward_ownership.gd")
const HELD_USE = preload("res://scripts/quests/quest_held_use238.gd")
const HP233 = preload("res://scripts/loot/quest_hp233_use.gd")
const CHOICE = preload("res://scripts/quests/quest_choice523.gd")
const PIN = "38ee3ec74d12adaa9847c507f6fb093c41a4f7a8c5c1cefcd08c3a9629920d27"
const SKILL_BOOKS=preload("res://scripts/quests/quest_skillbooks523.gd")
const FIXED=preload("res://scripts/quests/quest_fixed_cards523.gd")
const REVIEWED_IDS: Array[int] = [177292,177322,177342,177432,306611,306621,306631,306641,859,1281,239,233,368202,369002,177192,177202,177212,177222,177232,177252,177332,177452]
var skill_books=SKILL_BOOKS.new()
var definitions: Dictionary = {}
var owner: WeakRef
var ready: bool = false

class Candidate extends Node:
	var inventory: Dictionary = {}
	var item_instances: Dictionary = {}
	var gold: int = 0
	var lookup: Callable
	func _catalog_item_from_source_id(id: String) -> Dictionary: return lookup.call(id)

func configure(world: Node) -> void:
	owner=weakref(world)
	definitions.clear();ready=false
	skill_books.configure_arguments()
	if world.quest_service.source.quests.is_empty() or D.pack_identity().get("sha256")!=PIN: return
	for id: int in REVIEWED_IDS:
		var definition: Dictionary = D.definition_id(str(id))
		var spec: Dictionary = definition.get("native_record",{}).get("source_use_spec",{})
		if id==239:
			if not world.consumable_service.has_method("use_owned_native_return"):continue
		elif id==233:
			if not HP233.metadata(D.variant_item(definition.get("native_record",{}),1)).get("ok",false):continue
		elif id in FIXED.IDS:
			if FIXED.target(world,D.variant_item(definition.get("native_record",{}),1)).is_empty():continue
		elif id in SKILL_BOOKS.IDS:
			var identity: Dictionary=skill_books.identity(D.variant_item(definition.get("native_record",{}),1))
			if identity.is_empty():continue
			var skill: Dictionary=world.original_skills.catalog.record_for(str(identity.local_skill_id))
			if skill.get("id")!=identity.local_skill_id:continue
			if bool(skill.get("runtime_blocked",false)) and not SKILL_BOOKS.REFERENCE.matches(id,int(spec.get("spell_class_id",0)),str(identity.local_skill_id),str(spec.get("source_spell_row_sha256",""))):continue
		elif spec.get("activation_status")!="unrestricted" or spec.get("kind") not in ["source_timed_buff","guaranteed_bag","source_selectable_reward"]: continue
		definitions[id]=definition
		_register(world,definition.native_record,1)
		for reward: Dictionary in spec.get("rewards",[]):
			var summary: Dictionary = D.data().get("item_definitions",{}).get(str(int(reward.item_class_id)),{})
			if not summary.get("native_record",{}).is_empty(): _register(world,summary.native_record,int(reward.bless_raw))
	world._index_catalog_item_sources()
	world._index_item_weights()
	ready=not definitions.is_empty()

func _register(world: Node, original: Dictionary, bless: int) -> void:
	var record: Dictionary = D.variant_item(original,bless)
	if not world._catalog_item_from_source_id(str(record.sourceId)).is_empty(): return
	# Definitions only. Unbound child effects retain the existing use guard;
	# never replace another supplier's metadata or widen the monster loot pool.
	record["source_automation_catalog_only"]=true
	record["quest238_definition_only"]=true
	if int(record.get("source_item_class_id",0))==233 and HP233.metadata(record).get("auto_use_registrable",false):record["source_automation_catalog_only"]=false
	world.catalog_db["아이템"].append(record)
	world.catalog_item_by_source_id[str(record.sourceId)]=record

func resolve(reward: Dictionary) -> Dictionary:
	if not ready or owner.get_ref()==null or bool(reward.get("UseImmediately",false)): return {}
	var world: Node = owner.get_ref()
	var id: int = int(reward.get("RewardClassID",0))
	var definition: Dictionary = definitions.get(id,{})
	if definition.is_empty() or definition.original_item!=reward.get("source_item",{}): return {}
	var bless: int = int(reward.ItemBlessCodeID)
	if bless not in [1,2,3] or definition.original_item.get("TestItem",true): return {}
	if id==239 and bless!=1:return {}
	var record: Dictionary = D.variant_item(definition.native_record,bless)
	if not D.deadline_problem(record,int(world.ui_preferences.get("patch523_source_clock_offset_minutes",540))).is_empty(): return {}
	_register(world,definition.native_record,bless)
	if not D.matches(world._catalog_item_from_source_id(str(record.sourceId)),record): return {}
	return {"record":record,"pack_sha256":PIN}

func handles(record: Dictionary) -> bool:
	return ready and record.get("source_m_native_item",false) and definitions.has(int(record.get("source_item_class_id",0)))

func retains_issued_reference(world: Node, item_key: String) -> bool:
	# Preserve an unavailable saved reference; this never permits use, new
	# registration, fallback identity or a reward grant when a pack is absent.
	for quest_id: String in world.quest_service.item_grants:
		if world.quest_service.claimed.get(quest_id)!=true:continue
		for receipt: Dictionary in world.quest_service.item_grants[quest_id]:
			if not receipt.has("origin") and receipt.inventory_key==item_key and receipt.get("pack_sha256")==PIN and REVIEWED_IDS.has(int(receipt.item_class_id)):return true
	return false

func try_use_inventory(world: Node, item_key: String) -> bool:
	if try_use(world,world._find_catalog_item_record(item_key)):return true
	for rows: Array in world.quest_service.item_grants.values():
		for receipt: Dictionary in rows:
			if not receipt.has("origin") and receipt.inventory_key==item_key and REVIEWED_IDS.has(int(receipt.item_class_id)):
				world.hud.show_message("검증된 원본 소비 팩·정체 확인 필요 · 지급 보상 보존")
				return true
	return false

func try_use(world: Node, record: Dictionary) -> bool:
	if not handles(record): return false
	if world.quest_service.save_blocked:
		world.hud.show_message("저장 보호 중 · 정상 저장 불러오기 필요");return true
	if not world._patch523_item_allowed():return true
	if world._item_locked(str(record.name),""):
		world.hud.show_message("잠긴 원본 아이템은 소비하지 않습니다")
		return true
	var before: String=FileAccess.get_sha256(world.save_path())
	var handled: bool=true
	if int(record.get("source_item_class_id",0))==239:
		var result: Dictionary=world.consumable_service.use_owned_native_return(str(record.name))
		world.hud.show_message(str(result.get("message",result.get("reason","귀환 결과 확인 필요"))))
	elif int(record.get("source_item_class_id",0)) in FIXED.IDS:FIXED.use(world,record)
	elif int(record.get("source_item_class_id",0)) in SKILL_BOOKS.IDS:skill_books.use(world,record)
	elif int(record.get("source_item_class_id",0))==369002:handled=CHOICE.open(world,record)
	elif int(record.get("source_item_class_id",0))==233:handled=HP233.use(world,record)
	else:handled=USE.try_use(world,record)
	if FileAccess.get_sha256(world.save_path())!=before:
		var durable: Variant=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
		var aligned: bool=durable is Dictionary
		if aligned:
			for key: String in ["inventory","item_instances","gold","active_item_buffs","item_use_cooldowns","hp"]:
				if durable.get(key)!=JSON.parse_string(JSON.stringify(world.get(key))):aligned=false;break
		if not aligned:
			# The unchanged shared consumer may report an error after the atomic
			# writer has committed. Preserve that save and require reload before
			# another transaction, rather than retrying against stale ownership.
			world.quest_service.save_blocked=true
			world.hud.show_message("아이템 사용 저장 결과 확인 필요 · 다시 불러오기 전까지 저장 보호")
	return handled

func held_binding(world: Node, id: String) -> Dictionary:
	if not ready: return {}
	var owned: Dictionary=OWN.proof(world,id)
	if not owned.ok or owned.source_use_immediately or not definitions.has(int(owned.item_class_id)): return {}
	var definition: Dictionary=definitions[int(owned.item_class_id)]
	if owned.source_item!=definition.original_item or int(owned.bless_code_id) not in [1,2,3]: return {}
	if int(owned.item_class_id)==239 and int(owned.bless_code_id)!=1:return {}
	return owned

func supported_held(world: Node) -> Dictionary:
	var result: Dictionary={}
	if not ready:return result
	for id: String in world.item_instances:
		var record: Dictionary=world.item_instances[id].get("record",{})
		if not definitions.has(int(record.get("source_item_class_id",0))):continue
		var owned: Dictionary=held_binding(world,id)
		if owned.is_empty():continue
		if not result.has(owned.quest_id):result[owned.quest_id]={}
		result[owned.quest_id][str(int(owned.reward_id))]=true
	return result

func try_use_held(world: Node, id: String) -> bool:
	var owned: Dictionary=held_binding(world,id)
	if owned.is_empty():return false
	if not world._patch523_item_allowed():return true
	if int(owned.item_class_id) in FIXED.IDS:
		var canonical: Dictionary=D.variant_item(definitions[int(owned.item_class_id)].native_record,int(owned.bless_code_id))
		FIXED.use(world,canonical,id);return true
	if int(owned.item_class_id) in SKILL_BOOKS.IDS:
		var canonical: Dictionary=D.variant_item(definitions[int(owned.item_class_id)].native_record,int(owned.bless_code_id))
		skill_books.use(world,canonical,id);return true
	if int(owned.item_class_id)==369002:
		var record: Dictionary=D.variant_item(definitions[369002].native_record,int(owned.bless_code_id))
		return CHOICE.open(world,record,id)
	if int(owned.item_class_id)==239:
		var outcome: Dictionary=world.consumable_service.use_owned_quest_return(id)
		world.hud.show_message(str(outcome.get("message",outcome.get("reason","귀환 결과 확인 필요"))))
		if outcome.get("ok",false) and outcome.get("saved",false) and int(outcome.get("consumed",0))==1:world.quest_auto.refresh_context(world)
		return bool(outcome.get("handled",false))
	var prepared: Dictionary=OWN.prepare_debit(world,id,1)
	if not prepared.ok:
		world.hud.show_message(str(prepared.reason));return true
	var record: Dictionary=D.variant_item(definitions[int(owned.item_class_id)].native_record,int(owned.bless_code_id))
	var result: Dictionary=HELD_USE.perform(world,prepared,record)
	if result.uncertain:world.hud.show_message("저장 결과 확인 필요 · 원본 보상 재사용 중지")
	if result.committed:
		world.quest_auto.refresh_context(world)
		world.hud.refresh_inventory(world.inventory)
	return bool(result.handled)

func stage(world: Node, base: Dictionary, grants: Array, receipts: Array) -> Dictionary:
	if not ready or D.pack_identity().get("sha256")!=PIN: return {"ok":false,"error":"검증된 아이템 소비 팩 미설치"}
	var candidate := Candidate.new()
	candidate.inventory=base.inventory;candidate.item_instances=base.item_instances;candidate.gold=int(base.gold)
	candidate.lookup=Callable(world,"_catalog_item_from_source_id")
	var result: Dictionary = GRANTS.stage(candidate,grants,{"kind":"quest_current523","source_sha256":world.quest_service.source.SOURCE_SHA,"quest_receipts":receipts.duplicate(true)})
	candidate.free()
	return result
