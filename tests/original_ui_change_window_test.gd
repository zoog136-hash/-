extends SceneTree
## The original 523 polymorph window (source_main_change_window.gd).
## Without arguments (no original files): every TWILIGHT card grade has an
## original Change_Card_A prefab, each card picture node is declared as an
## external original slot, a pack without the members fails closed, owned
## cards are listed highest grade first, option lines split into the row's
## two labels, and the HUD opens the window first for 변신/마법인형 while
## the apply path stays catalog_equip_requested.
## Real input: -- --pack=<private original main UI pack directory>: the window
## mounts from the original CSBs with the catalog's owned cards.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_change_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const CARDS=preload("res://scripts/card_draw_fusion.gd")
var checks: int=0
var failures: Array[String]=[]

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{}}

class FakeHud extends Node:
	signal catalog_equip_requested(category: String, record: Dictionary)
	var catalog_data: Dictionary={}
	var card_collection_state: Dictionary={}
	var character_state: Dictionary={}

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_grades_and_slots()
	_fails_closed()
	_owned_order()
	_option_split()
	_hud_hooks()
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	print("ORIGINAL_UI_CHANGE_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
	quit(0 if failures.is_empty() else 1)

func _grades_and_slots() -> void:
	for grade: String in CARDS.GRADES:
		check(WINDOW.GRADE_MEMBERS.has(grade),"grade has an original card prefab: "+grade)
	var external: Dictionary=SOURCE_PACK.CODE_EXTERNAL_TEXTURE_NODES
	for member: String in WINDOW.CARD_NODES:
		check(int(WINDOW.CARD_NODES[member].sample) in external.get(member,[]),"card picture node declared external: "+member)
		check(member in WINDOW.GRADE_MEMBERS.values(),"prefab is used by a grade: "+member)
	check(WINDOW.SAMPLE in external.get(WINDOW.DETAIL,[]),"detail illustration node declared external")
	# Transcend frames are 508-only; the window mounts no transcend node.
	var source: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_change_window.gd")
	check(not source.contains("Transcend.csb") and not source.contains("14884"),"no transcend node is mounted")

func _fails_closed() -> void:
	var window=WINDOW.new()
	var hud:=FakeHud.new()
	var result: Dictionary=window.configure(FakePack.new(),hud)
	check(not result.get("ok",true) and result.get("code")=="source_change_window_member_missing","missing members fail closed: "+str(result))
	check(not window.is_open(),"nothing is open")
	hud.free()

func _owned_order() -> void:
	var window=WINDOW.new()
	var hud:=FakeHud.new()
	var low: Dictionary={"name":"A","grade":"고급","sourceId":"m508:1:1"}
	var high: Dictionary={"name":"B","grade":"영웅","sourceId":"m508:1:2"}
	var missing: Dictionary={"name":"C","grade":"전설","sourceId":"m508:1:3"}
	hud.catalog_data={"변신":[low,high,missing]}
	hud.card_collection_state={"owned":{"변신":{CARDS.card_id(low):true,CARDS.card_id(high):true}}}
	window._hud=weakref(hud)
	window._category="변신"
	var cards: Array[Dictionary]=window._owned_cards()
	check(cards.size()==2,"only owned cards are listed: "+str(cards.size()))
	check(cards.size()==2 and cards[0].name=="B" and cards[1].name=="A","highest grade first")
	hud.character_state={"equipped":{"변신":high}}
	check(window._equipped_id()==CARDS.card_id(high),"equipped card identity follows the catalog")
	# Applying emits the existing catalog equip signal with the card record.
	var emitted: Array=[]
	hud.catalog_equip_requested.connect(func(category: String, record: Dictionary) -> void: emitted.append([category,record]))
	window._cards=cards
	window._selected=CARDS.card_id(low)
	var applied: Dictionary=window._apply_selected()
	check(applied.get("existing_equip_requested",false) and emitted.size()==1 and emitted[0][0]=="변신" and emitted[0][1].name=="A","apply uses catalog_equip_requested: "+str(applied))
	window._selected=CARDS.card_id(high)
	check(window._apply_selected().get("already_applied",false) and emitted.size()==1,"the applied card is not re-applied")
	hud.free()

func _option_split() -> void:
	check(_split("SP +1")==["SP","+1"],"value suffix goes to the value label")
	check(_split("최대 공격 거리 제한 +1")==["최대 공격 거리 제한","+1"],"multi-word option")
	check(_split("대미지 리덕션")==["대미지 리덕션",""],"no value keeps one label")

static func _split(line: String) -> Array:
	var cut: int=line.rfind(" ")
	if cut>0 and line.substr(cut+1).left(1) in ["+","-"]:return [line.left(cut),line.substr(cut+1)]
	return [line,""]

func _hud_hooks() -> void:
	var renewal: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(renewal.contains("_open_original_change_window(category)") and renewal.contains("try_open_change_window"),"open_catalog opens the original window first")
	check(renewal.contains("close_change_window()"),"closing the workspace closes the window")
	var main_hud: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_hud.gd")
	check(main_hud.contains("func try_open_change_window") and main_hud.contains("ChangeWindow.ROOT"),"main HUD controller owns the window")
	var window: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_change_window.gd")
	check(window.contains("\"catalog_equip_requested\""),"window applies through the existing equip signal")

func _real_pack(pack_dir: String) -> void:
	var receipt: Variant=JSON.parse_string(FileAccess.get_file_as_string(pack_dir.path_join("receipt.json")))
	check(receipt is Dictionary,"pack receipt readable")
	if not receipt is Dictionary:return
	var pack=SOURCE_PACK.new()
	var loaded: Dictionary=pack.open(pack_dir,str(receipt.manifest_sha256))
	check(loaded.get("ok",false),"pack opens: "+str(loaded))
	if not loaded.get("ok",false):return
	var hud:=FakeHud.new()
	root.add_child(hud)
	var configured: Dictionary=WINDOW.new().configure(pack,hud)
	check(configured.get("ok",false),"window configures from the original pack: "+str(configured))
	var window=WINDOW.new()
	window.configure(pack,hud)
	var parent:=Node2D.new()
	root.add_child(parent)
	var opened: Dictionary=window.open(parent,"변신")
	check(opened.get("handled",false) and opened.get("cards")==0,"window mounts with no owned cards: "+str(opened))
	window.close()
	await process_frame
	parent.queue_free()
	hud.queue_free()
