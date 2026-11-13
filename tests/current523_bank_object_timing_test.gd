extends SceneTree
const OBJECTS=preload("res://scripts/maps/current523_bank_objects.gd")
class Probe extends OBJECTS:
	var samples: int=0
	var shown: Array[int]=[]
	func _frame_index(sprite: Dictionary) -> int:
		samples+=1
		return super._frame_index(sprite)
	func _show(_node: Node2D, _sprite: Dictionary, index: int) -> void:
		shown.append(index)
	func baseline(delta: float) -> void:
		_clock+=maxf(delta,0.0)
		for node: Node2D in _nodes:
			var sprite: Dictionary=_sprites.get(int(node.get_meta("sprite_id")),{})
			if sprite.get("ok",false) and not sprite.static:_show(node,sprite,_frame_index(sprite))
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok:failures.append(why)
func make_probe() -> Probe:
	var p:=Probe.new()
	var frames: Array=[]
	var total: float=0.0
	for i: int in 64:
		var duration: float=0.0 if i%7==0 else 0.125
		frames.append({"duration":duration,"presentation_duration":duration})
		total+=duration
	p._sprites={1:{"ok":true,"static":false,"total":total,"frames":frames},2:{"ok":true,"static":false,"total":0.25,"frames":[{"duration":0.125},{"duration":0.125}]},3:{"ok":true,"static":true},4:{"ok":false}}
	for i: int in 1024:
		var node:=Node2D.new()
		node.set_meta("sprite_id",1 if i<512 else (2 if i<768 else (3 if i<896 else (4 if i<1023 else 5))))
		p.add_child(node);p._nodes.append(node)
	return p
func _initialize() -> void:
	var before:=make_probe()
	var after:=make_probe()
	for delta: float in [0.0,0.125,0.125,-4.0,0.0,8.0,0.001,1000.0]:
		before.shown.clear();after.shown.clear();before.samples=0;after.samples=0
		before.baseline(delta);after._process_step(delta)
		check(before.shown==after.shown,"frame values and placement order match baseline at delta %s"%delta)
		check(before._clock==after._clock,"clock and negative delta unchanged")
		check(before.samples==768 and after.samples==2,"768 repeated timeline samples become two")
		check(after.shown.size()==768,"static/invalid/missing excluded as before")
	# Changing an existing record must be visible on the next update.
	before._sprites[1]={"ok":true,"static":false,"total":1.0,"frames":[{"duration":1.0}]}
	after._sprites[1]=before._sprites[1].duplicate(true)
	before.shown.clear();after.shown.clear();before.baseline(0);after._process_step(0)
	check(before.shown==after.shown,"record replacement is not masked by cross-frame memo")
	before.free();after.free()
	if "--benchmark" in OS.get_cmdline_user_args():
		var old_times: Array[int]=[]
		var new_times: Array[int]=[]
		for sample: int in 5:
			var old:=make_probe()
			var current:=make_probe()
			old._clock=3.0;current._clock=3.0
			var started: int=Time.get_ticks_usec()
			for step: int in 120:
				old.shown.clear();old.baseline(1.0/30.0)
			old_times.append(Time.get_ticks_usec()-started)
			started=Time.get_ticks_usec()
			for step: int in 120:
				current.shown.clear();current._process_step(1.0/30.0)
			new_times.append(Time.get_ticks_usec()-started)
			check(old.shown==current.shown and old._clock==current._clock,"benchmark final state preserved")
			old.free();current.free()
		old_times.sort();new_times.sort()
		print("MAP_OBJECT_TIMING_BENCH "+JSON.stringify({"synthetic_only":true,"steps_per_sample":120,"baseline_median_usec":old_times[2],"shared_median_usec":new_times[2],"baseline_samples_usec":old_times,"shared_samples_usec":new_times}))
	print("CURRENT523_BANK_OBJECT_TIMING_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"synthetic_placements":1024,"baseline_samples":768,"shared_samples":2}))
	quit(0 if failures.is_empty() else 1)
