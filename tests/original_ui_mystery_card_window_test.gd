extends SceneTree
## The original 523 미스터리 카드 합성 window (source_main_mystery_card_window)
## over the existing mystery card item use. Without arguments (no original
## files): only a mystery spec qualifies, and the inventory activation of a
## mystery card tries the window before the 몬스터 도감. Real input:
## -- --pack=<private original main UI pack directory>: MysteryCardScene
## mounts, only the 영웅 challenge uses a card through the existing use(), and
## the last card closes the window.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_mystery_card_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeCatalog extends RefCounted:
	func export_state() -> Dictionary:
		return {"source_items":{"미스터리 변신 카드":{"kind":"mystery"},"물약":{"kind":"none"}}}

class FakeUse extends RefCounted:
	var owner: WeakRef
	var used: int=0
	func spec(record: Dictionary) -> Dictionary:
		if record.get("kind","")=="mystery":return {"kind":"mystery","category":"변신","hero_weight":1000,"label":"자체 확률 · 영웅 10.00% / 희귀 90.00%"}
		return {"error":"no"}
	func use(name: String, _choice: int=0) -> Dictionary:
		used+=1
		var world: Node=owner.get_ref()
		world.inventory[name]=int(world.inventory[name])-1
		if int(world.inventory[name])<=0:world.inventory.erase(name)
		return {"ok":true,"results":[{"kind":"card","name":"데스나이트","grade":"영웅" if used==1 else "희귀"}]}

class FakeRuntime extends RefCounted:
	var catalog:=FakeCatalog.new()
	var item_use:=FakeUse.new()

class FakeWorld extends Node:
	var inventory: Dictionary={"미스터리 변신 카드":2,"물약":3}
	var monsterbook523_runtime:=FakeRuntime.new()
	func _init() -> void:
		monsterbook523_runtime.item_use.owner=weakref(self)

class FakeHud extends Node:
	var messages: Array[String]=[]
	func show_message(text: String) -> void:
		messages.append(text)

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world:=FakeWorld.new()
	root.add_child(world)
	check(WINDOW.mystery_action(world,"미스터리 변신 카드").get("category","")=="변신" and WINDOW.mystery_action(world,"물약").is_empty(),"only a mystery card qualifies")
	check(WINDOW.owned_count(world,"미스터리 변신 카드")==2,"the owned count")
	var world_source: String=FileAccess.get_file_as_string("res://scripts/world.gd")
	check(world_source.contains("hud.open_mystery_card523(str(source_reward.name)): return\n\t\thud.open_monsterbook523()"),"a mystery card activation tries the window before the 몬스터 도감")
	var hud_source: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(hud_source.contains("_open_original_feature(\"mystery_card\",[item_name])"),"the HUD opens the original window")
	world.queue_free()
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	print("ORIGINAL_UI_MYSTERY_CARD_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
	quit(0 if failures.is_empty() else 1)

func _real_pack(pack_dir: String) -> void:
	var receipt: Variant=JSON.parse_string(FileAccess.get_file_as_string(pack_dir.path_join("receipt.json")))
	check(receipt is Dictionary,"pack receipt readable")
	if not receipt is Dictionary:return
	var pack=SOURCE_PACK.new()
	var loaded: Dictionary=pack.open(pack_dir,str(receipt.manifest_sha256))
	check(loaded.get("ok",false),"pack opens: "+str(loaded))
	if not loaded.get("ok",false):return
	var world:=FakeWorld.new()
	var hud:=FakeHud.new()
	world.add_child(hud)
	root.add_child(world)
	var parent:=Node2D.new()
	root.add_child(parent)
	var window=WINDOW.new()
	check(window.configure(pack,hud).get("ok",false),"window configures")
	var opened: Dictionary=window.open(parent,"미스터리 변신 카드")
	check(opened.get("handled",false) and int(opened.get("filled",{}).get("count",0))==2,"MysteryCardScene mounts: "+str(opened).left(300))
	var refused: Dictionary=window._challenge(3)
	check(not refused.get("ok",true) and world.monsterbook523_runtime.item_use.used==0,"희귀 is 선택 불가")
	var won: Dictionary=window._challenge(4)
	check(won.get("handled",false) and won.get("won",false) and hud.messages[-1]=="영웅 합성 성공 · 데스나이트" and window.is_open(),"영웅 uses a card and restages: "+str(hud.messages))
	var lost: Dictionary=window._challenge(4)
	check(lost.get("closed",false) and not lost.get("won",true) and hud.messages[-1]=="영웅 합성 실패 · 희귀 데스나이트 획득" and not window.is_open(),"the last card closes the window")
	await process_frame
	parent.queue_free()
	world.queue_free()
