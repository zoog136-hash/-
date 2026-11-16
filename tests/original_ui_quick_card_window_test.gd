extends SceneTree
## The original 523 빠른 변신 / 빠른 소환 windows (source_main_quick_change_window,
## source_main_quick_summon_window; TWILIGHT 근사 favourites,
## source_main_quick_card_base). Without arguments (no original files): only
## owned cards register, nine at most, the list is stored in
## ui_preferences["quick_card523"] with a save request, a tap equips through
## catalog_equip_requested, 해제 sends an empty card, 모두 초기화 clears, and the
## menu opens both. Real input: -- --pack=<private original main UI pack
## directory>: ChangeQuick_All mounts its cells, 관리 list and 등급 리스트, and
## SummonQuick_All its lists.
const CHANGE=preload("res://scripts/ui/original_ui/source_main_quick_change_window.gd")
const SUMMON=preload("res://scripts/ui/original_ui/source_main_quick_summon_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeWorld extends Node:
	var ui_preferences: Dictionary={"item_locks":{}}
	var saves: int=0
	func _request_deferred_save() -> void:
		saves+=1

class FakeHud extends Node:
	signal catalog_equip_requested(category: String, record: Dictionary)
	var messages: Array[String]=[]
	var equips: Array=[]
	var catalog_data: Dictionary={"변신":[],"마법인형":[{"sourceId":"501","name":"인형 A","grade":"희귀"}],"성물":[]}
	var card_collection_state: Dictionary={"owned":{"변신":{},"마법인형":{"source:501":true}}}
	var character_state: Dictionary={"equipped":{}}
	func _init() -> void:
		for i: int in range(12):
			catalog_data["변신"].append({"sourceId":str(100+i),"name":"변신 %d" % i,"grade":"영웅" if i%2==0 else "일반"})
			card_collection_state.owned["변신"]["source:%d" % (100+i)]=i<11
		catalog_equip_requested.connect(func(category: String, record: Dictionary) -> void:equips.append([category,str(record.get("name",""))]))
	func show_message(text: String) -> void:
		messages.append(text)

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _host() -> Dictionary:
	var world:=FakeWorld.new()
	var hud:=FakeHud.new()
	world.add_child(hud)
	root.add_child(world)
	return {"world":world,"hud":hud}

func _run() -> void:
	var host: Dictionary=_host()
	var window=CHANGE.new()
	window._hud=weakref(host.hud)
	check(window.owned_cards().size()==11 and str(window.owned_cards()[0].grade)=="영웅","owned 변신 cards, highest grade first")
	check(window.owned_cards("일반").size()==5,"the grade filter")
	check(not window.toggle("source:111").get("ok",true),"a card not owned does not register")
	for i: int in range(10):window.toggle("source:%d" % (100+i))
	check(window.registered().size()==9 and host.hud.messages[-1].contains("9칸"),"nine at most: "+str(window.registered()))
	check(host.world.ui_preferences.quick_card523["변신"].size()==9 and host.world.saves==9,"the list is stored with a save request")
	window.toggle("source:100")
	check(not "source:100" in window.registered(),"a registered card taps out")
	window.equip("source:101")
	check(host.hud.equips[-1]==["변신","변신 1"],"a tap equips through the existing catalog equip")
	host.hud.character_state.equipped["변신"]={"sourceId":"101"}
	window.equip("source:101")
	check(host.hud.equips.size()==1,"the worn card is not sent again")
	window._unequip()
	check(host.hud.equips[-1]==["변신",""],"해제 sends no card")
	window._clear()
	check(window.registered().is_empty(),"모두 초기화 clears the list")
	var summon=SUMMON.new()
	summon._hud=weakref(host.hud)
	summon.toggle("source:501")
	check(summon.registered()==["source:501"] and host.world.ui_preferences.quick_card523["마법인형"]==["source:501"],"빠른 소환 keeps its own list")
	summon.equip("source:501")
	check(host.hud.equips[-1]==["마법인형","인형 A"],"a doll tap summons")
	var renewal: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(renewal.contains("[\"quick_change523\",\"빠른 변신\"]") and renewal.contains("[\"quick_summon523\",\"빠른 소환\"]") and renewal.contains("_open_original_feature(key)"),"the menu opens both windows")
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	host.world.queue_free()
	print("ORIGINAL_UI_QUICK_CARD_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
	quit(0 if failures.is_empty() else 1)

func _real_pack(pack_dir: String) -> void:
	var receipt: Variant=JSON.parse_string(FileAccess.get_file_as_string(pack_dir.path_join("receipt.json")))
	check(receipt is Dictionary,"pack receipt readable")
	if not receipt is Dictionary:return
	var pack=SOURCE_PACK.new()
	var loaded: Dictionary=pack.open(pack_dir,str(receipt.manifest_sha256))
	check(loaded.get("ok",false),"pack opens: "+str(loaded))
	if not loaded.get("ok",false):return
	var host: Dictionary=_host()
	var parent:=Node2D.new()
	root.add_child(parent)
	var window=CHANGE.new()
	check(window.configure(pack,host.hud).get("ok",false),"빠른 변신 configures")
	window.toggle("source:100")
	window.toggle("source:101")
	var opened: Dictionary=window.open(parent)
	check(opened.get("handled",false) and int(opened.filled.registered)==2,"ChangeQuick_All mounts the registered cells: "+str(opened).left(300))
	var edit: Dictionary=window._set_mode("edit")
	check(edit.get("handled",false) and int(edit.filled.shown)==9 and int(edit.filled.pages)==2,"관리 mounts nine owned cards a page: "+str(edit).left(300))
	check(window._page(1).filled.shown==2,"◀ ▶ pages")
	check(window._set_mode("grade").get("handled",false),"등급 리스트 mounts")
	check(window._set_grade("일반").filled.shown==5,"a grade button filters the 관리 list")
	window.close()
	var summon=SUMMON.new()
	check(summon.configure(pack,host.hud).get("ok",false),"빠른 소환 configures")
	summon.toggle("source:501")
	var quick: Dictionary=summon.open(parent)
	check(quick.get("handled",false) and int(quick.filled.shown)==1,"SummonQuick_All mounts the registered dolls: "+str(quick).left(300))
	check(summon._set_tab("list").filled.shown==1,"소환 리스트 mounts the owned dolls")
	summon.close()
	await process_frame
	parent.queue_free()
	host.world.queue_free()
