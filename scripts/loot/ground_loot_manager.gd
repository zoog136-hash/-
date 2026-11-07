extends RefCounted
class_name TwilightGroundLootManager
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")

const LOOT = preload("res://scripts/loot/ground_loot.gd")
const GRADES = preload("res://scripts/catalog_grade_policy.gd")
const GROUND_SOURCE = preload("res://scripts/resources/current523_source_ground_selection.gd")
const SOURCE_ITEMS = preload("res://scripts/loot/patch523_monster_drops.gd")
const LIFETIME: float = 600.0
const MIN_VISIBLE_MS: int = 850
const OCCUPANCY_CELL: float = 64.0
const SEPARATION: float = 36.0
var world: Node
var records: Dictionary = {}
var views: Dictionary = {}
var current_map: String = ""
var current_batch: String = ""
var expiry_timer: float = 0.0
var revision: int = 0
var _pruning: bool=false
var _restoring: bool=false
# Only the active map participates in placement. Spatial buckets keep a burst
# of boss drops independent of the number of items left in distant maps.
var occupancy: Dictionary = {}
var occupancy_probes: int = 0
# Transient visual bindings supplied by the source consumer owner. Never added
# to ground ownership records, item receipts or saved drop quantities.
var source_ground_bindings: Dictionary = {}

static func _native_stack_record(record: Dictionary) -> bool:
	var physical: Variant=record.get("physical_item",{})
	return physical is Dictionary and physical.get("data") is Dictionary and physical.data.has("source_native_stack_receipt")

func configure(owner_world: Node) -> void:
	world = owner_world

func new_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

func begin_hunt_batch() -> String:
	current_batch = new_id()
	return current_batch

func item_record(item_name: String) -> Dictionary:
	# Drop grades come from the very same catalog that performed the roll.
	var catalog: Dictionary = world.get("loot_catalog")
	return (catalog.get("by_name", {}) as Dictionary).get(item_name, {})

func _icon(item_name: String) -> Texture2D:
	var images: Dictionary = (world.get("catalog_image_index") as Dictionary).get("아이템", {})
	return preload("res://scripts/ui/item_visual_resolver.gd").texture(item_record(item_name),item_name,images,true)

func _index_record(record: Dictionary) -> void:
	if str(record["map_id"]) != current_map: return
	var key := Vector2i((_position(record) / OCCUPANCY_CELL).floor())
	if not occupancy.has(key): occupancy[key] = {}
	occupancy[key][str(record["id"])] = true

func _unindex_record(record: Dictionary) -> void:
	if str(record["map_id"]) != current_map: return
	var key := Vector2i((_position(record) / OCCUPANCY_CELL).floor())
	if not occupancy.has(key): return
	occupancy[key].erase(str(record["id"]))
	if occupancy[key].is_empty(): occupancy.erase(key)

func _occupied(point: Vector2) -> bool:
	var low := Vector2i(((point - Vector2.ONE * SEPARATION) / OCCUPANCY_CELL).floor())
	var high := Vector2i(((point + Vector2.ONE * SEPARATION) / OCCUPANCY_CELL).floor())
	for y: int in range(low.y, high.y + 1):
		for x: int in range(low.x, high.x + 1):
			for id: String in occupancy.get(Vector2i(x, y), {}):
				occupancy_probes += 1
				if records.has(id) and _position(records[id]).distance_squared_to(point) < SEPARATION * SEPARATION:
					return true
	return false

func _position(record: Dictionary) -> Vector2:
	return Vector2(float(record["position"][0]), float(record["position"][1]))

func _find_spot(origin: Vector2) -> Vector2:
	for ring: int in range(17):
		for side: int in range(1 if ring == 0 else 16):
			var point: Vector2 = origin + Vector2.from_angle(float(side) * TAU / 16.0) * float(ring * 38)
			if bool(world.call("_is_walkable_world", point)) and not _occupied(point):
				return point
	var cell: Vector2i = world.call("_nearest_walkable_cell", world.call("_world_to_cell", origin))
	var fallback: Vector2 = world.call("_cell_to_world", cell)
	return fallback if bool(world.call("_is_walkable_world", fallback)) and not _occupied(fallback) else Vector2.INF

func spawn(item_name: String, origin: Vector2, quantity: int = 1, batch: String = "", metadata: Dictionary = {}) -> Button:
	var staged: Dictionary=stage_spawn(item_name,origin,quantity,batch,metadata)
	return publish_spawn(staged) if not staged.is_empty() else null

func stage_spawn(item_name: String, origin: Vector2, quantity: int = 1, batch: String = "", metadata: Dictionary = {}) -> Dictionary:
	var item: Dictionary = metadata.get("item_record",item_record(item_name))
	if item.is_empty() or quantity < 1 or not origin.is_finite(): return {}
	var point: Vector2 = _find_spot(origin)
	if not point.is_finite(): return {}
	var now: float = Time.get_unix_time_from_system()
	var record: Dictionary = {"id":new_id(), "item_name":item_name, "grade":str(item.get("grade", "일반")), "quantity":quantity,
		"map_id":current_map, "position":[point.x, point.y], "created_at":now, "expires_at":now + LIFETIME, "state":"ground", "hunt_batch":batch}
	while records.has(str(record.id)):record.id=new_id()
	# Whitelist transferable payload; never allow callers to override ownership IDs.
	for key: String in ["physical_item","item_record","player_dropped"]:
		if metadata.has(key): record[key] = metadata[key]
	# Snapshot only explicitly identified awakening materials at spawn time.
	# Old name-only floor saves never acquire provenance during reload.
	if preload("res://scripts/cards/source_awakening_items.gd").recognized(item):record["item_record"]=item.duplicate(true)
	return record

func publish_spawn(staged: Dictionary) -> Button:
	if staged.is_empty() or not staged.get("id") is String or records.has(staged.id) or staged.get("map_id")!=current_map or staged.get("state")!="ground":return null
	var point: Variant=staged.get("position")
	if not point is Array or point.size()!=2:return null
	var position:=Vector2(float(point[0]),float(point[1]))
	if not position.is_finite() or not bool(world.call("_is_walkable_world",position)) or _occupied(position):return null
	var record: Dictionary=staged.duplicate(true)
	records[record.id]=record;_index_record(record);revision+=1
	return _create_view(record)

func _create_view(record: Dictionary) -> Button:
	var view: TwilightGroundLoot = LOOT.new()
	var item_data: Dictionary = record.get("item_record",item_record(str(record["item_name"])))
	var visual_slot: String = "scroll" if bool(item_data.get("crafting_scroll",false)) else ("material" if bool(item_data.get("crafting_material",false)) else str(item_data.get("slot","")))
	var ground_request: Dictionary = _source_ground_request(item_data,str(record["id"]))
	var icon: Texture2D = null
	if ground_request.is_empty():
		var images: Dictionary = world.catalog_image_index.get("아이템",{})
		icon = preload("res://scripts/ui/item_visual_resolver.gd").texture(item_data,str(record["item_name"]),images,true)
	view.configure(record, icon, visual_slot, ground_request)
	(world.get("drops_root") as Node).add_child(view)
	view.pressed.connect(world._on_ground_drop_clicked.bind(view))
	views[record["id"]] = view
	return view

func _source_ground_request(item: Dictionary, ground_id: String = "") -> Dictionary:
	if item.get("source_m_native_item") != true: return {}
	var owner_context: Dictionary = {}
	var has_owner_context: bool = not ground_id.is_empty() and has_method("source_item_context")
	var original: Dictionary = {}
	if has_owner_context:
		# Integration269 reads the actual current floor/physical selection. Keep
		# its complete provenance and explicit non-authorization flags intact.
		var supplied: Variant = call("source_item_context",ground_id)
		if supplied is Dictionary: owner_context = supplied.duplicate(true)
		else: owner_context = {"ok":false,"reason":"current_ground_owner_context_invalid"}
		if owner_context.get("ok") == true and owner_context.get("ground_id") == ground_id and owner_context.get("original_item") is Dictionary:
			original = owner_context.original_item.duplicate(true)
	else:
		# Compatibility with the earlier local checkpoint does not fabricate the
		# later owner's floor proof. Its missing renderer relationship stays held.
		original = SOURCE_ITEMS.item_definition(item).get("original_item",{})
	var configured: Dictionary = source_ground_bindings.get(str(item.get("source_item_class_id",-1)),{})
	# A source-row reader may supply the current full row for the same already
	# identified native item when the drop-definition pack is unavailable here.
	# The selector checked that complete row against the pinned current tables.
	if original.is_empty() and not has_owner_context: original = configured.get("original_item",{})
	var context: Dictionary = {}
	var player: Variant = world.get("player")
	if is_instance_valid(player) and player.get("source_visual_context") is Dictionary:
		context = player.get("source_visual_context").duplicate(true)
	if configured.get("original_item") == original:
		context.merge(configured.get("source_bank_context",{}),true)
	return {"required":true,"original_item":original,"source_bank_context":context,"source_owner_context":owner_context,
		"source_binding":configured.get("source_binding",{}) if configured.get("original_item") == original else {}}

func bind_source_ground_definition(original_item: Dictionary, context: Dictionary = {}, source_binding: Dictionary = {}) -> Dictionary:
	# Accept a full current row from the image/data source reader for an existing
	# item view. The unresolved ground renderer relationship remains pending.
	var selected: Dictionary = GROUND_SOURCE.select(original_item,context,source_binding)
	if selected.get("reason") != "current523_ground_original_member_and_renderer_role_unresolved": return selected
	source_ground_bindings[str(original_item.ID)] = {"original_item":original_item.duplicate(true),
		"source_binding":source_binding.duplicate(true),"source_bank_context":context.duplicate(true)}
	for id: String in views:
		var view: Button = views[id]
		if not is_instance_valid(view) or not records.has(id): continue
		var record: Dictionary = records[id]
		var item: Dictionary = record.get("item_record",item_record(str(record.item_name)))
		if item.get("source_item_class_id") == original_item.ID:
			view.call("configure_source_ground",_source_ground_request(item,id))
	return selected

func hide_map() -> void:
	for view: Button in views.values():
		if is_instance_valid(view):
			view.get_parent().remove_child(view)
			view.queue_free()
	views.clear()

func activate(map_id: String) -> void:
	hide_map()
	current_map = map_id
	prune()
	occupancy.clear()
	for record: Dictionary in records.values(): _index_record(record)
	for record: Dictionary in records.values():
		if str(record["map_id"]) == current_map:
			if not bool(world.call("_is_walkable_world", _position(record))):
				var position_value: Vector2 = _find_spot(_position(record))
				if not position_value.is_finite(): continue
				_unindex_record(record)
				record["position"] = [position_value.x, position_value.y]
				_index_record(record)
			_create_view(record)
	revision += 1

func valid_view(view: Button) -> bool:
	if not is_instance_valid(view) or view.is_queued_for_deletion(): return false
	var id: String = str(view.get_meta("id", ""))
	if not records.has(id) or views.get(id) != view or view.get_parent() != world.get("drops_root"): return false
	var record: Dictionary = records[id]
	return str(record["map_id"]) == current_map and str(record["state"]) == "ground" and float(record["expires_at"]) > Time.get_unix_time_from_system()

func take(view: Button, from: Vector2, radius: float) -> Dictionary:
	if not valid_view(view): return {}
	var id: String = str(view.get_meta("id", ""))
	var record: Dictionary = records[id]
	if from.distance_to(_position(record)) > radius: return {}
	if Time.get_ticks_msec() - (view as TwilightGroundLoot).visible_since < MIN_VISIBLE_MS: return {}
	if not bool(world.call("_has_line_of_sight_world", from, _position(record))): return {}
	# Remove authoritative ID before issuing the inventory grant. Reentrant or
	# stale callbacks cannot claim the same item twice.
	if not _remove(id):return {}
	record["state"]="collected"
	return record

func _remove(id: String) -> bool:
	if _native_stack_record(records.get(id,{})):
		var owner: Script=load("res://scripts/loot/current523_native_stack.gd")
		if not owner.call("can_remove_floor",records[id]):return false
	if records.has(id): _unindex_record(records[id])
	if views.has(id):
		var view: Button = views[id]
		if is_instance_valid(view):
			view.get_parent().remove_child(view)
			view.queue_free()
		views.erase(id)
	records.erase(id)
	revision += 1
	return true

func clear_map(map_id: String) -> void:
	for id: String in records.keys():
		if str(records[id]["map_id"]) == map_id: _remove(id)

func tick(delta: float) -> void:
	expiry_timer += delta
	if expiry_timer >= 0.5:
		expiry_timer = 0.0
		prune()

func prune() -> void:
	if _pruning or _restoring:return
	_pruning=true
	var now: float=Time.get_unix_time_from_system()
	for id: String in records.keys():
		if float(records[id]["expires_at"])>now:continue
		if _native_stack_record(records[id]):
			var owner: Script=load("res://scripts/loot/current523_native_stack.gd")
			owner.call("expire_floor",world,records[id].duplicate(true))
		else:_remove(id)
	_pruning=false

func snapshot() -> Array:
	prune()
	return records.values().duplicate(true)

func restore(saved: Variant) -> void:
	_restoring=true
	hide_map()
	records.clear()
	occupancy.clear()
	var now: float = Time.get_unix_time_from_system()
	if saved is Array:
		for entry: Variant in saved:
			if not entry is Dictionary: continue
			var record: Dictionary = (entry as Dictionary).duplicate(true)
			var item_name: String = str(record.get("item_name", ""))
			var point: Variant = record.get("position", [])
			var item: Dictionary = item_record(item_name)
			if record.get("item_record") is Dictionary and str(record.item_record.get("name","")) == item_name: item = record.item_record
			if item.is_empty() or not point is Array or point.size() < 2: continue
			if not preload("res://scripts/loot/inventory_ground_transfer.gd").can_collect(world,record): continue
			if record.has("physical_item"):
				var physical_id: String = str(record.physical_item.id)
				var duplicate: bool = false
				for existing: Dictionary in records.values():
					if str(existing.get("physical_item",{}).get("id","")) == physical_id: duplicate = true
				if duplicate: continue
				if physical_id.is_valid_int(): world.next_item_instance_id = maxi(world.next_item_instance_id,int(physical_id)+1)
			if not (point[0] is float or point[0] is int) or not (point[1] is float or point[1] is int): continue
			if not Vector2(float(point[0]), float(point[1])).is_finite(): continue
			var map_id: String = str(record.get("map_id", current_map))
			var native_stack: bool=_native_stack_record(record)
			if not (world.get("maps_by_id") as Dictionary).has(map_id) and not native_stack: continue
			var expires: float = float(record.get("expires_at", now + LIFETIME))
			if (expires <= now and not native_stack) or not is_finite(expires) or str(record.get("state", "ground")) != "ground": continue
			var id: String = str(record.get("id", new_id()))
			if id.is_empty() or records.has(id): continue
			var quantity: int = int(record.get("quantity", 1))
			if quantity < 1: continue
			record.merge({"id":id, "item_name":item_name, "grade":str(item.get("grade", "일반")), "quantity":quantity,
				"map_id":map_id, "created_at":float(record.get("created_at", now)), "expires_at":expires, "state":"ground", "hunt_batch":str(record.get("hunt_batch", ""))}, true)
			records[id] = record
	var source_catalog: Variant = world.get("catalog_db")
	var gameplay_items: Variant = world.get("item_db")
	if source_catalog is Dictionary and gameplay_items is Array:
		GRADES.synchronize_ground_grades(source_catalog.get("아이템", []), gameplay_items, records.values())
	activate(current_map)
	_restoring=false


# Source actor-render handoff only. This reads the actually published current
# floor selection; it does not create/collect/move/save or authenticate a grant.
func source_item_context(ground_id: String) -> Dictionary:
	var record: Variant=records.get(ground_id)
	if not record is Dictionary or record.get("id")!=ground_id or record.get("map_id")!=current_map or record.get("state")!="ground":return {"ok":false,"reason":"actual_current_ground_selection_unavailable"}
	var item: Variant=record.get("item_record",item_record(str(record.get("item_name",""))))
	if not item is Dictionary or item.is_empty():return {"ok":false,"reason":"ground_original_item_record_unavailable"}
	var source: Script=load("res://scripts/resources/current523_definition_rows.gd")
	var definition: Dictionary=load("res://scripts/loot/patch523_monster_drops.gd").call("current_original_definition",item)
	var original: Variant=definition.get("original_item")
	if not original is Dictionary or original.is_empty() or original!=NATIVE_FIELDS.full(item).get("source_original_item") or original!=source.call("row","ItemClass",int(original.get("ID",0))):return {"ok":false,"reason":"current_ground_full_original_item_identity_required"}
	var physical: Variant=record.get("physical_item",{})
	return {"ok":true,"ground_id":ground_id,"ground_record":record.duplicate(true),"map_id":current_map,"quantity":record.get("quantity"),"item_name":str(record.get("item_name","")),"position":record.get("position",[]).duplicate(),"physical_id":str(physical.get("id","")) if physical is Dictionary else "","physical_item":physical.duplicate(true) if physical is Dictionary else {},"original_item":original.duplicate(true),"item_record":item.duplicate(true),"source_definition_archive":source.call("identity"),"source_basis":"existing_current_floor_record_and_exact_current_original_item","ownership_authorized":false,"sprite_action_selected":false,"render_observed":false}
