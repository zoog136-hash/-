extends SceneTree
## Real Main/pack save compatibility. Render proof is the separate OpenGL suite.
const REGISTRY=preload("res://scripts/maps/native_png_registry.gd")
const QA=preload("res://tests/qa_class_selection.gd")
const WRITER=preload("res://scripts/skills/save_writer.gd")
# Independent historical fixture from PR #137 commit 594438d, not the current
# migration table: changing the accepted provenance must not change this test.
const ENTRY_PLAN_SHA256: String="6dddc9772b9b1605a0aeaaa1b3a52e6ae88aa99ecb7d3e9b4ddd9946fdb83da4"
const MAP_IDS: Array[String]=["aden_world","faith_01","faith_02","faith_03","faith_04"]
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);printerr("ADEN_FAITH_SAVE_FAIL: "+label)
func finish(world: TwilightWorld) -> void:
	print("ADEN_FAITH_SAVE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"ACTUAL_MAIN_SAVE_MIGRATION; RENDER_VALIDATION_SEPARATE"}))
	world.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
func run() -> void:
	if not REGISTRY.extra_installed():
		print("ADEN_FAITH_SAVE_SKIP: actual verified private PNG pack required");quit();return
	var child: bool="--legacy-save-child" in OS.get_cmdline_user_args()
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world)
	world.set_process(false);world.save_timer=-100000
	if child:
		var saved: Dictionary=REGISTRY.read_json(world.save_path())
		check(not world.source_save_blocked and world.active_map_id=="faith_02","explicit legacy mode restores existing map ID")
		check(not world.field_map is NativePngField,"explicit legacy mode uses actual previous terrain")
		check(world.gold==1234567 and world.level==int(saved.level),"explicit legacy mode retains latest progression")
		check(JSON.parse_string(JSON.stringify(world.inventory))==saved.inventory,"explicit legacy mode retains inventory quantities")
		check(JSON.parse_string(JSON.stringify(world.item_instances))==saved.item_instances,"explicit legacy mode retains physical equipment IDs/enhancement")
		check(world.player.global_position.distance_to(world._spawn_position())<1 and world.field_map.walkable(world.player.global_position),"PNG pixels migrate to safe legacy entry")
		await finish(world);return
	check(not REGISTRY.enabled(),"ordinary character save migration fixture")
	check(QA.enter_game(world),"actual Main character entry")
	world._set_map("faith_02",false);world.gold=1234567;world._save_game(true)
	var fixture: Dictionary=REGISTRY.read_json(world.save_path())
	fixture.erase("native_png_plan_sha256");fixture.erase("native_png_review_sha256")
	fixture.map_layout_revision=1;fixture.position=[200,200]
	check(WRITER.write(world.save_path(),fixture)==OK,"legacy schema fixture through real save writer")
	var legacy_hash: String=FileAccess.get_sha256(world.save_path())
	var prior_backup: String=FileAccess.get_sha256(world.save_path()+".pre-native-png") if FileAccess.file_exists(world.save_path()+".pre-native-png") else ""
	var installed: String=OS.get_environment("TWILIGHT_ADEN_FAITH_PNG_PACK")
	var default_root: String=ProjectSettings.globalize_path("user://aden_faith_png_maps")
	check(not DirAccess.dir_exists_absolute(default_root),"isolated app-data corruption fixture")
	DirAccess.make_dir_recursive_absolute(default_root)
	var bad:=FileAccess.open(default_root+"/index.json",FileAccess.WRITE)
	bad.store_string("corrupt negative-test index");bad.close()
	# Override a valid Git bundle with the isolated corrupt installation.
	OS.set_environment("TWILIGHT_ADEN_FAITH_PNG_PACK",default_root)
	world.gold=77;world._load_game(true);world._save_game(true)
	check(world.source_save_blocked and world.gold==77,"corrupt pack cannot partially mutate a legacy character")
	check(FileAccess.get_sha256(world.save_path())==legacy_hash,"corrupt installation cannot overwrite old ordinary save bytes")
	DirAccess.remove_absolute(default_root+"/index.json");DirAccess.remove_absolute(default_root)
	OS.set_environment("TWILIGHT_ADEN_FAITH_PNG_PACK",installed);world._load_game(true)
	check(not world.source_save_blocked and world.field_map is NativePngField and world.gold==1234567,"verified pack migrates legacy progression")
	check(world.player.global_position.distance_to(world._spawn_position())<1,"legacy pixels replaced with inspected PNG entry")
	check(FileAccess.get_sha256(world.save_path()+".pre-native-png")== (legacy_hash if prior_backup.is_empty() else prior_backup),"one-time pre-PNG save backup retains original bytes")
	world._save_game(true)
	var native_hash: String=FileAccess.get_sha256(world.save_path())
	for legacy_switch: String in ["--legacy-map-layouts","--legacy-aden-faith-layouts"]:
		var args:=PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/aden_faith_png_save_migration_test.gd","--",legacy_switch,"--legacy-save-child"])
		var pid: int=OS.create_process(OS.get_executable_path(),args,false)
		check(pid>0,"isolated legacy-mode child started with the same test-owned save: "+legacy_switch)
		if pid>0:
			var deadline: int=Time.get_ticks_msec()+60000
			while OS.is_process_running(pid) and Time.get_ticks_msec()<deadline: await process_frame
			if OS.is_process_running(pid): OS.kill(pid);check(false,"legacy child completed before deadline")
			else: check(OS.get_process_exit_code(pid)==0,"actual explicit legacy restart restores latest native-save progression: "+legacy_switch)
	check(FileAccess.get_sha256(world.save_path())==native_hash,"loading in legacy mode does not silently overwrite PNG save bytes")
	world.process_mode=Node.PROCESS_MODE_DISABLED
	check_historical_native_upgrade(world)
	await finish(world)

func normalized(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))

func check_rejected_upgrade(world: TwilightWorld, fixture: Dictionary, label: String) -> void:
	check(WRITER.write(world.save_path(),fixture)==OK,label+" fixture saved")
	var before: String=FileAccess.get_sha256(world.save_path())
	var live_gold: int=world.gold
	var live_position: Vector2=world.player.global_position
	var live_inventory: Dictionary=world.inventory.duplicate(true)
	world._load_game(true)
	check(world.source_save_blocked and world.gold==live_gold and world.player.global_position==live_position and world.inventory==live_inventory,label+" rejects before changing live progression")
	check(world._save_game(true)!=OK and FileAccess.get_sha256(world.save_path())==before,label+" keeps original save bytes and blocks overwriting")

func check_historical_native_upgrade(world: TwilightWorld) -> void:
	var fixture: Dictionary=REGISTRY.read_json(world.save_path())
	fixture.native_png_plan_sha256=ENTRY_PLAN_SHA256
	fixture.native_png_review_sha256=ENTRY_PLAN_SHA256
	fixture.map_layout_revision=2026102001
	fixture.position=[200,200] # Deliberately outside every inspected PNG entry.
	fixture.hp=17;fixture.mp=3;fixture.gold=7654321
	check(not fixture.item_instances.is_empty() and not fixture.equipped_items.is_empty(),"historical native fixture carries real physical equipment")
	# A valid persisted collection receipt makes this a nonempty progress test.
	var collection: Dictionary=world.equipment_collections.definitions()[0]
	var requirement: Dictionary=collection.requirements[0]
	var receipt_id: String="historical-native-137-receipt"
	var progress: Dictionary=fixture.equipment_collections
	progress.revision=13
	progress.progress={str(collection.id):{str(requirement.slot_id):[receipt_id]}}
	progress.receipts={receipt_id:{"instance_id":receipt_id,"collection_id":str(collection.id),"slot_id":str(requirement.slot_id),"canonical_name":str(requirement.name),"enchant":requirement.get("enchant",0)}}
	progress.favorites=[str(collection.id)]
	check(world.equipment_collections.check_load(fixture).is_empty(),"historical collection fixture uses the real validated save schema")
	var deadline: float=Time.get_unix_time_from_system()+86400.0
	var identities: Array[String]=["aden_world:드레이크","aden_world:dark_elder_encounter","aden_world:샌드 웜","aden_world:피닉스","aden_world:death_knight_encounter","faith_01:교만의 왕자 데우스","faith_02:탐욕의 여왕 벨리엘","faith_03:질투의 공주 이자벨","faith_04:분노의 주시자 라즈엘"]
	fixture.monster_world={"version":2,"game_seconds":137.0,"bosses":{}}
	for index: int in range(identities.size()):
		var cooling: bool=index in [1,2,6,8]
		fixture.monster_world.bosses[identities[index]]={"phase":"cooldown" if cooling else "alive","hp":-1 if cooling else 71+index,"ready_at":deadline+index,"layout_revision":2026102001,"position":[200,200],"home":[200,200]}
	var unknown: Dictionary=fixture.duplicate(true)
	unknown.native_png_plan_sha256="f".repeat(64)
	check_rejected_upgrade(world,unknown,"unknown native plan hash")
	var wrong_revision: Dictionary=fixture.duplicate(true)
	wrong_revision.map_layout_revision=2026102000
	check_rejected_upgrade(world,wrong_revision,"known hash with unknown layout revision")
	var wrong_review: Dictionary=fixture.duplicate(true)
	wrong_review.native_png_review_sha256="e".repeat(64)
	check_rejected_upgrade(world,wrong_review,"known hash with unknown review")
	var installed: String=OS.get_environment("TWILIGHT_ADEN_FAITH_PNG_PACK")
	OS.set_environment("TWILIGHT_ADEN_FAITH_PNG_PACK",ProjectSettings.globalize_path("user://missing-native-upgrade-pack"))
	check_rejected_upgrade(world,fixture,"known historical save with unavailable current pack")
	OS.set_environment("TWILIGHT_ADEN_FAITH_PNG_PACK",installed)
	var original_hash: String=FileAccess.get_sha256(world.save_path())
	var backup_path: String=world.save_path()+".pre-aden-faith-population-"+original_hash
	var bad_backup:=FileAccess.open(backup_path,FileAccess.WRITE)
	bad_backup.store_string("damaged historical backup");bad_backup.close()
	check_rejected_upgrade(world,fixture,"historical backup could not be verified")
	DirAccess.remove_absolute(backup_path)
	for mid: String in MAP_IDS:
		fixture.map_id=mid
		check(WRITER.write(world.save_path(),fixture)==OK,mid+" historical native save fixture written")
		original_hash=FileAccess.get_sha256(world.save_path())
		backup_path=world.save_path()+".pre-aden-faith-population-"+original_hash
		world._load_game(true)
		check(not world.source_save_blocked and world.field_map is NativePngField and world.active_map_id==mid,mid+" historical native plan migrates into actual current field")
		check(world.player.global_position.distance_to(world._spawn_position())<1 and world.field_map.point_clear(world.player.global_position),mid+" incompatible historical pixels reset to inspected body-clear entry")
		check(FileAccess.get_sha256(world.save_path())==original_hash and FileAccess.get_sha256(backup_path)==original_hash,mid+" loading preserves original bytes and verifies distinct historical backup")
		check(world.hp==int(fixture.hp) and world.mp==int(fixture.mp) and world.gold==int(fixture.gold) and world.level==int(fixture.level) and world.experience==int(fixture.experience),mid+" HP MP gold and character progression survive")
		for key: String in ["inventory","item_instances","equipped_items","equipped_catalog","enhancement_levels"]:
			check(normalized(world.get(key))==fixture[key],mid+" preserves "+key)
		check(normalized(world.equipment_collections.export_state())==normalized(fixture.equipment_collections),mid+" nonempty collection receipts/progress survive")
		var states: Dictionary=world.legacy_population.boss_director.states
		for identity: String in identities:
			var expected: Dictionary=fixture.monster_world.bosses[identity]
			var state: Dictionary=states.get(identity,{})
			check(not state.is_empty() and state.phase==expected.phase and int(state.hp)==int(expected.hp) and float(state.ready_at)==float(expected.ready_at),mid+" retains boss life HP and exact cooldown: "+identity)
		for slot: Dictionary in world.field_population.slots:
			if str(slot.region.get("mode","normal"))!="boss": continue
			var identity: String=world.legacy_population.boss_director.key(mid,slot.region)
			var expected: Dictionary=fixture.monster_world.bosses.get(identity,{})
			if expected.is_empty(): check(false,mid+" boss uses historical identity: "+identity);continue
			var actor: Variant=slot.monster
			check((not is_instance_valid(actor)) if expected.phase=="cooldown" else (is_instance_valid(actor) and actor.hp==int(expected.hp) and world.field_map.spawn_contains(slot.region,actor.global_position)),identity+" restored boss remains in cooldown or alive in its reviewed encounter")
		check(world._save_game(true)==OK,mid+" upgraded save commits through existing atomic writer")
		var upgraded: Dictionary=REGISTRY.read_json(world.save_path())
		check(upgraded.native_png_plan_sha256==REGISTRY.plan_hash(mid) and int(upgraded.map_layout_revision)==(2026102301 if mid=="aden_world" else 2026102002),mid+" next save records current verified plan/revision")
		check(FileAccess.get_sha256(backup_path)==original_hash,mid+" original backup remains unchanged after current save")
	world._load_game(true)
	check(not world.source_save_blocked and world.active_map_id=="faith_04" and world.gold==int(fixture.gold),"current native save reloads after historical migration")
