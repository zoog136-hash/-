extends SceneTree
## Real Main, backend domain APIs and production save writer, without a custom
## content form. Ownership/pass-XP fixtures are explicit setup, not acquisition.
## Widget/confirmation/capture assertions remain in the historical custom-form
## audits under tests/audits; this suite does not claim original-UI execution.
const QA = preload("res://tests/qa_class_selection.gd")
const SOURCE = preload("res://scripts/unconfirmed523/source523.gd")
const WRITER = preload("res://scripts/skills/save_writer.gd")
const EXP = preload("res://scripts/experience_progression.gd")
const NOW: int = 1793800800 # 2026-11-04 14:00 UTC.
const MARKER: String = "user://unconfirmed523-main-evidence.json"

const NativeImageLoader = preload("res://tests/native_resource_loader.gd")

var loader: NativeImageLoader
var world
var rt
var checks: int = 0
var failures: Array[String] = []
var phase: String = "initial"

func _initialize() -> void:
	loader = NativeImageLoader.new()
	ResourceLoader.add_resource_format_loader(loader,true)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="): phase = arg.trim_prefix("--phase=")
	call_deferred("run")

func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		printerr("UNCONFIRMED523_MAIN_FAIL: " + label)
	return value

func same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(JSON.parse_string(JSON.stringify(a)),"",true,true) == JSON.stringify(JSON.parse_string(JSON.stringify(b)),"",true,true)

func frames() -> void:
	await process_frame
	await process_frame

func freeze() -> void:
	world.set_process(false)
	world.set_physics_process(false)
	world.save_timer = -1000000.0
	world.player.set_physics_process(false)
	world.player.set_auto_enabled(false)
	if world.field_population != null: world.field_population.set_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)

func has_custom_form(node: Node) -> bool:
	var script: Script = node.get_script()
	if script != null and script.resource_path in ["res://scripts/unconfirmed523/view.gd","res://tests/audits/unconfirmed523_custom_form.gd"]: return true
	for child: Node in node.get_children():
		if has_custom_form(child): return true
	return false

func presentation_separation() -> void:
	check(not world.hud.has_method("open_unconfirmed523"),"actual HUD exposes no custom content-form mount method")
	var hud_source: String = FileAccess.get_file_as_string(world.hud.get_script().resource_path)
	check(not "unconfirmed523/view.gd" in hud_source and not "audits/unconfirmed523_custom_form.gd" in hud_source,"production HUD imports neither former nor archived custom form")
	world.hud.toggle_menu()
	check(world.hud.menu_page.find_child("MenuTile_unconfirmed523",true,false) == null,"actual HUD menu contains no custom content-form entry")
	check(not has_custom_form(world.hud),"actual Main HUD tree has no mounted custom content form")
	world.hud._close_workspace()
	var before: Array = ownership()
	var disk: String = FileAccess.get_sha256(world.save_path())
	var unavailable: Dictionary = rt.request_presentation("events")
	check(not unavailable.get("ok",false) and unavailable.get("code") == "presentation_unavailable","Main backend reports missing original UI adapter explicitly")
	check(same(before,ownership()) and FileAccess.get_sha256(world.save_path()) == disk,"missing UI adapter preserves live ownership domain RNG and exact save bytes")

func recognized_item_without_presentation() -> void:
	var grails: Array = ids_for(338438)
	if not check(not grails.is_empty(),"recognized-item probe uses a genuinely owned source grail"): return
	var item_name: String = str(world.item_instances[str(grails[0])].name)
	var before: Array = ownership()
	var disk: String = FileAccess.get_sha256(world.save_path())
	check(rt.try_use(item_name),"recognized owned source item remains handled while original UI adapter is absent")
	world._on_inventory_item_activated(item_name)
	check(same(before,ownership()) and FileAccess.get_sha256(world.save_path()) == disk,"ordinary Main inventory activation cannot fall through to another item owner while UI is absent")
	world._use_quick_item(item_name)
	check(same(before,ownership()) and FileAccess.get_sha256(world.save_path()) == disk,"ordinary Main quick-item activation preserves recognized item while UI is absent")
	check(same(before,ownership()) and FileAccess.get_sha256(world.save_path()) == disk,"recognized item cannot consume activate reward or save through absent UI")
	check(not has_custom_form(world.hud),"recognized-item request never mounts the archived custom form")

func ownership() -> Array:
	return [world.gold,world.inventory.duplicate(true),world.item_instances.duplicate(true),world.next_item_instance_id,rt.state.duplicate(true),world.ain_service.export_state()]

func reload_ownership_matches(before: Array) -> bool:
	var after: Array = ownership()
	var labels: Array = ["gold","inventory","instances","next_native_id","domain_state_and_rng","ain"]
	for index: int in range(before.size()):
		if not same(before[index],after[index]):
			print("UNCONFIRMED523_RELOAD_DIFF " + JSON.stringify({"field":labels[index],"before":before[index],"after":after[index]}))
		if index != 5 and not same(before[index],after[index]): return false
	var ain_before: Dictionary = before[5].duplicate(true)
	var ain_after: Dictionary = after[5].duplicate(true)
	# Production Ain.import_state() observes offline time. At >=200 blessing
	# it advances only last_regen_at; that clock observation is not a debit.
	var earlier: int = int(ain_before.get("last_regen_at",0))
	var later: int = int(ain_after.get("last_regen_at",0))
	ain_before.erase("last_regen_at"); ain_after.erase("last_regen_at")
	return same(ain_before,ain_after) and later >= earlier

func ids_for(source_id: int) -> Array:
	var result: Array = []
	for uid: String in world.item_instances:
		if rt.native_id(world.item_instances[uid].get("record",{})) == source_id: result.append(uid)
	return result

func fixture_items() -> bool:
	var staged: Dictionary = {"inventory":world.inventory.duplicate(true),"item_instances":world.item_instances.duplicate(true),"gold":10000000,"next_item_instance_id":int(world.next_item_instance_id),"level":89,"experience":0,"exp_need":EXP.table_requirement(89),"stat_points":int(world.stat_points),"quest_state":world.quest_service.export_state()}
	for pair: Array in [[338438,1,2],[355334,6,1],[166594,2,1],[164683,1,1]]:
		var error: String = rt.stage_item(staged,int(pair[0]),int(pair[1]),0,int(pair[2]))
		if not check(error.is_empty(),"stage real source ownership %d: %s" % [int(pair[0]),error]): return false
	var staged_before: Dictionary = staged.duplicate(true)
	check(not rt.stage_item(staged,139931,1).is_empty() and same(staged,staged_before),"source TestItem jade139931 cannot enter production ownership")
	if not check(world._save_game(true,staged) == OK,"ownership fixture uses production atomic writer before live assignment"): return false
	for key: String in staged: world.set(key,staged[key])
	rt.rebuild()
	world._update_hud()
	return true

func persist_state(next: Dictionary) -> bool:
	if not check(world._save_game(true,{"unconfirmed523":next}) == OK,"explicit progression fixture saved before live assignment"): return false
	rt.state = next
	rt.rebuild()
	return true

func combat_and_hp_fixtures() -> void:
	# Real Monster and World consumers; this actor/identity is explicit test
	# setup, not a source-map spawn or natural NPC/supply claim.
	var monster = world.MONSTER_SCENE.instantiate()
	world.monsters_root.add_child(monster)
	monster.setup({"name":"conditional consumer fixture","hp":10000,"lv":1},world.player,world,null)
	monster.set_physics_process(false)
	await frames()
	var totals: Dictionary = rt.totals.duplicate(true)
	var conditional: Dictionary = rt.conditional_totals.duplicate(true)
	monster.set_meta("source_received_reduction_percent",50)
	world._deal_successful_player_hit(monster,100,false,"melee",true,false,{"final_blow":false})
	var baseline: int = 10000-monster.hp
	monster.hp=10000;monster.hp_bar.value=monster.hp
	rt.totals["ignore_melee_damage_reduction:percent"]=10
	world._deal_successful_player_hit(monster,100,false,"melee",true,false,{"final_blow":false})
	check(10000-monster.hp == baseline+10,"actual Main typed ignore reduces one existing percentage budget")
	rt.totals=totals
	monster.set_meta("source_received_reduction_percent",0)
	monster.hp=10000;monster.hp_bar.value=monster.hp
	world._deal_successful_player_hit(monster,100,false,"melee",true,false,{"final_blow":false})
	baseline=10000-monster.hp
	monster.undead=true
	rt.conditional_totals.undead={"undead_additional_max_damage:flat":5}
	var minimum: int=9999;var maximum: int=0
	for trial: int in range(30):
		monster.hp=10000;monster.hp_bar.value=monster.hp
		world._deal_successful_player_hit(monster,100,false,"melee",true,false,{"final_blow":false})
		var extra: int=10000-monster.hp-baseline
		minimum=mini(minimum,extra);maximum=maxi(maximum,extra)
	check(minimum>=1 and maximum<=5 and minimum<maximum,"actual Main undead physical rolls stay within source maximum and vary")
	monster.hp=10000;monster.hp_bar.value=monster.hp
	world._deal_successful_player_hit(monster,100,false,"magic",true,true,{"final_blow":false})
	check(10000-monster.hp == baseline,"source undead physical policy does not add damage to magic")
	rt.conditional_totals=conditional
	var started: Dictionary=rt.execute("challenge",{"op":"challenge_start","challenge_id":721,"local_policy":true})
	if check(started.get("ok",false),"actual Main local Challenge721 starts for HP consumer fixture"):
		monster.max_hp=101;monster.hp=101;monster.hp_bar.max_value=101;monster.hp_bar.value=101
		monster.source_m_npc_id=101841
		world._watch_unconfirmed_monster(weakref(monster))
		monster.take_damage(34)
		check(rt.state.domains.challenge.active.extra_sections.is_empty(),"raw HP67of101 stays above66percent without rounding into section")
		monster.take_damage(1)
		check(rt.state.domains.challenge.active.extra_sections == [241],"actual Monster HP signal crosses exact source66percent section once")
		monster.hp=90;monster.hp_bar.value=90
		monster.take_damage(25)
		check(rt.state.domains.challenge.active.extra_sections == [241],"healing and repeated threshold crossing cannot duplicate section")
		monster.take_damage(32)
		check(rt.state.domains.challenge.active.extra_sections == [241,251],"actual subsequent HP loss crosses second source section")
		check(rt.execute("challenge",{"op":"challenge_abandon"}).get("ok",false),"HP fixture abandons without minting completion or section rewards")
	monster.queue_free()
	await frames()

func final_cube_fixtures() -> void:
	var staged: Dictionary={"inventory":world.inventory.duplicate(true),"item_instances":world.item_instances.duplicate(true),"next_item_instance_id":int(world.next_item_instance_id)}
	if not check(rt.stage_item(staged,8951,8).is_empty(),"explicit fixture stages eight separate native8951 units"): return
	if not check(world._save_game(true,staged)==OK,"cube ownership fixture uses existing atomic writer"): return
	for key: String in staged: world.set(key,staged[key])
	check(ids_for(8951).size()==8,"source MaxStack1 preserves eight distinct cube identities")
	var before: Array=ownership()
	var disk: String=FileAccess.get_sha256(world.save_path())
	var rejected: Dictionary=rt.execute("events",{"action":"consume_item","item_id":8951})
	check(not rejected.get("ok",false) and same(before,ownership()),"actual8951 graph TestItem8961 blocks before consuming ownership counter rewards or RNG")
	check(FileAccess.get_sha256(world.save_path())==disk,"source TestItem leaf rejection preserves exact durable bytes")
	check(rt.state.domains.events.final_progress.get("8951",{}).is_empty(),"blocked native final bag creates no fictitious seventh completion history")
	var row: Dictionary = {}
	for value: Dictionary in rt.page("events").rows:
		if str(value.id) == "container:8951": row = value; break
	check(not row.is_empty() and not row.get("actions",[]).is_empty() and row.actions[0].get("disabled",false),"backend owned8951 action preserves source TestItem leaf rejection")
	check("시험용 보상 포함" in str(row.get("detail","")),"backend owned8951 detail explains the preserved source restriction")

func craft_progress_fixtures() -> void:
	# Existing TWILIGHT recipe, real Main writer and explicit ingredient fixture.
	# This verifies the pass event boundary, not source crafting/natural supply.
	var original_text: String=FileAccess.get_file_as_string(world.save_path())
	var ingredients: Dictionary=world.inventory.duplicate(true)
	ingredients["HP 물약"]=int(ingredients.get("HP 물약",0))+3
	ingredients["약초"]=int(ingredients.get("약초",0))+2
	if not check(world._save_game(true,{"inventory":ingredients})==OK,"craft ingredients fixture saves through existing owner boundary"):return
	world.inventory=ingredients
	world._sync_item_instances()
	var before: Array=ownership()
	var disk: String=FileAccess.get_sha256(world.save_path())
	var count: int=int(rt.state.event_counters.get("craft",0))
	world.equipment_collections.test_save_writer=func(_path: String,_payload: Dictionary)->Error:return ERR_CANT_CREATE
	world._craft_requested("healing_plus",1)
	check(same(before,ownership()) and FileAccess.get_sha256(world.save_path())==disk,"failed actual craft preserves ingredients products and pass event state together")
	world.equipment_collections.test_save_writer=Callable()
	world._craft_requested("healing_plus",1)
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(int(rt.state.event_counters.get("craft",0))==count+1,"successful actual craft records one pass event")
	check(int(saved.get("unconfirmed523",{}).get("event_counters",{}).get("craft",0))==count+1,"actual craft result and pass event share the same durable save")
	world._load_game(true);freeze()
	check(int(rt.state.event_counters.get("craft",0))==count+1,"immediate Main reload retains committed crafting progress")
	check(WRITER.write_text(world.save_path(),original_text)==OK,"restore exact pre-fixture profile through atomic writer")
	world._load_game(true);freeze()
	check(FileAccess.get_file_as_string(world.save_path())==original_text,"craft integration fixture preserves original profile bytes after verification")

func finish() -> void:
	write_resource_usage()
	print("UNCONFIRMED523_MAIN_RESULT " + JSON.stringify({"phase":phase,"checks":checks,"failures":failures,"raw_resource_paths":loader.read_paths.size(),"scope":"ACTUAL_MAIN_BACKEND_PRIVATE_SOURCE_ATOMIC_SAVE; NO_CUSTOM_FORM; EXPLICIT_OWNERSHIP_AND_PASS_XP_FIXTURES"}))
	if is_instance_valid(world): world.queue_free()
	await process_frame
	ResourceLoader.remove_resource_format_loader(loader)
	quit(0 if failures.is_empty() else 1)

func write_resource_usage() -> void:
	if not is_instance_valid(world) or not is_instance_valid(rt): return
	var native: Array=[]
	for path: String in loader.read_paths:
		var file: FileAccess=FileAccess.open(path,FileAccess.READ)
		if file!=null:native.append({"path":path,"bytes":file.get_length()})
	var tables: Array=[]
	for table: String in rt.source._tables:
		if rt.source._metadata.has(table):
			var meta: Dictionary=rt.source._metadata[table]
			tables.append({"path":str(rt.source.status().path)+"!"+str(meta.path),"decoded_bytes":int(meta.bytes),"sha256":str(meta.sha256)})
	var textures: Array=[]
	var store_script=load("res://scripts/maps/source_map_texture_store.gd")
	var store: Node=store_script.shared_ref.get_ref() if store_script.shared_ref!=null else null
	if is_instance_valid(store):
		for path: String in store.verified_files:
			var stamp: Array=store.verified_files[path]
			textures.append({"path":path,"bytes":int(stamp[1]),"sha256":str(stamp[0])})
	var pack: String=OS.get_environment("TWILIGHT_SOURCE_MAP_PACK")
	var report: Dictionary={"schema":1,"phase":phase,"profile_path":world.save_path(),"profile_sha256":FileAccess.get_sha256(world.save_path()),"integration_main_sha":OS.get_environment("TWILIGHT_264_MAIN_SHA"),"world_sha256":FileAccess.get_sha256("res://scripts/world.gd"),"runtime_sha256":FileAccess.get_sha256("res://scripts/unconfirmed523/runtime.gd"),"active_map":world.active_map_id,"active_field_script":world.field_map.get_script().resource_path if world.field_map!=null else "","active_map_manifest_path":pack+"/index.json","active_map_manifest_sha256":FileAccess.get_sha256(pack+"/index.json"),"content_archive":rt.source.status(),"content_archive_sha256":SOURCE.SOURCE_SHA256,"native_loader_reads":native,"parsed_source_entries":tables,"map_store_verified_reads":textures,"coverage_limit":"Scoped native ResourceLoader, parsed source entries and map-store SHA reads only; not a complete OS file-open trace or whole-game installation."}
	var output: FileAccess=FileAccess.open("user://unconfirmed523-resource-usage-"+phase+".json",FileAccess.WRITE)
	if output!=null:output.store_string(JSON.stringify(report,"\t"));output.close()

func run() -> void:
	if not check(OS.get_environment("TWILIGHT_523_MAIN_TEST") == "1","explicit isolated integration-test opt-in"):
		await finish(); return
	if not check(OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/"),"test profile isolated under /tmp"):
		await finish(); return
	if not check(not OS.get_environment("TWILIGHT_SOURCE_MAP_PACK").is_empty(),"explicit existing source-map pack"):
		await finish(); return
	var zip: String = OS.get_environment("TWILIGHT_523_SOURCE_ZIP")
	if not check(FileAccess.get_sha256(zip) == SOURCE.SOURCE_SHA256,"private common ZIP exact validated SHA"):
		await finish(); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SOURCE.SOURCE_PATH).get_base_dir())
	if not check(DirAccess.copy_absolute(zip,ProjectSettings.globalize_path(SOURCE.SOURCE_PATH)) == OK,"common ZIP copied to isolated user data before Main configure"):
		await finish(); return
	var scene: PackedScene = load("res://Main.tscn")
	if not check(scene != null,"actual Main scene parses and loads"):
		await finish(); return
	root.size = Vector2i(1280,720)
	world = scene.instantiate()
	world.unconfirmed523.test_now = NOW
	print("UNCONFIRMED523_MAIN_STAGE: actual Main ready")
	root.add_child(world)
	check(QA.enter_game(world),"ordinary Main class confirmation")
	if not check(world.player != null and world.player.get_script().can_instantiate() and world.hud != null,"Main actors and HUD initialized without script failure"):
		await finish(); return
	freeze()
	rt = world.unconfirmed523
	if not check(world.field_map != null and not world.source_save_blocked,"actual current source map boots without fallback"):
		await finish(); return
	check(world.active_map_id == "aden_world" and world.field_map.get_script().resource_path == "res://scripts/maps/source_map_runtime_field.gd","ordinary Aden entry uses current source field class")
	check(is_instance_valid(world.field_renderer) and world.field_renderer.get_script().resource_path == "res://scripts/maps/source_map_runtime_renderer.gd","actual Main uses current source renderer class")
	if not check(rt.source.ready() and rt.domains.size() == 3,"live host loads verified source and three authorized domains"):
		await finish(); return
	presentation_separation()
	check(loader.read_paths.size() > 0,"test loader reads existing real image/font/audio bytes")
	print("UNCONFIRMED523_MAIN_STAGE: current map and shared source ready")
	if phase == "reload":
		await reload_phase(); await finish(); return
	var initial_hp: int = world._effective_max_hp()
	var initial_xp: float = world._experience_multiplier()
	if not fixture_items(): await finish(); return
	recognized_item_without_presentation()
	check(world._effective_max_hp() == initial_hp + 50,"owned blessed source grail adds actual Main max HP50")
	check(is_equal_approx(world._experience_multiplier(),initial_xp+0.01),"owned source grail adds actual Main experience1percent")
	check(rt.context().owned.get("355334",0) == 6 and ids_for(338438).size() == 1,"native ownership IDs and exact stack quantity visible to domain")
	await combat_and_hp_fixtures()
	var native_totals: Dictionary = rt.totals.duplicate(true)
	var cooldown_before: float = world._skill_cooldown_factor()
	var damage_before: int = world._catalog_damage_bonus("melee")
	rt.totals["cast_speed:percent"] = float(rt.totals.get("cast_speed:percent",0.0))+10.0
	rt.totals["damage_reduction_ignore:flat"] = float(rt.totals.get("damage_reduction_ignore:flat",0.0))+3.0
	check(is_equal_approx(world._skill_cooldown_factor(),maxf(0.1,cooldown_before-0.1)),"native cast-speed10 reaches actual world skill cooldown consumer")
	check(world._catalog_damage_bonus("melee") == damage_before+3,"native reduction-ignore3 reaches actual world damage consumer")
	rt.totals = native_totals
	print("UNCONFIRMED523_MAIN_STAGE: source ownership fixture committed")
	var state_before: Dictionary = rt.state.duplicate(true)
	var page: Dictionary = rt.page("events")
	var visible: Dictionary = {}
	for row: Dictionary in page.rows: visible[str(row.id)] = row
	check(visible.has("pass:692") and visible.has("pass:724"),"both actual simultaneous pass seasons visible in live page")
	check(same(state_before,rt.state),"backend page does not mutate domain state or RNG")
	var before: Array = ownership()
	var preview_hash: String = FileAccess.get_sha256(world.save_path())
	var purchase_preview: Dictionary = {}
	for action: Dictionary in visible.get("pass:724",{}).get("actions",[]):
		if action.get("request",{}).get("premium") == false: purchase_preview = action; break
	check(purchase_preview.get("request",{}) == {"action":"pass_purchase","pass_id":724,"premium":false},"backend pass724 preview retains the exact source purchase request")
	check(purchase_preview.get("costs",[]) == [{"kind":"currency","id":1,"amount":3000000}],"backend pass724 preview exposes the exact three-million source cost")
	check(same(before,ownership()),"reading backend purchase preview preserves ownership and RNG before submission")
	var choice_row: Dictionary = visible.get("container:164683",{})
	check(not choice_row.is_empty(),"actual source selection container visible in backend owned actions")
	if not choice_row.is_empty():
		var choice_action: Dictionary = choice_row.actions[0]
		var original_action: Dictionary = choice_action.duplicate(true)
		var requirements: Array = choice_action.get("required_choices",[])
		if check(requirements.size() == 1 and requirements[0].get("options",[]).size() == 4,"backend selection contract retains all four source options"):
			var discarded_selection: Dictionary = choice_action.request.duplicate(true)
			var key: String = str(requirements[0].get("key","selection"))
			var values: Array = [requirements[0].options[0].value]
			if key.begins_with("selection."):
				discarded_selection.selection = {key.trim_prefix("selection."):values}
			else: discarded_selection[key] = values
			check(discarded_selection != choice_action.request and same(choice_action,original_action),"preparing detached backend choice leaves the source action contract unchanged")
		check(same(before,ownership()),"discarded source choice request preserves container resources and domain RNG")
	check(FileAccess.get_sha256(world.save_path()) == preview_hash,"unsubmitted backend requests preserve exact durable save bytes")
	var wallet: int = world.gold
	var purchase: Dictionary = rt.execute("events",{"action":"pass_purchase","pass_id":724,"premium":false})
	check(purchase.get("ok",false) and world.gold == wallet-3000000,"source pass724 purchase atomically debits3million")
	check(not rt.execute("events",{"action":"pass_purchase","pass_id":724,"premium":false}).get("ok",false),"duplicate pass purchase rejected")
	var bless_before: int = world.ain_service.blessing
	var daily: Dictionary = rt.execute("events",{"action":"attendance_claim","version_id":8,"index":1})
	check(daily.get("ok",false) and world.ain_service.blessing == bless_before+1000,"current actual attendance claims source-rule blessing through Ain consumer")
	var daily_disk: String = FileAccess.get_sha256(world.save_path())
	check(not rt.execute("events",{"action":"attendance_claim","version_id":8,"index":1}).get("ok",false) and FileAccess.get_sha256(world.save_path()) == daily_disk,"duplicate attendance cannot change durable save")
	var next: Dictionary = rt.state.duplicate(true)
	next.domains.events.passes["724"].experience = 300
	if not persist_state(next): await finish(); return
	var pre_pass_xp: float = world._experience_multiplier()
	var claim: Dictionary = rt.execute("events",{"action":"pass_claim","pass_id":724,"level_id":17384,"premium":false})
	check(claim.get("ok",false) and rt.state.bonus_rewards.size() == 1,"actual source Bonus184 pass tier persists one receipt")
	check(is_equal_approx(world._experience_multiplier(),pre_pass_xp+0.03),"claimed source Bonus184 contributes actual Main experience3percent")
	check(not rt.execute("events",{"action":"pass_claim","pass_id":724,"level_id":17384,"premium":false}).get("ok",false),"pass bonus tier cannot be claimed twice")
	var before_port: Dictionary=rt.state.duplicate(true)
	var pass_plan: Dictionary=rt.prepare_pass_reward({"schema":1,"quest_id":101864,"reward_id":434674,"source_sha256":SOURCE.SOURCE_SHA256,"claim_id":"explicit_port_fixture_only"})
	if check(pass_plan.get("ok",false),"actual source Quest101864 Reward434674 Pass724 prepares future host port"):
		check(int(pass_plan.staged.unconfirmed523.domains.events.passes["724"].experience)==int(before_port.domains.events.passes["724"].experience)+60,"prepared pass patch preserves exact source60XP target")
		check(rt.cancel_prepared(pass_plan.plan_id) and same(rt.state,before_port),"cancelled source pass port never claims quest or mutates production progression")
	print("UNCONFIRMED523_MAIN_STAGE: detached backend previews, attendance and pass claims checked")
	var grail_id: String = str(ids_for(338438)[0])
	var request: Dictionary = {"op":"grail_roll","instance_id":grail_id}
	before = ownership()
	var disk: String = FileAccess.get_sha256(world.save_path())
	world.equipment_collections.test_save_writer = func(_path: String,_payload: Dictionary) -> Error: return ERR_CANT_CREATE
	var rejected: Dictionary = rt.execute("jade_grail",request)
	check(not rejected.get("ok",false) and same(before,ownership()),"writer error preserves exact live funds, items, domain progress and RNG")
	check(FileAccess.get_sha256(world.save_path()) == disk,"writer error preserves exact durable save bytes")
	check(rt.save_blocked and world._save_game(true) != OK,"uncertain write blocks further actions and overwriting until deliberate reload")
	world.equipment_collections.test_save_writer = Callable()
	world._load_game(true); freeze()
	check(not rt.save_blocked and reload_ownership_matches(before),"deliberate Main reload preserves committed funds, native IDs, domain RNG and Ain amounts")
	var confirmed_revision: int = int(rt.state.revision)
	var confirmed_fingerprint: String = rt.fingerprint()
	var scrolls_before: int = int(rt.context().owned.get("355334",0))
	wallet = world.gold
	var confirmed: Dictionary = rt.execute("jade_grail",request,confirmed_revision,confirmed_fingerprint)
	var confirmed_hash: String = FileAccess.get_sha256(world.save_path())
	var duplicate: Dictionary = rt.execute("jade_grail",request,confirmed_revision,confirmed_fingerprint)
	check(confirmed.get("ok",false) and not duplicate.get("ok",false),"backend accepts confirmed revision once and rejects the repeated token")
	check(world.gold == wallet-10000 and int(rt.context().owned.get("355334",0)) == scrolls_before-2,"repeated backend confirmation debits exactly two source scrolls and10000once")
	check(FileAccess.get_sha256(world.save_path()) == confirmed_hash,"repeated backend confirmation preserves exact once-committed save bytes")
	check(rt.state.domains.jade_grail.grails.has(grail_id),"actual physical grail stores rolled prefixes under exact instanceID")
	var revision: int = int(rt.state.revision)
	before = ownership()
	check(not rt.execute("jade_grail",request,revision-1,rt.fingerprint()).get("ok",false) and same(before,ownership()),"stale displayed revision rejected without mutation")
	var fingerprint: String = rt.fingerprint()
	world.gold += 1
	check(not rt.execute("jade_grail",request,revision,fingerprint).get("ok",false),"changed displayed wallet invalidates confirmation")
	world.gold -= 1
	var rng_before: String = str(rt.state.domains.events.rng_state)
	var bag_count: int = int(rt.context().owned.get("166594",0))
	var opened: Dictionary = rt.execute("events",{"action":"consume_item","item_id":166594})
	check(opened.get("ok",false) and int(rt.context().owned.get("166594",0)) == bag_count-1,"owned actualLuckyBag37864 consumes only its source item166594")
	check(opened.get("ok",false) and str(rt.state.domains.events.rng_state) != rng_before,"committed actual bag advances durable domain RNG")
	check(not opened.get("rewards",[]).is_empty(),"real bag reward resolves and is staged into same world save")
	var zero_blessing: Dictionary = world.ain_service.export_state()
	zero_blessing.blessing = 0
	zero_blessing.spend_remainder = 0.0
	if check(world._save_game(true,{"ainhasad_state":zero_blessing}) == OK,"explicit zero-blessing fixture saved before protection check"):
		world.ain_service.import_state(zero_blessing)
	var monthly_before: String = world.ain_service.last_orb_purchase_month
	before = ownership()
	var jade: Dictionary = rt.execute("jade_grail",{"op":"jade_use","item_id":139931})
	check(not jade.get("ok",false) and same(before,ownership()),"restricted historical jade cannot consume or activate")
	var monthly: Dictionary = world.ain_service.export_state()
	monthly.dragon_orb_expires_at = NOW+2592000
	if check(world._save_game(true,{"ainhasad_state":monthly}) == OK,"existing monthly-shop expiry fixture uses one authoritative saved timer"):
		world.ain_service.import_state(monthly)
		rt.rebuild()
	check(world.ain_service.last_orb_purchase_month == monthly_before and rt.state.domains.jade_grail.jade.is_empty(),"existing monthly orb retains entitlement without a duplicate source-jade timer")
	check(world.ain_service.protected_drops() and is_equal_approx(world.ain_service.experience_rate(),4.0) and is_equal_approx(world.ain_service.adena_rate(),1.5),"actual existing Ain consumer supplies zero-blessing jade protection")
	await final_cube_fixtures()
	var live: Array = ownership()
	var valid_bytes: PackedByteArray = FileAccess.get_file_as_bytes(world.save_path())
	var valid: Dictionary = JSON.parse_string(valid_bytes.get_string_from_utf8())
	var corrupt: Dictionary = valid.duplicate(true)
	corrupt.unconfirmed523.domains.events.rng_state = 0
	corrupt.gold = 123
	check(WRITER.write(world.save_path(),corrupt) == OK,"explicit corrupt-domain fixture reaches production writer")
	var corrupt_hash: String = FileAccess.get_sha256(world.save_path())
	world._load_game(true); freeze()
	check(rt.save_blocked and same(live,ownership()),"corrupt-domain Main load rejected before any inventory or progression mutation")
	check(world._save_game(true) != OK and FileAccess.get_sha256(world.save_path()) == corrupt_hash,"rejected corrupt load cannot overwrite source save")
	check(WRITER.write(world.save_path(),valid) == OK,"restore exact valid save payload after corruption probe")
	world._load_game(true); freeze()
	check(not rt.save_blocked and same(live,ownership()),"valid reload restores gate without losing native ownership")
	world.hp=world._effective_max_hp()
	check(world._save_game(true) == OK,"final integrated state saves through production writer")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	var namespaces: Dictionary = {}
	for key: String in ["unconfirmed523","inventory","item_instances","equipped_items","equipment_collections","card_draw_fusion","card_option_awakening","card_skill_awakening","growth","source_dungeon523","source_dungeon_play","warehouse","inventory_automation","ainhasad_state"]:
		check(saved.has(key),"existing save namespace retained " + key)
		namespaces[key] = saved.get(key)
	var marker: Dictionary = {"save_path":world.save_path(),"save_hash":FileAccess.get_sha256(world.save_path()),"namespaces":namespaces,"gold":world.gold,"grail_id":grail_id,"hp_bonus":rt.bonus("max_hp:flat"),"xp_bonus":rt.bonus("experience_bonus:percent"),"prefixes":rt.state.domains.jade_grail.grails[grail_id].duplicate(true),"clock":rt.test_now}
	marker["full_hp"]=world.hp
	var output: FileAccess = FileAccess.open(MARKER,FileAccess.WRITE)
	output.store_string(JSON.stringify(marker)); output.close()
	check(not FileAccess.file_exists(world.save_path()+".tmp"),"atomic writer leaves no unfinished temporary save")
	check(not has_custom_form(world.hud),"all active backend flows leave custom form unmounted")
	await finish()

func reload_phase() -> void:
	var marker: Variant = JSON.parse_string(FileAccess.get_file_as_string(MARKER))
	if not check(marker is Dictionary,"separate-process initial evidence present"): return
	rt.test_now=int(marker.get("clock",NOW))
	rt.rebuild()
	check(world.save_path() == str(marker.save_path),"new process resolves same active save path")
	check(FileAccess.get_sha256(world.save_path()) == str(marker.save_hash),"ordinary new-process boot preserves exact save bytes")
	check(world.gold == int(marker.gold),"new process restores exact committed wallet")
	check(world.hp == int(marker.full_hp) and world.hp == world._effective_max_hp(),"cold reload preserves full HP including restored grail possession bonus")
	for key: String in marker.namespaces:
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
		check(same(saved.get(key),marker.namespaces[key]),"new process preserves durable namespace " + key)
	check(same(rt.state,marker.namespaces.unconfirmed523),"new process restores source domain state and durable RNG")
	check(same(world.inventory,marker.namespaces.inventory) and same(world.item_instances,marker.namespaces.item_instances),"new process restores exact native inventory identities")
	check(same(rt.state.domains.jade_grail.grails[str(marker.grail_id)],marker.prefixes),"new process preserves exact physical grail prefixes")
	check(is_equal_approx(rt.bonus("max_hp:flat"),float(marker.hp_bonus)) and is_equal_approx(rt.bonus("experience_bonus:percent"),float(marker.xp_bonus)),"new process rebuilds actual source stat contributions")
	check(not rt.save_blocked and not world.source_save_blocked,"new process preserves valid source save gate")
	check(ids_for(8951).size()==8 and rt.state.domains.events.final_progress.get("8951",{}).is_empty(),"cold restart preserves all blocked native cube units without invented final history")
	await craft_progress_fixtures()
