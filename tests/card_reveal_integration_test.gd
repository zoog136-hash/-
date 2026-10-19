extends SceneTree

const PROFILES = preload("res://scripts/ui/card_reveal_profiles.gd")
const STAGE = preload("res://scripts/ui/card_reveal_stage.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("CARD_REVEAL_FAIL: "+label)

func _run() -> void:
	var game: Node = load("res://Main.tscn").instantiate()
	root.add_child(game)
	for frame: int in range(8):
		await process_frame
	var world: Node = game if game.has_method("_on_card_pack_draw_requested") else game.find_child("World",true,false)
	_check(world != null,"actual Main world resolves")
	if world == null:
		quit(1)
		return
	var hud: Node = world.hud
	world._on_card_pack_draw_requested("변신")
	await process_frame
	_check(hud.is_card_reveal_busy(),"real world draw opens native reveal")
	var stage: Control = hud.card_reveal_stage
	_check(stage.results.size() == 11,"eleven actual awarded cards are presented")
	var awarded: Dictionary = world.card_draw_fusion.export_state().duplicate(true)
	var view_before: Array = stage.results.duplicate(true)
	world._on_card_pack_draw_requested("변신")
	_check(awarded == world.card_draw_fusion.export_state(),"busy screen blocks additional authoritative draws")
	stage.seek(2.3)
	stage.skip_to_result()
	_check(stage.results == view_before,"skip preserves exact IDs and grades")
	_check(awarded == world.card_draw_fusion.export_state(),"skip cannot reroll or award")
	stage.close_reveal()
	await process_frame
	await process_frame
	_check(not hud.is_card_reveal_busy(),"closing releases busy state")
	_check(awarded == world.card_draw_fusion.export_state(),"closing cannot award")
	for category: String in ["변신","마법인형","성물"]:
		var identity: String = ""
		for raw: Variant in world.catalog_db[category]:
			if str(raw.get("grade","")) == "신화":
				identity = world.CARD_DRAW_FUSION.card_id(raw)
				break
		_check(not identity.is_empty(),category+" myth material exists")
		var fixture: Dictionary = world.card_draw_fusion.export_state()
		fixture.owned[category][identity] = true
		fixture.spare[category][identity] = 4
		world.card_draw_fusion.import_state(fixture)
		world._on_card_fusion_requested(category,"신화")
		stage = hud.card_reveal_stage
		_check(stage != null and stage.fusion and stage.upgrade,category+" actual successful fusion connected")
		_check(stage.results.size() == 1 and stage.results[0].grade == "유일",category+" unique result is authoritative")
		_check(world.card_draw_fusion.spare_count(category,"신화") == 0,category+" materials spent once")
		var saved: Dictionary = world.card_draw_fusion.export_state().duplicate(true)
		world._on_card_fusion_requested(category,"신화")
		stage.skip_to_result()
		stage.close_reveal()
		await process_frame
		await process_frame
		_check(saved == world.card_draw_fusion.export_state(),category+" duplicate request/skip/close does not consume twice")
	var previous: Dictionary = {}
	for grade: String in PROFILES.SHOWCASE:
		var p: Dictionary = PROFILES.profile(grade)
		if not previous.is_empty():
			for key: String in ["bolts","branches","pulses","burst","smoke","embers","power"]:
				_check(float(p[key]) > float(previous[key]),grade+" progressive "+key)
		previous = p
	_check(PROFILES.color("유일").g > PROFILES.color("유일").r*4 and PROFILES.color("유일").g > PROFILES.color("유일").b,"unique uses emerald")
	for viewport_size: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(412,915),Vector2i(915,412)]:
		root.size = viewport_size
		stage = STAGE.new()
		root.add_child(stage)
		stage.present_showcase()
		stage.set_process(false)
		await process_frame
		stage.seek(3.58)
		for card: Control in stage.cards:
			var body: Rect2 = card.get_global_rect()
			var visible_area: Rect2 = root.get_visible_rect()
			_check(visible_area.encloses(body),str(viewport_size)+" grade card visible")
		_check(stage.get_node("RevealComposition/ConfirmReveal").get_global_rect().end.y <= root.get_visible_rect().end.y,str(viewport_size)+" confirm reachable")
		stage.close_reveal()
		await process_frame
		for category: String in ["변신","마법인형","성물"]:
			stage = STAGE.new()
			root.add_child(stage)
			var records: Array[Dictionary] = []
			for entry: Dictionary in view_before:
				records.append(entry.duplicate(true))
			var textures: Array[Texture2D] = []
			stage.present(records,textures,category)
			stage.set_process(false)
			await process_frame
			stage.skip_to_result()
			for card: Control in stage.cards:
				_check(not stage.result_note.get_global_rect().intersects(card.grade_label.get_global_rect()),str(viewport_size)+category+" result note avoids card labels")
			stage.close_reveal()
			await process_frame
	game.queue_free()
	await process_frame
	print("CARD_REVEAL_RESULT "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
