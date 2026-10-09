extends SceneTree

var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		print("ORIGINAL CATALOG FAIL: ",message)

func run() -> void:
	var world: TwilightWorld = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.level = 90
	world._clear_monsters()
	var dummy: TwilightMonster = (load("res://scenes/Monster.tscn") as PackedScene).instantiate()
	world.monsters_root.add_child(dummy)
	dummy.setup({"name":"도감 실행 검사","hp":10000000,"lv":1,"ac":0,"mr":0},world.player,world,null)
	dummy.global_position = world.player.global_position + Vector2(10,0)
	dummy.set_physics_process(false)
	var catalog := world.original_skills.catalog
	for record: Dictionary in catalog.records: catalog.learned[str(record.id)] = 1
	var active_count := 0
	for record: Dictionary in catalog.records:
		world._clear_combat_actions()
		world.active_skill_buffs.clear()
		world.skill_cooldowns.clear()
		world.skill_global_cooldown = 0
		world.job_class = str(record.classes[0])
		world.equipped_items["weapon"] = {"name":"검사 무기","type":str(record.weapons[0]) if not record.weapons.is_empty() else "한손검","slot":"weapon"}
		catalog.schools["요정"] = record.school if record.school in ["water","earth","wind","fire"] else "water"
		world.mp = 999
		world.hp = world._effective_max_hp() - 5
		world.player.clear_status_effects()
		world.player.apply_poison(10,1)
		world.selected_monster = dummy
		if record.mode == "convert": world.mp = 0
		for item: String in record.items: world.inventory[item] = 100
		check(ResourceLoader.exists(str(record.icon)), "icon "+str(record.name))
		check(ResourceLoader.exists("res://assets/skills/audio/"+str(record.id)+".wav"), "sound "+str(record.name))
		if record.activation == "passive":
			check(not world._cast_job_skill(str(record.name)), "passive callable "+str(record.name))
		else:
			active_count += 1
			var successful := world._cast_job_skill(str(record.name))
			check(successful, "active path "+str(record.name))
			if not world.pending_attack.is_empty(): preload("res://tests/combat_test_clock.gd").settle(world)
			world.player.global_position = dummy.global_position - Vector2(10,0)
	# Corrected class and passive conditions replace the legacy fictional stats.
	var focus := catalog.record_for("멘탈 포커스")
	world.job_class = "요정"
	check(not catalog.enabled(focus), "mental focus cannot strengthen elf attacks")
	world.job_class = "마법사"
	check(catalog.enabled(focus), "mental focus wizard passive")
	check(float(catalog.resolve(focus).stats.get("atk",0)) == 0, "mental focus does not add attack")
	world.hud.open_skills()
	await process_frame
	var view: Node = world.hud.skills_view
	check(is_instance_valid(view.learn_button) and is_instance_valid(view.preview_vfx), "learning and VFX preview mounted")
	check(view.cards.item_count > 0, "original records displayed")
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
		root.size = extent
		world.hud._fit_hud()
		for _frame: int in range(3): await process_frame
		var browser: Control = view.cards.get_parent().get_parent()
		browser.detail_active = true
		browser.reflow()
		for _frame: int in range(3): await process_frame
		check(view.detail.size.y >= 120, "readable detail height " + str(extent))
		check(view.detail.scroll_active, "full learning details remain scrollable")
		check(browser.details is ScrollContainer, "compact actions have a scrollable detail pane")
		check(browser.details.get_global_rect().end.y <= world.hud.workspace.content.get_global_rect().end.y + 1, "detail pane stays inside the workspace " + str(extent))
	world.queue_free()
	await process_frame
	if failures.is_empty(): print("ORIGINAL_SKILL_CATALOG_RUNTIME_OK records=",catalog.records.size()," active=",active_count)
	quit(0 if failures.is_empty() else 1)
