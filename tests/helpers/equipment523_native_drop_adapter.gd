extends TwilightWorld
## Focused QA adapter for the optional, unchanged public native loot owner.
## Actual Monster death, floor ownership and pickup stay in the production host.
const NATIVE_DROP_LOOT_PATH: String = "res://scripts/loot_drop.gd"
const NATIVE_DROP_OWNER_PATH: String = "res://scripts/loot/patch523_monster_drops.gd"

var native_drop_registration: Dictionary = {}
var native_drop_identity: Dictionary = {}
var native_drop_groups: Dictionary = {}
var native_drop_entries: Array[Dictionary] = []
var native_drop_batch: String = ""
var native_drop_spawned_ids: Array[String] = []
var native_drop_diagnostics: Array[Dictionary] = []
var native_drop_context: Dictionary = {}
var native_drop_calls: int = 0
var native_drop_rng_before: int = 0
var native_drop_rng_after: int = 0

func _load_data() -> void:
	super._load_data()
	# Match the public host's definition registration before saved ownership loads.
	register_native_drop_catalog()

func _native_drop_owner() -> Variant:
	if not ResourceLoader.exists(NATIVE_DROP_OWNER_PATH): return null
	var owner: Variant = load(NATIVE_DROP_OWNER_PATH)
	if owner == null: return null
	for method: String in ["data","identity","candidates","ground_metadata","register_catalog","catalog_index","pack_identity"]:
		if not owner.has_method(method): return null
	return owner

func register_native_drop_catalog() -> Dictionary:
	# Definitions/indexes only; this never grants inventory or physical items.
	var owner: Variant = _native_drop_owner()
	var public_loot: Variant = load(NATIVE_DROP_LOOT_PATH)
	if owner == null or public_loot == null or not public_loot.has_method("roll_patch523"):
		native_drop_registration = {"ok":false,"error":"public_native_drop_owner_unavailable"}
		return native_drop_registration
	var document: Dictionary = owner.data()
	var identity: Dictionary = owner.pack_identity()
	if document.is_empty() or identity.get("schema") != 3:
		native_drop_registration = {"ok":false,"error":"verified_native_drop_pack_unavailable"}
		return native_drop_registration
	var registered: Dictionary = owner.register_catalog(document,catalog_db)
	_index_catalog_item_sources()
	_index_item_weights()
	loot_catalog["patch523_by_name"] = owner.catalog_index(catalog_db.get("아이템",[]))
	if loot_catalog.patch523_by_name.is_empty():
		native_drop_registration = {"ok":false,"error":"native_catalog_index_empty","registration":registered}
		return native_drop_registration
	native_drop_registration = {"ok":true,"owner_identity":identity.duplicate(true),"registration":registered.duplicate(true)}
	return native_drop_registration

func _native_drop_block(error: String, detail: Dictionary = {}) -> void:
	var diagnostic: Dictionary = detail.duplicate(true)
	diagnostic["error"] = error
	native_drop_diagnostics.append(diagnostic)

func _native_drop_whole(value: Variant) -> int:
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value) != floorf(float(value)) or float(value) < 1 or float(value) > 9007199254740991.0: return 0
	return int(value)

func _roll_drop(monster: TwilightMonster, can_drop_tradeable_equipment: bool = true, source_weights: Dictionary = {}) -> void:
	native_drop_calls += 1
	native_drop_identity = {}
	native_drop_groups = {}
	native_drop_entries.clear()
	native_drop_batch = ""
	native_drop_spawned_ids.clear()
	native_drop_diagnostics.clear()
	native_drop_context = {}
	native_drop_rng_before = rng.state
	native_drop_rng_after = rng.state
	if not is_instance_valid(monster):
		_native_drop_block("native_actor_unavailable")
		return
	native_drop_context = {"actor_id":monster.get_instance_id(),"life_id":monster.life_id,"dead":monster.dead,"can_drop_tradeable_equipment":can_drop_tradeable_equipment}
	var owner: Variant = _native_drop_owner()
	var public_loot: Variant = load(NATIVE_DROP_LOOT_PATH)
	if owner == null or public_loot == null or not public_loot.has_method("roll_patch523"):
		_native_drop_block("public_native_drop_owner_unavailable")
		return
	if not source_weights.is_empty():
		_native_drop_block("native_roll_has_no_source_weight_parameter",{"weights":source_weights})
		return
	# Old Monster retains the raw row but not its snapshot field. The harness
	# copies this metadata from the actual setup record; no snapshot is invented.
	var snapshot: Variant = monster.get_meta("source_m_snapshot",null)
	var raw: Dictionary = monster.source_m_original
	var source_id: int = _native_drop_whole(monster.source_m_npc_id)
	if snapshot not in ["base508","patch523"] or source_id <= 0 or _native_drop_whole(raw.get("ID")) != source_id or _native_drop_whole(raw.get("Sprite")) <= 0 or not raw.get("Name") is String or str(raw.Name).is_empty():
		_native_drop_block("native_actor_source_fields_unverified",{"snapshot":snapshot,"source_npc_id":source_id})
		return
	var document: Dictionary = owner.data()
	var canonical: Dictionary = document.get("npcs",{}).get(str(source_id),{})
	if canonical.is_empty() or canonical.get("sprite_id") != raw.Sprite or canonical.get("source_name") != raw.Name or not raw.get("TestNPC") is bool or raw.TestNPC != false or canonical.get("test_npc") != raw.TestNPC:
		_native_drop_block("native_actor_canonical_tuple_rejected",{"source_npc_id":source_id})
		return
	native_drop_identity = owner.identity({"source_m_snapshot":snapshot,"source_m_npc_id":source_id,"source_m_original":raw})
	if native_drop_identity.is_empty():
		_native_drop_block("native_actor_identity_rejected")
		return
	# candidates() checks the exact NPC ID/Sprite/Name/TestNPC tuple and all
	# original quest/blessing/item constraints against the verified public pack.
	var full_catalog: Dictionary = {"patch523_by_name":owner.catalog_index(catalog_db.get("아이템",[]))}
	native_drop_groups = owner.candidates(native_drop_identity,full_catalog)
	if native_drop_groups.is_empty():
		_native_drop_block("native_candidates_unavailable",{"owner_diagnostics":owner.diagnostics})
		return
	# Dynamic dispatch keeps this optional helper parseable on the old host.
	# The actual, unchanged public roll_patch523 owns all draws and quantities.
	var rolled: Array[Dictionary] = public_loot.call("roll_patch523",native_drop_groups,monster.is_boss,rng)
	native_drop_entries = rolled.duplicate(true)
	native_drop_rng_after = rng.state
	if rolled.is_empty(): return
	native_drop_batch = ground_loot.begin_hunt_batch()
	for entry: Dictionary in rolled:
		var item_name: String = str(entry.get("item_name",""))
		var quantity: int = _native_drop_whole(entry.get("quantity"))
		var item: Variant = entry.get("item_record")
		if item_name.is_empty() or quantity <= 0 or not item is Dictionary or item.get("name") != item_name:
			_native_drop_block("native_rolled_entry_rejected")
			continue
		if not can_drop_tradeable_equipment and not item_name.contains("각인") and _equipment_slot_base(item) != "":
			_native_drop_block("host_tradeable_equipment_protection",{"item_name":item_name})
			continue
		var metadata: Dictionary = owner.ground_metadata(entry)
		if not metadata.get("item_record") is Dictionary:
			_native_drop_block("native_ground_metadata_unavailable",{"item_name":item_name})
			continue
		var view: Button = ground_loot.spawn(item_name,monster.global_position,quantity,native_drop_batch,metadata)
		if not is_instance_valid(view):
			_native_drop_block("native_ground_spawn_failed",{"item_name":item_name})
			continue
		native_drop_spawned_ids.append(str(view.get_meta("id","")))
		if is_instance_valid(presentation_audio): presentation_audio.play_world("drop",monster.global_position)
	if is_instance_valid(hud): hud.show_message("아이템이 바닥에 떨어졌습니다")
