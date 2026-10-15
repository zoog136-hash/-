extends SceneTree
const ALPHA = preload("res://scripts/ui/ground_alpha.gd")
const RESOLVER = preload("res://scripts/ui/item_visual_resolver.gd")
const DROP = preload("res://scripts/loot/drop_visual.gd")
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("GROUND_ALPHA_FAIL ",label)
func _run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ALPHA.MANIFEST))
	for key: String in manifest.images:
		var entry: Dictionary = manifest.images[key]
		var source: Texture2D = load(key) as Texture2D
		check(source != null,"source loads:"+key)
		if source == null: continue
		var original_bytes: PackedByteArray = source.get_image().get_data()
		var cleaned: Texture2D = ALPHA.texture(source)
		check(cleaned != source and cleaned.resource_path == entry.path,"dedicated floor uses alpha PNG:"+key)
		check(cleaned.get_size() == source.get_size(),"unchanged dimensions:"+key)
		check(source.get_image().get_data() == original_bytes,"input texture not mutated:"+key)
		var before: Image = source.get_image()
		var after: Image = cleaned.get_image()
		var removed: int = 0
		var bad_foreground: int = 0
		for y: int in range(before.get_height()):
			for x: int in range(before.get_width()):
				var old: Color = before.get_pixel(x,y)
				var value: Color = after.get_pixel(x,y)
				if old.a > 0.0 and value.a == 0.0:
					removed += 1
					if minf(old.r,minf(old.g,old.b)) < 250.0/255.0: bad_foreground += 1
				elif old.a > 0.0 and old != value: bad_foreground += 1
		check(bad_foreground == 0,"foreground colours and surviving highlights unchanged:"+key)
		check(removed == int(entry.removed_white_pixels) and removed > 0,"only exterior white removed:"+key)
		check(ALPHA.texture(source) == cleaned,"bounded cutout cache reuses resource:"+key)
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false);world.field_population.set_process(false);world.player.set_physics_process(false)
	world._clear_monsters()
	var runtime: Array = world.catalog_db.get("아이템",[])
	var dedicated: int = 0
	var view: Node2D = DROP.new();root.add_child(view)
	for record: Dictionary in runtime:
		var name_value: String = str(record.name)
		var floor_info: Dictionary = RESOLVER.describe(record,name_value,{},true)
		var floor: Texture2D = RESOLVER.texture(record,name_value,{},true)
		view.configure(str(record.get("grade","일반")),floor,str(record.get("slot","")))
		check(view.texture != null,"actual floor renderer has texture:"+name_value)
		check(view.rank == maxi(0,DROP.GRADES.find(str(record.get("grade","일반")))),"grade effect unchanged:"+name_value)
		if floor_info.route in ["reviewed_ground","l1j_dedicated_ground_candidate"]:
			dedicated += 1
			check(view.texture.resource_path.begins_with("res://assets/ground_alpha/"),"renderer bypasses opaque original:"+name_value)
		else:
			check(view.texture == floor,"category image is not replaced:"+name_value)
		var inventory: Texture2D = RESOLVER.texture(record,name_value)
		check(inventory != null and not inventory.resource_path.begins_with("res://assets/ground_alpha/"),"inventory stays independent:"+name_value)
	for id: String in ["422","250","233"]:
		var record: Dictionary = {}
		for item: Dictionary in runtime:
			if str(item.get("sourceId","")) == id:record=item;break
		if record.is_empty():continue
		var name_value: String = str(record.name)
		var drop: Button = world.ground_loot.spawn(name_value,world.player.global_position,2,"",{"item_record":record})
		check(drop != null,"production drop created:"+name_value)
		if drop == null:continue
		check(str(drop.get_meta("item_name","")) == name_value and name_value in drop.tooltip_text,"actual name and tooltip preserved:"+name_value)
		world.loot_pickup.select(drop)
		check(name_value in world.loot_pickup.info.text,"actual selected-name overlay preserved:"+name_value)
		world.loot_pickup.cancel();world._clear_drops()
	check(ALPHA.cache_size() <= 64,"floor cache remains bounded")
	var result: Dictionary = {"checks":checks,"failures":failures,"runtime_rows":runtime.size(),"dedicated_rows":dedicated,"cutout_images":manifest.images.size()}
	var path: String = OS.get_environment("GROUND_ALPHA_REPORT")
	if not path.is_empty():
		var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
		if file != null:file.store_string(JSON.stringify(result,"\t"))
	print("GROUND_ALPHA_RESULT ",JSON.stringify(result))
	view.queue_free();world.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
