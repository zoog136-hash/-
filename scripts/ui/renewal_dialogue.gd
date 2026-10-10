extends VBoxContainer
const UI = preload("res://scripts/ui/renewal_theme.gd")
var hud: Node
var world: Node
var npc_id: String = ""
var current_node: String = ""
var message_label: RichTextLabel
var options: VBoxContainer

func configure(controller: Node, requested_npc_id: String) -> void:
	hud = controller
	world = hud.get_parent()
	npc_id = requested_npc_id
	current_node = ""
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(UI.label("TWILIGHT NPC 대화",20,UI.GOLD))
	message_label = UI.rich("")
	message_label.fit_content = true
	message_label.scroll_active = false
	message_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(message_label)
	options = VBoxContainer.new()
	options.name = "DialogueOptions"
	add_child(options)
	_show_node("")

func _show_node(id: String) -> void:
	var service: Object = world.get("dialogue_service")
	var state: Dictionary = world.call("_npc_dialogue_state")
	var dialogue: Dictionary = service.call("resolve",npc_id,id,state)
	for child: Node in options.get_children():
		options.remove_child(child)
		child.queue_free()
	if not bool(dialogue.get("ok",false)):
		message_label.text = UI.safe(dialogue.get("reason","대화를 시작할 수 없습니다"))
		return
	current_node = str(dialogue.get("node_id",""))
	message_label.text = "[color=#d8b878][font_size=22]%s[/font_size][/color]\n\n%s" % [
		UI.safe(dialogue.get("npc_name",npc_id)), UI.safe(dialogue.get("text",""))
	]
	var choices: Array = dialogue.get("choices",[])
	for raw: Variant in choices:
		if not (raw is Dictionary):
			continue
		var choice: Dictionary = raw as Dictionary
		var next_id: String = str(choice.get("next",""))
		var action: String = str(choice.get("action",""))
		var button: Button = UI.button(str(choice.get("label","계속")),
			_choice_picked.bind(next_id,action),Vector2(0,40))
		options.add_child(button)

func _choice_picked(next_id: String,action: String) -> void:
	if not next_id.is_empty():
		_show_node(next_id)
	elif not action.is_empty() and hud.has_signal("npc_dialogue_action_requested"):
		hud.emit_signal("npc_dialogue_action_requested",npc_id,current_node,action)
