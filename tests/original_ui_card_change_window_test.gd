extends SceneTree
## The original 523 카드 다시 뽑기 window (source_main_card_change_window.gd)
## over the existing card swap feature (world.card523_swap_*). Without
## arguments (no original files): only owned 영웅+ cards are listed, waiting
## results first and shown as their result, 다시 뽑기 runs the quote token
## (the result waits), the 6th swap takes a picked candidate first, 카드 확정
## runs the confirm token, and the menu opens the window. Real input:
## -- --pack=<private original main UI pack directory>: CardChange_All mounts
## with the retry, pick and confirm popups.
const WINDOW=preload("res://scripts/ui/original_ui/source_main_card_change_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeWorld extends Node:
	var calls: Array=[]
	var waiting: Array=[{"category":"변신","identity":"source:202","name":"전설 B","result":{"identity":"source:203","name":"전설 C","grade":"전설"},"swap_count":1,"picked":false}]
	var picks: int=0
	func card523_swap_pending() -> Array:
		return waiting.duplicate(true)
	func card523_swap_quote(category: String, identity: String) -> Dictionary:
		calls.append(["quote",category,identity])
		var pending: bool=identity=="source:202"
		return {"ok":true,"token":"t%d" % calls.size(),"remaining":4,"cost":{"amount":2900},"diamonds":10000,"pick_count":picks,
			"pick_candidates":[{"identity":"source:301","name":"영웅 X","grade":"영웅"},{"identity":"source:302","name":"영웅 Y","grade":"영웅"}] if picks>0 else [],
			"can_confirm":pending,"confirm_reason":"" if pending else "확정할 결과가 없습니다","confirm_token":"c%d" % calls.size() if pending else ""}
	func card523_swap_execute(token: String, pick: String="") -> Dictionary:
		calls.append(["execute",token,pick])
		return {"ok":true,"pending":{"result":{"identity":"source:101","name":"영웅 Z","grade":"영웅"}}}
	func card523_swap_confirm(token: String) -> Dictionary:
		calls.append(["confirm",token])
		return {"ok":true,"category":"변신","result":{"identity":"source:203","name":"전설 C","grade":"전설"}}

class FakePack extends RefCounted:
	var manifest: Dictionary={"scenes":{"UI/CardChange/CardChange_Gacha.csb":{},"UI/CardChange/CardChange_Result.csb":{}}}

class FakeHud extends Node:
	var messages: Array[String]=[]
	var catalog_data: Dictionary={"변신":[{"sourceId":"101","name":"영웅 A","grade":"영웅"},{"sourceId":"202","name":"전설 B","grade":"전설"},{"sourceId":"203","name":"전설 C","grade":"전설"},{"sourceId":"9","name":"희귀 Q","grade":"희귀"}],"마법인형":[],"성물":[]}
	var card_collection_state: Dictionary={"owned":{"변신":{"source:101":true,"source:202":true,"source:9":true}}}
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
	var world: FakeWorld=host.world
	var window=WINDOW.new()
	window._hud=weakref(host.hud)
	var all: Array=window.cards()
	check(all.size()==2 and all[0].identity=="source:202" and all[1].identity=="source:101","owned 영웅+ cards, waiting results first: "+str(all.map(func(e: Dictionary) -> String:return e.identity)))
	check(window.shown(all[0]).name=="전설 C" and window.shown(all[1]).name=="영웅 A","a waiting slot shows its result")
	window._retry(1)
	check(window.popup=="retry" and window.target.identity=="source:101","다시 뽑기 opens the retry popup with the quote")
	window._swap()
	check(world.calls[-1]==["execute","t%d" % (world.calls.size()-1),""] and window.popup=="" and host.hud.messages[-1].contains("카드 확정으로"),"다시 뽑기 executes the quote token; the result waits: "+str(world.calls))
	world.picks=5
	window._retry(1)
	window._swap()
	check(window.popup=="pick","the 6th swap first asks for a candidate")
	check(not window._swap().get("ok",true),"no candidate: nothing runs")
	window._choose("source:302")
	window._swap()
	check(world.calls[-1][0]=="execute" and world.calls[-1][2]=="source:302","the picked candidate runs with the token")
	check(not window._confirm(1).get("ok",true),"a card without a waiting result has nothing to confirm")
	window._confirm(0)
	check(window.popup=="confirm","카드 확정 opens the confirm popup")
	window._confirm_result()
	check(world.calls[-1][0]=="confirm" and str(world.calls[-1][1]).begins_with("c") and window.popup=="","카드 확정 runs the confirm token")
	# The client reveal: CardChange_Gacha after 다시 뽑기, CardChange_Result
	# after 카드 확정 (only when the UI pack has them; above, without them,
	# the list stays).
	world.picks=0
	window._pack=FakePack.new()
	window._retry(1)
	window._swap()
	check(window.popup=="gacha" and window.reveal.after.name=="영웅 Z" and window.reveal.before.name=="영웅 A" and window.reveal.category=="변신","다시 뽑기 shows the flip of the card before and the result: "+str(window.reveal))
	window._close_popup()
	check(window.popup=="","a tap returns to the list")
	window._confirm(0)
	window._confirm_result()
	check(window.popup=="result" and window.reveal.after.name=="전설 C" and window.reveal.after.grade=="전설","카드 확정 shows the confirmed card: "+str(window.reveal))
	window._close_popup()
	window._pack=null
	var offer: Dictionary={"candidate_count":3,"candidates":[{"name":"가"},{"name":"나"},{"name":"다"}]}
	check(WINDOW.probability_text(offer)=="같은 등급 카드 3종 중 1장이 나옵니다 (각 33.3333%, 지금 카드 제외)","뽑기 확률: each candidate 1 / count: "+WINDOW.probability_text(offer))
	check(WINDOW.list_text(offer)=="다시 뽑기 후보 3종: 가 · 나 · 다" and WINDOW.probability_text({}).contains("없습니다"),"목록 보기 lists the quote's candidates")
	var renewal: String=FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(renewal.contains("[\"card_swap523\",\"카드 다시 뽑기\"]") and renewal.contains("_open_original_feature(\"card_change\")"),"the menu opens the original window")
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	host.world.queue_free()
	print("ORIGINAL_UI_CARD_CHANGE_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
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
	var window=WINDOW.new()
	check(window.configure(pack,host.hud).get("ok",false),"window configures")
	var opened: Dictionary=window.open(parent)
	check(opened.get("handled",false) and int(opened.filled.cards)==2,"CardChange_All mounts the cards: "+str(opened).left(300))
	var retry: Dictionary=window._retry(1)
	check(retry.get("handled",false) and retry.filled.popup=="retry","CardChange_Popup_Retry mounts: "+str(retry).left(300))
	host.world.picks=5
	window._retry(1)
	var pick: Dictionary=window._swap()
	check(pick.get("handled",false) and int(pick.filled.popup_fill.candidates)==2,"CardChange_Popup_RetrySpecial_Select mounts the candidates: "+str(pick).left(300))
	check(window._choose("source:301").get("handled",false),"a picked candidate mounts")
	var confirm: Dictionary=window._confirm(0)
	check(confirm.get("handled",false) and confirm.filled.popup=="confirm","CardChange_Popup_Confirm mounts: "+str(confirm).left(300))
	if pack.manifest.get("scenes",{}).has(WINDOW.GACHA):
		host.world.picks=0
		window._retry(1)
		var flipped: Dictionary=window._swap()
		check(flipped.get("handled",false) and flipped.filled.popup_fill.popup=="gacha" and flipped.filled.popup_fill.clip=="CardSet_One","CardChange_Gacha mounts and flips: "+str(flipped).left(300))
		window._close_popup()
		window._confirm(0)
		var shown_result: Dictionary=window._confirm_result()
		check(shown_result.get("handled",false) and shown_result.filled.popup_fill.popup=="result" and shown_result.filled.popup_fill.lit,"CardChange_Result mounts and a 전설 card lights up: "+str(shown_result).left(300))
	else:
		print("original_ui_card_change_window_test: pack without CardChange_Gacha (before ui43); reveal not mounted")
	window.close()
	await process_frame
	parent.queue_free()
	host.world.queue_free()
