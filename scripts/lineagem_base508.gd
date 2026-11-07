extends RefCounted
## Verified client snapshot definitions. Source IDs are namespaced; never match old IDs by integer/name.
# Historical path identifiers remain for compatibility; cards()/npc() do not
# load these files as current numeric input or as fallback data.
const CARD_PATH = "res://data/lineagem_base508/cards.json"
const CURRENT_CARD_PATH = "res://data/lineagem_base508/cards_patch523.json"
const NPC_PATH = "res://data/lineagem_base508/npc_classes.json"
const CURRENT_CARD_CATALOG = preload("res://scripts/cards/current523_card_catalog.gd")
const CURRENT_DEFINITIONS = preload("res://scripts/resources/current523_definition_rows.gd")
static var _cards: Dictionary = {}
static var _by_id: Dictionary = {}
static var _npcs: Dictionary = {}
static var current_card_problem: String = ""
static var current_npc_problem: String = ""
static func cards() -> Dictionary:
	if CURRENT_DEFINITIONS.identity().is_empty():
		_cards = {}; _by_id.clear()
		current_card_problem = CURRENT_DEFINITIONS.problem()
		return {}
	if _cards.is_empty():
		var value: Dictionary = CURRENT_CARD_CATALOG.build()
		current_card_problem = str(value.get("problem",""))
		if not value.get("ready",false):
			_by_id.clear()
			return {}
		value["current_source_table_sha256"] = value.get("source_table_sha256",{}).duplicate(true)
		_cards = value
		_index_cards(value)
	current_card_problem = str(_cards.get("problem",""))
	return _cards
static func _index_cards(value: Dictionary) -> void:
	# Independent native supplements can repeat an identity. Keep its position
	# and overlay supplied fields, retaining omitted provenance/variant metadata.
	_by_id.clear()
	for category: String in value.get("catalog", {}):
		var rows: Array=[]
		var positions: Dictionary={}
		for record: Dictionary in value.catalog[category]:
			var identity: String=str(record.sourceId)
			if positions.has(identity):
				var merged: Dictionary=(rows[int(positions[identity])] as Dictionary).duplicate(true)
				merged=merge_metadata(merged,record)
				record=merged
				rows[int(positions[identity])]=record
			else:positions[identity]=rows.size();rows.append(record)
			_by_id[identity]=record
		value.catalog[category]=rows

static func merge_metadata(base: Dictionary, supplement: Dictionary) -> Dictionary:
	var merged: Dictionary=base.duplicate(true)
	for key: Variant in supplement:
		var next: Variant=supplement[key]
		if next is Dictionary and merged.get(key) is Dictionary:
			merged[key]=merge_metadata(merged[key],next)
		elif key=="sourceOptions":merged[key]=next.duplicate(true)
		elif next is Array and merged.get(key) is Array:
			# A repeated source row is one declaration, not another stat award.
			var rows: Array=merged[key].duplicate(true)
			for entry: Variant in next:
				if not entry in rows:rows.append(entry.duplicate(true) if entry is Dictionary or entry is Array else entry)
			merged[key]=rows
		else:merged[key]=next.duplicate(true) if next is Dictionary or next is Array else next
	return merged

static func native(record: Dictionary) -> bool:
	return record.get("source", "") in ["lineagem_base508","lineagem_patch523"]
static func canonical(record: Dictionary) -> Dictionary:
	if not native(record): return record
	# Item identity is owned by its supplier, never the card registry. Retain
	# these records without relaxing the missing-card-definition hold below.
	var source_key: String=str(record.get("sourceId",""))
	if source_key.begins_with("m508:item:") or source_key.begins_with("m523:item:"):
		if record.get("source_m_native_item")==true:
			var owner: Resource=load("res://scripts/loot/patch523_monster_drops.gd")
			return owner.call("current_owned_record",record) if owner!=null else {}
		return record
	cards()
	var current: Dictionary = _by_id.get(str(record.get("sourceId", "")),{})
	if current.is_empty(): current_card_problem = "현재523 원문에서 해당 저장 카드 정체를 읽을 수 없습니다. 기존 저장은 보존합니다."
	return current
static func apply_catalog(existing: Dictionary) -> Dictionary:
	var data: Dictionary = cards()
	# Shallow copy: only the three replaced categories get new arrays below. A
	# deep copy duplicated the whole item catalog (~34,700 original records).
	var result: Dictionary = existing.duplicate(false)
	# Keep prior registries for preservation only. Missing current source input
	# cannot make a former card pack the active numeric catalog again.
	var preserved: Variant = existing.get("_legacy_collectibles_before_base508",{})
	var legacy: Dictionary = preserved.duplicate(true) if preserved is Dictionary else {}
	for category: String in ["변신","마법인형","성물"]:
		if not legacy.has(category): legacy[category] = existing.get(category,[]).duplicate(true)
		result[category] = data.get("catalog",{}).get(category,[]).duplicate(true)
	result["_legacy_collectibles_before_base508"] = legacy
	result["_current523_card_input"] = {"available":not data.is_empty(),"problem":current_card_problem,"source_definition_archive":data.get("source_definition_archive",{})}
	return result
static func flat_bonus(record: Dictionary, type_name: String) -> int:
	var total: int = 0
	for detail: Dictionary in record.get("source_bonuses", []):
		if detail.get("application", "") == "unconditional_native_value" and detail.bonus_type.Name == type_name:
			total += int(detail.bonus.Value)
	return total
static func npc(source_id: int) -> Dictionary:
	if CURRENT_DEFINITIONS.identity().is_empty():
		_npcs = {}
		current_npc_problem = CURRENT_DEFINITIONS.problem()
		return {}
	current_npc_problem = ""
	if not _npcs.has(source_id):
		var current: Dictionary = CURRENT_CARD_CATALOG.npc(source_id)
		current_npc_problem = CURRENT_CARD_CATALOG.npc_problem
		if current.is_empty(): return {}
		_npcs[source_id] = current
	return _npcs.get(source_id, {})
static func npc_record(source_id: int, local_context: Dictionary) -> Dictionary:
	var row: Dictionary = npc(source_id)
	if row.is_empty(): return local_context
	var result: Dictionary = local_context.duplicate(true)
	result["source_m_npc_id"] = source_id
	result["source_m_snapshot"] = "base508"
	result["source_m_original"] = row.duplicate(true)
	result["source_m_previous_application"] = local_context.duplicate(true)
	result["name"] = str(row.get("DisplayName_from_DescId", ""))
	result["hp"] = int(row.HP)
	result["mp"] = int(row.MP)
	result["ac"] = int(row.AC)
	result["mr"] = int(row.MR)
	result["xp"] = int(row.Exp)
	# Combat level remains local unless an exact, nonzero spawn-context NpcLevel is supplied.
	if local_context.has("source_m_spawn_npc_level") and int(local_context.source_m_spawn_npc_level) > 0:
		result["lv"] = int(local_context.source_m_spawn_npc_level)
		result["source_m_level_origin"] = "NpcSpawnPackNpcClassView.NpcLevel_explicit_context"
	else:
		result["source_m_level_origin"] = "local_compatibility_only_native_level_unknown"
	return result
static func asset_path(source_path: String) -> String:
	if not preload("res://scripts/lineagem_pack_install.gd").active_manifest_problem().is_empty(): return ""
	# One exact source-table / physical-archive case mismatch, verified by source bytes.
	var physical: String = source_path
	if source_path == "Image/UIImage/Illust_Legend_WorldTree_Helm_ON.png":
		physical = "Image/UIImage/Illust_Legend_WorldTree_Helm_On.png"
	var path: String = preload("res://scripts/lineagem_pack_install.gd").resolve_file(preload("res://scripts/lineagem_pack_install.gd").active_root(), "ui/" + physical)
	if physical != source_path and FileAccess.file_exists(path):
		if FileAccess.get_sha256(path) != "b23768894fa574911d9cf063cfb3b6ee621a67cb372a7e612fa8c7db66315e6c": return ""
	return path
static var _icons: Dictionary = {}
static func icon(record: Dictionary) -> Texture2D:
	if not native(record):
		var legacy: String = str(record.get("image_path", ""))
		return load(legacy) as Texture2D if not legacy.is_empty() and ResourceLoader.exists(legacy) else null
	if record.get("source_snapshot", "") == "patch523": return null
	var asset: Variant = record.get("source_ui_assets", {}).get("DisplayBaseAssetID")
	if not asset is Dictionary: return null
	var path: String = asset_path(str(asset.get("path", "")))
	if not FileAccess.file_exists(path): return null
	if _icons.has(path): return _icons[path]
	var image: Image = Image.load_from_file(path)
	if image == null or image.is_empty(): return null
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	if _icons.size() >= 96: _icons.erase(_icons.keys()[0])
	_icons[path] = texture
	return texture

static var _identity_rules: Dictionary = {}
static func identity_rules() -> Dictionary:
	if _identity_rules.is_empty():
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/lineagem_base508/identity_rules.json"))
		if value is Dictionary:
			for row: Dictionary in value.get("records", []): _identity_rules[int(row.card_id)] = row
	return _identity_rules
static func source_class_id(localized_class_name: String) -> int:
	var matches: Array = []
	for row: Dictionary in cards().get("classes", []):
		if str(row.name) == localized_class_name: matches.append(int(row.source_original.ID))
	return int(matches[0]) if matches.size() == 1 else 0
static func select_visual(record: Dictionary, context: Dictionary = {}) -> Dictionary:
	var canonical_record: Dictionary = canonical(record)
	if canonical_record.get("source_snapshot", "") == "patch523":
		return {"status":"selection_pending","reason":"patch523_original_pack_required","declared_sprite_ids":canonical_record.get("source_inworld_sprite_ids",[]).duplicate()}
	var card_id: int = int(canonical_record.get("source_card_id", -1))
	var rule: Dictionary = identity_rules().get(card_id, {})
	if rule.is_empty():
		var ids: Array = canonical_record.get("source_inworld_sprite_ids", [])
		return {"status":"selected","sprite_id":int(ids[0]),"origin":"verified_single_inworld_identity"} if ids.size() == 1 else {"status":"selection_pending","reason":"source_identity_context_required"}
	var kind: String = str(rule.selection_kind)
	if kind == "indirect_subslot_buff_summon":
		# Appearance identity is independent of interpreting the original gameplay slot enum.
		return {"status":"selected","sprite_id":int(rule.inworld_sprite_id),"origin":"verified_indirect_subslot_summon","native_application_condition":rule.native_application_condition.duplicate(true),"gameplay_condition":"preserved_uninterpreted; presentation_only"}
	var entities: Array = []
	if kind == "base_polymorph_or_declared_custom_sprite_option":
		var options: Dictionary = context.get("active_card_options", {})
		var option_id: int = int(options.get(str(canonical_record.sourceId), record.get("source_active_custom_option_id", canonical_record.get("source_active_custom_option_id", 0))))
		if option_id > 0:
			for option: Dictionary in rule.get("custom_options", []):
				if int(option.native_option.ID) == option_id and int(option.native_option.BuffCardID) == card_id:
					entities = option.polymorph.entities
					if entities.size() == 1:
						return {"status":"selected","sprite_id":int(entities[0].SpriteID),"origin":"explicit_active_native_option","native_option":option.native_option.duplicate(true),"eligibility":"StarEnchant preserved; no inferred equality/threshold/highest-unlocked selection"}
			return {"status":"selection_pending","reason":"active_option_not_declared_for_card"}
		for link: Dictionary in rule.base_links: entities.append_array(link.polymorph.entities)
		return {"status":"selected","sprite_id":int(entities[0].SpriteID),"origin":"source_declared_base_without_active_custom_option"} if entities.size() == 1 else {"status":"selection_pending","reason":"source_base_not_unique"}
	if kind == "polymorph_entity_class_gender_variants":
		var class_id: int = int(context.get("class_id", 0))
		var gender_id: int = int(context.get("gender_id", 0))
		if class_id <= 0 or gender_id <= 0: return {"status":"selection_pending","reason":"character_class_and_gender_required"}
		for link: Dictionary in rule.base_links:
			for entity: Dictionary in link.polymorph.entities:
				if int(entity.ClassID) == class_id and int(entity.GenderID) == gender_id: entities.append(entity)
		return {"status":"selected","sprite_id":int(entities[0].SpriteID),"origin":"exact_native_class_gender_pair","native_entity":entities[0].duplicate(true)} if entities.size() == 1 else {"status":"selection_pending","reason":"native_class_gender_pair_not_unique_or_not_declared"}
	return {"status":"selection_pending","reason":"unmapped_source_rule"}
static func select_visual_key(key: String, context: Dictionary = {}) -> Dictionary:
	cards()
	var source_id: String = key.substr(key.find(":") + 1)
	var record: Dictionary = _by_id.get(source_id, {})
	return select_visual(record, context) if not record.is_empty() else {}

