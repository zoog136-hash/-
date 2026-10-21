extends SceneTree
# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_NATIVE_PNG_PACK
## Main loads bundled native art automatically while retaining the ordinary save.
const REGISTRY = preload("res://scripts/maps/native_png_registry.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);printerr("NATIVE_NORMAL_FAIL: "+label)
func ticks(n: int) -> void:
	for i: int in range(n): await physics_frame
func run() -> void:
	if OS.get_environment("TWILIGHT_NATIVE_PNG_PACK").is_empty():
		print("NATIVE_NORMAL_SKIP: actual private pack required; no PNG validation claimed");quit();return
	check(not REGISTRY.enabled(),"ordinary launch without replacement flag")
	check(REGISTRY.installed(),"actual pinned private pack installed")
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world)
	check(QA.enter_game(world),"actual Main character entry")
	world.set_process(false);world.save_timer=-100000
	check(world.maps.size()==27,"25 persistent legacy IDs plus two independent temples")
	check(REGISTRY.menu_entries(world.maps).size()==27,"temples available in ordinary region selection")
	check(world.maps_by_id.yahee_temple.name=="야히의신전" and world.maps_by_id.balrog_temple.name=="발록의 시전","exact user display names")
	for mid: String in ["albino_01","albino_02","albino_03","escaros_01","escaros_05"]:
		world._set_map(mid,false)
		check(world.field_map is NativePngField and world.active_map_id==mid,mid+" normal save ID shows verified native PNG")
		check(not world.field_map.data.monster_spawn.is_empty(),mid+" registered PNG encounter population retained")
	world._set_map("albino_04",false)
	check(not world.field_map is NativePngField and world.active_map_id=="albino_04","Albino fourth historical ID remains legacy")
	world._set_map("aden_world",false)
	var bosses: Dictionary=world.field_population.boss_director.export_state().bosses.duplicate(true)
	var db_hash: String=FileAccess.get_sha256("res://data/game_db_v17.json")
	world.gold=128901
	for mid: String in ["yahee_temple","balrog_temple"]:
		world._set_map(mid,false);world.portal_cooldown=10000
		check(world.active_map_id==mid and world.field_map is NativePngField,mid+" real PNG field loads in ordinary game")
		await ticks(4)
		var renderer: NativePngRenderer=world.field_renderer
		check(renderer.chunks.size()>0,mid+" actual native chunk textures")
		check(not world.field_map.data.monster_spawn.is_empty() and world.field_population.slots.size()>0,mid+" provisional registered monsters populate temple")
		check(world.field_map.data.monster_spawn.all(func(row: Dictionary) -> bool: return str(row.mode)!="boss"),mid+" no invented named temple boss")
		for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
		var start: Vector2=world.player.global_position
		world._set_click_destination(start+Vector2(32,0));await ticks(24)
		check(world.player.global_position.distance_to(start)>16,mid+" actual player moves")
		world.player.clear_click_path();world.player.velocity=Vector2.ZERO
		var saved: Vector2=world.player.global_position
		world._save_game(true)
		check(world.save_path()==world.SAVE_PATH,mid+" retains ordinary character save namespace")
		world._set_map("aden_world",false);world._load_game(true)
		check(world.active_map_id==mid and not world.source_save_blocked,mid+" ordinary save reenters temple with pack")
		check(world.gold==128901 and world.player.global_position.distance_to(saved)<16,mid+" progress and compatible native pixels restored")
		check(world.field_population.boss_director.export_state().bosses==bosses,mid+" all legacy boss lives and cooldowns retained")
		world.player.global_position=start;world.portal_cooldown=0;world.set_process(true)
		world._set_click_destination(start-Vector2(60,0));await ticks(45);world.set_process(false)
		check(world.active_map_id=="aden_world",mid+" real return portal reaches existing world")
	world._set_map("yahee_temple",false);world._save_game(true)
	var saved_hash: String=FileAccess.get_sha256(world.save_path())
	var installed: String=OS.get_environment("TWILIGHT_NATIVE_PNG_PACK")
	OS.set_environment("TWILIGHT_NATIVE_PNG_PACK",OS.get_user_data_dir()+"/absent-pack")
	world._set_map("aden_world",false)
	var preserved_field: PlayableField=world.field_map
	var preserved_renderer: FieldRenderer=world.field_renderer
	world.pending_attack={"probe":true,"id":999}
	var combat_generation: int=world.combat_generation
	world._set_map("balrog_temple",false)
	check(world.active_map_id=="aden_world" and world.field_map==preserved_field and world.field_renderer==preserved_renderer,"pack removed after registration preserves actual Aden field and renderer without an empty substitute temple")
	check(world.combat_generation==combat_generation and world.pending_attack=={"probe":true,"id":999},"failed private map entry preserves pending combat")
	world._load_game(true);world._save_game(true)
	check(world.source_save_blocked and FileAccess.get_sha256(world.save_path())==saved_hash,"missing pack preserves the ordinary temple save byte for byte")
	OS.set_environment("TWILIGHT_NATIVE_PNG_PACK",installed);world._load_game(true)
	check(not world.source_save_blocked and world.active_map_id=="yahee_temple","restored pack resumes the preserved ordinary save")
	# Review updates may close a formerly walkable pixel. Preserve progression
	# and restore the safe entry instead of reviving inside the new obstacle.
	world._set_map("yahee_temple",false)
	var inspected_entry: Vector2=world.player.global_position
	world.player.global_position=inspected_entry+Vector2(32,0);world._save_game(true)
	var old_save: Dictionary=REGISTRY.read_json(world.save_path())
	old_save.native_png_review_sha256="previous-review";old_save.map_layout_revision=2026101902
	check(preload("res://scripts/skills/save_writer.gd").write(world.save_path(),old_save)==OK,"old review save fixture written through real writer")
	world._set_map("aden_world",false);world.gold=1;world._load_game(true)
	check(not world.source_save_blocked and world.gold==128901,"geometry revision keeps ordinary character progression")
	check(world.active_map_id=="yahee_temple" and world.player.global_position.distance_to(inspected_entry)<1,"geometry revision resets old pixels to inspected safe entry")
	check(world.field_population.boss_director.export_state().bosses==bosses,"geometry revision keeps legacy boss state")
	check(FileAccess.get_sha256("res://data/game_db_v17.json")==db_hash,"combat, monsters, bosses, items and rewards remain byte-identical")
	print("NATIVE_NORMAL_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"ordinary_temple_travel":true,"legacy_replacements":false}))
	world.queue_free();await ticks(3);quit(0 if failures.is_empty() else 1)
