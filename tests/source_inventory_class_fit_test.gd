extends SceneTree
## Real view configuration, refresh/apply/action and FontFile measurement.
## Counted source records and mounted child setters are synthetic fixtures.
const VIEW=preload("res://scripts/ui/original_ui/source_main_inventory_lock_view.gd")
const HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
var checks: int=0
var failures: Array[String]=[]
var samples: Array=[]
class Pack extends RefCounted:
	var manifest: Dictionary={"files":{VIEW.MEMBER:{"sha256":VIEW.SHA256},VIEW.PARENT_MEMBER:{"sha256":VIEW.PARENT_SHA256}}}
	var reads: int=0
	var fonts: int=0
	var width: float=269.0
	var font_available: bool=true
	var class_present: bool=true
	var original_font: FontFile=load("res://assets/fonts/NotoSansKR.ttf")
	func scene(_member: String) -> Dictionary:
		reads+=1
		var nodes: Array=[]
		for offset: int in VIEW.SOURCE_OFFSETS:nodes.append({"_offset":offset,"options":{}})
		if class_present:
			nodes.append({"_offset":40928,"options":{}})
			nodes.append({"_offset":40580,"options":{"fontResource":{"path":"synthetic.ttf"},"fontSize":20,"widgetOptions":{"size":[width,20]}}})
		return {"nodeTree":{"_offset":1,"children":nodes}}
	func font(_reference: Dictionary) -> FontFile:
		fonts+=1
		return original_font if font_available else null
class Bag extends Control:
	var detail_active: bool=true
	var selected_item: String="sword@@@physical-7"
	var character_state: Dictionary={"item_locks":{}}
	var lock_button: Button
	var detail_name: Label
	var source_detail_type: Dictionary={}
	var source_detail_safe_enhancement: Dictionary={}
	var source_detail_classes: Dictionary={}
	var toggles: int=0
	var closes: int=0
	func _toggle_lock() -> void:
		toggles+=1
		character_state.item_locks[selected_item]=not character_state.item_locks.get(selected_item,false)
	func close_detail() -> void:
		closes+=1
		detail_active=false
class ButtonState extends RefCounted:
	var current_state: String="normal"
class Child extends Node2D:
	var source_nodes: Dictionary={}
	var texts: Dictionary={}
	var shown: Dictionary={}
	var enabled: Dictionary={}
	var reject: bool=false
	func set_bound_text(offset: int, value: String) -> Dictionary:
		if reject:return {"ok":false,"code":"synthetic_text_rejected"}
		texts[offset]=value;return {"ok":true}
	func set_bound_visible(offset: int, value: bool) -> Dictionary:
		shown[offset]=value;return {"ok":true}
	func set_bound_displaystate(offset: int, value: bool) -> Dictionary:
		enabled[offset]=value
		source_nodes[offset].get_meta("source_button").current_state="normal" if value else "disabled"
		return {"ok":true}
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label)
func _initialize() -> void:run.call_deferred()
func previous() -> GDScript:
	var source: String=FileAccess.get_file_as_string("res://scripts/ui/original_ui/source_main_inventory_lock_view.gd")
	var insertion: String="\tif _class_in_scope:model.class_text=_fitting_class_text(model.class_text)\n\tvar bindings: Dictionary = {"
	check(source.contains(insertion),"new initial-build fit site located")
	source=source.replace(insertion,"\tvar bindings: Dictionary = {")
	var begin: int=source.find("func refresh(")
	var at: int=source.find("\tvar model: Dictionary = _model(bag)\n",begin)+"\tvar model: Dictionary = _model(bag)\n".length()
	check(begin>=0 and at>begin,"previous refresh insertion located")
	source=source.left(at)+"\tif _class_in_scope and model.get(\"ok\",false):model.class_text=_fitting_class_text(model.class_text)\n"+source.substr(at)
	source=source.replace("\tif value.is_empty():return \"\"\n","")
	var script:=GDScript.new();script.source_code=source
	check(script.reload()==OK,"old refresh oracle compiles")
	return script
func fixture(script: Script, text: String, class_present: bool=true) -> Dictionary:
	var host:=Node2D.new();root.add_child(host)
	var bag:=Bag.new();host.add_child(bag)
	bag.lock_button=Button.new();bag.add_child(bag.lock_button)
	bag.detail_name=Label.new();bag.detail_name.text="Same sword";bag.add_child(bag.detail_name)
	var close:=Button.new();close.name="InventoryDetailClose";bag.add_child(close)
	bag.source_detail_classes={"reference":bag.selected_item,"text":text}
	var pack:=Pack.new();pack.class_present=class_present
	var view: RefCounted=script.new()
	check(view.configure(pack,bag).get("ok",false),"real view validates source scope and owner")
	var child:=Child.new();host.add_child(child)
	for offset: int in VIEW.LOCK_BUTTONS:
		var node:=Node2D.new();node.set_meta("source_button",ButtonState.new());child.add_child(node);child.source_nodes[offset]=node
	# Already mounted native presentation: construction itself is not timed.
	view._scene=child;view._child=child;view._parent=weakref(host);view._action=weakref(bag.lock_button);view._reference=bag.selected_item
	pack.reads=0;pack.fonts=0
	return {"host":host,"bag":bag,"pack":pack,"view":view,"child":child}
func state(f: Dictionary) -> Dictionary:
	return {"texts":f.child.texts,"shown":f.child.shown,"enabled":f.child.enabled,"selected":f.bag.selected_item,"locks":f.bag.character_state.item_locks,"toggles":f.bag.toggles,"closes":f.bag.closes}
func compare(a: Dictionary,b: Dictionary) -> void:
	check(a.view.refresh(a.host)==b.view.refresh(b.host),"refresh result equivalent")
	check(state(a)==state(b),"text/visibility/button and owner state equivalent")
func dispose(f: Dictionary) -> void:
	f.view.close();f.host.free()
func run() -> void:
	HITCH.reset_for_test("user://inventory_class_fit")
	var old:=previous()
	for text: String in ["","Knight Wizard","Knight ".repeat(100)]:
		var a: Dictionary=fixture(old,text);var b: Dictionary=fixture(VIEW,text)
		var child: Node2D=b.child
		for frame: int in 12:compare(a,b)
		check(a.pack.reads==24 and a.pack.fonts==24,"previous warm refresh reads and measures twice")
		var expected: int=0 if text.is_empty() else 12
		check(b.pack.reads==expected and b.pack.fonts==expected,"empty text skips source IO; nonempty fits once per refresh")
		check(b.view._scene==child and b.bag.toggles==0,"refresh preserves mounted scene and performs no lock transaction")
		samples.append({"case":"empty" if text.is_empty() else ("overlong" if text.length()>100 else "fitting"),"refreshes":12,"old_scene_reads":a.pack.reads,"new_scene_reads":b.pack.reads,"old_font_lookups":a.pack.fonts,"new_font_lookups":b.pack.fonts})
		dispose(a);dispose(b)
	_live_changes(old)
	_boundaries(old)
	check(HITCH._details.has("ui.inventory_class_fit"),"class fit has a fixed inclusive diagnostic")
	print("SOURCE_INVENTORY_CLASS_FIT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"samples":samples,"android_measured":false}))
	quit(0 if failures.is_empty() else 1)
func _live_changes(old: Script) -> void:
	var a: Dictionary=fixture(old,"Knight");var b: Dictionary=fixture(VIEW,"Knight")
	compare(a,b)
	for f: Dictionary in [a,b]:f.pack.width=1
	compare(a,b)
	check(b.child.texts[40580]=="","live width change still hides the whole overlong class list")
	for f: Dictionary in [a,b]:f.pack.width=269;f.pack.font_available=false
	compare(a,b)
	check(b.child.texts[40580]=="","missing font never manufactures a class label")
	for f: Dictionary in [a,b]:f.pack.font_available=true;f.bag.source_detail_classes.text="Wizard"
	compare(a,b)
	check(b.child.texts[40580]=="Wizard","changed nonempty text/font is measured again immediately")
	check(a.view._activate()==b.view._activate(),"lock action still forwards to the existing owner")
	check(state(a)==state(b) and b.bag.toggles==1,"fresh lock state preserved")
	for f: Dictionary in [a,b]:f.bag.lock_button.disabled=true
	check(a.view._activate()==b.view._activate() and b.bag.toggles==1,"disabled action still refuses transaction")
	for f: Dictionary in [a,b]:f.bag.selected_item="other"
	compare(a,b)
	check(b.view._scene==null,"selection replacement retires stale presentation")
	dispose(a);dispose(b)
func _boundaries(old: Script) -> void:
	for kind: String in ["no_class_scope","hidden","not_detail","invalid_parent","rejected_text","close_detail"]:
		var a: Dictionary=fixture(old,"",kind!="no_class_scope");var b: Dictionary=fixture(VIEW,"",kind!="no_class_scope")
		for f: Dictionary in [a,b]:
			if kind=="hidden":f.bag.hide()
			if kind=="not_detail":f.bag.detail_active=false
			if kind=="rejected_text":f.child.reject=true
		if kind=="invalid_parent":check(a.view.refresh(null)==b.view.refresh(null),"invalid mount still rejected")
		elif kind=="close_detail":check(a.view._close_detail()==b.view._close_detail() and b.bag.closes==1,"detail close still uses owner action")
		else:compare(a,b)
		if kind=="no_class_scope":check(a.pack.reads==0 and b.pack.reads==0,"out-of-scope class remains absent")
		else:check(b.view._scene==null,"invalid/closed presentation retired")
		dispose(a);dispose(b)
