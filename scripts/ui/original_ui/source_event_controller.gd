extends RefCounted
## Concrete original event-screen caller. Only source nodes/fields are bound;
## the service retains transactions and the existing caller supplies missing
## list templates, reward pixels, tooltips and confirmation presentations.
const Screens=preload("res://scripts/ui/original_ui/source_event_screen_bindings.gd")
const PassModel=preload("res://scripts/ui/original_ui/source_pass_model_adapter.gd")
const AttendanceModel=preload("res://scripts/ui/original_ui/source_attendance_model_adapter.gd")
signal action_result(result: Dictionary)
var model_adapter: RefCounted
var _pack: RefCounted
var _kind: String=""
var _remaining: Callable
var _session: WeakRef
var _scene: WeakRef
var _attendance_tab: String="daily"

func configure(pack: RefCounted, kind: String, remaining_factory: Callable) -> Dictionary:
	if not Screens.ROOTS.has(kind):return _fail("source_event_component_unknown")
	if not remaining_factory.is_valid():return _fail("source_event_remaining_node_factory_required")
	_pack=pack
	_kind=kind
	_remaining=remaining_factory
	return {"ok":true,"controller":self}

func build(model: Dictionary, session: RefCounted) -> Dictionary:
	_scene=null
	_session=weakref(session)
	model_adapter=PassModel.new() if _kind=="pass" else AttendanceModel.new()
	var projected: Dictionary=model_adapter.configure(session)
	if not projected.get("ok",false):return projected
	var focus: Dictionary=model.get("focus",{})
	var selected: Dictionary={"ok":true}
	if _kind=="pass":
		if focus.has("pass_id"):selected=model_adapter.select_pass(int(focus.pass_id))
		elif projected.passes.size()==1:selected=model_adapter.select_pass(int(projected.passes.keys()[0]))
	else:
		if focus.has("version_id"):selected=model_adapter.select_version(int(focus.version_id))
		elif projected.versions.size()==1:selected=model_adapter.select_version(int(projected.versions.keys()[0]))
	if not selected.get("ok",false):return selected
	# The caller receives the concrete model adapter, so it can resolve row
	# identities itself instead of manually copying opaque action references.
	var supplied: Variant=_remaining.call(model.duplicate(true),model_adapter)
	if not supplied is Dictionary:return _fail("source_event_remaining_node_factory_failed")
	var bindings: Dictionary=supplied
	if supplied.has("ok"):
		if not supplied.get("ok",false):return supplied
		if not supplied.get("bindings") is Dictionary:return _fail("source_event_remaining_node_factory_failed")
		bindings=supplied.bindings
	var result: Dictionary
	if _kind=="pass":
		result=model_adapter.build_root(_pack,bindings)
	else:
		bindings=bindings.duplicate(true)
		# Actual Attendance_All ProjectNodes and the corresponding source
		# daily/promotion buttons. Only the component visibility changes;
		# source On/Off decorative variants and event-version assignments are
		# not inferred. The second named promotion needs its own version link.
		for offset: int in [24332,24016]:
			var child: Dictionary=bindings.get(offset,{"role":"project","bindings":{}}).duplicate(true)
			child.visible=(_attendance_tab=="daily") if offset==24332 else (_attendance_tab=="promotion")
			bindings[offset]=child
		for offset: int in [20764,19636,8100,7020]:bindings[offset]={"role":"button","activate":Callable(self,"show_attendance_tab").bind("daily")}
		for offset: int in [16948,15860,4332,3244]:bindings[offset]={"role":"button","activate":Callable(self,"show_attendance_tab").bind("promotion")}
		result=Screens.build(_pack,"attendance",session,bindings)
	if result.get("ok",false):
		session.connect("action_result",Callable(self,"_on_action_result"))
		result["controller"]=self
	return result

func bind_presented(scene: Node2D, session: RefCounted) -> void:
	if _session==null or _session.get_ref()!=session:return
	if not is_instance_valid(scene) or scene.get("source_member")!=Screens.ROOTS[_kind].member:return
	_scene=weakref(scene)

func show_attendance_tab(tab: String) -> Dictionary:
	if _kind!="attendance" or tab not in ["daily","promotion"]:return _fail("source_attendance_tab_unknown")
	var scene: Object=_scene.get_ref() if _scene!=null else null
	if scene==null or not scene.is_inside_tree() or not scene.is_visible_in_tree():return _fail("presentation_unavailable")
	var daily: Dictionary=scene.set_bound_visible(24332,tab=="daily")
	if not daily.get("ok",false):return daily
	var promotion: Dictionary=scene.set_bound_visible(24016,tab=="promotion")
	if not promotion.get("ok",false):return promotion
	_attendance_tab=tab
	return {"ok":true,"tab":tab,"transaction_performed":false}

func _on_action_result(result: Dictionary) -> void:
	# Existing game presentation may display its original confirmation/result
	# component. This hook never confirms a ready plan by itself.
	action_result.emit(result.duplicate(true))

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
