extends "res://tests/current523_aden_source_main_test.gd"
## Actual Main/UI bridge audit. The provider below is a pinned TEST adapter,
## not PR230's production definition loader or proof of native portal activation.
const GENERIC_FIELD = preload("res://scripts/maps/current523_source_field.gd")
const SOURCE_PACK = preload("res://scripts/maps/current523_source_pack.gd")
const DEFINITION_PIN = "2de8cebbcf486e5c2afa3e471ddc0cceeebe20ab8389916291eb24a5739ffa90"
const HANDOFF_PIN = "ba3619ad35f72cf49c271605b32c7a0e516fddeb5fc2c17d33da2c16d05eacea"
const PORTAL_EXPECTED = "user://current523-generic-portal-main-expected.json"
var source_sha: String
var tile_sha: String
var handoff_path: String
var failure_tile_root: String
var phase_name: String = "entry"

class PinnedHandoffTestProvider extends RefCounted:
	var contexts: Dictionary = {}
	func load_handoff(path: String, pin: String) -> bool:
		contexts.clear()
		if pin!=HANDOFF_PIN or FileAccess.get_sha256(path)!=pin: return false
		var rows: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if not rows is Array or rows.size()!=1150: return false
		for row: Variant in rows:
			if not row is Dictionary: return false
			for key: String in ["Portal","SourceLand","TargetTerritory","TargetLand"]:
				if not row.get(key) is Dictionary: return false
			var id: int=int(row.Portal.get("ID",-1))
			if id<0 or contexts.has(id) or row.Portal.get("SourceLandID")!=row.SourceLand.get("ID") \
				or row.Portal.get("TargetTerritoryID")!=row.TargetTerritory.get("ID") \
				or row.TargetTerritory.get("LandID")!=row.TargetLand.get("ID"): return false
			contexts[id]=row.duplicate(true)
		return true
	func portal_evidence_for_land(land_id: int, exact_asset: String) -> Array:
		var result: Array=[]
		var ids: Array=contexts.keys(); ids.sort()
		for id: int in ids:
			var context: Dictionary=contexts[id]
			if context.SourceLand.ID==land_id and context.SourceLand.AssetPath==exact_asset:
				result.append(context.Portal.duplicate(true))
		return result
	func portal_context_for_land(land_id: int, exact_asset: String, id: int) -> Dictionary:
		if not contexts.has(id): return {}
		var context: Dictionary=contexts[id]
		return context.duplicate(true) if context.SourceLand.ID==land_id and context.SourceLand.AssetPath==exact_asset else {}

func open_generic(id: int, cell: Vector2i) -> bool:
	return world.open_current523_aden_play(raw_root,tile_root,{"navigation_profile":OPTIONS.GENERIC,
		"source_manifest_sha256":source_sha,"tile_manifest_sha256":tile_sha,"native_land_id":id,
		"allowed_raw_words":OPTIONS.SOURCE_WORDS.duplicate(),"source_position":[cell.x+0.5,cell.y+0.5],"portal_contract":""})

func cell_now() -> Vector2i:
	return world.field_map.world_to_cell(world.player.global_position)+world.field_map.coordinates.origin

func camera_state() -> Dictionary:
	var camera: Camera2D=world.player.camera
	return {"left":camera.limit_left,"top":camera.limit_top,"right":camera.limit_right,"bottom":camera.limit_bottom}

func snapshot() -> Dictionary:
	var controller: RefCounted=world.get("_current523_aden_play_controller")
	return {"field":world.field_map,"renderer":world.field_renderer,"physics":world.field_physics,
		"renderer_id":world.field_renderer.get_instance_id(),"physics_id":world.field_physics.get_instance_id(),
		"position":world.player.global_position,"camera":camera_state(),"settings":controller.settings.duplicate(true),
		"prefs_sha":FileAccess.get_sha256(OPTIONS.PATH),"save_sha":FileAccess.get_sha256(world.save_path()),"protected":state()}

func preserved(before: Dictionary, label: String) -> void:
	var controller: RefCounted=world.get("_current523_aden_play_controller")
	check(world.current523_aden_source_active() and world.field_map==before.field and world.field_renderer==before.renderer
		and world.field_physics==before.physics and world.player.global_position==before.position,label+" preserves active field,renderer,physics and actor")
	check(camera_state()==before.camera and controller.settings==before.settings and not controller.get("_source_travel_busy"),label+" preserves camera/settings and releases transaction lock")
	check(FileAccess.get_sha256(OPTIONS.PATH)==before.prefs_sha and FileAccess.get_sha256(world.save_path())==before.save_sha
		and state()==before.protected,label+" preserves exact checkpoint/save bytes and protected progress")
	check(bool(world.field_renderer.get("_configured")) and not bool(world.field_renderer.get("_return_pending")),label+" leaves old renderer configured with no pending safe return")

func reward_state() -> Dictionary:
	return JSON.parse_string(JSON.stringify({"level":world.level,"experience":world.experience,
		"quests":world.quest_service.export_state(),"ground_loot":world.ground_loot.records},"",true,true))

func returned_bosses(before: Dictionary, after: Dictionary) -> Dictionary:
	var evidence: Dictionary={"ok":true,"initialized_ready_bosses":[],"rejected_changes":[]}
	if before.get("version")!=after.get("version") or before.bosses.keys().size()!=after.bosses.keys().size(): evidence.ok=false
	for key: String in before.bosses:
		if not after.bosses.has(key): evidence.ok=false; evidence.rejected_changes.append(key); continue
		var prior: Dictionary=before.bosses[key]
		var current: Dictionary=after.bosses[key]
		if prior==current: continue
		# Closing resumes ordinary host population creation. Only a previously
		# uninitialized ready life may become exactly one healthy host actor.
		var initialized: bool=prior.get("phase")=="ready" and prior.get("hp")==-1 \
			and prior.get("position")==[] and prior.get("home")==[] and current.get("phase")=="alive"
		var allowed: Dictionary=prior.duplicate(true)
		for field: String in ["phase","hp","position","home"]: allowed[field]=current.get(field)
		initialized=initialized and allowed==current and current.get("position") is Array and current.position.size()==2 \
			and current.get("home") is Array and current.home.size()==2
		var actors: Array=[]
		for slot: Dictionary in world.field_population.slots:
			if str(slot.region.get("mode","normal"))!="boss" \
				or world.field_population.boss_director.key(str(world.field_map.data.map_id),slot.region)!=key: continue
			var actor: Variant=slot.get("monster")
			if is_instance_valid(actor) and not actor.dead: actors.append({"actor":actor,"region":slot.region})
		initialized=initialized and actors.size()==1
		if initialized:
			var actor: Node2D=actors[0].actor
			var position:=Vector2(current.position[0],current.position[1])
			var home:=Vector2(current.home[0],current.home[1])
			initialized=bool(actor.get("is_boss")) and int(actor.get("hp"))==int(actor.get("max_hp")) \
				and int(current.hp)==int(actor.get("max_hp")) and actor.global_position==position \
				and actor.get("home_position")==home and world.field_map.walkable(position) \
				and world.field_map.point_clear(position) and world.field_map.spawn_contains(actors[0].region,home)
			if initialized:
				evidence.initialized_ready_bosses.append({"key":key,"actor_name":actor.name,"actor_instance_id":actor.get_instance_id(),
					"hp":actor.get("hp"),"max_hp":actor.get("max_hp"),"position":current.position.duplicate(),"home":current.home.duplicate(),
					"ready_at_unchanged":current.ready_at==prior.ready_at,"walkable_host_spawn":true})
		if not initialized: evidence.ok=false; evidence.rejected_changes.append(key)
	return evidence

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--source-root="): raw_root=argument.trim_prefix("--source-root=")
		if argument.begins_with("--tile-root="): tile_root=argument.trim_prefix("--tile-root=")
		if argument.begins_with("--source-sha="): source_sha=argument.trim_prefix("--source-sha=")
		if argument.begins_with("--tile-sha="): tile_sha=argument.trim_prefix("--tile-sha=")
		if argument.begins_with("--handoff="): handoff_path=argument.trim_prefix("--handoff=")
		if argument.begins_with("--failure-tile-root="): failure_tile_root=argument.trim_prefix("--failure-tile-root=")
		if argument.begins_with("--phase="): phase_name=argument.trim_prefix("--phase=")
	if phase_name=="return-audit":
		# Repeat only the failing close audit from the recorded target checkpoint.
		# The initial reconnect result and its disabled preference stay in its log.
		var recorded: Dictionary=OPTIONS.read(); recorded.enabled=true
		check(OPTIONS.write(recorded)==OK,"TEST close audit reenables the existing recorded source checkpoint")
	world=(load("res://Main.tscn") as PackedScene).instantiate(); root.add_child(world)
	world.set_process(false); world.save_timer=-100000.0
	check(QA.enter_game(world),"ordinary actual Main class entry")
	world.player.set_physics_process(false); world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
	if phase_name in ["reconnect","return-audit"]: await reconnect_portal(); return
	world.gold=523111
	check(world._save_game(true)==OK,"baseline actual Main save")
	var protected: Dictionary=state()
	var host=world.field_map
	var host_renderer=world.field_renderer
	var host_view: Dictionary=PRIOR_RENDERER.renderer_signature(host_renderer)
	var host_position: Vector2=world.player.global_position
	var save_sha: String=FileAccess.get_sha256(world.save_path())
	var provider=PinnedHandoffTestProvider.new()
	check(provider.load_handoff(handoff_path,HANDOFF_PIN),"TEST provider reads exact pinned private1150-row handoff")
	if not failures.is_empty(): await finish_portal(); return
	check(world.bind_current523_source_portal_provider(provider,DEFINITION_PIN),"caller explicitly binds TEST provider to bridge contract")
	# This negative setup places an actor on a blocked cell only for rejection;
	# it never claims that actual movement can enter the cell or that travel works.
	check(open_generic(807,Vector2i(32739,32806)),"Land807 enters at nativePortal2931 clear declared source")
	if not world.current523_aden_source_active(): await finish_portal(); return
	await frames()
	var valid_position: Vector2=world.player.global_position
	var blocked_cell:=Vector2i(32740,32807)
	var target=GENERIC_FIELD.new()
	check(target.configure_catalog(raw_root,source_sha,808),"Portal523 actual target Land808 is available")
	check(world.field_map.source_cell_info(blocked_cell).raw_pair==[0,1]
		and target.source_cell_info(Vector2i(32750,32802)).raw_pair==[0,1],"Portal523 both actual endpoints retain unlisted raw word1")
	target.close()
	world.player.global_position=world.field_map.coordinates.to_world(Vector2(blocked_cell))
	world.portal_cooldown=0
	var blocked_snapshot: Dictionary=snapshot()
	check(not world.use_current523_aden_source_portal(523) and world.current523_aden_play_problem.contains("source_endpoint_blocked"),"actual Main rejectsPortal523 under unchanged default own policy: "+world.current523_aden_play_problem)
	measurements.append({"portal_id":523,"expected_rejection":"source_endpoint_blocked","actual_problem":world.current523_aden_play_problem,"source_raw_pair":[0,1],"target_raw_pair":[0,1]})
	preserved(blocked_snapshot,"blockedPortal523")
	world.player.global_position=valid_position
	world.close_current523_aden_play(); await frames()
	check(world.field_map==host and restored_renderer(host_renderer,host_view) and world.player.global_position==host_position
		and state()==protected and FileAccess.get_sha256(world.save_path())==save_sha,"blocked portal session restores exact initial host and protected state")
	check(open_generic(1,Vector2i(32668,32803)),"World API entersLand1 nativePortal1101 exact source cell")
	if not world.current523_aden_source_active(): await finish_portal(); return
	await frames()
	world.portal_cooldown=0
	check(cell_now()==Vector2i(32668,32803) and world.field_map.source_asset=="1/","actual native source identity and actor cell agree")
	check(not world.bind_current523_source_portal_provider(provider,"0".repeat(64)) and not world.current523_aden_source_portals().is_empty(),"rejected provider rebinding retains previous valid binding")
	var copied: Dictionary=world.current523_aden_source_portal_context(1101)
	copied.Portal.SourceX=0
	check(world.current523_aden_source_portal_context(1101).Portal.SourceX==32668,"Main context queries cannot mutate TEST provider definitions")
	var controller: RefCounted=world.get("_current523_aden_play_controller")
	var before: Dictionary=snapshot()
	controller.settings.tile_root=failure_tile_root
	check(not world.use_current523_aden_source_portal(1101),"missing actual arrival pixels reject staged travel")
	var render_problem: String=world.current523_aden_play_problem
	controller.settings=before.settings.duplicate(true)
	check(render_problem.contains("도착 화면 확인 실패"),"render-denial injection reaches arrival renderer prevalidation: "+render_problem)
	measurements.append({"injection":"arrival_pixels_missing","actual_problem":render_problem})
	preserved(before,"arrival render denial")
	await frames(); preserved(before,"render denial after deferred frames")
	if not await deny_checkpoint_write(): await finish_portal(); return
	world.hud.call("open_settings_info",true); await frames()
	var panel=world.hud.workspace.find_child("Current523AdenReviewSettings",true,false)
	check(panel!=null,"actual Settings portal controls are present")
	if panel==null: await finish_portal(); return
	panel._refresh_source_portals(); panel._update_open_button()
	check(panel.source_portal_button.text.contains("TWILIGHT 자체 수동") and not panel.source_portal_button.disabled,"manual portal UI explicitly labels own interpretation")
	var selected: bool=false
	for index: int in range(panel.source_portal_choice.item_count):
		if panel.source_portal_choice.get_item_id(index)==1101:
			panel.source_portal_choice.select(index); selected=true
			check(panel.source_portal_choice.get_item_text(index).contains("Land0"),"portal UI identifies destination logical Land0")
	check(selected,"actual portal selection contains nativePortal1101")
	world.portal_cooldown=0
	panel.source_portal_button.pressed.emit(); await frames()
	var arrived: bool=world.current523_aden_source_active() and world.field_map.definition.source_map_id==0 and world.field_map.source_asset=="0/" and cell_now()==Vector2i(32477,32855)
	check(arrived,"actual Settings manual button executesPortal1101 exact Land1-to-Land0 destination: "+world.current523_aden_play_problem)
	if not arrived: await finish_portal(); return
	check(world.field_minimap.field==world.field_map and world.field_physics.get_instance_id()!=before.physics_id
		and world.field_renderer.get_instance_id()!=before.renderer_id,"arrival publishes target field renderer physics and minimap consistently")
	check(world.field_map.data.spawn_position.size()==2 and world.field_map.walkable(world._spawn_position())
		and world._spawn_position().distance_to(world.player.global_position)<0.1,"target own spawn cursor is valid and equals declared arrival")
	check(state()==protected and FileAccess.get_sha256(world.save_path())==save_sha,"successful portal preserves items,currency,collections,bosses and original save bytes")
	var landed: Vector2=world.player.global_position
	check(not world.use_current523_aden_source_portal(1101) and world.player.global_position==landed,"immediate repeated request cannot move or transact again")
	var metrics: Dictionary=world.current523_aden_play_metrics()
	check(metrics.native_land_id==0 and metrics.unresolved_refs==0 and metrics.budget_skips==0 and not metrics.native_M_rules_verified,"actual destination render has complete visible refs and retains own-rule provenance")
	measurements.append({"portal_id":1101,"source_land_id":1,"source_cell":[32668,32803],"target_land_id":0,"target_cell":[32477,32855],"metrics":metrics,"provider":"PINNED_HANDOFF_TEST_ADAPTER_ONLY"})
	capture("generic-portal1101-Land0-arrival")
	check(world._save_game(true)==OK,"source session saves progress through retained original host")
	var disk: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(Vector2(disk.position[0],disk.position[1]).distance_to(host_position)<0.1
		and disk.original_position.grid_sha256==host.definition.source_sha256,"normal save retains initial host coordinates and original grid identity")
	var options: Dictionary=OPTIONS.read()
	check(options.native_land_id==0 and options.source_position==[32477.5,32855.5],"separate checkpoint persists target logical Land and exact centered cursor together")
	var expected: Dictionary={"protected":protected,"save_sha":FileAccess.get_sha256(world.save_path()),"position":options.source_position,
		"host_position":[host_position.x,host_position.y],"host_grid_sha":host.definition.source_sha256,"host_map_id":world.active_map_id,
		"source_sha":source_sha,"tile_sha":tile_sha,"provider":"PINNED_HANDOFF_TEST_ADAPTER_ONLY"}
	var file:=FileAccess.open(PORTAL_EXPECTED,FileAccess.WRITE); file.store_string(JSON.stringify(expected,"",true,true)); file.close()
	await finish_portal()

func deny_checkpoint_write() -> bool:
	var before: Dictionary=snapshot()
	var path: String=ProjectSettings.globalize_path(OPTIONS.PATH)
	var held: String=path+".portal-test-held-"+str(OS.get_process_id())
	var renamed: bool=DirAccess.rename_absolute(path,held)==OK
	check(renamed,"isolated checkpoint is retained before write-denial injection")
	if not renamed: return false
	var blocked: bool=DirAccess.make_dir_absolute(path)==OK
	check(blocked,"isolated config path temporarily rejects file replacement")
	if not blocked:
		check(DirAccess.rename_absolute(held,path)==OK,"checkpoint restored after injection setup failure")
		return false
	var denied: bool=not world.use_current523_aden_source_portal(1101)
	var reason: String=world.current523_aden_play_problem
	var removed: bool=DirAccess.remove_absolute(path)==OK
	var restored: bool=DirAccess.rename_absolute(held,path)==OK if removed else false
	check(removed and restored,"exact checkpoint file restored before yielding or subsequent tests")
	if not removed or not restored: return false
	check(denied and reason.contains("목적지 위치를 저장하지 못해"),"actual staged travel refuses checkpoint-write failure: "+reason)
	measurements.append({"injection":"checkpoint_write_failure","actual_problem":reason})
	preserved(before,"checkpoint write denial")
	await frames(); preserved(before,"write denial after deferred frames")
	return true

func reconnect_portal() -> void:
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PORTAL_EXPECTED))
	var deadline: int=Time.get_ticks_msec()+20000
	while not world.current523_aden_source_active() and Time.get_ticks_msec()<deadline: await process_frame
	check(world.current523_aden_source_active(),"separate actual Main process restores target generic session")
	if not world.current523_aden_source_active(): await finish_portal(); return
	await frames()
	check(world.field_map.definition.source_map_id==0 and world.field_map.source_asset=="0/" and cell_now()==Vector2i(32477,32855),"reconnect retains exact target Land0 and native declared cell")
	check(world.field_map.coordinates.source_components(world.player.global_position)==expected.position,"reconnect restores exact separate source cursor")
	check(state()==expected.protected and FileAccess.get_sha256(world.save_path())==expected.save_sha,"reconnect preserves all protected progress and exact stored save bytes")
	check(world.current523_aden_source_portals().is_empty(),"reconnect does not silently install TEST provider or claim PR230 integration")
	check(world.field_map.walkable(world._spawn_position()),"restored generic field has valid own spawn cursor")
	var provider=PinnedHandoffTestProvider.new()
	check(provider.load_handoff(handoff_path,HANDOFF_PIN) and world.bind_current523_source_portal_provider(provider,DEFINITION_PIN),"reconnect TEST provider is installed only through explicit caller binding")
	world.portal_cooldown=0
	var before: Dictionary=snapshot()
	check(world.current523_aden_source_portal_context(1101).is_empty() and not world.use_current523_aden_source_portal(1101),"stale Portal1101 source is rejected in target Land0 after cooldown expires")
	preserved(before,"stale source request")
	await frames(); preserved(before,"stale request after deferred frames")
	capture("generic-portal1101-reconnect-Land0")
	var rewards_before: Dictionary=reward_state()
	world.close_current523_aden_play()
	var immediate: Dictionary=state()
	# A cold host population is rebuilt on close. Freeze its newly created nodes
	# before yielding so preservation is measured without subsequent simulation.
	world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
	await frames()
	check(not world.current523_aden_source_active() and world.active_map_id==expected.host_map_id
		and world.field_map.definition.source_sha256==expected.host_grid_sha
		and world.player.global_position.distance_to(Vector2(expected.host_position[0],expected.host_position[1]))<0.1,"explicit close returns to original host field and initial host position")
	var after: Dictionary=state()
	var changed: Array[String]=[]
	for key: String in after:
		if after[key]!=expected.protected.get(key): changed.append(key)
	measurements.append({"stage":"after_explicit_close","changed_protected_keys":changed,"save_sha_after":FileAccess.get_sha256(world.save_path()),
		"source_enabled_after":OPTIONS.read().enabled,"bosses_before":expected.protected.bosses,"bosses_immediately_after":immediate.bosses,"bosses_after":after.bosses})
	for key: String in expected.protected:
		if key!="bosses": check(immediate.get(key)==expected.protected[key] and after.get(key)==expected.protected[key],"close preserves exact protected progress: "+key)
	var boss_evidence: Dictionary=returned_bosses(expected.protected.bosses,immediate.bosses)
	measurements.append({"stage":"host_boss_reconstruction","evidence":boss_evidence})
	check(boss_evidence.ok,"preexisting boss lives/cooldowns remain exact; only uninitialized ready lives may restore valid host actors")
	check(immediate.bosses.game_seconds==expected.protected.bosses.game_seconds and after.bosses==immediate.bosses,
		"boss clock does not advance synchronously and frozen post-close simulation changes no boss state")
	check(reward_state()==rewards_before,"host boss reconstruction produces no kill progression,XP,reward or ground drop")
	check(FileAccess.get_sha256(world.save_path())==expected.save_sha and not OPTIONS.read().enabled,"close preserves exact stored save and disables source restoration")
	await finish_portal()

func finish_portal() -> void:
	print("CURRENT523_GENERIC_PORTAL_MAIN_RESULT "+JSON.stringify({"phase":phase_name,"checks":checks,"failures":failures,
		"actual_Main":true,"measurements":measurements,"captures":captures,"provider":"PINNED_HANDOFF_TEST_ADAPTER_ONLY",
		"genuine_PR230_binding_verified":false,"native_m_rules_verified":false},"",true,true))
	if is_instance_valid(world): world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
