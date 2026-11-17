extends SceneTree
## Original 523 floor body of every ground item (ItemClass.SpriteID in the
## pinned SP2 bank), with the user's "원본에 없으면 검색 후 근사" policy:
## - client static picture of the item's own sprite (original);
## - declared action 3 of the own sprite, played (original, unchanged);
## - own sprite with actions only: the client static-branch picture (direction 0
##   picture 0) of that action's body file, held still (approximation);
## - no own sprite (0 / absent / source dummy): the most used original floor
##   sprite of the same original category + "[분류-세부]" kind (approximation);
## - otherwise nothing is drawn.
## Measures the whole ItemClass catalog and drops samples of each kind on the
## actual Main. Without the original tables only the name-kind rule is checked.
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
const BANK = preload("res://scripts/resources/reference_sp2_bank.gd")
const SOURCE = preload("res://scripts/resources/current523_source_bank.gd")
const CATEGORY = preload("res://scripts/loot/current523_ground_category_sprite.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("GROUND523_SPRITES_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func rules() -> void:
	check(CATEGORY.name_kind("[BM][악세-귀걸이] 룸티스의 붉은빛 귀걸이")=="악세-귀걸이", "name kind skips plain tags")
	check(CATEGORY.name_kind("[이벤트][2022 국왕의 수렵 사냥터] 상자")=="", "tags without a kind give no kind")
	check(CATEGORY.name_kind("일반 이름")=="", "untagged name has no kind")

func coverage(bank: RefCounted, path: String, sha: String) -> Dictionary:
	var ids: Variant = DEF.column("ItemClass","ID")
	var sprites: Variant = DEF.column("ItemClass","SpriteID")
	var tests: Variant = DEF.column("ItemClass","TestItem")
	var counts: Dictionary = {"items":0,"static":0,"action3":0,"still":0,"category":0,"empty":0}
	var memo: Dictionary = {}
	for index: int in ids.size():
		if tests[index] != false: continue
		counts.items += 1
		var sprite: int = int(sprites[index])
		if not memo.has(sprite): memo[sprite] = bank.ground_kind(path,sha,sprite)
		var kind: String = memo[sprite]
		if kind in ["static","action3","still"]: counts[kind] += 1
		else:
			var picked: Dictionary = CATEGORY.select(DEF.row("ItemClass",int(ids[index])),path+"|"+sha,func(id: int) -> bool: return bank.ground_kind(path,sha,id) == "static")
			counts["category" if picked.get("ok",false) else "empty"] += 1
	counts["before_original"] = counts.static + counts.action3
	counts["after_shown"] = counts.static + counts.action3 + counts.still + counts.category
	return counts

func sample(world: Node, item_class_id: int) -> Dictionary:
	return world._catalog_item_from_source_id("m523:item:%d" % item_class_id)

func find_native(world: Node, bank: RefCounted, path: String, sha: String, wanted: String) -> Dictionary:
	for record: Dictionary in world.catalog_db.get("아이템",[]):
		if record.get("source_m_native_item") != true: continue
		var row: Dictionary = DEF.row("ItemClass",int(record.get("source_item_class_id",0)))
		if row.is_empty() or row.get("TestItem") != false: continue
		var kind: String = bank.ground_kind(path,sha,int(row.get("SpriteID",0)))
		if wanted == "still" and kind == "still": return record
		if wanted == "category" and kind in ["","excluded"]: return record
	return {}

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false)
	world._clear_monsters(); world._clear_drops()
	for frame: int in range(30): await process_frame
	var context: Dictionary = world.player.get("source_visual_context") if world.player.get("source_visual_context") is Dictionary else {}
	var supplied: Dictionary = SOURCE.source_tables(context,["ItemClass"])
	if not check(supplied.get("ok",false), "pinned source bank and tables (%s)" % JSON.stringify(supplied).left(200)):
		world.queue_free(); return
	var path: String = str(supplied.options.manifest_path)
	var sha: String = str(supplied.options.manifest_sha256)
	var bank = BANK.new()
	var started: int = Time.get_ticks_msec()
	var counts: Dictionary = coverage(bank,path,sha)
	counts["measure_ms"] = Time.get_ticks_msec()-started
	evidence["coverage"] = counts
	check(counts.items > 30000 and counts.after_shown > counts.before_original and counts.empty < counts.items/50, "whole-catalog coverage grows and leaves under 2%% empty (%s)" % JSON.stringify(counts))
	var cases: Array = [
		["static", sample(world,137), "ItemClass.SpriteID"],
		["still", find_native(world,bank,path,sha,"still"), "approx_static_branch_of_declared_action_body"],
		["category", sample(world,621) if not sample(world,621).is_empty() else find_native(world,bank,path,sha,"category"), "approx_same_category"],
	]
	var shown: Dictionary = {}
	for entry: Array in cases:
		var record: Dictionary = entry[1]
		if not check(not record.is_empty(), "%s: a native catalog item" % entry[0]): continue
		var view: Button = world.ground_loot.spawn(str(record.name),world.player.global_position,1,"",{"item_record":record})
		if not check(view != null, "%s: item drops" % entry[0]): continue
		var ground_id: String = str(view.get_meta("id"))
		await process_frame
		view = world.ground_loot.views.get(ground_id)
		if not check(is_instance_valid(view), "%s: view stays" % entry[0]): continue
		var status: Dictionary = view.source_ground_status
		var drawn: Array = status.get("drawn_layers",[])
		check(status.get("ok",false) and status.get("status")=="selected_static_picture" and str(status.get("basis","")).begins_with(entry[2]) and not drawn.is_empty() and drawn[0]=="body", "%s: original floor body drawn (%s)" % [entry[0],JSON.stringify(status).left(400)])
		var body: Sprite2D = view.source_ground_view.get_node_or_null("StaticBody") if is_instance_valid(view.source_ground_view) else null
		check(body != null and body.texture != null and body.texture.get_width() > 0, "%s: body texture present" % entry[0])
		check(not view.source_ground_label.visible if is_instance_valid(view.source_ground_label) else true, "%s: no pending label" % entry[0])
		shown[entry[0]] = {"id":int(record.get("source_item_class_id",0)),"name":str(record.name),"sprite":int(status.get("sprite_id",0)),"own":int(status.get("own_sprite_id",0)),"basis":str(status.get("basis",""))}
		world._clear_drops()
	evidence["ground"] = shown
	world.queue_free()
	await process_frame

func run() -> void:
	rules()
	if not DEF.not_installed(): await runtime()
	print("GROUND523_SPRITES_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
