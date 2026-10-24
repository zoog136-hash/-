extends SceneTree
## Independent historical unit fixtures; real saves, pack, actor and field.
const QA=preload("res://tests/qa_class_selection.gd")
const PNG=preload("res://scripts/maps/native_png_registry.gd")
const WRITER=preload("res://scripts/skills/save_writer.gd")
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("ADEN_SCALE_FAIL ",label)
func run() -> void:
	if not PNG.extra_installed():print("ADEN_SCALE_SKIP: actual pinned Aden PNG required");quit();return
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world);QA.enter_game(world)
	world.set_process(false);world.save_timer=-100000;world._set_map("aden_world",false)
	check(world.field_map is NativePngField,"actual native Aden")
	var field: NativePngField=world.field_map
	check(field.artwork_scale==6 and field.data.layout_revision==2026102301,"measured display units")
	check(world.player.scale==Vector2.ONE and world.player.class_sprite.scale==Vector2.ONE and world.player.move_speed==210,"actor sprite and movement unchanged")
	check(world.player.get_node("CollisionShape2D").shape.radius==4,"actual foot remains 4px")
	world.gold=987654;world._save_game(true)
	var fixture: Dictionary=PNG.read_json(world.save_path())
	var boss_lives: Dictionary=fixture.monster_world.duplicate(true)
	# Source-native coordinate in the reviewed entry plaza, not a generated ruler.
	var source_position:=Vector2(11700,2915)
	check(field.point_clear(source_position*6),"historical source point on reviewed floor")
	for revision: int in [2026102002,2026102003]:
		var old_scale: float=1 if revision==2026102002 else 2
		var saved: Dictionary=fixture.duplicate(true);saved.map_layout_revision=revision
		saved.position=[source_position.x*old_scale,source_position.y*old_scale]
		saved.native_png_review_sha256=saved.native_png_plan_sha256
		check(WRITER.write(world.save_path(),saved)==OK,"historical save written "+str(revision))
		var hash: String=FileAccess.get_sha256(world.save_path())
		world.gold=1;world._load_game(true)
		check(not world.source_save_blocked and world.active_map_id=="aden_world","historical revision accepted "+str(revision))
		check(world.player.global_position.distance_to(source_position*6)<1,"source position converted exactly once "+str(revision))
		check(world.gold==987654,"progression survives "+str(revision))
		check(FileAccess.get_sha256(world.save_path())==hash and FileAccess.get_sha256(world.save_path()+".pre-aden-scale-"+hash)==hash,"original bytes and SHA backup preserved "+str(revision))
		world._save_game(true);var migrated: Dictionary=PNG.read_json(world.save_path())
		check(migrated.map_layout_revision==2026102301,"new units recorded "+str(revision))
		world._load_game(true);check(world.player.global_position.distance_to(source_position*6)<1,"current revision never multiplied twice")
		for id: String in boss_lives.get("bosses",{}):
			var before: Dictionary=boss_lives.bosses[id];var after: Dictionary=migrated.monster_world.bosses.get(id,{})
			for key: String in ["hp","phase","ready_at"]:check(before.get(key)==after.get(key),"boss life/cooldown retained "+id+" "+key)
	var unknown: Dictionary=fixture.duplicate(true);unknown.map_layout_revision=91234
	WRITER.write(world.save_path(),unknown);var hash: String=FileAccess.get_sha256(world.save_path());world._load_game(true)
	check(world.source_save_blocked and world._save_game(true)!=OK and FileAccess.get_sha256(world.save_path())==hash,"unknown units fail closed without changing save")
	# Foreign-map coordinates are already in that map's own frame.
	var raw: Dictionary=PNG.read_json(PNG.EXTRA_PLAN_PATH).maps.aden_world
	for portal: Dictionary in field.data.portal:
		var prior: Dictionary=raw.portals.filter(func(p: Dictionary)->bool:return p.id==portal.id)[0]
		if str(portal.target_map)!="aden_world" and prior.has("target_position"):check(portal.target_position==prior.target_position,"foreign target not rescaled "+str(portal.id))
	print("ADEN_SCALE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"engine":Engine.get_version_info().string}))
	world.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
