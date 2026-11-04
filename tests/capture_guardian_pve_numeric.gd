extends "res://tests/capture_guardian_authored.gd"
## Actual Main/current source map, existing population monsters and native UI.
## Prerequisite ownership / fixed winning card are QA fixtures; raw values stay intact.
const TARGETS=["source523_2192","source523_2742","source523_2752","source523_3202","source523_3382"]
const GROUPS=["joe","atun","atun","christ","christ"]
func snapshot(label: String) -> void:
	await frames();await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory+"/"+label+".png")==OK,"capture "+label)
func actual_monster() -> TwilightMonster:
	for candidate: Node in world.monsters_root.get_children():
		if candidate is TwilightMonster and not candidate.dead and candidate.hp>20:return candidate
	return null
func verify_combat(label: String) -> void:
	var monster: TwilightMonster=actual_monster()
	check(monster!=null,"existing population monster for "+label)
	if monster==null:return
	check(not monster.get_meta("is_player_combatant",false),"actual monster never marked PvP")
	var policy: Dictionary=world.growth.guardian_combat.pve_numeric_policy()
	for kind: String in ["melee","ranged","magic"]:
		var hp: int=monster.hp
		policy.enabled=false
		world._deal_successful_player_hit(monster,10,false,kind)
		var off: int=hp-monster.hp;monster.hp=hp
		policy.enabled=true
		world._deal_successful_player_hit(monster,10,false,kind)
		var on: int=hp-monster.hp;monster.hp=hp
		check(on-off==(2 if kind=="magic" else 4),label+" real "+kind+" hit consumes exact source additions; off="+str(off)+" on="+str(on))
	# Use the real source-edge combat lane; no fake safe-zone or target flags.
	var pair: Dictionary=preload("res://tests/qa_aden_source_combat_positions.gd").find_source_combat_pair(world.field_map,world.rng)
	check(not pair.is_empty(),"real non-safe source combat lane")
	if pair.is_empty():return
	world.player.global_position=pair.player;monster.global_position=pair.monster
	check(monster.player_hit.is_connected(world._on_player_hit),"population monster uses real world incoming signal")
	var found: bool=false
	for seed_value: int in range(20):
		world.rng.seed=seed_value;world.hp=world._effective_max_hp()
		var health: int=world.hp
		policy.enabled=false;monster.player_hit.emit(monster,30,"magic")
		var off: int=health-world.hp
		world.rng.seed=seed_value;world.hp=health
		policy.enabled=true;monster.player_hit.emit(monster,30,"magic")
		var on: int=health-world.hp
		if off>0:
			check(off-on==1,label+" actual incoming NPC hit consumes source reduction; off="+str(off)+" on="+str(on))
			check(int(world.hud.hp_bar.value)==world.hp,"live HP HUD displays compatibility reduction")
			found=true;break
	check(found,"incoming real hit occurred without synthetic context")
	print("GUARDIAN_PVE_LIVE_MONSTER ",label," ",monster.monster_name," ",world.active_map_id)
func run() -> void:
	directory=OS.get_environment("GUARDIAN_CAPTURE_DIR");DirAccess.make_dir_recursive_absolute(directory)
	root.size=Vector2i(1280,720)
	world=load("res://Main.tscn").instantiate();root.add_child(world);await frames()
	world.hud.complete_class_selection();world.set_process(false);world.player.set_physics_process(false);world.field_population.set_process(false)
	for monster: Node in world.monsters_root.get_children():monster.set_physics_process(false)
	world.inventory["수호석"]=1000
	var rt=world.growth
	for index: int in range(TARGETS.size()):
		var id: String=TARGETS[index]
		var fixture: Dictionary=rt.state.duplicate(true)
		for parent: String in rt.node(id).prerequisites:grant(rt,fixture,parent)
		rt.restore(fixture)
		check(rt.validate(rt.state).is_empty(),"valid source prerequisites for "+id)
		check(world._save_game(true)==OK,"prerequisite fixture durable")
		await reopen();await press("GrowthTab_"+str(GROUPS[index]));await press("GuardianNode_"+id)
		var notice: Label=view.find_child("GuardianPveNumericCompatibility",true,false)
		check(notice!=null and notice.text.contains("TWILIGHT") and notice.text.contains("PvE"),"real node UI labels local conversion "+id)
		check(str(rt.node(id).name).contains("PVP"),"raw original node identity stays intact")
		await action("activate")
		rt.state.searches[id].winner=0
		var stones: int=world.inventory["수호석"]
		if index==0:
			var state: Dictionary=rt.state.duplicate(true)
			var hash: String=FileAccess.get_sha256(world.save_path())
			world.source_save_blocked=true
			await press("GuardianCard_0");await press("GrowthConfirm")
			check(rt.state==state and world.inventory["수호석"]==stones and not rt.state.nodes.has(id),"failed paid unlock rolls ownership/cost back")
			check(rt.guardian_combat.pvp_numeric_value("PiercePVPDamageReduction",{})==0 and FileAccess.get_sha256(world.save_path())==hash,"failed unlock has no combat reward and preserves save bytes")
			world.source_save_blocked=false
		await press("GuardianCard_0");await press("GrowthConfirm")
		check(rt.state.nodes.has(id) and world.inventory["수호석"]==stones-int(rt.node(id).cost),"actual paid source card unlock "+id)
	await reopen();await press("GrowthTab_christ");await press("GuardianNode_source523_3382")
	view.scroll.ensure_control_visible(view.find_child("GuardianPveNumericCompatibility",true,false));await frames()
	await snapshot("guardian-pve-numeric-source-and-compatibility")
	world.hud._close_workspace();await frames()
	verify_combat("before reconnect")
	check(world._save_game(true)==OK,"save actual unlocked compatibility rewards")
	var saved_stones: int=world.inventory["수호석"]
	world._load_game(true);await frames();rt=world.growth
	for id: String in TARGETS:check(rt.state.nodes.has(id),"paid source ownership persists "+id)
	check(world.inventory["수호석"]==saved_stones,"paid materials persist without duplicate consumption")
	for monster: Node in world.monsters_root.get_children():monster.set_physics_process(false)
	verify_combat("after reconnect")
	var locked: int=0
	for group: Dictionary in rt.config.guardians:
		if int(group.server_limit_set_id)==0:continue
		for node: Dictionary in group.nodes:
			locked+=1
			check(not rt.quote("activate",str(node.id)).ok,"server condition remains locked")
	check(locked==60,"exact excluded60 untouched")
	await snapshot("guardian-pve-numeric-actual-monster-combat")
	world.queue_free();await create_timer(.1).timeout
	print("GUARDIAN_PVE_NUMERIC_UI_RESULT: ",checks," checks, ",failures," failures; ",RenderingServer.get_video_adapter_name())
	quit(0 if failures==0 else 1)
