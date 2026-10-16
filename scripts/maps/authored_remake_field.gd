extends "res://scripts/maps/playable_field.gd"
class_name AuthoredRemakeField
## Existing TWILIGHT polygons, never presented as recovered A3/M coordinates.
var remake_profile: Dictionary = {}
var collision_stream: StaticBody2D

func configure_remake(definition: Dictionary, profile: Dictionary) -> void:
	remake_profile = profile.duplicate(true)
	# The factory receives the effective DB layout. Only render metadata changes;
	# collision, paths, spawn regions and layout revisions keep their exact values.
	definition["remake"] = {"source_kind":"TWILIGHT_AUTHORED_POLYGONS",
		"source_edition":"PROVISIONAL_PUBLIC_REFERENCE_ADAPTATION",
		"current_M_coordinates":"UNVERIFIED","source_map_id":null}
	if profile.has("display_name"): definition.map_name = profile.display_name
	for key: String in profile.get("render_style",{}):
		definition.render_style[key] = profile.render_style[key]
	var replacements: Dictionary = profile.get("prop_replacements",{})
	for prop: Dictionary in definition.props:
		var previous: String = str(prop.kind)
		if replacements.has(previous):
			prop["legacy_visual_kind"] = previous
			prop.kind = replacements[previous]
			prop["visual_evidence"] = "REFERENCE_INSPIRED_POSITION_STILL_PROVISIONAL"
	configure(definition)

func build_physics(parent: Node2D) -> StaticBody2D:
	collision_stream = preload("res://scripts/maps/authored_collision_stream.gd").new()
	collision_stream.configure(self,parent.get_node("Player"))
	parent.add_child(collision_stream)
	return collision_stream
