extends SceneTree
## The class picker asks for the character's gender (original Gender table:
## 1 Male, 2 Female). The 523 character picture is chosen by class and gender,
## so without this choice the installed 523 bank drew no player at all.
## - a new character confirms class + gender together;
## - confirming only a gender for an existing character keeps its class and
##   equipped transform card;
## - the gender is saved and restored.
## Real input: -- --source523-pack=<installed pack folder> also checks that the
## 523 player picture appears once the gender is known.
const PACK = preload("res://scripts/boot/source523_pack.gd")
const HOST = preload("res://scripts/maps/current523_host.gd")
var checks: int = 0
var failures: Array[String] = []
var world: Node
var save_backup: PackedByteArray
var save_existed: bool = false
var save_file: String = ""
var save_checked: bool = false

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func arg(prefix: String) -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return ""

func _initialize() -> void:
	_run.call_deferred()

func _picker() -> Node:
	return world.find_child("ClassSelectionScreen", true, false)

func _source_pictures() -> int:
	var preview: Node = world.get("player").get("original_source_preview")
	var count: int = 0
	if preview != null and (preview as CanvasItem).is_visible_in_tree():
		for node: Node in preview.find_children("*", "Sprite2D", true, false):
			if (node as Sprite2D).texture != null and (node as Sprite2D).is_visible_in_tree(): count += 1
	return count

func _run() -> void:
	var base: String = arg("--source523-pack=")
	if not base.is_empty():
		var read: Dictionary = PACK.read_descriptor(base.path_join("source523_pack.json"))
		check(read.ok and PACK.apply(PACK.selections(base, read.descriptor, PACK.read_addons(base))).ok, "installed pack applied")
		HOST.refresh()
	var scene: PackedScene = load("res://Main.tscn")
	save_file = "user://twilight_v20_save.json"
	save_existed = FileAccess.file_exists(save_file)
	if save_existed:
		save_backup = FileAccess.get_file_as_bytes(save_file)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_file))
	world = scene.instantiate()
	root.add_child(world)
	for _frame: int in 900:
		if base.is_empty() or bool(world.get("current523_aden_play_active")): break
		await process_frame
	for _frame: int in 5: await process_frame
	check(int(world.get("source_gender_id")) == 0, "a new character has no gender yet")
	var hud: Node = world.get("hud")
	hud.call("open_class_selection", true)
	await process_frame
	var picker: Node = _picker()
	check(picker != null, "the class picker opens")
	if picker == null: _finish(); return
	var confirm: Button = picker.find_child("ClassConfirm", true, false)
	var gender_row: Control = picker.find_child("GenderRow", true, false)
	if base.is_empty():
		# Without the 523 bank nothing is drawn by gender: class-only, as before.
		check(gender_row != null and not gender_row.visible, "without the 523 bank the picker stays class-only")
		picker.call("_choose", "기사")
		check(not confirm.disabled, "a class alone confirms without the 523 bank")
		picker.call("_confirm")
		for _frame: int in 5: await process_frame
		check(str(world.get("job_class")) == "기사" and int(world.get("source_gender_id")) == 0, "the character is created without a gender")
		check(not bool(world.call("_source_gender_needed")), "no gender is asked for without the 523 bank")
		_finish()
		return
	check(gender_row != null and gender_row.visible, "with the 523 bank the picker asks for the gender")
	check(picker.find_child("Gender_1", true, false) is Button and picker.find_child("Gender_2", true, false) is Button, "the picker offers 남성/여성")
	picker.call("_choose", "기사")
	check(confirm.disabled, "a class alone cannot be confirmed without a gender")
	# 마검사 has no female picture in the original Class table (FemaleSpriteID 0).
	picker.call("_choose", "마검사")
	var female: Button = picker.find_child("Gender_2", true, false)
	check(female.disabled and int(picker.get("selected_gender")) == 1, "a male-only class offers only 남성")
	picker.call("_choose", "기사")
	check(not female.disabled, "기사 offers both genders")
	picker.call("_choose_gender", 2)
	check(not confirm.disabled and confirm.text.contains("여성"), "class + gender can be confirmed: " + confirm.text)
	picker.call("_confirm")
	for _frame: int in 5: await process_frame
	check(int(world.get("source_gender_id")) == 2 and str(world.get("job_class")) == "기사", "the new character is a female 기사")
	check(world.call("_source_visual_context").get("gender_id") == 2, "the 523 picture context carries the gender")
	var transform_before: Variant = (world.get("equipped_catalog") as Dictionary).get("변신", {}).duplicate(true)
	if not base.is_empty():
		for _frame: int in 30: await process_frame
		print("FIRST transform=%s source_class=%s key=%s" % [str(world.get("player").get("transform_active")), str(world.get("player").get("_source_only_class")), str(world.get("player").get("original_source_preview").get("reference_bank_status").get("request_key"))])
		check(_source_pictures() > 0, "the 523 player picture is drawn: " + str(world.get("player").get("original_source_preview").get("source_selection_status")).left(300))
	# An existing character: change only the gender.
	hud.call("open_class_selection", false)
	await process_frame
	picker = _picker()
	check(picker != null and int(picker.get("selected_gender")) == 2, "the current gender is preselected")
	if picker == null: _finish(); return
	picker.call("_choose_gender", 1)
	picker.call("_confirm")
	for _frame: int in 5: await process_frame
	check(int(world.get("source_gender_id")) == 1 and str(world.get("job_class")) == "기사", "only the gender changed")
	check((world.get("equipped_catalog") as Dictionary).get("변신", {}) == transform_before, "the equipped transform card is kept")
	# The gender is written by the existing save (source_visual_context.gender_id).
	# Without the private game data this headless setup refuses to save at all;
	# then only the in-memory state is checked.
	var saved_error: int = int(world.call("_save_game", true))
	save_checked = saved_error == OK
	if save_checked:
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(world.call("save_path"))))
		var saved_context: Variant = (saved as Dictionary).get("source_visual_context", {}) if saved is Dictionary else null
		check(saved_context is Dictionary and int(saved_context.get("gender_id", -1)) == 1, "the gender is saved: " + str(saved_context).left(200))
	if not base.is_empty():
		for _frame: int in 30: await process_frame
		var preview_after: Node = world.get("player").get("original_source_preview")
		check(_source_pictures() > 0, "the 523 player picture follows the new gender: transform=%s source_class=%s visible=%s status=%s bank=%s" % [str(world.get("player").get("transform_active")), str(world.get("player").get("_source_only_class")), str((preview_after as CanvasItem).visible), str(preview_after.get("source_selection_status")).left(400), str(preview_after.get("reference_bank_status")).left(300)])
		var shot: String = arg("--shot=")
		if not shot.is_empty() and DisplayServer.get_name() != "headless":
			for _frame: int in 20: await process_frame
			root.get_viewport().get_texture().get_image().save_png(shot)
	_finish()

func _finish() -> void:
	if world != null:
		world.queue_free()
	if save_existed:
		var file := FileAccess.open(save_file, FileAccess.WRITE)
		if file != null: file.store_buffer(save_backup); file.close()
	elif FileAccess.file_exists(save_file):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_file))
	print("SOURCE_GENDER_SELECTION_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"real_input_checked":not arg("--source523-pack=").is_empty(),"save_checked":save_checked}))
	quit(0 if failures.is_empty() else 1)
