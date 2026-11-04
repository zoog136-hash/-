extends RefCounted
## Exact current523 key/path bindings; Godot owns the responsive layout.
const PROFILE = preload("res://data/ui/patch523_collection_bindings.json")
const ATLAS = preload("res://scripts/ui/source_ui_atlas.gd")

static func bind(control: Control, key: String) -> void:
	var binding: Dictionary = PROFILE.data.bindings.get(key, {})
	if binding.is_empty(): return
	control.set_meta("original_ui_binding", binding)
	if not control is Button: return
	var node: Dictionary = binding.node
	for field: String in ["normal_resource", "pressed_resource", "disabled_resource"]:
		var ref: Dictionary = node.get(field, {})
		if str(ref.get("plist", "")).is_empty(): continue
		var texture: Texture2D = ATLAS.texture("UI/" + str(ref.plist), str(ref.path))
		if texture == null: continue
		var box := StyleBoxTexture.new()
		box.texture = texture
		var state: String = {"normal_resource":"normal", "pressed_resource":"pressed", "disabled_resource":"disabled"}[field]
		control.add_theme_stylebox_override(state, box)
		if state == "normal": control.add_theme_stylebox_override("hover", box)

static func effect_identity(effect: Dictionary) -> String:
	# BonusType alone loses distinct SpellClass/SpecialResistance targets.
	var raw: Dictionary = effect.get("source_original", {}).get("bonus", {})
	if raw.is_empty(): return str(effect.key) + ":" + str(effect.unit)
	return "%d:%d:%d:%s" % [int(raw.BonusTypeID), int(raw.BonusApplicationTypeID), int(raw.BonusApplicationTargetID), str(effect.unit)]

static func effect_title(effect: Dictionary) -> String:
	var raw: Dictionary = effect.get("source_original", {})
	if raw.is_empty(): return str(effect.get("label", effect.key))
	if preload("res://scripts/cards/native_collection_rules.gd").interval_supported(effect):
		var target: String=str(raw.nested_intervals[0].application_target.Name)
		return "HP 구간 · "+("스턴" if target=="Stun" else "공포")+" 내성"
	var label: String = str(effect.label)
	var pattern := RegEx.new()
	pattern.compile("\\s*[+-]?[0-9]+(?:\\.[0-9]+)?%?$")
	label = pattern.sub(label, "").strip_edges()
	# Unknown targets remain distinct and inspectable without an invented name.
	var bonus: Dictionary = raw.get("bonus", {})
	if int(bonus.get("BonusApplicationTypeID", 0)) != 0 and raw.get("application_target", {}).get("target_row") == null:
		label += " · 대상 %d:%d" % [int(bonus.BonusApplicationTypeID), int(bonus.BonusApplicationTargetID)]
	return label

static func detail_tooltip(row: Dictionary) -> String:
	var parts: Array[String] = []
	for effect: Dictionary in row.effects:
		var raw: Dictionary = effect.get("source_original", {})
		var bonus: Dictionary = raw.get("bonus", {})
		if not bonus.is_empty():
			parts.append("%s [Bonus %d · 대상 %d:%d]" % [effect.label, int(bonus.ID), int(bonus.BonusApplicationTypeID), int(bonus.BonusApplicationTargetID)])
		for interval: Dictionary in raw.get("nested_intervals", []):
			var nested: Dictionary = interval.get("bonus", {})
			parts.append("HP 원본 구간 %s~%s · %s · 대상 %s:%s · 원값 %s" % [interval.Low, interval.High, str(interval.get("bonus_type", {}).get("Name", "")), str(nested.get("BonusApplicationTypeID", "")), str(nested.get("BonusApplicationTargetID", "")), str(nested.get("Value", ""))])
	if row.effects.any(func(effect: Dictionary) -> bool:return preload("res://scripts/cards/native_collection_rules.gd").interval_supported(effect)):
		parts.append("HP 구간: 생존 HP 비율 올림 · 양 끝 포함 · 빈 구간 0 (TWILIGHT 적용 규칙)")
	return "\n".join(parts)

static func interval_description(effect: Dictionary) -> String:
	var rules: Script=preload("res://scripts/cards/native_collection_rules.gd")
	if not rules.interval_supported(effect):return str(effect.label)
	var parts: Array[String]=[]
	for branch: Dictionary in effect.source_original.nested_intervals:
		var name: String="스턴" if branch.application_target.Name=="Stun" else "공포"
		parts.append("HP %d~%d%% · %s 내성 +%s%%" % [maxi(1,int(branch.Low)),int(branch.High),name,str(float(branch.bonus.Value)/float(branch.ui_unit.Denominator))])
	return " / ".join(parts)
