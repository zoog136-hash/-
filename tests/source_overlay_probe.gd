extends "res://scripts/animation/original_source_preview.gd"
## No pixels: a factory/selection probe, never source-art validation.
static var reject_small: bool = false
var files_available: bool = true
func _overlay_files_available(_sprite_id: int, _original_id: int = -1) -> bool: return files_available
func configure(key: String, _manifest: String, _context: Dictionary = {}) -> bool:
	set_meta("probe_key",key)
	return not (reject_small and key=="overlay:29044")
func advance_source(_delta: float, _role_name: String, _facing: int, _sequence_id: int, _attack: bool) -> void: pass
