extends "res://scripts/maps/native_png_field.gd"
## Diagnostic subclass only; every call delegates to the real implementation.
var timings: Dictionary={"reachability_us":[]}
func configure_png(mid: String,plan: Dictionary,manifest: Dictionary,local_root: String) -> void:
	var start: int=Time.get_ticks_usec()
	super.configure_png(mid,plan,manifest,local_root)
	timings.configure_png_us=Time.get_ticks_usec()-start
func configure(definition: Dictionary) -> void:
	var start: int=Time.get_ticks_usec()
	super.configure(definition)
	timings.base_configure_us=Time.get_ticks_usec()-start
func _build_reachability() -> void:
	var start: int=Time.get_ticks_usec()
	super._build_reachability()
	timings.reachability_us.append(Time.get_ticks_usec()-start)
func build_physics(parent: Node2D) -> StaticBody2D:
	var start: int=Time.get_ticks_usec()
	var result: StaticBody2D=super.build_physics(parent)
	timings.build_physics_us=Time.get_ticks_usec()-start
	return result

var detailed: bool=OS.get_environment("TWILIGHT_ENTRY_DETAIL")=="1"
var calls: Dictionary={}
func _record(label: String,elapsed: int) -> void:
	if not calls.has(label):calls[label]={"count":0,"us":0}
	calls[label].count+=1
	calls[label].us+=elapsed
func inside_navigable_area(point: Vector2) -> bool:
	if not detailed:return super.inside_navigable_area(point)
	var start: int=Time.get_ticks_usec()
	var result: bool=super.inside_navigable_area(point)
	_record("inside_navigable_area",Time.get_ticks_usec()-start)
	return result
func _inside_shape(p: Vector2,shape: Dictionary,padding: float) -> bool:
	if not detailed:return super._inside_shape(p,shape,padding)
	var start: int=Time.get_ticks_usec()
	var result: bool=super._inside_shape(p,shape,padding)
	_record("inside_shape",Time.get_ticks_usec()-start)
	return result
func is_safe(p: Vector2) -> bool:
	if not detailed:return super.is_safe(p)
	var start: int=Time.get_ticks_usec()
	var result: bool=super.is_safe(p)
	_record("is_safe",Time.get_ticks_usec()-start)
	return result
func region_at(p: Vector2) -> Dictionary:
	if not detailed:return super.region_at(p)
	var start: int=Time.get_ticks_usec()
	var result: Dictionary=super.region_at(p)
	_record("region_at",Time.get_ticks_usec()-start)
	return result
func spawn_contains(region: Dictionary,point: Vector2) -> bool:
	if not detailed:return super.spawn_contains(region,point)
	var start: int=Time.get_ticks_usec()
	var result: bool=super.spawn_contains(region,point)
	_record("spawn_contains",Time.get_ticks_usec()-start)
	return result
func navigation_snapshot() -> Dictionary:
	var start: int=Time.get_ticks_usec()
	var result: Dictionary=super.navigation_snapshot()
	if detailed:_record("navigation_snapshot",Time.get_ticks_usec()-start)
	return result
