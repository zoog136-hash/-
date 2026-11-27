extends "res://scripts/ui/original_ui/source_main_window_kit.gd"
## The installed Chat_All panel displays the existing offline combat log.
## Only the local transcript and Close participate in this window.
const Chrome = preload("res://scripts/ui/original_ui/source_common_chrome.gd")
const TouchText = preload("res://scripts/ui/native_touch_text.gd")
const CHAT_LIST: String = "Nd_Chat/ListView_ChatPanel"
var history: RichTextLabel

func _root_member() -> String:
	return Chrome.CHAT

func configure(pack: RefCounted, owner: Node) -> Dictionary:
	if not pack.manifest.get("scenes",{}).has(Chrome.CHAT): return super.configure(pack,owner)
	if Chrome.checked_tree(pack,Chrome.CHAT,Chrome.CHAT_SHA).is_empty():
		return _fail("source_chat_scene_identity_mismatch")
	return super.configure(pack,owner)

func open(parent: Node) -> Dictionary:
	return open_window(parent)

func _spec() -> Dictionary:
	var result: Dictionary = {"Btn_Close":{"activate":Callable(self,"_close_requested")},
		"Nd_Chat/Nd_Notice/Label_Notice":{"role":"source_text","text":"전투 / 시스템 기록"}}
	for name: String in ["Inven_Base/Nd_Short","Inven_Base/Nd_Long","Tab","Nd_Block","Nd_Signal","Nd_Macro",
		"Nd_Chat/Nd_ChatInput","Nd_Chat/Fx_Chat_NameSelect","Btn_Filter","Button_Close_Filter","Nd_BlockMenu",
		"Nd_ChatMenu","Nd_Channel_ButtonSet","Btn_Channel","Fx_Voice_Rec","Fx_Popup_RightBottom","Fx_Popup_LeftUp"]:
		result[name] = {"exclude":true}
	return result

func _fill(root: Node2D, out: Dictionary) -> Dictionary:
	var location: Dictionary = _locate(root,out,CHAT_LIST)
	if not location.get("ok",false): return location
	var list_node: Node2D = location.player.source_nodes.get(location.offset)
	var clip: Control = list_node.get_node_or_null("SourceContentOrigin/SourceClipRect")
	var font: FontFile = _pack.font(Chrome.FONT)
	if clip == null or font == null: return _fail("original_chat_transcript_inputs_missing")
	var blocker := ColorRect.new()
	blocker.position = Vector2(-800,-338)
	blocker.size = Vector2(1600,676)
	blocker.color = Color(0,0,0,0.54)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(blocker)
	root.move_child(blocker,0)
	history = TouchText.new()
	history.name = "CombatLogHistory"
	history.size = clip.size
	history.scroll_active = true
	history.scroll_following = true
	history.mouse_filter = Control.MOUSE_FILTER_STOP
	history.add_theme_font_override("normal_font",font)
	history.add_theme_font_size_override("normal_font_size",16)
	clip.add_child(history)
	return {"ok":true,"original_log_panel":true}

func close() -> void:
	history = null
	super.close()
