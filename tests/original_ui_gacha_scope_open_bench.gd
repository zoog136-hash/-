extends SceneTree
## Optional private-pack check, not an Android benchmark. Both arms use the
## exact verified release and the same warmed assets; evict only the scoped
## projection (our change affects misses, not warm window cache hits).
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const WINDOW=preload("res://scripts/ui/original_ui/source_main_card_gacha_window.gd")
const BASE=preload("res://tests/original_ui_card_gacha_window_test.gd")
const SCENE=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const PIN="5263d92594e8f44248ad799d6b56ba7816fc5f30bdc4ead0bafaf0bf2dd0b94c"
class OldPack extends PACK:
	func scope_input(member: String)->Dictionary:return {"tree":scene(member),"owned":false}
func _initialize()->void:run.call_deferred()
func run()->void:
	var path: String=OS.get_environment("TWILIGHT_SCOPE_BENCH_UI44")
	if path.is_empty():printerr("needs TWILIGHT_SCOPE_BENCH_UI44");quit(2);return
	var packs: Array=[OldPack.new(),PACK.new()]
	var windows: Array=[];var hud:=BASE.FakeHud.new();root.add_child(hud)
	var parent:=Node2D.new();root.add_child(parent)
	for p in packs:
		if not p.open(path,PIN).get("ok",false) or p._records==null:printerr("expected verified real baked ui44");quit(1);return
		var window:=WINDOW.new()
		if not window.configure(p,hud).get("ok",false):printerr("config failed");quit(1);return
		windows.append(window)
	var views: Array=[{"name":"영웅 카드","grade":"영웅"},{"name":"희귀 카드","grade":"희귀"},{"name":"신화 카드","grade":"신화"}]
	var baseline:=PackedByteArray();var times: Array=[[],[]]
	for i: int in 9:
		for arm: int in ([0,1] if i%2==0 else [1,0]):
			SCENE._scoped_trees.clear()
			var start:=Time.get_ticks_usec()
			var opened: Dictionary=windows[arm].open(parent,views,"변신","크리스터의 영웅 변신 카드 선택 상자")
			var elapsed:=Time.get_ticks_usec()-start
			if i>0:times[arm].append(elapsed)
			var bytes:=var_to_bytes(opened.get("filled",{}))
			if baseline.is_empty():baseline=bytes
			if not opened.get("handled",false) or bytes!=baseline or int(opened.filled.get("shown",0))!=3:printerr("open differs");quit(1);return
			if int(windows[arm].open_all().get("lit",-1))!=2:printerr("wrong grade highlights");quit(1);return
			windows[arm].close()
			await process_frame
	print("ORIGINAL_UI_GACHA_OPEN_AB_RESULT ",JSON.stringify({"paired_opens":times[0].size(),"open_usec_old_new":times,"shown":3,"lit":2}))
	quit(0)
