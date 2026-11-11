extends Control
## Owner of one original 523 NPC talk. It draws nothing itself: the page model
## (original DialogData_Korean text, see scripts/npc/source523_town_npcs.gd) is
## handed to the original UI/NpcDialogue/NpcDialogue_All.csb presenter. When
## that window is unavailable the talk is closed with its reason; there is no
## TWILIGHT-made dialogue screen.
signal source_dialogue_resolved(resolved: Dictionary)
const TOWN_NPCS = preload("res://scripts/npc/source523_town_npcs.gd")
var hud: Node
var world: Node
var npc_id: String = ""
var current_node: String = ""
var source_dialogue_model: Dictionary = {}

func configure(controller: Node, requested_npc_id: String) -> void:
	hud = controller
	world = hud.get_parent()
	npc_id = requested_npc_id
	current_node = ""
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_show_node("")

func _show_node(id: String) -> void:
	var dialogue: Dictionary = TOWN_NPCS.resolve(world, npc_id, id)
	source_dialogue_model = dialogue.duplicate(true)
	if bool(dialogue.get("ok", false)): current_node = str(dialogue.get("node_id", ""))
	source_dialogue_resolved.emit(dialogue.duplicate(true))

func _choice_picked(next_id: String, action: String) -> void:
	if not next_id.is_empty():
		_show_node(next_id)
		return
	if action.is_empty() or not hud.has_signal("npc_dialogue_action_requested"): return
	var section: Variant = hud.get("active_section")
	hud.emit_signal("npc_dialogue_action_requested", npc_id, current_node, action)
	# A refused or unconnected function leaves this talk's empty workspace behind.
	if is_instance_valid(hud) and hud.get("active_section") == section and is_inside_tree() and not is_queued_for_deletion() and hud.has_method("_close_workspace"):
		hud.call("_close_workspace")
