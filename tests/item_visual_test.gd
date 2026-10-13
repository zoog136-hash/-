extends SceneTree

const UI = preload("res://scripts/ui/renewal_theme.gd")
const RESOLVER = preload("res://scripts/ui/item_visual_resolver.gd")
const EFFECT = preload("res://scripts/ui/item_visual.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("ITEM_VISUAL_FAIL: "+label)

func _run() -> void:
	var db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	var groups: Dictionary = {}
	for record: Dictionary in db["아이템"]:
		if not groups.has(record.name): groups[record.name] = []
		groups[record.name].append(record)
		var original: String = JSON.stringify(record)
		check(RESOLVER.describe(record,record.name).path == record.image_path,"pinned source "+record.sourceId)
		check(RESOLVER.texture(record,record.name) == load(record.image_path),"native pixels "+record.sourceId)
		check(original == JSON.stringify(record),"read-only "+record.sourceId)
	for name_value: String in groups:
		if groups[name_value].size() > 1:
			check(RESOLVER.describe({"name":name_value},name_value).status == "self_authored_substitute","ambiguous name blocked "+name_value)
	var first: Dictionary = db["아이템"][0]
	var wrong: Dictionary = first.duplicate(true)
	wrong.name = "not the source name"
	check(RESOLVER.describe(wrong,wrong.name).status == "self_authored_substitute","known ID wrong name blocked")
	wrong.name = "HP 물약"
	check(RESOLVER.describe(wrong,wrong.name,{},true).status == "self_authored_substitute","ground cannot recover rejected ID through a reviewed name")
	check(RESOLVER.describe({"sourceId":"unknown","name":first.name},first.name,{first.name:first.image_path}).path == "","unknown ID never borrows name image")
	check(RESOLVER.texture({"name":"local weapon","slot":"weapon","type":"활"}).get_meta("item_family") == "bow","own bow is explicitly a family symbol")
	check(RESOLVER.describe({"name":"드래곤의 루비","type":"축복충전"},"드래곤의 루비",{"드래곤의 루비":"res://assets/ui/potionRed.png"}).family == "gem","legacy ruby placeholder becomes an explicit gem symbol")
	check(RESOLVER.cache_size() <= 256,"bounded texture cache")
	var clip := Control.new()
	clip.clip_contents = true
	clip.size = Vector2(180,180)
	root.add_child(clip)
	var views: Array[TextureRect] = []
	for index: int in range(7):
		var view := TextureRect.new()
		view.size = Vector2(64,64)
		clip.add_child(view)
		var record: Dictionary = first.duplicate(true)
		record.grade = EFFECT.GRADES[index]
		UI.apply_item_visual(view,record,record.name)
		views.append(view)
	await process_frame
	await process_frame
	var scheduler: Node = root.get_node("ItemVisualScheduler")
	check(scheduler.clients.size() == 4,"one shared scheduler for only animated grades")
	for index: int in range(7):
		check((views[index].material != null) == (index >= 3),"grade animation threshold "+str(index))
		check(views[index].rotation == 0.0 and views[index].scale == Vector2.ONE,"control transforms untouched")
	views[6].position = Vector2(300,0)
	views[6].get_node("ItemVisual").refresh_visibility()
	check(views[6].material == null,"scrolled/clipped icon has no animated material")
	views[6].position = Vector2.ZERO
	views[6].get_node("ItemVisual").refresh_visibility()
	check(views[6].material != null,"visible icon resumes shared material")
	clip.hide()
	check(views[5].material == null,"hidden ancestor stops effect immediately")
	clip.show()
	for i: int in range(100): UI.apply_item_visual(views[6],first,first.name)
	check(views[6].get_child_count() == 2,"refresh does not accumulate effects or marks")
	check(scheduler.clients.size() == 4,"refresh does not duplicate scheduler registrations")
	UI.apply_item_visual(views[6],first,first.name,{},"quickslot")
	check(views[6].material == null,"small quickslot stays static")
	check(EFFECT.materials.size() <= 32,"materials shared by four grades and eight phases")
	clip.queue_free()
	await process_frame
	check(scheduler.clients.is_empty(),"freeing view releases scheduler clients")
	print("ITEM_VISUAL_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	if failures.is_empty(): print("ITEM_VISUAL_OK")
	quit(0 if failures.is_empty() else 1)
