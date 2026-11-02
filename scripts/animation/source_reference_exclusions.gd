extends RefCounted
## User game policy, not recovered M behavior. Never modifies source dictionaries.
const PATH = "res://data/lineagem_base508/unlocated_effect_exclusions.json"
const SOURCE = preload("res://scripts/lineagem_base508.gd")
static var _data: Dictionary = {}
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary and int(parsed.get("schema", 0)) == 1 and parsed.get("source_snapshot", "") == "base508": _data = parsed
	return _data

static func eligible(key: String, snapshot: String) -> bool:
	if snapshot != "base508" or not bool(data().get("default_enabled", false)): return false
	var category: String = {"transform":"변신", "doll":"마법인형", "relic":"성물"}.get(key.get_slice(":", 0), "")
	if category.is_empty(): return false
	var identity: String = key.substr(key.find(":") + 1)
	for entry: Dictionary in data().get("affected_source_cards", []):
		if entry.source_id != identity or entry.category != category or entry.runtime_policy != "exclude_unlocated_references": continue
		for card: Dictionary in SOURCE.cards().get("catalog", {}).get(category, []):
			if card.sourceId == identity: return int(card.source_grade_id) == int(entry.source_grade_id)
	return false

static func clothes_hash(record: Dictionary) -> String:
	var raw: PackedStringArray = []
	for directive: Dictionary in record.get("source_all_declarations", {}).get("directives", []):
		if int(directive.get("code", -1)) == 105: raw.append(str(directive.get("body", "")))
	return "\n".join(raw).sha256_text()

static func matches(record: Dictionary, role: String, track: Dictionary, rule: Dictionary) -> bool:
	return int(record.get("source_sprite_id", -1)) == int(rule.actor_sprite_id) and int(record.get("body_id", -1)) == int(rule.body_id) and role == rule.role and int(track.get("source_sprite_id", -1)) == int(rule.source_sprite_id) and int(track.get("source_action_id", -1)) == int(rule.source_action_id) and str(track.get("source_raw_body", "")).sha256_text() == rule.source_raw_body_sha256

static func has_pixels(track: Dictionary, layer_id: int) -> bool:
	for frames: Array in track.get("directions", []):
		for frame: Dictionary in frames:
			for layer: Dictionary in frame.get("effect_layers", []):
				if int(layer.get("layer_id", -1)) == layer_id and not str(layer.get("path", "")).is_empty(): return true
	return false

static func apply(record: Dictionary, tracks: Dictionary, key: String, manifest: Dictionary) -> Dictionary:
	var state: Dictionary = {"policy_id":data().get("policy_id", ""), "enabled":eligible(key, str(manifest.get("source_snapshot", ""))), "mode":"user_approved_unlocated_effect_exclusion_not_M_equivalence", "excluded_layer_files":[], "excluded_layer_references":[], "excluded_event_rules":[]}
	if not state.enabled: return state
	var reference_hash: String = clothes_hash(record)
	for role: String in tracks:
		var track: Dictionary = tracks[role]
		var kept: Array = []
		for info: Dictionary in track.get("source_effect_layers", []):
			var layer_id: int = int(info.get("sprite_id", -1))
			# A newer supplied pixel, a known sparse layer or explicit empty asset
			# always wins over this user exclusion. No global prefix suppression.
			if not info.get("assets", []).is_empty() or has_pixels(track, layer_id): kept.append(info); continue
			var required: Dictionary = {}
			for frames: Array in track.get("directions", []):
				for frame: Dictionary in frames: required[int(frame.get("physical_group", -1))] = true
			var covered: Dictionary = {}
			var files: Array = []
			for rule: Dictionary in data().get("layer_rules", []):
				if not matches(record, role, track, rule) or reference_hash != rule.source_clothes_body_sha256: continue
				if layer_id != int(rule.layer_id) or int(info.get("physical_sprite_id", -1)) != int(rule.physical_layer_id) or info.get("relation", "") != rule.source_relation: continue
				var attrs: Array = []
				for attr: Variant in info.get("source_attributes", []): attrs.append(str(attr))
				if attrs != rule.source_attributes: continue
				covered[int(rule.chunk)] = true
				if not files.has(rule.file): files.append(rule.file)
			var all_covered: bool = not required.is_empty()
			for chunk: int in required:
				if not covered.has(chunk): all_covered = false
			if not all_covered: kept.append(info); continue
			state.excluded_layer_references.append({"role":role,"source_layer":info.duplicate(true),"files":files})
			for file: String in files:
				if not state.excluded_layer_files.has(file): state.excluded_layer_files.append(file)
		track["source_effect_layers"] = kept
		for rule: Dictionary in data().get("event_rules", []):
			if not matches(record, role, track, rule) or manifest.get("records", {}).has("overlay:" + str(int(rule.event_sprite_id))): continue
			for annotation: Dictionary in track.get("source_annotations", []):
				if int(annotation.get("token_index", -1)) == int(rule.token_index) and str(annotation.get("raw", "")).sha256_text() == rule.annotation_sha256:
					state.excluded_event_rules.append(rule.duplicate(true));break
	return state

static func event_excluded(state: Dictionary, event: Dictionary, sprite_id: int) -> bool:
	if not bool(state.get("enabled", false)): return false
	for rule: Dictionary in state.get("excluded_event_rules", []):
		if sprite_id == int(rule.event_sprite_id) and str(event.get("role", "")) == rule.role and int(event.get("token_index", -1)) == int(rule.token_index) and str(event.get("annotation", {}).get("raw", "")).sha256_text() == rule.annotation_sha256: return true
	return false
