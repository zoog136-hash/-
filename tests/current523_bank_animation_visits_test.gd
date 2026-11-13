extends SceneTree
const F=preload("res://tests/current523_bank_object_refresh_test.gd")
const HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
class Current extends F.Fixture:
	var shows: Array=[]
	var trace_calls: bool=true
	func _show(node: Node2D,sprite: Dictionary,index: int) -> void:
		if trace_calls:shows.append([node.get_index(),index])
		super._show(node,sprite,index)
class Previous extends Current:
	# Exact pre-change scheduler from main 6733f32.
	func _process_step(delta: float) -> void:
		_clock += maxf(delta, 0.0)
		var frames: Dictionary = {}
		for node: Node2D in _nodes:
			var id: int = int(node.get_meta("sprite_id"))
			var sprite: Dictionary = _sprites.get(id, {})
			if sprite.get("ok", false) and not sprite.static:
				if not frames.has(id): frames[id] = _frame_index(sprite)
				_show(node, sprite, int(frames[id]))
		FRAME_HITCH.count("map.object_timeline_samples", frames.size())
		FRAME_HITCH.count("map.object_placements_visited", _nodes.size())
var checks: int=0
var failures: Array[String]=[]
var pixel_comparisons: int=0
var visits: Dictionary={}
var cpu_benchmark: Dictionary={}
var render: bool=false
var fixture: SceneTree
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("MAP_ANIMATION_VISITS_FAIL ",label)
func view(old: bool,a: Texture2D,b: Texture2D) -> Dictionary:
	var vp:=SubViewport.new();vp.size=Vector2i(96,64);vp.disable_3d=true;vp.transparent_bg=true;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	var bg:=ColorRect.new();bg.size=Vector2(96,64);bg.color=Color(0.21,0.37,0.58,0.7);vp.add_child(bg)
	var owner: Current=Previous.new() if old else Current.new()
	owner.coordinates=F.Mapping.new();owner.catalog=fixture.catalog(a,b);owner.position=Vector2(16,16);owner._mode="compatible";owner.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	vp.add_child(owner);owner.set_process(false)
	return {"vp":vp,"o":owner}
func refresh_pair(a: Dictionary,b: Dictionary,ids: Array) -> void:
	var rows: Array[Dictionary]=fixture.rows(ids)
	a.o.refresh(rows);b.o.refresh(rows)
	a.o.shows.clear();b.o.shows.clear()
func step_pair(a: Dictionary,b: Dictionary,delta: float) -> void:
	a.o.shows.clear();b.o.shows.clear();a.o._process_step(delta);b.o._process_step(delta)
	check(a.o.shows==b.o.shows,"same ordered _show calls, including interleaved duplicate IDs")
	check(a.o._clock==b.o._clock,"clock retained even when every placement is static")
func compare(a: Dictionary,b: Dictionary,label: String) -> void:
	check(fixture.snapshot(a.o)==fixture.snapshot(b.o),label+" complete ordered holder/layer/frame state")
	check(a.o.metrics()==b.o.metrics() and a.o.loads==b.o.loads and a.o.texture_calls==b.o.texture_calls,label+" metrics, source loads and texture calls")
	if render:
		await process_frame;await RenderingServer.frame_post_draw
		pixel_comparisons+=1;check(fixture.pixels(a.vp)==fixture.pixels(b.vp),label+" complete RGBA")
func count_ticks(owner: Current,iterations: int) -> Dictionary:
	# Operation counts do not depend on process uptime. Backdating by 500ms
	# can produce a negative start on fast runners and record no frame.
	HITCH.reset_for_test("user://map_animation_visits_test");HITCH.frame_at_for_test(1000000,"synthetic_ticks")
	var trace: bool=owner.trace_calls;owner.trace_calls=false
	for i: int in iterations:owner._process_step(1.0/60.0)
	owner.trace_calls=trace
	HITCH.frame_at_for_test(1500000,"synthetic_ticks")
	var summary: Dictionary=HITCH.summary()
	check(summary.hitches==1 and summary.worst.size()==1 and summary.worst[0].ms==500,"deterministic count probe records one 500ms frame")
	return summary.worst[0].get("counters",{})
func run() -> void:
	render="--render" in OS.get_cmdline_user_args()
	if render and (DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_method()!="gl_compatibility"):check(false,"requires Compatibility GL");quit(1);return
	fixture=F.new()
	var t1: Texture2D=fixture.make_texture(11);var t2: Texture2D=fixture.make_texture(97)
	var a: Dictionary=view(false,t1,t2);var b: Dictionary=view(true,t1,t2)
	refresh_pair(a,b,[2,1,3,1,4,1]);await compare(a,b,"initial")
	for delta: float in [0.0,0.1,0.39,0.02,0.5,2.8,-1.0]:
		step_pair(a,b,delta);await compare(a,b,"tick %s"%delta)
	# Reorder/reuse holders, then shrink before deferred frees have run.
	refresh_pair(a,b,[1,2,1,3]);step_pair(a,b,0.2);await compare(a,b,"reorder")
	var retired: WeakRef=weakref(a.o._nodes[2])
	refresh_pair(a,b,[2]);step_pair(a,b,0.7);await compare(a,b,"shrink")
	check(a.o._animated_nodes.is_empty(),"shrink releases animated index immediately")
	await process_frame;check(retired.get_ref()==null,"index does not retain retired holder")
	# Continue the same clock through a static interval, then add animation.
	step_pair(a,b,3.1);await compare(a,b,"static interval")
	refresh_pair(a,b,[1,2,1]);step_pair(a,b,0.6);await compare(a,b,"animation resumes at retained clock")
	# Cached source records are read again per ID, not assumed immutable forever.
	for v: Dictionary in [a,b]:v.o._sprites[1].static=true
	step_pair(a,b,0.2);await compare(a,b,"animated to static without refresh")
	for v: Dictionary in [a,b]:v.o._sprites[1].static=false
	step_pair(a,b,0.3);await compare(a,b,"static to animated without refresh")
	for v: Dictionary in [a,b]:v.o._sprites[1].ok=false
	step_pair(a,b,0.2);await compare(a,b,"invalid cached record")
	for v: Dictionary in [a,b]:v.o._sprites[1]=v.o.catalog[1].duplicate(true);v.o._sprites[1].ok=true
	step_pair(a,b,0.3);await compare(a,b,"replacement record")
	refresh_pair(a,b,[]);step_pair(a,b,0.4);await compare(a,b,"empty refresh")
	check(a.o._animated_nodes.is_empty() and a.o._placement_sprite_ids.is_empty(),"empty view retains no placement index")
	# Large operation-count probe: real holders/scheduler, synthetic empty layers.
	var ids: Array=[];ids.resize(1024);ids.fill(4)
	refresh_pair(a,b,ids)
	var old_static: Dictionary=count_ticks(b.o,60);var new_static: Dictionary=count_ticks(a.o,60)
	check(old_static.get("map.object_placements_visited",0)==61440 and new_static.get("map.object_placements_visited",0)==0,"static placements: 61440 tick visits to zero")
	check(new_static.get("map.object_sprite_states_checked",0)==60,"one live source classification per static tick")
	for i: int in 1024:ids[i]=1 if i%2==0 else 4
	refresh_pair(a,b,ids)
	var old_mixed: Dictionary=count_ticks(b.o,60);var new_mixed: Dictionary=count_ticks(a.o,60)
	check(old_mixed.get("map.object_placements_visited",0)==61440 and new_mixed.get("map.object_placements_visited",0)==30720,"mixed tick visits retain exactly animated half")
	check(new_mixed.get("map.object_index_holders_scanned",0)==1024,"one ordered membership scan, separately accounted")
	check(old_mixed.get("map.object_timeline_samples",0)==new_mixed.get("map.object_timeline_samples",0),"timeline sampling cadence preserved")
	visits={"iterations":60,"holders":1024,"old_static":old_static,"new_static":new_static,"old_mixed":old_mixed,"new_mixed":new_mixed}
	check(fixture.snapshot(a.o)==fixture.snapshot(b.o),"large mixed final state agrees")
	a.vp.free();b.vp.free()
	if "--benchmark" in OS.get_cmdline_user_args():benchmark()
	fixture.free()
	print("MAP_ANIMATION_VISITS_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"pixel_comparisons":pixel_comparisons,"visits":visits,"cpu_benchmark":cpu_benchmark,"synthetic_only":true,"android_verified":false}))
	quit(0 if failures.is_empty() else 1)

func benchmark_owner(old: bool,scenario: String) -> Current:
	var owner: Current=Previous.new() if old else Current.new()
	owner.coordinates=F.Mapping.new();owner.trace_calls=false;root.add_child(owner);owner.set_process(false)
	var ids: Array=[]
	for i: int in 1024:
		var id: int=1000 if scenario=="static" else 1000+i%2 if scenario=="mixed" else 1000+i%512
		ids.append(id)
		if not owner.catalog.has(id):
			owner.catalog[id]={"ok":true,"static":scenario=="static" or (scenario=="mixed" and id==1000),"total":1.0,"frames":[{"duration":0.5,"layers":[]},{"duration":0.5,"layers":[]}]}
	owner.refresh(fixture.rows(ids))
	return owner
func benchmark() -> void:
	# Actual old/new scheduler and _show, with empty synthetic layers. No
	# per-call trace arrays, file I/O, GPU rendering or timing pass threshold.
	for scenario: String in ["static","mixed","animated_512_ids"]:
		var old: Current=benchmark_owner(true,scenario);var next: Current=benchmark_owner(false,scenario)
		for owner: Current in [old,next]:
			for i: int in 3:owner._process_step(1.0/60.0)
		var old_usec: Array[int]=[];var new_usec: Array[int]=[]
		for round_index: int in 4:
			var owners: Array=[old,next] if round_index%2==0 else [next,old]
			for owner: Current in owners:
				var started: int=Time.get_ticks_usec()
				for i: int in 120:owner._process_step(1.0/60.0)
				var elapsed: int=Time.get_ticks_usec()-started
				if owner==old:old_usec.append(elapsed)
				else:new_usec.append(elapsed)
		cpu_benchmark[scenario]={"updates_per_sample":120,"holders":1024,"old_usec":old_usec,"new_usec":new_usec,"rendering_excluded":true}
		old.free();next.free()
