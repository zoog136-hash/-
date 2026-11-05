extends SceneTree
const Catalog=preload("res://scripts/combinations/source_catalog.gd")
const Effects=preload("res://scripts/combinations/effects.gd")
func _initialize() -> void:
	var path: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--source-zip="):path=arg.trim_prefix("--source-zip=")
	if path.is_empty():push_error("Explicit private latest523 input required");quit(2);return
	var result: Dictionary=Catalog.from_zip(path)
	if not result.ok:push_error(str(result.error));quit(1);return
	var rows: int=0;var effects: int=0;var slots: int=0;var unsupported: Array=[]
	for combo: Dictionary in result.catalog.combinations:
		slots+=combo.slots.size()
		for slot: Dictionary in combo.slots:rows+=slot.candidates.size()
		for effect: Dictionary in combo.effects:
			effects+=1
			if not Effects.supported(effect):unsupported.append(effect.type)
	var output: String="user://combination-source-catalog.json"
	preload("res://scripts/skills/save_writer.gd").write(output,result.catalog)
	print("COMBINATION_SOURCE ",JSON.stringify({"combinations":result.catalog.combinations.size(),"requirements":rows,"slots":slots,"effects":effects,"unsupported":unsupported,"private_catalog":ProjectSettings.globalize_path(output)}))
	quit(0 if rows==272 and effects==91 and slots==199 and unsupported.is_empty() else 1)
