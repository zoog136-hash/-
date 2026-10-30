extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
var capture_dir := ""
func _initialize() -> void: call_deferred("run")
func fail(note: String) -> void: push_error(note); quit(1)
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(capture_dir + "/" + name + ".png")
	if result != OK: fail("capture write failed")
func freeze_sources(vfx: Node) -> void:
	vfx.set_process(false)
	for item: Dictionary in vfx.live:
		var sprite: AnimatedSprite2D = item.get("spx_sprite") as AnimatedSprite2D
		if is_instance_valid(sprite):
			sprite.pause()
			sprite.frame = sprite.sprite_frames.get_frame_count(sprite.animation) / 2
func run() -> void:
	if DisplayServer.get_name() == "headless": fail("OpenGL rendering required"); return
	capture_dir = OS.get_environment("TWILIGHT_SKILL_CAPTURE_DIR")
	if capture_dir.is_empty(): fail("set TWILIGHT_SKILL_CAPTURE_DIR"); return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	for flag: String in ["--legacy-map-layouts", "--legacy-aden-faith-layouts", "--png-review", "--no-native-png-auto"]:
		if flag in OS.get_cmdline_user_args(): fail("representative capture forbids legacy/map override: " + flag); return
	var registry = preload("res://scripts/maps/native_png_registry.gd")
	if not registry.extra_installed(): fail("approved aden_faith_png_v1 pack missing or invalid"); return
	var world: TwilightWorld = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	if not QA.enter_game(world): quit(1); return
	var contract=preload("res://tests/current_main_map_contract.gd")
	if not contract.valid(world):fail("representative capture requires verified current main map identity");return
	print("SIMILAR_RENDER_MAP ",JSON.stringify(contract.describe(world)))
	world.save_timer = -100000
	world.self_mode_enabled = false
	world.player.set_auto_enabled(false)
	world.level = 90
	world.job_class = "기사"
	world.mp = 999
	world.equipped_items["weapon"] = {"name":"검증 양손검", "type":"양손검", "slot":"weapon"}
	world._clear_monsters()
	world._update_hud()
	world.hud.open_skills()
	for i: int in range(4): await process_frame
	var view: Node = world.hud.skills_view
	for row: Dictionary in view.filtered:
		if not row.classes.has("기사"): fail("class permission filter leak"); return
	view.search.text = "no-such-skill-9827"
	view.refresh()
	if not view.learn_button.disabled or not view.book_button.disabled or not view.preview_button.disabled:
		fail("empty query actions remain enabled"); return
	view.search.text = ""
	view.refresh()
	for index: int in range(view.filtered.size()):
		if str(view.filtered[index].name) == "카운터 배리어": view.cards.select(index); view.select(index)
	var browser: Node = view.cards.get_parent().get_parent()
	browser.detail_active = true
	browser.reflow()
	view.preview_button.pressed.emit()
	freeze_sources(view.preview_vfx)
	await process_frame
	var scroll: ScrollContainer = view.find_child("OriginalSkillDetailsScroll", true, false) as ScrollContainer
	scroll.ensure_control_visible(view.preview_container)
	for i: int in range(3): await process_frame
	if view.preview_vfx.live.is_empty(): fail("preview did not render"); return
	await capture("01-learning-preview")
	world.hud._close_workspace()
	var catalog = world.original_skills.catalog
	var counter: Dictionary = catalog.record_for("카운터 배리어")
	catalog.learned[str(counter.id)] = 1
	world.skill_cooldowns.clear()
	world.skill_global_cooldown = 0
	if not world._cast_job_skill(str(counter.id)): fail("real buff cast failed"); return
	freeze_sources(world.original_skills.vfx)
	for i: int in range(3): await process_frame
	var source := false
	for item: Dictionary in world.original_skills.vfx.live:
		if not str(item.get("similar_key", "")).is_empty(): source = true
	if not source: fail("real cast did not select source art"); return
	await capture("02-real-buff-cast")
	var passive: Dictionary = {}
	for row: Dictionary in catalog.records:
		if str(row.mode) == "stats" and catalog.permitted(row): passive = row; break
	catalog.learned.erase(str(passive.id))
	world.inventory[str(passive.book_name)] = 1
	world.original_skills.vfx.clear()
	if not catalog.learn(str(passive.id)): fail("passive learning failed"); return
	if world.original_skills.vfx.live.is_empty(): fail("passive learning cue missing"); return
	freeze_sources(world.original_skills.vfx)
	for i: int in range(3): await process_frame
	await capture("03-passive-learn")
	world.original_skills.vfx.clear()
	world.original_skills.tick(.1)
	for item: Dictionary in world.original_skills.vfx.live:
		if str(item.id) == str(passive.id): fail("stats passive periodically cast"); return
	world.gold=10000000;world.max_mp=1000;world.mp=1000
	world.hud.open_skills()
	for i: int in range(2): await process_frame
	view=world.hud.skills_view
	view.search.text="프라이드";view.refresh()
	view.book_button.pressed.emit();view.learn_button.pressed.emit()
	world.inventory["명예 코인"]=8;world.skill_cooldowns.clear();world.skill_global_cooldown=0
	view.select(0);view.use_button.pressed.emit()
	if not world.active_skill_buffs.has("프라이드") or world.mp!=970 or world.inventory["명예 코인"]!=0:
		fail("new Pride actual UI cast/cost failed");return
	freeze_sources(world.original_skills.vfx)
	var new_browser: Node=view.cards.get_parent().get_parent()
	new_browser.detail_active=true;new_browser.reflow()
	view.preview_button.pressed.emit();freeze_sources(view.preview_vfx)
	await process_frame
	var new_scroll: ScrollContainer=view.find_child("OriginalSkillDetailsScroll",true,false) as ScrollContainer
	new_scroll.ensure_control_visible(view.preview_container)
	await capture("04-pride-paid-cast")
	world.hud._close_workspace()
	world._on_job_class_selected("요정")
	world.level=90;world.max_mp=1000;world.mp=1000
	world.equipped_items={"weapon":{"name":"검증 활","type":"활","slot":"weapon"}}
	world._update_hud();world.hud.open_skills()
	for i: int in range(2): await process_frame
	view=world.hud.skills_view;view.search.text="슈팅 스타";view.refresh()
	view.book_button.pressed.emit();view.learn_button.pressed.emit()
	world.skill_global_cooldown=0;world.skill_cooldowns.clear();view.select(0);view.use_button.pressed.emit()
	if not world.original_skills.local_runtime.is_on(view.selected) or world.mp!=974:
		fail("Shooting actual ON toggle/cost failed");return
	freeze_sources(world.original_skills.vfx)
	new_browser=view.cards.get_parent().get_parent();new_browser.detail_active=true;new_browser.reflow()
	view.preview_button.pressed.emit();freeze_sources(view.preview_vfx)
	await process_frame
	new_scroll=view.find_child("OriginalSkillDetailsScroll",true,false) as ScrollContainer
	new_scroll.ensure_control_visible(view.preview_container)
	await capture("05-shooting-real-toggle-on")
	world.queue_free()
	await process_frame
	print("SIMILAR_RENDER_OK: verified current-main Aden contract, real OpenGL game, UI permission/empty query, buff cast, passive learning without periodic cast")
	quit(0)
