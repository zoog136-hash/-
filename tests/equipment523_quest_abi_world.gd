extends RefCounted
## Build an observation-only adapter before Main enters the tree. Preserve its
## actual script and reuse inherited public owners instead of redeclaring them.
static func attach(world: Node) -> Error:
	if world.is_inside_tree(): return ERR_ALREADY_IN_USE
	var original: Script = world.get_script()
	if original == null or original.resource_path.is_empty(): return ERR_INVALID_DATA
	var properties: Dictionary = {}
	for property: Dictionary in world.get_property_list(): properties[str(property.name)] = true
	var source: String = "extends "+JSON.stringify(original.resource_path)+"\n"
	for binding: Array in [["quest_auto","res://scripts/quests/quest_auto_runner.gd"],["quest_item_provider","res://scripts/quests/quest_item_provider238.gd"]]:
		if properties.has(str(binding[0])): continue
		if not ResourceLoader.exists(str(binding[1])): return ERR_FILE_NOT_FOUND
		source += "var "+str(binding[0])+" = load("+JSON.stringify(str(binding[1]))+").new()\n"
	for name: String in ["qa_quest_save_attempts","qa_quest_writer_calls","qa_quest_reject_next_save"]:
		if properties.has(name): return ERR_ALREADY_IN_USE
	source += "var qa_quest_save_attempts: int = 0\nvar qa_quest_writer_calls: int = 0\nvar qa_quest_reject_next_save: bool = false\n"
	source += "func _save_game(quiet: bool, overrides: Dictionary = {}, movement: Dictionary = {}) -> Error:\n"
	source += "\tqa_quest_save_attempts += 1\n\tif qa_quest_reject_next_save:\n\t\tqa_quest_reject_next_save = false\n\t\treturn ERR_CANT_CREATE\n"
	source += "\tqa_quest_writer_calls += 1\n\treturn super._save_game(quiet,overrides,movement)\n"
	var observer := GDScript.new()
	observer.source_code = source
	var result: Error = observer.reload()
	if result != OK: return result
	world.set_script(observer)
	return OK if world.get_script() == observer else ERR_CANT_CREATE
