extends SceneTree
## Explicit negative-input test: ConfigFile emits one expected parse error.
## Kept separate from clean Main/UI logs; ERR_PARSE must preserve exact bytes.
func _initialize() -> void:
	var rules=preload("res://scripts/skills/recovery_rules523.gd").new()
	var path: String=rules.PATH
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string("[broken");file.close()
	var before: String=FileAccess.get_sha256(path)
	var blocked: bool=not rules.update_setting("lm_1fb2fb45ca7bb6e5","heal",999)
	var preserved: bool=FileAccess.get_sha256(path)==before
	var finite: bool=not rules.update_setting("lm_1fb2fb45ca7bb6e5","heal",NAN)
	DirAccess.remove_absolute(path)
	print("RECOVERY523_NEGATIVE_RESULT ",JSON.stringify({"blocked":blocked,"preserved":preserved,"finite":finite,"expected_engine_parse_errors":1}))
	quit(0 if blocked and preserved and finite else 1)
