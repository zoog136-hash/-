extends SceneTree
## Real HUD reel callback plus original source window. Run without a pack for
## the authored-size and alternate-owner fixture used by CI.
const GACHA=preload("res://scripts/ui/original_ui/source_main_card_gacha_window.gd")
const PACK=preload("res://scripts/ui/original_ui/source_pack.gd")
const SCENE=preload("res://scripts/ui/original_ui/sprite_scene.gd")
const BASE=preload("res://tests/original_ui_card_gacha_window_test.gd")
const REEL=preload("res://scripts/ui/card_reveal_stage.gd")
const PIN="5263d92594e8f44248ad799d6b56ba7816fc5f30bdc4ead0bafaf0bf2dd0b94c"
class CountingPack extends PACK:
	var count: int=0
	func scene(member: String)->Dictionary:
		count+=1
		return super.scene(member)

class Prior extends GACHA:
	func _card_effect_extent(_located: Dictionary,out: Dictionary,panel: String)->Vector2:
		return _node_size(out,panel)

class Spy extends GACHA:
	var fallbacks: int=0
	func _node_size(_out: Dictionary,_suffix: String)->Vector2:
		fallbacks+=1;return Vector2(17,27)

var checks: int=0
var failures: Array[String]=[]
var samples: Dictionary={}
func check(value: bool,what: String)->void:
	checks+=1
	if not value:failures.append(what);printerr("CARD_EFFECT_EXTENT_FAIL ",what)
func _initialize()->void:run.call_deferred()

func run()->void:
	var w:=Spy.new();var scene:=SCENE.new()
	scene.source_member="UI/Test"
	scene.source_tree={"nodeTree":{"_offset":1,"classname":"Node","children":[{"_offset":31,"classname":"Panel","options":{"widgetOptions":{"size":[90,120]},"backGroundScale9Enabled":true,"scale9Size":[120,160]}}]}}
	var at: Dictionary={"player":scene,"member":"UI/Test","key":"/Cell/Panel","offset":31}
	var out: Dictionary={"/Cell/Panel":{"kind":"Panel"}}
	check(w._card_effect_extent(at,out,"Panel")==Vector2(90,120) and w.fallbacks==0,"read authored panel not scaled display extent")
	at.offset=77
	check(w._card_effect_extent(at,out,"Panel")==Vector2(17,27) and w.fallbacks==1,"missing retained node falls back")
	at.offset=31;at.member="UI/Other"
	check(w._card_effect_extent(at,out,"Panel")==Vector2(17,27) and w.fallbacks==2,"other owner cannot supply a size")
	at.member=scene.source_member;out["/Cell/Panel"].kind="ProjectNode"
	check(w._card_effect_extent(at,out,"Panel")==Vector2(17,27) and w.fallbacks==3,"project root override is not the child's own authored panel")
	scene.free()
	var path:=OS.get_environment("TWILIGHT_REEL_BENCH_UI44")
	if not path.is_empty():await _real(path)
	print("ORIGINAL_UI_CARD_EFFECT_EXTENT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"samples":samples}))
	quit(0 if failures.is_empty() else 1)

# Linux-only process-local scheduler CPU clock; no runtime instrumentation.
# The wall clock below also includes disk waits / descheduling, unlike this.
func _thread_ns()->int:
	if OS.get_name()!="Linux":return -1
	var file:=FileAccess.open("/proc/thread-self/schedstat",FileAccess.READ)
	if file==null:return -1
	var first:=file.get_line().get_slice(" ",0)
	return int(first) if first.is_valid_int() else -1

func _real(path: String)->void:
	var pack:=CountingPack.new()
	var loaded: Dictionary=pack.open(path,PIN)
	check(loaded.get("ok",false) and pack._records!=null,"exact privately installed UI44")
	if not loaded.get("ok",false):return
	var hud:=BASE.FakeHud.new();root.add_child(hud)
	var host:=Node2D.new();root.add_child(host)
	var windows: Array=[Prior.new(),GACHA.new()]
	for window: Variant in windows:check(window.configure(pack,hud).get("ok",false),"window configured")
	# No invented artwork: missing card portraits and empty reel candidate
	# pool use the real production fallback. Geometry uses the exact UI44.
	var exact: Dictionary={}
	var image_root:=OS.get_environment("TWILIGHT_REEL_BENCH_IMAGES")
	if not image_root.is_empty():
		var images=preload("res://scripts/ui/source523_image_assets.gd")
		check(images.configure(image_root,"db51444bcd65d89c8775b67f321db0c1aa6bcb801f5e4375f6d50a0de2d3cb1f").get("ok",false),"pinned installed image pack")
		var rows: Array=preload("res://scripts/lineagem_base508.gd").cards().get("catalog",{}).get("변신",[])
		for r: Dictionary in rows:
			if int(r.get("source_card_id",0))==12231:exact=r;break
		var portrait: Dictionary=preload("res://scripts/ui/source_card_presentation.gd").detail(exact,true,false)
		check(portrait.get("status")=="original" and portrait.get("texture") is Texture2D and int(portrait.get("source_asset_id",0))==191631,"BuffCard#12231 resolves original MagicSoldier portrait")
		if not failures.is_empty():return
	var candidates: Array=[] if exact.is_empty() else [exact]
	var effect: Callable=REEL.play_result_cell.bind("변신",false,false,candidates,{})
	for n: int in [1,10]:
		var cards: Array=[]
		for i: int in n:cards.append({"name":"카드 %d"%i,"grade":["영웅","희귀","신화"][i%3]} if exact.is_empty() else exact)
		var lit: int=n-floori(float(n+1)/3) if exact.is_empty() else 0
		var cpu: Array=[[],[]];var ready: Array=[[],[]];var interval: Array=[[],[]];var opening: Array=[[],[]];var reads: Array=[[],[]]
		var expected: Array=[]
		for i: int in 21:
			for arm: int in ([0,1] if i%2==0 else [1,0]):
				var w: Variant=windows[arm]
				await process_frame
				var start:=Time.get_ticks_usec()
				var opened: Dictionary=w.open(host,cards,"변신","테스트",Callable(),effect)
				var open_usec:=Time.get_ticks_usec()-start
				check(opened.get("handled",false) and int(opened.filled.get("backs",-1))==n,"all awarded cards start face down")
				await process_frame
				pack.count=0
				var before_cpu:=_thread_ns()
				start=Time.get_ticks_usec()
				var shown: Dictionary=w.open_all()
				var elapsed:=Time.get_ticks_usec()-start
				var after_cpu:=_thread_ns()
				var read_count: int=pack.count
				# Real reel widgets already exist synchronously. Only cheap
				# checks after the interval keep QA inspection out of its timer.
				await process_frame
				var whole:=Time.get_ticks_usec()-start
				if i>0:
					if before_cpu>=0 and after_cpu>=before_cpu:cpu[arm].append(float(after_cpu-before_cpu)/1000.0)
					opening[arm].append(open_usec);ready[arm].append(elapsed);interval[arm].append(whole);reads[arm].append(read_count)
				check(shown.opened==n and shown.lit==lit and w.open_all().opened==0,"same grants/grades, no second activation")
				var effects: Array=w._scene.find_children("CardRevealEffect","Control",true,false)
				check(effects.size()==n and read_count==(n if arm==0 else 0),"all actual reels mounted; per-card scene reads removed")
				var state: Array=[]
				for card: Variant in effects:
					if not exact.is_empty():check(card.face.artwork is Texture2D and card.face.candidates.size()==1 and card.face.candidates[0]==card.face.artwork,"real award portrait and reel candidate match")
					state.append([card.position,card.size,card.record.name,card.grade,card.reveal_at(),card.reel_seconds,card.extra_lightning_seconds,card.result_cell_illumination])
				if expected.is_empty():expected=state
				check(state==expected,"%d original reel bounds, recorded card and authored duration unchanged"%n)
				w.close();await process_frame
		samples[str(n)]={"real_card_id":int(exact.get("source_card_id",0)),"tap_thread_cpu_us":cpu,"window_open_us":opening,"tap_to_reels_us":ready,"tap_to_next_process_us":interval,"scene_reads":reads}
	# Let one real tween finish without shortening or manually seeking it.
	# Validate the source face/owner state, not just the first reel widget.
	var live: Variant=windows[1]
	var last_card: Dictionary=exact if not exact.is_empty() else {"name":"마지막 카드","grade":"희귀"}
	check(live.open(host,[last_card],"변신","테스트",Callable(),effect).get("handled",false),"settlement window")
	live.open_all()
	var started: Array=live._scene.find_children("CardRevealEffect","Control",true,false)
	check(started.size()==1,"actual final card reel starts")
	if started.size()==1:
		await create_timer(started[0].reveal_at()+0.35).timeout
		var panel: Dictionary=live._locate(live._scene,live._out,"Nd_CardSet_One/Card_00/Panel")
		var displayed: Variant=panel.player.source_nodes.get(panel.offset) if panel.get("ok",false) else null
		check(live.page_open() and displayed is Node2D and displayed.visible and live._scene.find_children("CardRevealEffect","Control",true,false).is_empty(),"actual tween settles and original face is displayed; reel removed")
		live.close()
	host.queue_free();hud.queue_free()
