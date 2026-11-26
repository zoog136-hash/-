extends SceneTree
## The real Main bag with one original source award in its compact prior-save shape.
## Requires the actual source archive and a privately pinned release sample.
const QA = preload("res://tests/qa_class_selection.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
const CHOICE = preload("res://scripts/ui/patch523_reward_choice.gd")
const PROJECTION = preload("res://scripts/ui/original_ui/source_main_inventory_images.gd")
const PIN := "db51444bcd65d89c8775b67f321db0c1aa6bcb801f5e4375f6d50a0de2d3cb1f"
const NAME := "[원본 보상] [변신 카드] 매직 솔져"
const UID := "73000773"
const ID := 139781
const REWARD_ID := 93201
var count := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	count += 1
	if not ok: failures.append(label); printerr("FAIL "+label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var zip := OS.get_environment("TWILIGHT_QUEST_CARD_ICON_DEFINITIONS")
	var pack := OS.get_environment("TWILIGHT_QUEST_CARD_ICON_IMAGES")
	if OS.get_environment("XDG_DATA_HOME").is_empty() or zip.is_empty() or pack.is_empty(): quit(2); return
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world),"actual Main entered in isolated profile")
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",zip)
	SOURCE.reset()
	var opened: Dictionary = IMAGES.configure(pack,PIN)
	check(opened.get("ok",false),"source image loader admitted exact independent pack pin")
	if not opened.get("ok",false): quit(1); return
	var source_row: Dictionary = SOURCE.row("ItemClass",ID)
	var source_reward: Dictionary = SOURCE.row("Reward",REWARD_ID)
	check(not source_row.is_empty() and source_row.IconID == 1841 and NAME == "[원본 보상] " + str(source_row.Name),"real main reward exact ItemClass and icon declaration")
	var bag: Control = world.hud.lineage_inventory_ui
	var prior_shape: Dictionary = {"name":NAME,"grade":"미확인","slot":"quest_reward","type":"원본 보상 보관","source_pending_use":true}
	var receipt: Dictionary = {"schema":1,"quest_id":"m523:quest:77381","reward_id":REWARD_ID,"item_class_id":ID,"bless_code_id":source_reward.ItemBlessCodeID,"source_sha256":SOURCE.SOURCE_SHA,"quantity":1}
	var physical: Dictionary = {"name":NAME,"record":prior_shape,"source_reward_quantity":1,"level":0,"quest_reward_receipt":receipt}
	var instances: Dictionary = {UID:physical}
	bag.inventory = {NAME:1}
	bag.set_character_state({"item_instances":instances})
	var exact_key := NAME+"@@@"+UID
	var before := JSON.stringify(instances)
	var save_before: String = FileAccess.get_sha256(world.save_path())
	var fallback: Dictionary = bag._find_item_record(exact_key)
	var shown: Dictionary = bag._item_visual_record(exact_key,fallback)
	check(shown.get("source_original_item") == source_row and not shown.has("source_m_native_item"),"the old selected physical receipt recovers only the canonical image DTO")
	check(fallback == prior_shape and JSON.stringify(instances) == before,"the actual selection never rewrites gameplay or serialized ownership")
	bag._select_item(exact_key)
	var details: Dictionary = bag.detail_icon.get_meta("item_visual",{})
	check(bag.detail_icon.texture != null and details.get("item_class_id") == ID and details.get("provenance",{}).get("path") == "icon/Item/Card_Polymorph_Common.png" and details.get("original_bytes_unchanged",false),"actual inventory detail mounted the exact original reward PNG")
	var native: Dictionary = PROJECTION.resolve_owned(world.hud,{"reference":exact_key,"record":fallback,"name":NAME})
	check(native.get("ok",false) and native.get("texture") == bag.detail_icon.texture,"native inventory presenter reaches the same original without replacing ownership")
	check(FileAccess.get_sha256(world.save_path()) == save_before,"read-only image draw preserves exact save bytes")
	var current: Dictionary = prior_shape.duplicate(true)
	current.merge({"source":"lineagem_patch523","source_snapshot":"patch523","sourceId":"m523:item:139781","source_item_class_id":ID,"source_original_item":source_row,"quest_item":true},true)
	physical.record = current
	bag._refresh_detail(exact_key)
	check(bag.detail_icon.texture != null and bag._item_visual_record(exact_key,current) == current,"ordinary modern full source row remains the first correct identity")
	physical.record = prior_shape
	receipt.reward_id = 93202
	check(bag._item_visual_record(exact_key,fallback) == fallback,"wrong quest-reward link cannot produce an image DTO")
	receipt.reward_id = REWARD_ID
	receipt.source_sha256 = "a".repeat(64)
	check(bag._item_visual_record(exact_key,fallback) == fallback,"unverified archive provenance cannot produce an image DTO")
	check(bag._item_visual_record(NAME+"@@@stale",fallback) == fallback,"stale physical reference cannot select another item's image")
	var box: Dictionary = SOURCE.row("LuckyBagEntityView",159143)
	check(box.get("LuckyBagClassID") == 23233 and box.get("ItemClassID") == 1025,"original reward box declares its exact test-only option")
	var selectable: Dictionary = CHOICE.describe_choice_icon(1025,"다크 나이트")
	check(selectable.get("texture") is Texture2D and selectable.get("status") == "choice_preview_original" and selectable.get("provenance",{}).get("icon_id") == 1845,"explicit original selector option shows its own preview instead of a blank slot")
	check(IMAGES.describe_item_class(1025).get("reason") == "source_test_item_excluded","preview does not admit the test ItemClass to ordinary item rendering")
	check(FileAccess.get_sha256(world.save_path()) == save_before,"selection preview performs no save or grant")
	IMAGES.clear_selection()
	world.queue_free()
	await process_frame
	print("QUEST_REWARD_CARD_ICON_RESULT ",JSON.stringify({"checks":count,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
