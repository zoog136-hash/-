extends SceneTree
## No original/binary fixtures; read-only owner simulation for exact alias routes.
const Hub = preload("res://scripts/ui/source523_image_assets.gd")
const Resolver = preload("res://scripts/ui/item_visual_resolver.gd")
const Visual = preload("res://scripts/ui/item_visual.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const NAME := "각성서 조각"
const ICON_ID := 84728
const ICON_PATH := "Item/SkillAwakenbook_common_piece_01.png"
const POLICY = preload("res://data/ui/item_icon_identity.json")

class Fixture extends RefCounted:
	var policy: Dictionary
	var state: String = "missing_current_member"
	func source_consumer_row(_table: String, id: int) -> Dictionary:
		return {"ok":true,"row":{"ID":id},"provenance":{}}
	func resolve_consumer(_table: String, id: int, _field: String) -> Dictionary:
		var details: Dictionary = {"source_id":id,"icon_id":ICON_ID}
		if state != "missing_icon_key": details.path = ICON_PATH
		if state == "wrong_file": details.path = "icon/wrong.png"
		return {"status":state,"provenance":details,"ok":false,"texture":null}

const REAL_PACK_PIN := "db51444bcd65d89c8775b67f321db0c1aa6bcb801f5e4375f6d50a0de2d3cb1f"

var checks := 0
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("FAIL "+label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	if OS.get_environment("XDG_DATA_HOME").is_empty(): quit(2); return
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000
	check(QA.enter_game(world),"actual Main loads and enters game in isolated profile")
	check("정상" not in preload("res://scripts/ui/item_icon_resource_status.gd").label({"ok":false}),"missing inventory pack is not labelled healthy")
	var fixture := Fixture.new()
	fixture.policy = POLICY.data.exact[NAME]
	Hub._selection_checked = true
	Hub._selected = true
	Hub._pack = fixture
	var id := int(fixture.policy.item_class_id)
	var record := {}
	var info := Resolver.describe(record,NAME)
	check(info.route == "source523_images" and info.item_class_id == id and info.provenance.icon_id == ICON_ID and info.path.ends_with(str(fixture.policy.icon_file)) and info.reason == "missing_current_member","name-only exact alias keeps canonical id, icon id, path and missing member reason")
	check(record.is_empty() and info.texture == null,"no gameplay identity or substitute art added")
	var view := TextureRect.new()
	world.hud.add_child(view)
	Visual.apply(view,record,NAME,{},"inventory")
	var meta: Dictionary = view.get_meta("item_visual",{})
	check(view.texture == null and meta.get("item_class_id") == id and meta.get("reason") == "missing_current_member" and (view.get_node("SubstituteIconMark") as Label).text == "팩에 없음","existing item control keeps the precise unavailable source reason")
	fixture.state = "missing_icon_key"
	info = Resolver.describe({"name":NAME},NAME)
	check(info.reason == "missing_icon_key" and info.provenance.icon_id == ICON_ID and info.path.is_empty(),"missing Icon row is not rewritten into filename mismatch")
	fixture.state = "wrong_file"
	check(Resolver.describe({"name":NAME},NAME).reason == "item_icon_identity_file_differs","actual wrong filename fails identity validation")
	check(Resolver.describe({"sourceId":"fixture-explicit-other"},NAME).route != "source523_images","name-only fallback cannot replace an explicit different record")
	check(Resolver.describe({},NAME,{},true).route != "source523_images","floor art doesn't borrow the bag IconID")
	Hub._pack = null
	Hub._error = "manifest_sha_mismatch"
	var unverified := Resolver.describe({},NAME)
	check(unverified.reason == "manifest_sha_mismatch" and unverified.declared_icon_file == fixture.policy.icon_file and Hub.missing_label(unverified) == "원본 확인 불가","verification unavailable keeps expected filename and is not reported as a physical missing member")
	Hub.clear_selection()
	var sample_pack := OS.get_environment("TWILIGHT_EXACT_ICON_SAMPLE_PACK")
	if not sample_pack.is_empty():
		var selected: Dictionary = Hub.configure(sample_pack,REAL_PACK_PIN)
		check(selected.get("ok",false),"real release image pack manifest and source tables admitted: "+str(selected.get("status")))
		if selected.get("ok",false):
			Visual.apply(view,{},NAME,{},"inventory")
			meta = view.get_meta("item_visual",{})
			check(view.texture != null and view.texture.get_size() == Vector2(64,64) and meta.get("status") == "original_linked" and meta.get("original_bytes_unchanged") == true and meta.get("provenance",{}).get("icon_id") == ICON_ID,"actual Main item control loaded the exact release sample texture")
		Hub.clear_selection()
	world.queue_free()
	await process_frame
	print("EXACT_ITEM_ICON_DIAGNOSTICS ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
