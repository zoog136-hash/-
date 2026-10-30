extends RefCounted
class_name TwilightGroundLootManager

const LOOT = preload("res://scripts/loot/ground_loot.gd")
const GRADES = preload("res://scripts/catalog_grade_policy.gd")
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
# Only the active map participates in placement. Spatial buckets keep a burst
# of boss drops independent of the number of items left in distant maps.
var occupancy: Dictionary = {}
var occupancy_probes: int = 0

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
	var item: Dictionary = metadata.get("item_record",item_record(item_name))
	if item.is_empty() or quantity < 1 or not origin.is_finite(): return null
	var point: Vector2 = _find_spot(origin)
	if not point.is_finite(): return null
	var now: float = Time.get_unix_time_from_system()
	var record: Dictionary = {"id":new_id(), "item_name":item_name, "grade":str(item.get("grade", "일반")), "quantity":quantity,
		"map_id":current_map, "position":[point.x, point.y], "created_at":now, "expires_at":now + LIFETIME, "state":"ground", "hunt_batch":batch}
	# Whitelist transferable payload; never allow callers to override ownership IDs.
	for key: String in ["physical_item","item_record","player_dropped"]:
		if metadata.has(key): record[key] = metadata[key]
	records[record["id"]] = record
	_index_record(record)
	revision += 1
	return _create_view(record)

func _create_view(record: Dictionary) -> Button:
	var view: TwilightGroundLoot = LOOT.new()
	var item_data: Dictionary = record.get("item_record",item_record(str(record["item_name"])))
	var visual_slot: String = "scroll" if bool(item_data.get("crafting_scroll",false)) else ("material" if bool(item_data.get("crafting_material",false)) else str(item_data.get("slot","")))
	var images: Dictionary = world.catalog_image_index.get("아이템",{})
	var icon: Texture2D = preload("res://scripts/ui/item_visual_resolver.gd").texture(item_data,str(record["item_name"]),images,true)
	view.configure(record, icon, visual_slot)
	(world.get("drops_root") as Node).add_child(view)
	view.pressed.connect(world._on_ground_drop_clicked.bind(view))
	views[record["id"]] = view
	return view

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
	record["state"] = "collected"
	# Remove authoritative ID before issuing the inventory grant. Reentrant or
	# stale callbacks cannot claim the same item twice.
	_remove(id)
	return record

func _remove(id: String) -> void:
	if records.has(id): _unindex_record(records[id])
	if views.has(id):
		var view: Button = views[id]
		if is_instance_valid(view):
			view.get_parent().remove_child(view)
			view.queue_free()
		views.erase(id)
	records.erase(id)
	revision += 1

func clear_map(map_id: String) -> void:
	for id: String in records.keys():
		if str(records[id]["map_id"]) == map_id: _remove(id)

func tick(delta: float) -> void:
	expiry_timer += delta
	if expiry_timer >= 0.5:
		expiry_timer = 0.0
		prune()

func prune() -> void:
	var now: float = Time.get_unix_time_from_system()
	for id: String in records.keys():
		if float(records[id]["expires_at"]) <= now: _remove(id)

func snapshot() -> Array:
	prune()
	return records.values().duplicate(true)

func restore(saved: Variant) -> void:
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
			if not (world.get("maps_by_id") as Dictionary).has(map_id): continue
			var expires: float = float(record.get("expires_at", now + LIFETIME))
			if expires <= now or not is_finite(expires) or str(record.get("state", "ground")) != "ground": continue
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
