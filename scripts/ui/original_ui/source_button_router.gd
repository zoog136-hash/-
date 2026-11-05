extends RefCounted
## Ordered routing to actual existing source buttons only. Root supplies the
## context/candidate order and excludes PointerTransfer-owned slot controls.
## No global input, hit geometry, mouse emulation or gesture policy lives here.
const BUTTON_SCRIPT_PATH="res://scripts/ui/original_ui/source_button.gd"
var _captured: WeakRef
var _touch_index: int=-1

func is_capturing() -> bool:
	return _touch_index>=0

func route(event: InputEvent, viewport_point: Vector2, candidates: Array) -> Dictionary:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):return {"handled":false,"activated":false}
	if _touch_index>=0:
		var button: Object=_captured.get_ref() if _captured!=null else null
		if not _available(button):
			# This gesture was already owned. Do not pass its invalidated
			# release/drag through to the world or retarget it to another button.
			cancel()
			return {"handled":true,"activated":false,"capture_released":true}
		if event.index!=_touch_index:return {"handled":true,"activated":false,"capture_preserved":true}
		var result: Dictionary=button.call("handle_native_touch",event,viewport_point)
		var finished: bool=event is InputEventScreenTouch and (not event.pressed or event.canceled)
		if finished or not _available(button):cancel()
		# Retain ownership even if the button disarmed itself after hiding or
		# becoming disabled; it never licenses a second target for this event.
		result["handled"]=true
		return result
	if not viewport_point.is_finite() or not event is InputEventScreenTouch or not event.pressed or event.canceled or event.index<0:return {"handled":false,"activated":false}
	for candidate: Variant in candidates:
		if not _available(candidate):continue
		var result: Dictionary=candidate.call("handle_native_touch",event,viewport_point)
		if not result.get("handled",false):continue
		# A callback normally cannot run on a press, but a source button may
		# invalidate during delivery. Capture only a still-live original.
		if _available(candidate):
			_captured=weakref(candidate)
			_touch_index=event.index
		else:
			if _actual_button(candidate):candidate.call("cancel_native_touch")
		return result
	return {"handled":false,"activated":false}

func cancel() -> void:
	var button: Object=_captured.get_ref() if _captured!=null else null
	# Clear router ownership before invoking the existing button API.
	_captured=null
	_touch_index=-1
	if _actual_button(button):button.call("cancel_native_touch")

static func _actual_button(value: Variant) -> bool:
	if not value is Node2D or not is_instance_valid(value) or value.is_queued_for_deletion():return false
	var script: Script=value.get_script()
	return script!=null and script.resource_path==BUTTON_SCRIPT_PATH and value.has_method("handle_native_touch") and value.has_method("cancel_native_touch")

static func _available(value: Variant) -> bool:
	return _actual_button(value) and value.is_visible_in_tree() and value.get("current_state")!="disabled"
