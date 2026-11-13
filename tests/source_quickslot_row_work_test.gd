extends SceneTree
const BINDINGS=preload("res://scripts/ui/original_ui/source_main_quickslot_bindings.gd")
const HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
const VIEW=preload("res://scripts/ui/original_ui/source_main_quickslot_view.gd")
class Pack extends RefCounted:
	var manifest: Dictionary={"files":{BINDINGS.SET_MEMBER:{"sha256":BINDINGS.SET_SHA256},BINDINGS.SLOT_MEMBER:{"sha256":BINDINGS.SLOT_SHA256}}}
class World extends Node:
	var pages: Array=[0,1]
	var reads: int=0
	var amount: int=37
	var without_ammo: bool=false
	func _quickslot_pages() -> Array:return pages
	func _quickslot_ammo_source(entry: Dictionary) -> Dictionary:
		reads+=1
		return {"ammo_count":amount,"can_use_without_ammo":without_ammo} if entry.get("kind")=="skill" else {}
class Hud extends Node:
	var quickslot_entries: Array=[]
	var quickslot_captions: Array=[]
	var quickslot_cooldown_labels: Array=[]
	var indices: Array=[]
	var clicks: Array=[]
	func quickslot_index(visible: int) -> Variant:return indices[visible]
	func _emit_quickslot(visible: int) -> void:clicks.append(visible)
class Slot extends Node2D:
	var source_member: String=BINDINGS.SLOT_MEMBER
	var text: Dictionary={}
	var shown: Dictionary={}
	var reject_text: bool=false
	func set_bound_text(offset: int,value: String) -> Dictionary:
		if reject_text:return {"ok":false,"code":"fixture_text_rejected"}
		text[offset]=value
		return {"ok":true}
	func set_bound_visible(offset: int,value: bool) -> Dictionary:
		shown[offset]=value
		return {"ok":true}
var checks: int=0
var failures: Array[String]=[]
var evidence: Dictionary={}
var cpu_benchmark: Dictionary={}
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("QUICKSLOT_ROW_WORK_FAIL ",label)
func fixture(old: bool,counted: bool=true) -> Dictionary:
	var source: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_quickslot_bindings.gd")
	# Exact former call scope: each refresh_slot projected the full live model.
	# With default -1, _snapshot_model executes the unchanged full row path.
	check(source.count("_snapshot(int(visible))")==1,"baseline call substitution is exact")
	if old:source=source.replace("_snapshot(int(visible))","_snapshot()")
	if counted:source=source.replace("extends RefCounted\n","extends RefCounted\nvar test_rows: int=0\n")
	if counted:source=source.replace("\t\trows.append({\"visible_index\"", "\t\ttest_rows+=1\n\t\trows.append({\"visible_index\"")
	var script:=GDScript.new();script.source_code=source
	check(script.reload()==OK,"comparison script compiles")
	var w:=World.new();root.add_child(w)
	var h:=Hud.new();w.add_child(h)
	for i: int in 10:
		h.indices.append(i)
		h.quickslot_entries.append({"kind":"skill","id":str(i),"auto":i%2==0,"nested":{"value":i}})
		var caption:=Label.new();caption.text=str(i+1);h.add_child(caption);h.quickslot_captions.append(caption)
		var cooldown:=Label.new();cooldown.text="0.5" if i%2==0 else "";h.add_child(cooldown);h.quickslot_cooldown_labels.append(cooldown)
	var pack:=Pack.new();var bindings: RefCounted=script.new()
	check(bindings.configure(pack,h,Callable()).ok,"bindings configure")
	var v: RefCounted=VIEW.new();v._bindings=bindings;v._parent=weakref(w);v._hud=weakref(h)
	v._scene=Node2D.new();w.add_child(v._scene)
	var model: Dictionary=bindings.snapshot();v._identity=v._model_identity(model)
	for row: Dictionary in model.rows:
		var slot:=Slot.new();v._scene.add_child(slot);v._hits[row.visible_index]={"native_slot_scene":slot}
	w.reads=0
	if counted:bindings.test_rows=0
	return {"w":w,"h":h,"b":bindings,"v":v,"pack":pack}
func compare(a: Dictionary,b: Dictionary,label: String) -> void:
	for i: int in 10:
		var x: Slot=a.v._hits[i].native_slot_scene;var y: Slot=b.v._hits[i].native_slot_scene
		check(x.text==y.text and x.shown==y.shown and x.get_meta("source_quickslot_identity")==y.get_meta("source_quickslot_identity"),label+" slot %d"%i)
func run() -> void:
	var a: Dictionary=fixture(false);var b: Dictionary=fixture(true)
	HITCH.reset_for_test("user://quickslot_row_work_test")
	HITCH.frame("quickslot")
	check(a.v.refresh()==b.v.refresh(),"actual view refresh result matches former scope")
	HITCH.backdate_frame_for_test(200000)
	HITCH.frame("quickslot")
	var recorded: Dictionary=HITCH.summary().worst[0]
	var calls: int=0
	for detail: Array in recorded.get("details",[]):
		if detail[0]=="ui.quickslot_snapshot":calls=int(detail[2])
	check(calls==22,"inclusive detail records all old/new snapshot calls")
	for section: Array in recorded.sections:check(section[0]!="ui.quickslot_snapshot","snapshot detail adds no duplicate section")
	compare(a,b,"whole view")
	evidence={"old_ammo_reads":b.w.reads,"new_ammo_reads":a.w.reads,"old_projected_rows":b.b.test_rows,"new_projected_rows":a.b.test_rows}
	check(a.w.reads==20 and b.w.reads==110 and a.b.test_rows==20 and b.b.test_rows==110,"one view refresh projects 20 rather than 110 rows")
	# Nothing survives between calls: live amount/cooldown/auto changes are read
	# after the caller's earlier snapshot, as in the former single-slot API.
	for iteration: int in 4:
		var ar: Dictionary=a.b.snapshot().rows[2];var br: Dictionary=b.b.snapshot().rows[2]
		for f: Dictionary in [a,b]:
			f.w.amount=[0,5,999,-1][iteration];f.w.without_ammo=iteration%2==0
			f.h.quickslot_entries[2].auto=iteration%2==0
			f.h.quickslot_cooldown_labels[2].text=str(iteration)
		var x: Slot=a.v._hits[2].native_slot_scene;var y: Slot=b.v._hits[2].native_slot_scene
		check(a.b.refresh_slot(x,ar)==b.b.refresh_slot(y,br),"live values after snapshot remain current")
		compare(a,b,"live changes")
	# Snapshot ownership, empty and non-skill rows retain the full public API.
	var snapshot: Dictionary=a.b.snapshot();snapshot.rows[0].entry.nested.value=999
	check(a.h.quickslot_entries[0].nested.value==0,"snapshot isolates mutable entries")
	for f: Dictionary in [a,b]:
		f.h.quickslot_entries[4]={};f.h.quickslot_entries[5]={"kind":"item","id":"potion"};f.h.indices[9]=999
	check(a.b.snapshot()==b.b.snapshot(),"public full model preserves empty/out-of-range/item rows")
	# Reset stored identities to exercise each failure from the same valid state.
	for failure: int in 8:
		var ar: Dictionary=a.b.snapshot().rows[2];var br: Dictionary=b.b.snapshot().rows[2]
		for f: Dictionary in [a,b]:
			var slot: Slot=f.v._hits[2].native_slot_scene
			if failure==0:f.h.indices[9]=-1
			if failure==1:f.h.quickslot_captions[9]=null
			if failure==2:f.w.pages[0]=-1
			if failure==3:f.h.quickslot_entries[2].id="replacement"
			if failure==4:f.w.pages[0]=2
			if failure==5:f.pack.manifest.files[BINDINGS.SLOT_MEMBER].sha256="changed"
			if failure==6:slot.source_member="wrong"
			if failure==7:slot.reject_text=true
		var ra: Dictionary=a.b.refresh_slot(a.v._hits[2].native_slot_scene,ar)
		var rb: Dictionary=b.b.refresh_slot(b.v._hits[2].native_slot_scene,br)
		check(ra==rb and not ra.ok,"same rejection for invalid live input %d"%failure)
		for f: Dictionary in [a,b]:
			f.h.indices[9]=999
			f.h.quickslot_captions[9]=f.h.get_child(18)
			f.w.pages[0]=0;f.h.quickslot_entries[2].id="2"
			f.pack.manifest.files[BINDINGS.SLOT_MEMBER].sha256=BINDINGS.SLOT_SHA256
			f.v._hits[2].native_slot_scene.source_member=BINDINGS.SLOT_MEMBER
			f.v._hits[2].native_slot_scene.reject_text=false
	# Action dispatch continues to validate the presented entry and live page.
	var row: Dictionary=a.b.snapshot().rows[2]
	var identity: Dictionary=a.b._presented_identity(row)
	check(a.b.activate_presented(2,identity).ok and a.h.clicks==[2],"live matching identity dispatches")
	a.h.quickslot_entries[2].id="new"
	check(not a.b.activate_presented(2,identity).ok and a.h.clicks==[2],"stale identity never dispatches")
	a.w.free();b.w.free()
	if "--benchmark" in OS.get_cmdline_user_args():benchmark()
	print("QUICKSLOT_ROW_WORK_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,"cpu_benchmark":cpu_benchmark,"synthetic_only":true,"android_verified":false}))
	quit(0 if failures.is_empty() else 1)

func benchmark() -> void:
	# Fresh uninstrumented bindings, alternating CPU-only batches. These fake
	# slot sinks record the same production text/visibility calls without GPU work.
	var a: Dictionary=fixture(false,false);var b: Dictionary=fixture(true,false)
	for f: Dictionary in [a,b]:
		for i: int in 3:f.v.refresh()
	var old_usec: Array[int]=[];var new_usec: Array[int]=[]
	for round_index: int in 4:
		var ordered: Array=[b,a] if round_index%2==0 else [a,b]
		for f: Dictionary in ordered:
			var started: int=Time.get_ticks_usec()
			for i: int in 100:f.v.refresh()
			var elapsed: int=Time.get_ticks_usec()-started
			if f.w==b.w:old_usec.append(elapsed)
			else:new_usec.append(elapsed)
	cpu_benchmark={"refreshes_per_sample":100,"old_usec":old_usec,"new_usec":new_usec,"synthetic_slot_sinks":true,"rendering_excluded":true}
	a.w.free();b.w.free()
