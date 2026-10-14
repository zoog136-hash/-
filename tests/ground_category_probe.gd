extends SceneTree
const RESOLVER = preload("res://scripts/ui/item_visual_resolver.gd")
const CATEGORIES = preload("res://scripts/ui/ground_item_icons.gd")
var failures: Array[String] = []
var checks: int = 0
var rows: Array[Dictionary] = []
var routes: Dictionary = {}
var counts: Dictionary = {}
var after: bool = false

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("GROUND_CATEGORY_FAIL ",label)
func sha(bytes: PackedByteArray) -> String:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(bytes)
	return digest.finish().hex_encode()
func inspect(record: Dictionary, group: String, index: int) -> void:
	var old: String = JSON.stringify(record)
	var name_value: String = str(record.get("name", ""))
	var inventory: Dictionary = RESOLVER.describe(record,name_value)
	var icon: Texture2D = RESOLVER.texture(record,name_value)
	var ground: Dictionary = RESOLVER.describe(record,name_value,{},true)
	var texture: Texture2D = RESOLVER.texture(record,name_value,{},true)
	check(icon != null and texture != null,group+":"+name_value+":textures")
	check(JSON.stringify(record)==old,group+":"+name_value+":identity unchanged")
	check(str(ground.get("name", ""))==name_value,group+":"+name_value+":real name")
	if after:
		check(ground.route in ["ground_category", "reviewed_ground", "l1j_dedicated_ground_candidate"],group+":"+name_value+":floor route")
		var prior: Dictionary = RESOLVER._describe_original(record,name_value,{},true)
		if prior.route in ["reviewed_ground", "l1j_dedicated_ground_candidate"]:
			check(JSON.stringify(prior)==JSON.stringify(ground),group+":"+name_value+":dedicated unchanged")
		else:
			check(ground.get("source_id","")==prior.get("source_id",""),group+":"+name_value+":sourceId unchanged")
			check(not texture.has_meta("item_family"),group+":"+name_value+":not a vector fallback")
			check(texture.get_image().get_pixel(0,0).a==0.0,group+":"+name_value+":transparent border")
	rows.append({"group":group,"index":index,"name":name_value,"source_id":str(record.get("sourceId","")),"inventory":inventory,"inventory_sha256":sha(icon.get_image().get_data()) if icon!=null else ""})
	if group=="runtime":
		routes[ground.route]=int(routes.get(ground.route,0))+1
		var category: String = str(ground.get("category",ground.route))
		counts[category]=int(counts.get(category,0))+1
func _run() -> void:
	after=OS.get_environment("GROUND_STAGE")=="after"
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	world.set_process(false)
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	world._clear_monsters()
	var groups: Dictionary = {"runtime":world.catalog_db.get("아이템",[]),"legacy":world.item_db,"natural_loot":world.loot_catalog.get("by_name",{}).values()}
	for group: String in groups:
		var records: Array = groups[group]
		for i: int in range(records.size()): inspect(records[i],group,i)
	if after:
		for example: Array in [["미스릴의 갑옷","갑옷","body","armor"],["드래곤의 각반","각반","gaiters","pants"],["마력의 지팡이","지팡이","weapon","staff"],["천상의 체인소드","체인 소드","weapon","chain"],["HP 물약","소모품","consumable","potion_hp"],["마나 회복 물약","소모품","consumable","potion_mp"],["철 광석","제작재료","consumable","ore"],["무기 마법 주문서 (각인)","강화주문서","consumable","scroll"]]:
			check(CATEGORIES.category({"name":example[0],"type":example[1],"slot":example[2]},example[0])==example[3],"classification "+str(example[0]))
		var spoof: Dictionary = {"name":"HP 물약","sourceId":"423","type":"소모품","slot":"consumable"}
		check(RESOLVER.describe(spoof,spoof.name,{},true).route!="ground_category","mismatched known identity still rejected")
		var stable: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATEGORIES.MANIFEST))
		for category: String in stable.categories:
			var asset: Dictionary = stable.categories[category]
			check(FileAccess.get_sha256(asset.path)==asset.sha256,"representative PNG hash: "+category)
		# Actual production drop view, name overlay, grade beam and persistence.
		for name_value: String in ["HP 물약","강철 한손검","미스릴의 갑옷","가죽의 각반","무기 마법 주문서 (각인)"]:
			var item: Dictionary = world.loot_catalog.get("by_name",{}).get(name_value,{})
			if item.is_empty():
				for candidate: Dictionary in world.catalog_db.get("아이템",[]):
					if candidate.get("name","")==name_value: item=candidate;break
			check(not item.is_empty(),"drop source exists: "+name_value)
			if item.is_empty():continue
			var view: Button = world.ground_loot.spawn(name_value,world.player.global_position,2,"",{"item_record":item})
			check(view!=null,"real drop created: "+name_value)
			if view==null:continue
			check(view.get_meta("item_name")==name_value and name_value in view.tooltip_text,"name and tooltip preserved: "+name_value)
			check(view.visual.rank==maxi(0,TwilightDropVisual.GRADES.find(str(item.get("grade","일반")))),"grade beam rank preserved: "+name_value)
			world.loot_pickup.select(view)
			check(name_value in world.loot_pickup.info.text,"production selected-name label: "+name_value)
			var snapshot: Array = world.ground_loot.snapshot()
			world.loot_pickup.cancel()
			world.ground_loot.restore(snapshot)
			check(world.ground_loot.records.size()==snapshot.size(),"drop save restore count: "+name_value)
			world.ground_loot.clear_map(world.active_map_id)
	var report: Dictionary = {"stage":"after" if after else "before","checks":checks,"failures":failures,"runtime_count":groups.runtime.size(),"natural_loot_count":groups.natural_loot.size(),"routes":routes,"categories":counts,"inventory_rows":rows}
	var file: FileAccess = FileAccess.open(OS.get_environment("GROUND_REPORT"),FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(report,"\t"))
	else: check(false,"report file created")
	print("GROUND_CATEGORY_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"runtime_count":groups.runtime.size(),"routes":routes}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
