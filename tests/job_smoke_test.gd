extends SceneTree

const EXPECTED_JOBS: Array[String] = [
	"기사", "군주", "요정", "마법사", "다크엘프", "총사", "투사",
	"암흑기사", "신성검사", "광전사", "사신", "뇌신", "마검사"
]

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	failures.append(message)
	print("SMOKE FAIL: " + message)

func _run() -> void:
	var main_scene: PackedScene = load("res://Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main.tscn could not be loaded")
		_finish()
		return

	var world: Node = main_scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var jobs_value: Variant = world.get("job_classes")
	if not (jobs_value is Array):
		_fail("job_classes is not an Array")
	else:
		var jobs: Array = jobs_value as Array
		if jobs.size() != EXPECTED_JOBS.size():
			_fail("expected %d job classes, got %d" % [EXPECTED_JOBS.size(), jobs.size()])
		var seen: Dictionary = {}
		for value: Variant in jobs:
			if not (value is Dictionary):
				_fail("job profile is not a Dictionary")
				continue
			var profile: Dictionary = value as Dictionary
			var job_name: String = str(profile.get("name", ""))
			seen[job_name] = true
			var image_path: String = str(profile.get("image_path", ""))
			if image_path == "" or not ResourceLoader.exists(image_path):
				_fail("%s representative mythic image is missing: %s" % [job_name, image_path])
		for job_name: String in EXPECTED_JOBS:
			if not seen.has(job_name):
				_fail("missing job class: " + job_name)

	var skills_value: Variant = world.get("skills_db")
	if not (skills_value is Array):
		_fail("skills_db is not an Array")
	else:
		var skills: Array = skills_value as Array
		for job_name: String in EXPECTED_JOBS:
			var exclusive_count: int = 0
			for value: Variant in skills:
				if value is Dictionary and str((value as Dictionary).get("class", "")) == job_name:
					exclusive_count += 1
			if exclusive_count <= 0:
				_fail("%s has no class skills" % job_name)

	for job_name: String in EXPECTED_JOBS:
		world.call("_on_job_class_selected", job_name)
		await process_frame
		if str(world.get("job_class")) != job_name:
			_fail("job change did not stick: " + job_name)
		world.call("_refresh_combat_hud")
		var hud: Node = world.get("hud")
		if not str(hud.player_label.text).contains(job_name):
			_fail("combat HP refresh changed the base HUD class name: " + job_name)
		if str(hud.v20_status_name.text) != "황혼의 " + job_name:
			_fail("combat HP refresh changed the visible HUD class name: " + job_name)
		var quickbar_value: Variant = world.call("_quickbar_job_skills")
		if not (quickbar_value is Array) or (quickbar_value as Array).is_empty():
			_fail("%s quickbar is empty" % job_name)
		var transform_value: Variant = world.call("_job_transform_record", job_name)
		if not (transform_value is Dictionary) or (transform_value as Dictionary).is_empty():
			_fail("%s mythic transform record is missing" % job_name)

	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("JOB_SMOKE_OK: 13 jobs, mythic visuals, class skills and quickbars validated")
		quit(0)
	else:
		print("JOB_SMOKE_FAILED: %d failure(s)" % failures.size())
		quit(1)
