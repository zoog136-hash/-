extends SceneTree
## 오림 영웅 외형 (TWILIGHT 근사, docs/orim523_missing_rules.md): the hero's original
## OrimsTrailCharacter.SpriteID drawn over the player during an active Orim run with
## the Orim NPC core actions. Without the original ZIP only the refusal runs.
const VIEW = preload("res://scripts/orim523/orim523_actor_view.gd")
const MODEL = preload("res://scripts/orim523/orim523.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("ORIM523_HERO_VISUAL_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	var service = world.dungeon_play
	var model: Dictionary = service.orim_model()
	if not check(bool(model.get("ok",false)), "original Orim tables: "+str(model.get("problem",""))):
		world.queue_free(); await process_frame; return
	# Every hero's sprite with the core actions.
	var heroes: Dictionary = {}
	for hero: Dictionary in model.characters:
		var view: Node = VIEW.new()
		root.add_child(view)
		var ok: bool = view.configure_hero(int(hero.id), int(hero.sprite))
		heroes[str(hero.name)] = {"sprite":int(hero.sprite),"ok":ok,"reason":str(view.selection_status.get("reason",""))}
		view.queue_free()
		await process_frame
	evidence["heroes"] = heroes
	var opened: int = 0
	for value: Dictionary in heroes.values(): opened += 1 if value.ok else 0
	check(opened > 0, "hero sprites with the core actions: "+str(heroes))
	# An active run shows the hero over the player; ending it restores the player.
	var first: int = 0
	for hero: Dictionary in model.characters:
		if bool(heroes[str(hero.name)].ok): first = int(hero.id); break
	var saved_active: Dictionary = service.state.active.duplicate(true)
	service.state.active = {"kind":"orim","status":"active","orim":{"character":first}}
	service._orim_hero_visual(0.1)
	world.player._refresh_visual_visibility()
	var view_node: Node = world.player.get_node_or_null("OrimHeroVisual")
	evidence["on"] = {"status":service.orim_hero_status,"node":view_node != null,"override":world.player.appearance_override_active,"class_visible":world.player.class_sprite.visible}
	check(view_node != null and world.player.appearance_override_active and not world.player.class_sprite.visible, "active run: hero visual on, player sprites hidden "+str(evidence.on))
	for frame: int in 5:
		service._orim_hero_visual(0.1)
	check(is_instance_valid(view_node) and view_node.selection_status.get("ok",false), "hero visual keeps advancing")
	service.state.active = saved_active
	service._orim_hero_visual(0.1)
	world.player._refresh_visual_visibility()
	await process_frame
	evidence["off"] = {"override":world.player.appearance_override_active,"node":world.player.get_node_or_null("OrimHeroVisual") != null}
	check(not world.player.appearance_override_active and world.player.get_node_or_null("OrimHeroVisual") == null, "no run: player look restored "+str(evidence.off))
	world.queue_free()
	for frame: int in 10: await process_frame

func run() -> void:
	if SOURCE.not_installed():
		check(not VIEW.hero_selection(2, 23755).get("ok", true), "without the original ZIP no hero visual")
	else:
		await runtime()
	print("ORIM523_HERO_VISUAL_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
