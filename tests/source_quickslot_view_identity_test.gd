extends SceneTree
const VIEW=preload("res://scripts/ui/original_ui/source_main_quickslot_view.gd")
const BINDINGS=preload("res://scripts/ui/original_ui/source_main_quickslot_bindings.gd")
class Pack extends RefCounted:
	var manifest: Dictionary={"files":{BINDINGS.SET_MEMBER:{"sha256":BINDINGS.SET_SHA256},BINDINGS.SLOT_MEMBER:{"sha256":BINDINGS.SLOT_SHA256}}}
class World extends Node:
	var pages: Array=[0,1]
	var quickslots: Array=[]
	var amount: int=23
	func _quickslot_pages() -> Array:return pages
	func _quickslot_ammo_source(_entry: Dictionary) -> Dictionary:return {"ammo_count":amount,"can_use_without_ammo":false}
class Hud extends Node:
	var quickslot_entries: Array=[]
	var quickslot_captions: Array=[]
	var quickslot_cooldown_labels: Array=[]
	var indices: Array=[]
	var clicks: Array=[]
	func quickslot_index(visible: int) -> int:return indices[visible]
	func _emit_quickslot(visible: int) -> void:clicks.append(visible)
class Slot extends Node2D:
	var source_member: String=BINDINGS.SLOT_MEMBER
	var text: Dictionary={}
	var shown: Dictionary={}
	var reject: bool=false
	func set_bound_text(offset: int,value: String) -> Dictionary:
		if reject:return {"ok":false,"code":"test_slot_rejected"}
		text[offset]=value;return {"ok":true}
	func set_bound_visible(offset: int,value: bool) -> Dictionary:
		shown[offset]=value;return {"ok":true}
var checks: int=0
var failures: Array[String]=[]
var evidence: Dictionary={}
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("QUICKSLOT_VIEW_IDENTITY_FAIL ",label)

func fixture(old: bool,filled: int=10,counted: bool=true) -> Dictionary:
	var source:=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_quickslot_view.gd")
	check(source.count("not _matches_identity(model)")==1,"exact old comparator restoration")
	if old:
		source=source.replace("not _matches_identity(model)","_model_identity(model)!=_identity")
		source=source.replace("var _busy: bool=false","var _busy: bool=false\nvar _rows: Array=[]")
		source=source.replace("\t_identity.clear()","\t_identity.clear()\n\t_rows.clear()")
		source=source.replace('\treturn {"ok":true,"handled":true,"partial_source_scene":true', '\t_rows=model.rows.duplicate(true)\n\treturn {"ok":true,"handled":true,"partial_source_scene":true')
	# Stage construction itself is unchanged. Intercept only its entry to test
	# refresh/rebuild decisions without inventing private CSB/art fixtures.
	source=source.replace("func _stage(parent: Node)","func _production_stage(parent: Node)")
	source+="\nvar stage_calls: int=0\nfunc _stage(_parent_node: Node) -> Dictionary:\n\tstage_calls+=1\n\treturn {\"ok\":true,\"test_stage_requested\":true}\n"
	if counted:
		source+="\nvar test_identity_entries: int=0\nvar test_retained_rows: int=0\n"
		# Count duplicate operations at the original view-owned sites only;
		# live bindings continue making their required isolated snapshots.
		source=source.replace("_model_identity(model)!=_identity","_counted_identity(model)!=_identity")
		source=source.replace("\t_rows=model.rows.duplicate(true)","\ttest_retained_rows+=model.rows.size()\n\t_rows=model.rows.duplicate(true)")
		source+="\nfunc _counted_identity(model: Dictionary) -> Array:\n\ttest_identity_entries+=model.rows.size()\n\treturn _model_identity(model)\n"
	var script:=GDScript.new();script.source_code=source
	check(script.reload()==OK,"view comparison script compiles")
	var w:=World.new();root.add_child(w);var h:=Hud.new();w.add_child(h)
	for i: int in 10:
		h.indices.append(i)
		h.quickslot_entries.append({"kind":"skill","id":str(i),"auto":i%2==0,"nested":{"values":[i,{"value":i}]}} if i<filled else {})
		var label:=Label.new();label.text=str(i);h.add_child(label);h.quickslot_captions.append(label)
		var cooldown:=Label.new();h.add_child(cooldown);h.quickslot_cooldown_labels.append(cooldown)
	w.quickslots=h.quickslot_entries.duplicate(true)
	var pack:=Pack.new();var bindings:=BINDINGS.new()
	check(bindings.configure(pack,h,Callable()).ok,"production bindings configure")
	var view: RefCounted=script.new();view._bindings=bindings;view._hud=weakref(h);view._parent=weakref(w)
	view._scene=Node2D.new();w.add_child(view._scene)
	var model: Dictionary=bindings.snapshot();view._identity=VIEW._model_identity(model)
	for group: int in 2:
		var page:=Control.new();page.position=Vector2(group*100,0);page.size=Vector2(100,20);view._scene.add_child(page);view._pages.append(page)
	for row: Dictionary in model.rows:
		var slot:=Slot.new();view._scene.add_child(slot)
		var button:=Control.new();button.position=Vector2(row.visible_index*20,0);button.size=Vector2(20,20);slot.add_child(button)
		view._hits[row.visible_index]={"from":"quick","slot":row.absolute_index,"visible":row.visible_index,"entry":row.entry.duplicate(true),"control":button,"native_slot_scene":slot}
	return {"w":w,"h":h,"v":view,"b":bindings,"pack":pack}

func same_slots(a: Dictionary,b: Dictionary,label: String) -> void:
	for i: int in 10:
		var x: Slot=a.v._hits[i].native_slot_scene;var y: Slot=b.v._hits[i].native_slot_scene
		check(x.text==y.text and x.shown==y.shown and x.get_meta("source_quickslot_identity")==y.get_meta("source_quickslot_identity"),label+str(i))

func run() -> void:
	for filled: int in [0,4,10]:
		var a: Dictionary=fixture(false,filled);var b: Dictionary=fixture(true,filled)
		for tick: int in 12:
			for f: Dictionary in [a,b]:
				f.w.amount=tick*7;f.h.quickslot_captions[2].text=str(tick);f.h.quickslot_cooldown_labels[2].text=str(tick*0.1)
			check(a.v.refresh()==b.v.refresh(),"unchanged refresh result")
			same_slots(a,b,"current text/visibility ")
		check(a.v.stage_calls==0 and b.v.stage_calls==0,"caption/ammo/cooldown do not rebuild")
		check(b.v.test_identity_entries==120 and b.v.test_retained_rows==120 and a.v.test_identity_entries==0 and a.v.test_retained_rows==0,"12 refreshes avoid 240 extra entry/row copies")
		if filled==10:evidence={"refreshes":12,"old_extra_identity_entries":b.v.test_identity_entries,"old_retained_presentation_rows_copied":b.v.test_retained_rows,"new_extra_copies":0,"required_binding_snapshots_preserved":true}
		var model: Dictionary=a.b.snapshot();var original: Dictionary=model.duplicate(true)
		for variant: int in 10:
			model=original.duplicate(true)
			match variant:
				0:model.pages.reverse()
				1:model.rows.reverse()
				2:model.rows[0].visible_index=9
				3:model.rows[0].absolute_index=49
				4:model.rows[0].entry={"new":{"array":[1,2]}}
				5:model.rows[0].entry["auto"]=not bool(model.rows[0].entry.get("auto",false))
				6:model.rows.remove_at(9)
				7:model.rows.append(model.rows[0].duplicate(true))
				8:model.rows[0].amount_text="999"
				9:model.rows[0].cooldown_text="4"
			check(a.v._matches_identity(model)==(VIEW._model_identity(model)==a.v._identity),"old comparator parity %d/%d"%[filled,variant])
		if filled>0:
			var hit: Dictionary=a.v.hit_at(Vector2(10,10))
			check(not hit.is_empty(),"current hit accepted")
			hit.entry.nested.values[1].value=999
			check(a.v._hits[0].entry.nested.values[1].value==0,"returned hit owns nested data")
			for f: Dictionary in [a,b]:f.h.quickslot_entries[0].nested.values[1].value=100
			check(a.v.hit_at(Vector2(10,10)).is_empty() and b.v.hit_at(Vector2(10,10)).is_empty(),"stale nested entry rejects touch before refresh")
			check(a.v._identity[1][2].nested.values[1].value==0,"stage identity remains deeply isolated")
			check(a.v.refresh()==b.v.refresh() and a.v.stage_calls==1 and b.v.stage_calls==1,"nested change requests existing rebuild")
		for f: Dictionary in [a,b]:f.v.close()
		check(not a.v.is_open() and a.v._identity.is_empty() and a.v._hits.is_empty() and not b.v.is_open(),"close clears ownership")
		var before_reopen: int=a.v.stage_calls
		check(a.v.refresh()==b.v.refresh() and a.v.stage_calls==before_reopen+1 and a.v.stage_calls==b.v.stage_calls,"closed view requests fresh stage before deferred deletion")
		a.w.free();b.w.free()
	for kind: int in 8:
		var a: Dictionary=fixture(false);var b: Dictionary=fixture(true)
		for f: Dictionary in [a,b]:
			match kind:
				0:f.h.quickslot_captions[9]=null
				1:f.h.indices[9]=-1
				2:f.w.pages[1]=-1
				3:f.v._hits.erase(5)
				4:f.v._hits[0].native_slot_scene.reject=true
				5:f.v._busy=true
				6:f.h.quickslot_entries[0].auto=false
				7:f.w.pages[0]=2
		var ar: Dictionary=a.v.refresh();var br: Dictionary=b.v.refresh()
		check(ar==br and a.v.stage_calls==b.v.stage_calls and a.v.is_open()==b.v.is_open(),"error/busy/restage parity %d"%kind)
		if kind<5:check(not ar.ok and not a.v.is_open(),"invalid state declines and closes")
		a.w.free();b.w.free()
	if "--benchmark" in OS.get_cmdline_user_args():benchmark()
	print("QUICKSLOT_VIEW_IDENTITY_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,"synthetic_only":true,"android_verified":false}))
	quit(0 if failures.is_empty() else 1)

func benchmark() -> void:
	var a: Dictionary=fixture(false,10,false);var b: Dictionary=fixture(true,10,false)
	for f: Dictionary in [a,b]:
		for i: int in 3:f.v.refresh()
	var old_usec: Array=[];var new_usec: Array=[]
	for round_index: int in 4:
		for f: Dictionary in ([a,b] if round_index%2==0 else [b,a]):
			var started:=Time.get_ticks_usec()
			for i: int in 100:f.v.refresh()
			var elapsed:=Time.get_ticks_usec()-started
			if f.v==a.v:new_usec.append(elapsed)
			else:old_usec.append(elapsed)
	evidence["cpu_only_synthetic_refresh"]={"per_sample":100,"old_usec":old_usec,"new_usec":new_usec,"rendering_excluded":true}
	a.w.free();b.w.free()
