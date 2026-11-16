extends SceneTree
## The 던전 window's extra parts (source_main_dungeon_window) over the
## existing dungeon services: 오림의 흔적 버프 구매 (buy_buff) and the dungeon
## data API (world.dungeon_play: 시련의 탑 버프 / 스피드 모드 / 랭킹 / 상점,
## 오림 업적 / 챕터 스토리). Without arguments (no original files): the original
## OrimsTrailBuff rows, buying, speed mode, the shop route and achievements
## through the services. Real input: -- --pack=<private original main UI
## pack directory>: the 오림 tab mounts the buff rows, the badge and the
## story; the 시련의 탑 tab mounts its buff rows and the ranking popup rows.
const DUNGEON=preload("res://scripts/ui/original_ui/source_main_dungeon_window.gd")
const SOURCE_PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
var checks: int=0
var failures: Array[String]=[]

class FakeRules extends RefCounted:
	var data: Dictionary={"declarations":{"OrimsTrailBuff":[{"ID":2,"BuffClassID":71672,"CurrencyID":1,"CurrencyCost":200000},{"ID":12,"BuffClassID":71682,"CurrencyID":1,"CurrencyCost":300000},
		{"ID":22,"BuffClassID":71692,"CurrencyID":1,"CurrencyCost":500000},{"ID":32,"BuffClassID":72362,"CurrencyID":4,"CurrencyCost":20}]}}

class FakeService extends RefCounted:
	var rules:=FakeRules.new()
	var state: Dictionary={"active":{"kind":"orim","status":"active","stage_id":1,"buffs":{"71672":true}}}
	var save_blocked: bool=false
	var bought: Array=[]
	var speed: bool=false
	var claimed: Dictionary={}
	var tower_bought: Array=[]
	func check_idle() -> String:
		return "실행 중"
	func buy_buff(buff_id: int) -> Dictionary:
		bought.append(buff_id)
		if state.active.buffs.has(str(buff_id)):return {"ok":false,"reason":"이미 구매한 강화"}
		state.active.buffs[str(buff_id)]=true
		return {"ok":true}
	func tower_buff_offers(_floor: int=0) -> Array:
		return [{"buff_id":1,"name":"공격","buff_class_id":71672,"cost":{"currency":"시련의 탑 주화","currency_id":152,"amount":30},"active":tower_bought.has(1),"remaining_sec":0,"effects":{}},
			{"buff_id":2,"name":"명중","buff_class_id":71682,"cost":{"currency":"시련의 탑 주화","currency_id":152,"amount":50},"active":false,"remaining_sec":0,"effects":{}}]
	func tower_buy_buff(buff_id: int) -> Dictionary:
		tower_bought.append(buff_id)
		return {"ok":true,"reason":"","message":"공격 적용"}
	func tower_speed_mode() -> Dictionary:
		return {"available":true,"on":speed,"multiplier":3.0 if speed else 1.0,"cost":{},"reason":"","basis":"근사"}
	func tower_set_speed_mode(on: bool) -> Dictionary:
		speed=on
		return {"ok":true,"reason":""}
	func tower_ranking(floor_index: int, _hard: bool=false) -> Dictionary:
		return {"rows":[{"rank":1,"name":"나","class":"기사","clear_sec":75,"at":1},{"rank":2,"name":"나","class":"기사","clear_sec":130,"at":2}] if floor_index==3 else [],"mine":{}}
	func dungeon_shop(kind: String) -> Dictionary:
		return {"open_method":"open_shop","args":[],"market_display_category":122} if kind=="tower" else {}
	func orim_achievements(chapter: int) -> Array:
		var id: String="orim:%d:normal" % chapter
		return [{"id":id,"name":"1장 일반 클리어","progress":1,"goal":1,"reward":[],"claimed":claimed.has(id),"can_claim":not claimed.has(id)}]
	func orim_claim_achievement(id: String) -> Dictionary:
		if claimed.has(id):return {"ok":false,"reason":"이미 받은 업적입니다","message":""}
		claimed[id]=true
		return {"ok":true,"reason":"","message":"업적 완료 표시"}
	func orim_chapter_story(_chapter: int) -> Dictionary:
		return {"title":"하딘의 야망","text":"오림의 흔적을 찾아 떠나는 여정","unlocked":true}

class FakeRuns extends RefCounted:
	var state: Dictionary={"active":{},"clears":{},"cycles":{}}
	func check(_stage_id: int, _immediate: bool=false) -> Dictionary:
		return {"ok":true,"host":{}}

class FakeLocalTower extends RefCounted:
	func settings(_state: Dictionary) -> Dictionary:
		return {"enabled":false}

class FakeWorld extends Node:
	var dungeon_play:=FakeService.new()
	var source_dungeon_runs:=FakeRuns.new()
	var LOCAL_TOWER:=FakeLocalTower.new()
	var pending_dungeon_events: Array=[]
	var character_display_name: String="나"
	var level: int=60
	func source_dungeon_tower_cost(_hard: bool) -> Dictionary:
		return {"BaseTryCurrencyCost":1000}

class FakeHud extends Node:
	var messages: Array[String]=[]
	var shops: int=0
	func show_message(text: String) -> void:
		messages.append(text)
	func open_shop() -> void:
		shops+=1

class FakeFamily extends RefCounted:
	var selected: int=-1
	func select(value: int) -> void:
		selected=value

class FakeList extends RefCounted:
	func select(_row: int) -> void:
		pass

class FakeView extends Node:
	var family:=FakeFamily.new()
	var rows: Array=[{"stage":{"ID":1,"StageIndex":3,"TimeLimit":600,"MinLevel":1},"goals":[],"normal_rewards":[]}]
	var selected: int=0
	var listing:=FakeList.new()
	var orim_hero:=OptionButton.new()
	var notice:=Label.new()
	func _refresh() -> void:
		pass

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
	var buffs: Array=DUNGEON.orim_buffs(host.world)
	check(buffs.size()==4 and buffs[3]=={"buff_id":72362,"currency":4,"cost":20},"the original OrimsTrailBuff rows: "+str(buffs))
	check(not DUNGEON.REQUIRED.has(DUNGEON.BUFF_ROW) and not DUNGEON.REQUIRED.has(DUNGEON.RANK_ROW),"the buff and rank rows are optional (an older pack keeps them out)")
	var window=DUNGEON.new()
	window._hud=weakref(host.hud)
	window._buy_orim_buff(71682)
	check(host.world.dungeon_play.bought==[71682] and host.hud.messages[-1]=="버프를 구매했습니다 · 아데나 300,000","a tap buys through the existing buy_buff: "+str(host.hud.messages))
	window._buy_orim_buff(71672)
	check(host.hud.messages[-1]=="이미 구매한 강화 (아데나 200,000)","a refusal names the service's reason and the cost")
	window._buy_tower_buff(1)
	check(host.world.dungeon_play.tower_bought==[1] and host.hud.messages[-1]=="공격 적용 · 시련의 탑 주화 30","a tower buff buys through tower_buy_buff: "+str(host.hud.messages[-1]))
	window._speed_mode()
	check(host.world.dungeon_play.speed and host.hud.messages[-1].begins_with("스피드 모드 켜짐"),"스피드 모드 toggles through tower_set_speed_mode")
	window._shop("tower")
	check(host.hud.shops==1,"the tower shop opens the HUD's shop route")
	window._shop("orim")
	check(host.hud.shops==1 and host.hud.messages[-1]=="이 던전의 상점이 없습니다","오림 has no shop")
	window._achievement()
	check(host.world.dungeon_play.claimed.has("orim:0:normal") and host.hud.messages[-1]=="1장 일반 클리어 · 업적 완료 표시","a claimable achievement is claimed: "+str(host.hud.messages[-1]))
	window._achievement()
	check(host.hud.messages[-1]=="1장 일반 클리어 완료","then the progress is named")
	var pack_dir: String=""
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--pack="):pack_dir=value.trim_prefix("--pack=")
	if not pack_dir.is_empty():await _real_pack(pack_dir)
	host.world.queue_free()
	print("ORIGINAL_UI_DUNGEON_EXTRAS_WINDOW_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not pack_dir.is_empty()}))
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
	var dungeon=DUNGEON.new()
	check(dungeon.configure(pack,host.hud).get("ok",false),"the dungeon window configures")
	var view:=FakeView.new()
	host.world.add_child(view)
	dungeon._parent=weakref(parent)
	dungeon._view=weakref(view)
	dungeon.rows=view.rows
	var orim: Dictionary=dungeon._set_tab("orim")
	check(orim.get("handled",false) and orim.get("tab","")=="orim" and int(orim.get("buffs",0))==4,"the 오림 tab mounts one SlotBtn per buff: "+str(orim).left(300))
	var bought: Dictionary=dungeon._buy_orim_buff(71692)
	check(bought.get("handled",false) and bought.get("buy",{}).get("ok",false),"buying restages the tab")
	var story: Dictionary=dungeon._toggle_story()
	check(story.get("handled",false) and story.get("story_open",false),"the chapter story opens: "+str(story).left(200))
	dungeon._set_tab("tower")
	dungeon.trial_list=false
	var tower: Dictionary=dungeon.refresh()
	check(tower.get("handled",false) and int(tower.get("buffs",0))==2,"the 시련의 탑 tab mounts its buff rows: "+str(tower).left(300))
	var ranking: Dictionary=dungeon._toggle_ranking()
	check(ranking.get("handled",false) and ranking.get("ranking_open",false) and int(ranking.get("ranks",0))==2,"the ranking popup lists this floor's records: "+str(ranking).left(300))
	var closed: Dictionary=dungeon._toggle_ranking()
	check(closed.get("handled",false) and not closed.get("ranking_open",true),"the popup closes")
	dungeon.close()
	await process_frame
	parent.queue_free()
	host.world.queue_free()
