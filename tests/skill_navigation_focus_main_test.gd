extends SceneTree

const QA = preload("res://tests/qa_class_selection.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("SKILL_NAVIGATION_FOCUS_FAIL ", label)
	return ok

func run() -> void:
	if check(not FileAccess.file_exists("user://twilight_v20_save.json"), "isolated Main save profile"):
		root.size = Vector2i(1280, 720)
		var world: Node = load("res://Main.tscn").instantiate()
		root.add_child(world)
		current_scene = world
		world.set_process(false)
		world.save_timer = -100000.0
		await process_frame
		if check(QA.enter_game(world), "actual Main enters"):
			world.field_population.set_process(false)
			world.player.set_physics_process(false)
			await exercise(world.hud)
		world.queue_free()
		await process_frame
	print("SKILL_NAVIGATION_FOCUS_RESULT ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func exercise(hud: Node) -> void:
	hud.open_skills_workspace()
	await process_frame
	var list: Control = hud.skills_view
	if not check(list.filtered.size() >= 2, "two actual skill rows"): return
	var first: Dictionary = list.filtered[0]
	var second: Dictionary = list.filtered[1]
	var query: String = str(first.name)
	list.search.text = query
	list.refresh()
	for index: int in range(list.filtered.size()):
		if list.filtered[index].get("id") == first.id:
			list.select(index)
			break
	hud._close_workspace()
	var saved: Dictionary = hud.navigation_memory.states.get("skills", {}).duplicate(true)
	if not check(saved.get("query") == query and saved.get("id") == str(first.id), "normal list saves its search and selection"): return

	hud.open_skills_workspace(str(second.id))
	await process_frame
	await process_frame
	var focused: Control = hud.skills_view
	check(focused.focus_only and focused.selected.get("id") == second.id and focused.search.text.is_empty(),
		"deferred restore keeps the specific detail and never imports the normal search")
	hud._close_workspace()
	check(hud.navigation_memory.states.get("skills") == saved, "closing the detail keeps the normal list snapshot")

	hud.open_skills_workspace()
	await process_frame
	await process_frame
	var reopened: Control = hud.skills_view
	check(reopened.search.text == query and reopened.selected.get("id") == first.id, "normal list reopens with its prior search and selection")
	hud._close_workspace()
