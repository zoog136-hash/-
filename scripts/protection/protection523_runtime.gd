extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const Source = preload("res://scripts/protection/protection523_source.gd")
const SAVE_KEY := "protection523"
const POLICY_PATH := "res://data/protection/protection523_policy.json"
var world: Node
var source: Dictionary = {}
var problem := ""
var state: Dictionary = fresh()
var save_blocked := false
var busy := false
var policy: Dictionary = {"project_pvp_to_pve":true,"same_group":"keep_stronger","possession":"highest","title":"highest"}
var clock_anchor := 0
var clock_ticks := 0
var binding_cache: Dictionary = {}
var binding_catalog_size := -1

static func fresh() -> Dictionary:
	return {"schema":1,"source_sha256":Source.SOURCE_SHA,"crafted":{},"titles":[],
		"active":{},"cooldowns":{},"last_seen":0,"policy":{"project_pvp_to_pve":true,"same_group":"keep_stronger"}}

static func integer(value: Variant, minimum: int = 0, maximum: int = 4102444800) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum

static func has_id(values: Array, wanted: int) -> bool:
	for value: Variant in values:
		if integer(value) and int(value) == wanted: return true
	return false

static func validate(value: Variant) -> String:
	if not value is Dictionary: return "가호 저장 형식 오류"
	var s: Dictionary = value
	if s.get("schema") != 1 or s.get("source_sha256") != Source.SOURCE_SHA: return "가호 저장 출처·버전 오류"
	if not s.get("crafted") is Dictionary or not s.get("titles") is Array or not s.get("cooldowns") is Dictionary or not s.get("active") is Dictionary: return "가호 저장 장부 오류"
	if not integer(s.get("last_seen")) or not s.get("policy") is Dictionary: return "가호 저장 시각·설정 오류"
	if not s.policy.get("project_pvp_to_pve") is bool or s.policy.get("same_group") not in ["keep_stronger","replace"]: return "가호 설정 확인 필요"
	var recipes := [132033,162988,205288,223294,239231,258788]
	var titles := [1173,1508,1788,2144,2521,2658]
	for key: Variant in s.crafted:
		if not key is String or not key.is_valid_int() or not recipes.has(int(key)) or not integer(s.crafted[key],1,1): return "가호 제작 장부 오류"
	var seen: Array = []
	for id: Variant in s.titles:
		if not integer(id) or not titles.has(int(id)) or seen.has(int(id)): return "가호 영구 호칭 장부 오류"
		var i := titles.find(int(id))
		if not s.crafted.has(str(recipes[i])): return "제작 근거 없는 가호 호칭"
		seen.append(int(id))
	for key: Variant in s.cooldowns:
		if not key is String or not Source.IDS.has(int(key)) or not integer(s.cooldowns[key]): return "가호 재사용 저장 오류"
	if not s.active.is_empty():
		if not integer(s.active.get("item_id")) or not Source.IDS.has(int(s.active.item_id)) or not integer(s.active.get("until")): return "가호 활성 저장 오류"
		if not s.cooldowns.has(str(int(s.active.item_id))) or int(s.active.until) > int(s.cooldowns[str(int(s.active.item_id))]): return "가호 버프·재사용 장부 불일치"
	return ""

func setup(host: Node) -> void:
	world = host
	var parsed := JSON.new()
	if FileAccess.file_exists(POLICY_PATH) and parsed.parse(FileAccess.get_file_as_string(POLICY_PATH)) == OK and parsed.data is Dictionary:
		policy.merge(parsed.data,true)
	var result := Source.restore()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--protection523-source-zip="):
			result = Source.install(argument.trim_prefix("--protection523-source-zip="))
	if bool(result.get("ok",false)):
		source = result
		register_missing()
	else: problem = str(result.get("error","가호 원본 설치 필요"))
	state.policy.project_pvp_to_pve = bool(policy.get("project_pvp_to_pve",true))
	state.policy.same_group = str(policy.get("same_group","keep_stronger"))
	reset_clock()

func reset_clock() -> void:
	clock_anchor = maxi(int(Time.get_unix_time_from_system()),int(state.last_seen)) if bool(policy.get("elapsed_while_closed",true)) or int(state.last_seen) == 0 else int(state.last_seen)
	clock_ticks = Time.get_ticks_msec()

func now() -> int:
	var monotonic := clock_anchor + int((Time.get_ticks_msec()-clock_ticks)/1000)
	return maxi(int(Time.get_unix_time_from_system()),monotonic) if bool(policy.get("elapsed_while_closed",true)) else monotonic

func snapshot() -> Dictionary:
	var out := state.duplicate(true)
	out.last_seen = maxi(int(out.last_seen),now())
	return out

func load_state(data: Dictionary) -> bool:
	var quests: Variant = data.get("quest_state",{})
	if quests is Dictionary and world.quest_service.get("source") == null:
		for key: Variant in quests.get("claimed",{}):
			if str(key).begins_with("m523:"):
				# An older quest service drops native receipt IDs on import. Do not
				# let this independent feature erase a newer provider's save.
				save_blocked = true
				problem = "원본 퀘스트 저장을 보존합니다 · 호환 공급자 코드가 필요합니다"
				return false
	var candidate: Variant = data.get(SAVE_KEY,fresh())
	if not data.has(SAVE_KEY):
		candidate.policy.project_pvp_to_pve = bool(policy.get("project_pvp_to_pve",true))
		candidate.policy.same_group = str(policy.get("same_group","keep_stronger"))
	var error := validate(candidate)
	if not error.is_empty():
		save_blocked = true
		problem = error
		return false
	state = candidate.duplicate(true)
	# Godot JSON numbers are floats; Array.has uses type-sensitive matching.
	# Normalize identity arrays before they drive permanent effects or UI.
	state.titles = []
	for title_id: Variant in candidate.titles: state.titles.append(int(title_id))
	if not state.active.is_empty():
		state.active.item_id = int(state.active.item_id)
		state.active.until = int(state.active.until)
	save_blocked = false
	reset_clock()
	return true

func install(path: String) -> Dictionary:
	var result := Source.install(path)
	if bool(result.get("ok",false)):
		source = result
		if not save_blocked: problem = ""
		register_missing()
		world.hud.set_catalog_data(world.catalog_db,world.catalog_image_index)
	return result

func register_missing() -> void:
	# Exact existing Inven identities remain intact. New source definitions get
	# their own namespaced key; no item is granted by installing a definition.
	for item_id: int in Source.IDS:
		if not records_for(item_id).is_empty(): continue
		var definition: Dictionary = source.definitions[str(item_id)]
		var name_value := str(definition.name) + " · 원본#%d" % item_id
		var record := {"name":name_value,"sourceId":"m523:item:%d" % item_id,"source_item_class_id":item_id,
			"source_snapshot":"patch523","source":"protection523","source_bless_code":1,
			"sellable":false,"storable":false,"deletable":false,"droppable":bool(definition.item.IsDroppable),
			"grade":"신화" if int(definition.item.GradeID) == 32 else "전설","type":"마안","slot":"material",
			"desc":"원본523 가호 · 보유 효과 / 명예 코인 10개 사용 버프 / 제작 영구 호칭",
			"weight":int(definition.item.Weight),"sourceOptions":[],"originalSourceOptions":[]}
		world.catalog_db["아이템"].append(record)
	world._index_catalog_item_sources()
	world._index_item_weights()
	binding_catalog_size = -1

func source_id(record: Dictionary) -> int:
	if bool(record.get("source_pending_use",false)): return pending_material_id(record)
	var id := 0
	var source_id_value := str(record.get("sourceId",""))
	# PR227's established currency is a host wallet, without a native ID.
	# Match the complete generator contract, keep its metadata unchanged, and
	# expose this local-only adapter as an explicit configurable policy.
	if bool(policy.get("legacy_honor_wallet",true)) and source_id_value.is_empty() and str(record.get("name","")) == "명예 코인":
		if str(record.get("slot","")) == "currency" and str(record.get("type","")) == "화폐" and int(record.get("weight",-1)) == 0 and bool(record.get("stackable",false)) and not bool(record.get("droppable",true)) and not bool(record.get("sellable",true)) and str(record.get("desc","")) == "보유 재화 · 기존 인벤토리와 저장 데이터에 누적":
			return 3631
		return 0
	if source_id_value.is_valid_int() and str(record.get("source","")) == "inven":
		id = int(source_id_value)
	elif source_id_value.begins_with("m523:item:") and str(record.get("source_snapshot","")) == "patch523":
		id = int(record.get("source_item_class_id",0))
		if source_id_value != "m523:item:%d" % id: return 0
		if str(record.get("source","")) != "protection523":
			if str(record.get("source","")) != "lineagem_patch523" or not bool(record.get("source_m_native_item",false)) or not record.has("source_bless_raw") or int(record.source_bless_raw) != 1: return 0
			if record.has("source_m_drop_proof"):
				var proof: Variant = record.source_m_drop_proof
				if not proof is Dictionary or int(proof.get("source_item_class_id",-1)) != id or int(proof.get("bless_raw",0)) != 1 or int(proof.get("required_quest_id",-1)) != 0: return 0
	if id <= 0: return 0
	if not source.is_empty() and source.items.has(str(id)):
		var item: Dictionary = source.items[str(id)]
		var desc: Dictionary = source.descriptions.get(str(int(item.IdentifiedDescID)),{})
		var expected := str(desc.get("Description",""))
		var name_value := str(record.get("name",""))
		if expected.is_empty() or name_value not in [expected,expected + " · 원본#%d" % id]: return 0
		if record.has("source_bless_code") and int(record.source_bless_code) != 1: return 0
	return id

func records_for(item_id: int) -> Array:
	var records: Array = world.catalog_db.get("아이템",[])
	if records.size() != binding_catalog_size:
		binding_cache.clear()
		for raw: Variant in records:
			if not raw is Dictionary: continue
			var id := source_id(raw)
			if id <= 0: continue
			if not binding_cache.has(id): binding_cache[id] = []
			binding_cache[id].append(raw)
		binding_catalog_size = records.size()
	var result: Array = binding_cache.get(item_id,[]).duplicate()
	# PR262 stores native reward stacks as physical provenance records, rather
	# than inventing ordinary catalog items. Read that same ownership authority.
	for physical: Dictionary in world.item_instances.values():
		var record: Dictionary = physical.get("record",{})
		if pending_material_id(record) != item_id: continue
		var known := false
		for existing: Dictionary in result:
			if existing.get("name") == record.get("name"): known = true
		if not known: result.append(record)
	return result

func pending_material_id(record: Dictionary) -> int:
	if source.is_empty() or not record.get("source_pending_use") is bool or not bool(record.source_pending_use): return 0
	if not integer(record.get("source_item_class_id"),1): return 0
	var id := int(record.get("source_item_class_id",0))
	if id not in Source.QUEST_MATERIAL_IDS or not source.items.has(str(id)): return 0
	if record.get("source") != "lineagem_patch523" or record.get("source_snapshot") != "patch523" or record.get("sourceId") != "m523:item:%d" % id: return 0
	var original: Dictionary = source.items[str(id)]
	if NATIVE_FIELDS.full(record).get("source_original_item") != original or record.get("name") != "[원본 보상] "+str(original.Name) or record.get("source_display_name") != original.Name: return 0
	if record.get("slot") != "quest_reward" or not record.get("quest_item") is bool or not bool(record.quest_item) or not integer(record.get("source_bless_code_id"),1,1) or not record.get("source_use_immediately") is bool or bool(record.source_use_immediately): return 0
	if not integer(record.get("source_reward_id"),1): return 0
	var rid := str(int(record.source_reward_id))
	var reward: Dictionary = source.get("material_rewards",{}).get(rid,{})
	if int(reward.get("RewardTypeID",0)) != 2 or int(reward.get("RewardClassID",0)) != id or int(reward.get("ItemBlessCodeID",0)) != 1 or int(reward.get("RewardEnhancementTypeID",0)) != 1 or bool(reward.get("UseImmediately",true)) or bool(reward.get("ClanOnly",true)): return 0
	# Eligibility and all rewards belong to PR262. A consumer checks its durable
	# completed quest receipt; it never clears dates/class/predecessor gates.
	for qid: int in source.get("material_quests",{}).get(rid,[]):
		var claimed: Variant = world.quest_service.claimed.get("m523:quest:%d" % qid,false)
		if claimed is bool and claimed: return id
	return 0

func pending_quantity(key: String, item_id: int, instances: Dictionary) -> int:
	var amount := 0
	var by_reward: Dictionary = {}
	for physical: Dictionary in instances.values():
		if str(physical.get("name","")) != key: continue
		var record: Dictionary = physical.get("record",{})
		if pending_material_id(record) != item_id or not integer(physical.get("level"),0,0) or not integer(physical.get("source_reward_quantity"),1,10000): return -1
		var count := int(physical.source_reward_quantity)
		var rid := str(int(record.source_reward_id))
		by_reward[rid] = int(by_reward.get(rid,0))+count
		if int(by_reward[rid]) > int(source.material_rewards[rid].Amount): return -1
		amount += count
	return amount

func record_for_key(key: String) -> Dictionary:
	var catalog: Dictionary = world._find_catalog_item_record(key)
	if source_id(catalog) > 0: return catalog
	for physical: Dictionary in world.item_instances.values():
		if str(physical.get("name","")) == key and pending_material_id(physical.get("record",{})) > 0: return physical.record
	return {}

func managed(record: Dictionary) -> bool:
	var id := source_id(record)
	return Source.IDS.has(id) or id == Source.DISABLED_ID

func legacy_group_blocked(record: Dictionary) -> bool:
	return not source.is_empty() and source.group604_item_ids.has(source_id(record)) and int(effects().active_id) > 0

func owned_key(item_id: int, inventory: Dictionary) -> String:
	var found := ""
	for record: Dictionary in records_for(item_id):
		var key := str(record.name)
		if source_id(record) != item_id or source_id(record_for_key(key)) != item_id: continue
		if not integer(inventory.get(key,0),0,1500000000) or int(inventory.get(key,0)) < 1: continue
		if bool(record.get("source_pending_use",false)):
			if pending_quantity(key,item_id,world.item_instances) != int(inventory[key]): continue
		# Unknown physical or quest/provenance stacks must not be consumed as
		# unmarked legacy materials just because they share a source ID.
		if str(record.get("sourceId","")).begins_with("m523:item:") and str(record.get("source","")) != "protection523":
			if record.get("source_quest_ids",[]).size() > 0: continue
		if not found.is_empty() and found != key: return ""
		found = key
	return found

func locked(key: String) -> bool:
	var locks: Dictionary = world.ui_preferences.get("item_locks",{})
	if bool(locks.get(key,false)): return true
	for id: String in world.item_instances:
		if str(world.item_instances[id].get("name","")) == key and bool(locks.get(key+"@@@"+id,false)): return true
	return false

func craft_recipe(recipe_id: int) -> Dictionary:
	# Public delegation point for PR239. This owner alone consumes input and
	# commits the real body, Appellation IDs, lifetime ledger and crafting log.
	for item_id: int in Source.IDS:
		if int(source.get("definitions",{}).get(str(item_id),{}).get("recipe",{}).get("ItemCraftID",0)) == recipe_id: return craft(item_id)
	for item_id: int in [75764,123373]:
		if int(source.get("supply_recipes",{}).get(str(item_id),{}).get("recipe",{}).get("ItemCraftID",0)) == recipe_id: return craft_supply(item_id)
	return fail("가호 획득 소유자의 제작식이 아닙니다")

func effects() -> Dictionary:
	var out := {"possession_flat":0,"possession_percent_raw":0,"active_flat":0,"title_flat":0,"active_id":0,"remaining":0}
	if source.is_empty() or save_blocked: return out
	# Source has no separate possession-overlap table for these six identities.
	# Host policy takes the highest owned tier, independent of quantity.
	for item_id: int in Source.IDS:
		var d: Dictionary = source.definitions[str(item_id)]
		if not owned_key(item_id,world.inventory).is_empty():
			if str(policy.get("possession","highest")) == "sum_distinct":
				out.possession_flat = int(out.possession_flat)+int(d.possession_flat)
				out.possession_percent_raw = int(out.possession_percent_raw)+int(d.possession_percent_raw)
			else:
				out.possession_flat = maxi(int(out.possession_flat),int(d.possession_flat))
				out.possession_percent_raw = maxi(int(out.possession_percent_raw),int(d.possession_percent_raw))
		if has_id(state.titles,int(d.title.ID)): out.title_flat = maxi(int(out.title_flat),int(d.title_flat))
	if not state.active.is_empty() and int(state.active.until) > now():
		var id := int(state.active.item_id)
		out.active_id = id
		out.active_flat = int(source.definitions[str(id)].buff_flat)
		out.remaining = int(state.active.until)-now()
	return out

func fail(message: String) -> Dictionary:
	return {"ok":false,"error":message}

func ready_action() -> Dictionary:
	if busy or save_blocked or world.source_save_blocked or world.equipment_collections.save_blocked: return fail("저장 보호 중 · 가호와 재료를 보존합니다")
	if world.quest_service.get("save_blocked") == true: return fail("퀘스트 저장 보호 중 · 원본 보상 재료를 보존합니다")
	if source.is_empty(): return fail(problem)
	if bool(policy.get("elapsed_while_closed",true)) and int(Time.get_unix_time_from_system()) < int(state.last_seen): return fail("시각 역행 감지 · 마지막 저장 시각 이후 다시 이용하세요")
	if world.hp <= 0: return fail("부활 후 이용하세요")
	if world.player.is_stunned() or world.player.is_feared(): return fail("행동 제한 상태에서는 가호를 사용할 수 없습니다")
	return {"ok":true}

func quote_use(key: String) -> Dictionary:
	var ready := ready_action()
	if not bool(ready.ok): return ready
	var record: Dictionary = world._find_catalog_item_record(key)
	var id := source_id(record)
	if not Source.IDS.has(id) or int(world.inventory.get(key,0)) != 1: return fail("정확한 가호 1개 소지를 확인하세요")
	if locked(key): return fail("잠긴 가호는 사용할 수 없습니다")
	for instance: Dictionary in world.item_instances.values():
		if str(instance.get("name","")) == key: return fail("물리 장비로 저장된 가호는 정체 확인 후 사용하세요")
	var d: Dictionary = source.definitions[str(id)]
	if int(state.cooldowns.get(str(id),0)) > now(): return fail("재사용 대기 %d초" % (int(state.cooldowns[str(id)])-now()))
	for other: int in source.group604_item_ids:
		for legacy: Dictionary in records_for(other):
			if float(world.active_item_buffs.get(str(legacy.name),{}).get("remaining",0)) > 0: return fail("기존 방식의 가호 효과 종료 후 원본 가호를 사용하세요")
	var current := effects()
	if int(current.active_flat) > 0 and str(state.policy.same_group) == "keep_stronger" and int(current.active_flat) >= int(d.buff_flat):
		return fail("TWILIGHT 비중첩 정책 · 현재와 같거나 약한 버프는 교체하지 않습니다")
	var coin_key := owned_key(int(d.material_id),world.inventory)
	if coin_key.is_empty() or locked(coin_key) or int(world.inventory.get(coin_key,0)) < int(d.material_amount): return fail("잠금 해제된 정확한 명예 코인 10개가 필요합니다")
	return {"ok":true,"id":id,"key":key,"coin_key":coin_key,"definition":d}

func use(key: String) -> Dictionary:
	var quote := quote_use(key)
	if not bool(quote.ok): return quote
	var inventory: Dictionary = world.inventory.duplicate(true)
	var next := snapshot()
	var d: Dictionary = quote.definition
	inventory[quote.coin_key] = int(inventory[quote.coin_key])-int(d.material_amount)
	if int(inventory[quote.coin_key]) == 0: inventory.erase(quote.coin_key)
	next.active = {"item_id":int(d.id),"until":now()+int(d.duration)}
	next.cooldowns[str(int(d.id))] = now()+int(d.cooldown)
	var result := commit({"inventory":inventory,SAVE_KEY:next},"명예 코인 10개 사용 · %s %d분 · 가호 본체 보존" % [d.name,int(d.duration)/60])
	# Presentation starts only after the durable transaction. Its failure cannot
	# refund/re-spend coins or change the already committed gameplay state.
	if bool(result.ok): result.visual = play_use_visual(int(d.id))
	return result

var last_use_visual: Dictionary = {}

func play_use_visual(item_id: int) -> Dictionary:
	var d: Dictionary = source.get("definitions",{}).get(str(item_id),{})
	var sprite_id := int(d.get("consume_sprite_id",0))
	last_use_visual = {"item_id":item_id,"sprite_id":sprite_id,"status":"original_binding_unavailable",
		"source":"ItemBonus/BonusType107 ItemConsumeEffectSpriteID","source_sha256":Source.SOURCE_SHA,
		"trigger":"TWILIGHT_after_successful_atomic_use_commit","M_visual_equivalence_verified":false}
	if item_id not in Source.IDS or sprite_id <= 0: return last_use_visual.duplicate(true)
	var player: Node = world.player
	if not player is Node2D or not integer(player.get("facing"),0,7):
		last_use_visual.status = "source_target_unavailable"
		return last_use_visual.duplicate(true)
	var preview: Variant = player.get("original_source_preview")
	if not is_instance_valid(preview) or not preview.has_method("spawn_source_overlay"):
		last_use_visual.status = "source_renderer_unavailable"
		return last_use_visual.duplicate(true)
	# The established public compositor owns frames, offsets, layers, facing
	# conversion and source clocks. No SP2 decoder or guessed substitute here.
	# Retain live overlays; remove only freed references before its typed filter,
	# as required by the existing native-option consumer of the same public API.
	var handles: Variant = preview.get("_overlay_nodes")
	if handles is Array:
		var live: Array[Node2D] = []
		for node: Variant in handles:
			if is_instance_valid(node) and node is Node2D: live.append(node)
		preview.set("_overlay_nodes",live)
	var shown: Variant = preview.call("spawn_source_overlay",sprite_id,int(player.get("facing")),(player as Node2D).global_position)
	if shown is bool and shown: last_use_visual.status = "source_overlay_started"
	return last_use_visual.duplicate(true)

func quote_craft(item_id: int) -> Dictionary:
	var ready := ready_action()
	if not bool(ready.ok): return ready
	if not source.definitions.has(str(item_id)): return fail("사용 안함·미지원 가호 제작식입니다")
	var d: Dictionary = source.definitions[str(item_id)]
	var recipe_id := int(d.recipe.ItemCraftID)
	if state.crafted.has(str(recipe_id)): return fail("이미 제작한 가호입니다 · 캐릭터당 1회")
	for log: Dictionary in world.crafting_log:
		if str(log.get("recipe_id","")) in [str(recipe_id),"patch523:%d" % recipe_id]:
			return fail("기존 일반 제작 이력이 있습니다 · 중복 제작 보류")
	# The independent generic PR owns its own ledger. If installed later, a
	# pre-existing record for this exact recipe is not silently reset.
	var extra_value: Variant = world.equipment_collections.extra_save_fields.get("patch523_crafting_usage",{})
	if not extra_value is Dictionary: return fail("기존 일반 제작 제한 장부 손상 · 재료 보존")
	var extra: Dictionary = extra_value
	if not extra.is_empty():
		if int(extra.get("schema",0)) != 1 or not extra.get("recipes") is Dictionary or bool(extra.get("blocked",false)): return fail("기존 일반 제작 제한 장부 확인 필요")
		if extra.recipes.has(str(recipe_id)) or extra.recipes.has("patch523:%d" % recipe_id): return fail("일반 제작 제한 이력 확인 필요")
	if not owned_key(item_id,world.inventory).is_empty(): return fail("이미 보유한 가호입니다")
	var materials := material_keys(d.inputs)
	if not bool(materials.ok): return materials
	var outputs := records_for(item_id)
	if outputs.size() != 1: return fail("제작 결과 소지키가 모호합니다")
	return {"ok":true,"definition":d,"input_keys":materials.input_keys,"output_key":str(outputs[0].name)}

func material_keys(inputs: Array) -> Dictionary:
	var keys: Array = []
	for input: Dictionary in inputs:
		if int(input.Amount) != 1 or int(input.Enchant) != 0 or int(input.ItemBlessCodeID) != 1 or int(input.get("ItemHoningEpithetID",0)) != 0: return fail("미지원 가호 재료 상태")
		var key := owned_key(int(input.ItemClassID),world.inventory)
		if key.is_empty() or locked(key): return fail("정확한 재료 ID%d 1개가 필요합니다 · 잠금·중복 소지키 확인" % int(input.ItemClassID))
		for instance: Dictionary in world.item_instances.values():
			if str(instance.get("name","")) == key and not bool(instance.get("record",{}).get("source_pending_use",false)): return fail("물리 장비로 저장된 재료는 별도 정체 확인이 필요합니다")
		keys.append(key)
	return {"ok":true,"input_keys":keys}

func quote_supply(item_id: int) -> Dictionary:
	var ready := ready_action()
	if not bool(ready.ok): return ready
	if not source.get("supply_recipes",{}).has(str(item_id)): return fail("가호 공급 전용 제작식이 아닙니다")
	var d: Dictionary = source.supply_recipes[str(item_id)]
	if not owned_key(item_id,world.inventory).is_empty(): return fail("이미 보유한 정상 가호입니다")
	var materials := material_keys(d.inputs)
	if not bool(materials.ok): return materials
	var outputs := records_for(item_id)
	if outputs.size() != 1: return fail("제작 결과 소지키가 모호합니다")
	return {"ok":true,"definition":d,"input_keys":materials.input_keys,"output_key":str(outputs[0].name)}

func consume_materials(keys: Array) -> Dictionary:
	var inventory: Dictionary = world.inventory.duplicate(true)
	var instances: Dictionary = world.item_instances.duplicate(true)
	for key: String in keys:
		inventory[key] = int(inventory[key])-1
		if int(inventory[key]) == 0: inventory.erase(key)
		if bool(record_for_key(key).get("source_pending_use",false)):
			var consumed := false
			for physical_id: String in instances.keys():
				var physical: Dictionary = instances[physical_id]
				if str(physical.get("name","")) != key: continue
				var count := int(physical.source_reward_quantity)-1
				if count == 0: instances.erase(physical_id)
				else: physical.source_reward_quantity = count
				consumed = true
				break
			if not consumed: return fail("원본 보상 개체 수량 확인 필요 · 재료 보존")
	return {"ok":true,"inventory":inventory,"item_instances":instances}

func craft_supply(item_id: int) -> Dictionary:
	var quote := quote_supply(item_id)
	if not bool(quote.ok): return quote
	var materials := consume_materials(quote.input_keys)
	if not bool(materials.ok): return materials
	materials.inventory[quote.output_key] = 1
	var log: Array[Dictionary] = world.crafting_log.duplicate(true)
	log.append({"recipe_id":"patch523:%d" % int(quote.definition.recipe.ItemCraftID),"batch":1,"output":quote.output_key,"quantity":1,"gold":0,"at":now(),"source_sha256":Source.SOURCE_SHA})
	if log.size() > 200: log.pop_front()
	# Source has no quota rows for these two recipes. Do not invent the six
	# later titles or their character-once ledger for an upstream material.
	return commit({"inventory":materials.inventory,"item_instances":materials.item_instances,SAVE_KEY:snapshot(),"crafting_log":log},"정상 가호 확정 제작 · "+str(quote.definition.name))

func craft(item_id: int) -> Dictionary:
	var quote := quote_craft(item_id)
	if not bool(quote.ok): return quote
	var d: Dictionary = quote.definition
	var materials := consume_materials(quote.input_keys)
	if not bool(materials.ok): return materials
	var inventory: Dictionary = materials.inventory
	var instances: Dictionary = materials.item_instances
	inventory[quote.output_key] = 1
	var next := snapshot()
	var recipe_id := int(d.recipe.ItemCraftID)
	next.crafted[str(recipe_id)] = 1
	if not next.titles.has(int(d.title.ID)): next.titles.append(int(d.title.ID))
	var log: Array[Dictionary] = world.crafting_log.duplicate(true)
	log.append({"recipe_id":"patch523:%d" % recipe_id,"batch":1,"output":quote.output_key,"quantity":1,"gold":0,"at":now(),"source_sha256":Source.SOURCE_SHA})
	if log.size() > 200: log.pop_front()
	return commit({"inventory":inventory,"item_instances":instances,SAVE_KEY:next,"crafting_log":log},"가호 확정 제작 · 영구 호칭 획득 · 일반 리덕션 +%d" % int(d.title_flat))

func set_policy(project_to_pve: bool, group_policy: String) -> Dictionary:
	if group_policy not in ["keep_stronger","replace"]: return fail("알 수 없는 비중첩 정책")
	var ready := ready_action()
	if not bool(ready.ok): return ready
	var next := snapshot()
	next.policy = {"project_pvp_to_pve":project_to_pve,"same_group":group_policy}
	return commit({SAVE_KEY:next},"가호 전투·비중첩 정책 저장")

func commit(staged: Dictionary, message: String) -> Dictionary:
	busy = true
	var result: Error = world._save_game(true,staged)
	if result != OK:
		busy = false
		return fail("저장 실패 · 가호·명예 코인·제작 재료·호칭을 보존했습니다")
	if staged.has("inventory"): world.inventory = staged.inventory
	if staged.has("item_instances"): world.item_instances = staged.item_instances
	if staged.has("crafting_log"): world.crafting_log = staged.crafting_log
	state = staged[SAVE_KEY]
	busy = false
	world._update_hud()
	world.hud.show_message(message)
	world.hud.append_log(message)
	if is_instance_valid(world.player): world.player.show_status_text("가호")
	return {"ok":true,"message":message}
