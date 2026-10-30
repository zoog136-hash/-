extends RefCounted

const UI=preload("res://scripts/ui/renewal_theme.gd")
# Inspected Korean LineageM menu/UI guide: attribute groups on the left,
# other available statistics on the right. No copied game texture or values.
# https://imgfiles-cdn.plaync.com/file/LineageM/download/20220307220437-FAZOiUEZCkPhjjrpuxsm0-v4
const ATTRIBUTES={
	"STR":["melee_damage","melee_accuracy","melee_critical"],
	"DEX":["ranged_damage","ranged_accuracy","ranged_critical","ac","er"],
	"CON":["max_hp","hp_regen","max_weight"],
	"INT":["magic_damage","magic_accuracy","magic_critical"],
	"WIS":["max_mp","mp_regen","mr"]
}
const OTHER_ORDER=[
	"attack_speed_bonus","move_speed_bonus","dg","damage_reduction",
	"critical_resistance","skill_cooldown_reduction","attack_interval",
	"weapon_small_damage","weapon_large_damage","stun_resistance",
	"silence_resistance","hold_resistance","fear_resistance","poison_resistance","bleed_resistance"
]

static func build(view: ScrollContainer,state: Dictionary) -> HBoxContainer:
	var columns:=HBoxContainer.new()
	columns.name="StatusAttributeColumns"
	columns.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation",8)
	view.add_child(columns)
	var primary:=VBoxContainer.new()
	primary.name="StatusAttributeGroups"
	primary.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	primary.add_theme_constant_override("separation",5)
	columns.add_child(primary)
	var secondary:=VBoxContainer.new()
	secondary.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	columns.add_child(secondary)
	var specs: Dictionary={}
	for group: String in view.GROUPS:
		for spec: Array in view.GROUPS[group]:specs[str(spec[0])]=spec
	var used: Dictionary={}
	for attribute: String in ATTRIBUTES:
		var keys: Array=[]
		for key: String in ATTRIBUTES[attribute]:
			if state.has(key) and specs.has(key):
				keys.append(key)
				used[key]=true
		if not keys.is_empty():_group(view,primary,attribute,keys,specs)
	var other: Array=[]
	var ordered: Array=OTHER_ORDER.duplicate()
	for key: String in specs:
		if not ordered.has(key):ordered.append(key)
	for key: String in ordered:
		if state.has(key) and specs.has(key) and not used.has(key):other.append(key)
	if not other.is_empty():_group(view,secondary,"ETC",other,specs)
	return columns

static func _group(view: ScrollContainer,parent: VBoxContainer,code: String,keys: Array,specs: Dictionary) -> void:
	var panel:=PanelContainer.new()
	panel.name="StatusGroup"+code
	panel.add_theme_stylebox_override("panel",UI.MATERIAL.from_flat(UI.box(Color("201b17"),Color("3d332b"),7),true))
	parent.add_child(panel)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",7)
	panel.add_child(row)
	var heading: Label=UI.label(code,14,UI.TEXT)
	heading.custom_minimum_size.x=34
	heading.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(heading)
	var metrics:=VBoxContainer.new()
	metrics.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	metrics.add_theme_constant_override("separation",1)
	row.add_child(metrics)
	for key: String in keys:
		var metric:=HBoxContainer.new()
		metric.custom_minimum_size.y=25
		metric.add_theme_constant_override("separation",6)
		metrics.add_child(metric)
		var title: Label=UI.label(str(specs[key][1]),12,UI.TEXT)
		title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		metric.add_child(title)
		var value: Label=UI.label("",13,UI.GOLD)
		value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		value.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		value.custom_minimum_size.x=44
		metric.add_child(value)
		view.values[key]=value
