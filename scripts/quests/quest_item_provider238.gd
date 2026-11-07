extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Reuses exact PR238 modules; quest eligibility and receipts remain quest-owned.
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const USE = preload("res://scripts/loot/patch523_item_use.gd")
const GRANTS = preload("res://scripts/loot/patch523_item_inventory.gd")
const OWN = preload("res://scripts/quests/quest_reward_ownership.gd")
const HELD_USE = preload("res://scripts/quests/quest_held_use238.gd")
const HP233 = preload("res://scripts/loot/quest_hp233_use.gd")
const CHOICE = preload("res://scripts/quests/quest_choice523.gd")
const ORIGINAL=preload("res://scripts/resources/current523_definition_rows.gd")
const PIN = "38ee3ec74d12adaa9847c507f6fb093c41a4f7a8c5c1cefcd08c3a9629920d27"
const SKILL_BOOKS=preload("res://scripts/quests/quest_skillbooks523.gd")
const REGEN=preload("res://scripts/quests/quest_regen523.gd")
const CURE=preload("res://scripts/quests/quest_cure310.gd")
const REUSABLE=preload("res://scripts/quests/quest_reusable523.gd")
const FIXED=preload("res://scripts/quests/quest_fixed_cards523.gd")
const REVIEWED_IDS: Array[int] = [310,1186,282793,295524,203422,295504,295544,302461,376,385,177292,177322,177342,177432,306611,306621,306631,306641,859,1281,239,233,368202,369002,177192,177202,177212,177222,177232,177252,177332,177452]
var skill_books=SKILL_BOOKS.new()
var equipment_owner=preload("res://scripts/quests/quest_equipment523.gd").new()
var definitions: Dictionary = {}
var owner: WeakRef
var ready: bool = false
var _held_save_candidate: Dictionary = {}

func authorizes_held_save(payload: Dictionary) -> bool:
	return not _held_save_candidate.is_empty() and preload("res://scripts/equipment523/native_catalog.gd").same(_held_save_candidate,payload)

func commit_held_save(world: Node,payload: Dictionary) -> Error:
	if not _held_save_candidate.is_empty():return ERR_BUSY
	_held_save_candidate=payload.duplicate(true)
	var result: Error=world._save_game(true,payload)
	_held_save_candidate.clear()
	return result

func _scalar_bag(spec: Dictionary) -> bool:
	if spec.get("kind") not in ["guaranteed_bag","source_weighted_bag","mixed_rewards_bag"] or spec.get("rewards",[]).is_empty():return false
	for reward: Dictionary in spec.rewards:
		var kind: int=int(reward.get("entity_type_id",-1))
		if kind not in [0,1]:return false
		if kind==0:
			var weight: Variant=reward.get("probability_raw")
			if not (weight is int or weight is float) or not is_finite(float(weight)) or float(weight)!=floorf(float(weight)) or weight<0:return false
			if weight==0:continue # Keep the source row; it has no selectable mass.
		var id: int=int(reward.get("item_class_id",0))
		var definition: Dictionary=D.definition_id(str(id))
		var record: Dictionary=definition.get("native_record",{})
		if not preload("res://scripts/quests/source_dummy523.gd").item_evidence(definition.get("original_item",{})).is_empty():return false
		if OWN.positive(reward.get("amount"))==0 or int(reward.get("bless_raw",0)) not in [1,2,3] or record.is_empty() or definition.get("original_item",{}).get("TestItem",true) or D.equipment(record):return false
		# These outputs require their physical supply owner. Do not publish a
		# name-only wallet count and claim the next material consumer is bound.
		if id in preload("res://scripts/cards/native_awakening_supply.gd").IDS:return false
		if reward.get("enchant")!=null and reward.get("enchant")!=0:return false
	return true

class Candidate extends Node:
	var inventory: Dictionary = {}
	var item_instances: Dictionary = {}
	var gold: int = 0
	var lookup: Callable
	func _catalog_item_from_source_id(id: String) -> Dictionary: return lookup.call(id)

func current_input_available() -> bool:
	var marker: Dictionary=D.pack_identity()
	return marker.get("schema")==4 and marker.get("kind")=="current523_original_definition_projection" and marker.get("source_definition_archive")==ORIGINAL.identity() and marker.get("sha256")==ORIGINAL.SOURCE_SHA

func configure(world: Node) -> void:
	owner=weakref(world)
	definitions.clear();ready=false
	skill_books.configure_arguments()
	equipment_owner.configure(world)
	if world.quest_service.source.quests.is_empty() or not current_input_available(): return
	for id: int in REVIEWED_IDS:
		var definition: Dictionary = D.definition_id(str(id))
		var spec: Dictionary = NATIVE_FIELDS.full(definition.get("native_record",{})).get("source_use_spec",{})
		if id==239:
			if not world.consumable_service.has_method("use_owned_native_return"):continue
		elif id==233:
			if not HP233.metadata(D.variant_item(definition.get("native_record",{}),1)).get("ok",false):continue
		elif id in FIXED.IDS:
			if FIXED.target(world,D.variant_item(definition.get("native_record",{}),1)).is_empty():continue
		elif id in SKILL_BOOKS.IDS:
			var identity: Dictionary=skill_books.identity(D.variant_item(definition.get("native_record",{}),1),world)
			if identity.is_empty():continue
			var skill: Dictionary=world.original_skills.catalog.record_for(str(identity.local_skill_id))
			if skill.get("id")!=identity.local_skill_id:continue
			if bool(skill.get("runtime_blocked",false)) and not SKILL_BOOKS.REFERENCE.matches(id,int(spec.get("spell_class_id",0)),str(identity.local_skill_id),str(spec.get("source_spell_row_sha256",""))):continue
		elif id in REUSABLE.IDS:
			if REUSABLE.profile(D.variant_item(definition.get("native_record",{}),1)).is_empty():continue
		elif id==310:
			if CURE.profile(D.variant_item(definition.get("native_record",{}),1)).is_empty():continue
		elif id==1186:
			if NATIVE_FIELDS.full(USE.action_record(world,D.variant_item(definition.get("native_record",{}),1))).get("source_use_spec",{}).get("activation_status")!="unrestricted":continue
		elif id in REGEN.IDS:
			if NATIVE_FIELDS.full(REGEN.action(world,D.variant_item(definition.get("native_record",{}),1))).get("source_use_spec",{}).get("activation_status")!="unrestricted":continue
		elif spec.get("activation_status")!="unrestricted" or spec.get("kind") not in ["source_timed_buff","guaranteed_bag","source_selectable_reward"]: continue
		definitions[id]=definition
		_register(world,definition.native_record,1)
		for reward: Dictionary in spec.get("rewards",[]):
			var summary: Dictionary = D.data().get("item_definitions",{}).get(str(int(reward.item_class_id)),{})
			if not summary.get("native_record",{}).is_empty(): _register(world,summary.native_record,int(reward.bless_raw))
	# Bind only actual original quest rewards whose installed item owner already
	# provides an unrestricted typed effect or scalar bag. This does not grant
	# items, enable Test/expired effects or infer a positive bonus from a name.
	for quest: Dictionary in world.quest_service.index.values():
		if not quest.get("blockers",[]).is_empty() or not quest.get("excluded_reasons",[]).is_empty():continue
		for reward: Dictionary in quest.get("source_rewards",[]):
			var id: int=int(reward.get("RewardClassID",0))
			if definitions.has(id) or reward.get("type_name")!="Item" or reward.get("UseImmediately",false) or int(reward.get("ItemBlessCodeID",0))!=1:continue
			var definition: Dictionary=D.definition_id(str(id))
			if definition.get("original_item",{}).is_empty() or definition.original_item!=reward.get("source_item") or definition.original_item.get("TestItem",true):continue
			var record: Dictionary=USE.action_record(world,D.variant_item(definition.get("native_record",{}),1))
			var spec: Dictionary=NATIVE_FIELDS.full(record).get("source_use_spec",{})
			if spec.get("activation_status")!="unrestricted" or (spec.get("kind") not in ["source_timed_buff","source_mp_dice"] and not _scalar_bag(spec)):continue
			definitions[id]=definition
			_register(world,definition.native_record,1)
			if spec.get("kind") in ["guaranteed_bag","source_weighted_bag","mixed_rewards_bag"]:
				for output: Dictionary in spec.rewards:
					if int(output.get("entity_type_id",-1))==0 and int(output.get("probability_raw",0))==0:continue
					var child: Dictionary=D.definition_id(str(int(output.item_class_id)))
					if not child.get("native_record",{}).is_empty():_register(world,child.native_record,int(output.bless_raw))
	world._index_catalog_item_sources()
	world._index_item_weights()
	ready=not definitions.is_empty()

func _register(world: Node, original: Dictionary, bless: int) -> void:
	if not preload("res://scripts/quests/source_dummy523.gd").record_evidence(original).is_empty():return
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
	# Newly connected source rows retain actual quest-owned stacks until the
	# player selects use. Do not mass-convert grants or expand old save schemas.
	if id not in REVIEWED_IDS:return {}
	var definition: Dictionary = definitions.get(id,{})
	if definition.is_empty() or definition.original_item!=reward.get("source_item",{}): return {}
	var bless: int = int(reward.ItemBlessCodeID)
	if bless not in [1,2,3] or definition.original_item.get("TestItem",true): return {}
	if id==239 and bless!=1:return {}
	var record: Dictionary = D.variant_item(definition.native_record,bless)
	if not D.deadline_problem(record,int(world.ui_preferences.get("patch523_source_clock_offset_minutes",540))).is_empty(): return {}
	_register(world,definition.native_record,bless)
	if not D.matches(world._catalog_item_from_source_id(str(record.sourceId)),record): return {}
	return {"record":record,"pack_sha256":str(D.pack_identity().get("sha256","")),"source_input_marker":D.pack_identity()}

func handles(record: Dictionary) -> bool:
	return ready and record.get("source_m_native_item",false) and definitions.has(int(record.get("source_item_class_id",0)))

func retains_issued_reference(world: Node, item_key: String) -> bool:
	# Preserve an unavailable saved reference; this never permits use, new
	# registration, fallback identity or a reward grant when a pack is absent.
	for quest_id: String in world.quest_service.item_grants:
		if world.quest_service.claimed.get(quest_id)!=true:continue
		for receipt: Dictionary in world.quest_service.item_grants[quest_id]:
			if not receipt.has("origin") and receipt.inventory_key==item_key and receipt.get("pack_sha256") in [PIN,ORIGINAL.SOURCE_SHA] and REVIEWED_IDS.has(int(receipt.item_class_id)):return true
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
	elif int(record.get("source_item_class_id",0))==310:CURE.perform(world,record)
	elif int(record.get("source_item_class_id",0)) in REUSABLE.IDS:REUSABLE.perform(world,record)
	elif int(record.get("source_item_class_id",0)) in FIXED.IDS:FIXED.use(world,record)
	elif int(record.get("source_item_class_id",0)) in SKILL_BOOKS.IDS:skill_books.use(world,record)
	elif int(record.get("source_item_class_id",0))==369002:handled=CHOICE.open(world,record)
	elif int(record.get("source_item_class_id",0))==233:handled=HP233.use(world,record)
	else:handled=USE.try_use(world,record)
	if FileAccess.get_sha256(world.save_path())!=before:
		var durable: Variant=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
		var aligned: bool=durable is Dictionary
		if aligned:
			for key: String in ["inventory","item_instances","gold","active_item_buffs","item_use_cooldowns","hp","mp"]:
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
	if not preload("res://scripts/quests/source_dummy523.gd").item_evidence(owned.source_item).is_empty():return {}
	if int(owned.item_class_id) not in REVIEWED_IDS and int(owned.bless_code_id)!=1:return {}
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
	if equipment_owner.activate(world,id):return true
	# Ordinary original bags use the same real output supplier as new native
	# ownership, while the exact raw quest debit remains with the common ABI.
	var original_owned: Dictionary=OWN.proof(world,id)
	if original_owned.get("ok",false) and not original_owned.get("source_use_immediately",true):
		var original_definition: Dictionary=D.definition_id(str(int(original_owned.item_class_id)))
		var native_ammo: Script=load("res://scripts/loot/current523_native_stack.gd")
		if native_ammo.call("native_ammo",D.variant_item(original_definition.get("native_record",{}),int(original_owned.bless_code_id))):
			var equipped: Dictionary=native_ammo.call("equip_ammo",world,str(original_owned.inventory_key),id)
			world.hud.show_message(str(equipped.get("message",equipped.get("reason","퀘스트 탄약의 실제 소지 개체 착용 연결 대기"))))
			if equipped.get("ok",false) and equipped.get("saved",false):world.hud.refresh_inventory(world.inventory);world._update_hud()
			return true
		if NATIVE_FIELDS.full(original_definition.get("native_record",{})).get("source_use_spec",{}).get("kind") in ["guaranteed_bag","source_weighted_bag","mixed_rewards_bag","source_selectable_reward","source_skill_book"]:
			var stock: Script=load("res://scripts/loot/current523_native_stack.gd")
			var used: Dictionary=stock.call("use_owned_original",world,original_owned.source_item,{"physical_id":id,"quantity":1,"expected_quantity":original_owned.quantity,"expected_remaining":int(original_owned.quantity)-1,"quest_reward_receipt":world.item_instances[id].quest_reward_receipt.duplicate(true)})
			world.hud.show_message(str(used.get("message",used.get("reason","원본 상자 수령·사용 소유자 연결 대기"))))
			if used.get("ok",false) and used.get("saved",false) and used.get("consumed")==1:
				world.quest_auto.refresh_context(world);world.hud.refresh_inventory(world.inventory)
			return used.get("handled",false)
	var owned: Dictionary=held_binding(world,id)
	if owned.is_empty():return false
	if not world._patch523_item_allowed():return true
	if int(owned.item_class_id)==310:
		var canonical: Dictionary=D.variant_item(definitions[310].native_record,int(owned.bless_code_id))
		CURE.perform(world,canonical,id);return true
	if int(owned.item_class_id) in REUSABLE.IDS:
		var canonical: Dictionary=D.variant_item(definitions[int(owned.item_class_id)].native_record,int(owned.bless_code_id))
		REUSABLE.perform(world,canonical,id);return true
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
	if not ready or not current_input_available(): return {"ok":false,"error":"검증된 아이템 소비 팩 미설치"}
	var candidate := Candidate.new()
	candidate.inventory=base.inventory;candidate.item_instances=base.item_instances;candidate.gold=int(base.gold)
	candidate.lookup=Callable(world,"_catalog_item_from_source_id")
	var result: Dictionary = GRANTS.stage(candidate,grants,{"kind":"quest_current523","source_sha256":world.quest_service.source.SOURCE_SHA,"quest_receipts":receipts.duplicate(true)})
	candidate.free()
	return result
