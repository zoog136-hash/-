extends SceneTree
## Exact physical edges and compatible data corrections; no synthetic floor.
const REGISTRY=preload("res://scripts/maps/native_png_registry.gd")
const FIELD=preload("res://scripts/maps/native_png_field.gd")
var checks: int=0
var failures: Array[String]=[]
var metrics: Array[Dictionary]=[]

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("NATIVE_ROUTE_RECOVERY_FAIL "+label)

func digest(values: PackedInt32Array) -> String:
	var context:=HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(values.to_byte_array())
	return context.finish().hex_encode()

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var plan: Dictionary=REGISTRY.plan()
	check(not plan.is_empty(),"source and correction identities verified")
	if plan.is_empty():quit(1);return
	var corrections: Dictionary=REGISTRY.read_json(REGISTRY.NAVIGATION_CORRECTIONS)
	var original: Dictionary=plan.duplicate(true)
	for mid: String in corrections.maps:
		var patch: Dictionary=corrections.maps[mid]
		for polygon: Array in patch.get("walk_polygons_add",[]):original.maps[mid].walk_polygons.erase(polygon)
		for replacement: Dictionary in patch.get("route_checks_replace",[]):
			var index: int=original.maps[mid].route_checks.find(replacement.to)
			check(index>=0,mid+" correction retains the original review obligation")
			if index>=0:original.maps[mid].route_checks[index]=replacement.from
	for mid: String in ["domination_summit","escaros_world"]:
		var pack_root: String=REGISTRY.domination_root() if mid=="domination_summit" else REGISTRY.root_path()
		var manifest: Dictionary=REGISTRY.read_json(pack_root+"/"+mid+"/manifest.json")
		check(not manifest.is_empty(),mid+" actual committed manifest exists")
		if manifest.is_empty():continue
		var before: NativePngField=FIELD.new()
		var field: NativePngField=FIELD.new()
		before.configure_png(mid,original,manifest,pack_root+"/"+mid)
		field.configure_png(mid,plan,manifest,pack_root+"/"+mid)
		var old_grid: PackedInt32Array=before.navigation_snapshot().solid_runs
		var new_grid: PackedInt32Array=field.navigation_snapshot().solid_runs
		check(old_grid==new_grid,mid+" every physical solid cell unchanged")
		check(before.reachable==field.reachable,mid+" reachable raster unchanged")
		check(before.solid_rectangles()==field.solid_rectangles(),mid+" physical raster rectangles unchanged")
		check(JSON.stringify(before.spawn_cells)==JSON.stringify(field.spawn_cells),mid+" every spawn candidate unchanged")
		check(before.data.monster_spawn==field.data.monster_spawn,mid+" encounter identities and capacity unchanged")
		check(before.data.portal==field.data.portal and before.data.npc_spawn==field.data.npc_spawn,mid+" service and portal coordinates unchanged")
		check(before.data.spawn_position==field.data.spawn_position,mid+" player entry unchanged")
		check(before.data.layout_revision==field.data.layout_revision,mid+" save layout revision unchanged")
		check(before.data.route_checks.size()==field.data.route_checks.size(),mid+" no review destination removed")
		for replacement: Dictionary in corrections.maps[mid].get("route_checks_replace",[]):
			var old_point:=Vector2(replacement.from[0],replacement.from[1])
			var new_point:=Vector2(replacement.to[0],replacement.to[1])
			check(not before.line_clear(old_point,old_point),mid+" previous exact review foot was physically invalid")
			check(field.line_clear(new_point,new_point),mid+" corrected exact review foot is physically clear")
			check(new_point.distance_to(old_point)<12.0,mid+" same local destination retained")
		var spawn:=Vector2(field.data.spawn_position[0],field.data.spawn_position[1])
		var cold_usec: int=0
		var warm_target:=Vector2.INF
		for raw: Array in field.data.route_checks:
			var target:=Vector2(raw[0],raw[1])
			var cold: bool=field.precise_routes==null
			var started: int=Time.get_ticks_usec()
			var route: PackedVector2Array=field.path(spawn,target)
			var elapsed: int=Time.get_ticks_usec()-started
			if cold and field.precise_routes!=null:cold_usec=elapsed;warm_target=target
			check(field.line_clear(target,target),mid+" exact destination has full foot clearance "+str(target))
			check(not route.is_empty(),mid+" original destination remains connected "+str(target))
			if route.is_empty():continue
			check(route[-1].is_equal_approx(target),mid+" route reaches the exact corrected destination")
			var previous: Vector2=spawn
			for point: Vector2 in route:
				check(field.line_clear(previous,point),mid+" every returned segment physically clear")
				previous=point
		var warm_usec: int=0
		if warm_target.is_finite():
			var began: int=Time.get_ticks_usec()
			for _repeat: int in range(100):field.path(spawn,warm_target)
			warm_usec=(Time.get_ticks_usec()-began)/100
			var shifted_start: Vector2=spawn+Vector2(1,1)
			var shifted_target: Vector2=warm_target+Vector2(1,1)
			var shifted: PackedVector2Array=field.path(shifted_start,shifted_target)
			check(not shifted.is_empty(),mid+" cached cell pair supports moved endpoints")
			if not shifted.is_empty():
				check(shifted[-1].is_equal_approx(shifted_target),mid+" cached route reaches the updated target")
				var previous: Vector2=shifted_start
				for point: Vector2 in shifted:
					check(field.line_clear(previous,point),mid+" cached route rechecks moved endpoint clearance")
					previous=point
			check(field.precise_routes.route_cache.size()<=128,mid+" route cache is bounded")
		var direct: Vector2=spawn+Vector2(8,0)
		check(field.line_clear(spawn,direct),mid+" representative direct route is actually clear")
		var direct_started: int=Time.get_ticks_usec()
		for _repeat: int in range(100):field.path(spawn,direct)
		var direct_usec: int=(Time.get_ticks_usec()-direct_started)/100
		metrics.append({"map":mid,"physical_grid_sha256":digest(new_grid),"destinations":field.data.route_checks.size(),"cold_route_usec":cold_usec,"cached_route_average_usec":warm_usec,"direct_route_average_usec":direct_usec,"graph_points":field.precise_routes.get_point_count() if field.precise_routes!=null else 0})
		field.configure_png(mid,plan,manifest,pack_root+"/"+mid)
		check(field.precise_routes==null,mid+" reconfigure invalidates exact-edge cache")
	print("NATIVE_ROUTE_RECOVERY_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics}))
	if failures.is_empty():print("NATIVE_ROUTE_RECOVERY_OK")
	quit(0 if failures.is_empty() else 1)
