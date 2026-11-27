extends RefCounted
## Skin for local controls whose behavior already belongs to TWILIGHT.
## The same checked atlas inputs are used by the original review and chat scenes.
const REVIEW = preload("res://scripts/ui/original_ui/source_awakening_result_pack.gd")
const Scene = preload("res://scripts/ui/original_ui/sprite_scene.gd")
const UI = preload("res://scripts/ui/renewal_theme.gd")
const CHAT: String = "UI/FloatingUi/Chat_All.csb"
const CHAT_SHA: String = "825a88ba62537c26459413ab668a4db3e5f1ed073f3733bedc1f47c91bf3021f"
const FONT: Dictionary = {"path":"Font/font_B.ttf","resourceType":0}

static func build(pack: RefCounted) -> Dictionary:
	var skin: Dictionary = {"font":pack.font(FONT),"manifest_sha256":pack.manifest_sha256}
	var review: RefCounted = REVIEW.resolve(pack,REVIEW.REVIEW)
	if review != null:
		var tree: Dictionary = checked_tree(review,REVIEW.REVIEW,REVIEW.REVIEW_SHA)
		skin["frame"] = _style(review,tree,8940,"fileNameData",8)
		skin["dialog"] = _style(review,tree,8940,"fileNameData",18)
		skin["well"] = _style(review,tree,6948,"fileNameData",5)
		skin["confirm"] = _button_styles(review,tree,1484,7)
		skin["cancel"] = _button_styles(review,tree,2220,7)
		if skin.font == null: skin.font = review.font(FONT)
	var chat: Dictionary = checked_tree(pack,CHAT,CHAT_SHA)
	skin["close"] = _button_styles(pack,chat,65088,3)
	return skin

static func checked_tree(pack: RefCounted, member: String, source_sha: String) -> Dictionary:
	if pack.manifest.get("files",{}).get(member,{}).get("sha256") != source_sha: return {}
	var record: Dictionary = pack.scene(member)
	return record.get("nodeTree",{}) if record.get("_source_sha256") == source_sha else {}

static func _style(pack: RefCounted, tree: Dictionary, offset: int, state: String, margin: int) -> StyleBoxTexture:
	var node: Dictionary = Scene._node_at_offset(tree,offset) if not tree.is_empty() else {}
	var options: Dictionary = node.get("options",{})
	var reference: Dictionary = options.get(state,{})
	if reference.is_empty(): return null
	var texture: Texture2D = pack.texture(reference)
	if texture == null: return null
	var box := StyleBoxTexture.new()
	box.texture = texture
	if bool(options.get("scale9Enabled",false)):
		var insets: Array = options.get("capInsets",[])
		if insets.size() != 4: return null
		var edge := Vector2(float(insets[0]),float(insets[1]))
		var end := edge + Vector2(float(insets[2]),float(insets[3]))
		var tail: Vector2 = texture.get_size() - end
		if not edge.is_finite() or not tail.is_finite() or edge.x < 0 or edge.y < 0 or tail.x < 0 or tail.y < 0: return null
		box.set_texture_margin(SIDE_LEFT,edge.x)
		box.set_texture_margin(SIDE_TOP,edge.y)
		box.set_texture_margin(SIDE_RIGHT,tail.x)
		box.set_texture_margin(SIDE_BOTTOM,tail.y)
	for side: int in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		box.set_content_margin(side,margin)
	box.set_meta("original_ui_source",{"manifest_sha256":pack.manifest_sha256,"node_offset":offset,"frame":reference.path})
	return box

static func _button_styles(pack: RefCounted, tree: Dictionary, offset: int, margin: int) -> Dictionary:
	var normal: StyleBoxTexture = _style(pack,tree,offset,"normalData",margin)
	var pressed: StyleBoxTexture = _style(pack,tree,offset,"pressedData",margin)
	if normal == null or pressed == null: return {}
	var disabled: StyleBoxTexture = _style(pack,tree,offset,"disabledData",margin)
	return {"normal":normal,"hover":normal,"pressed":pressed,"hover_pressed":pressed,"disabled":disabled if disabled != null else normal}

static func apply_theme(theme: Theme, skin: Dictionary) -> void:
	if skin.get("font") is FontFile: theme.default_font = skin.font
	var frame: StyleBoxTexture = skin.get("frame")
	if frame != null:
		for kind: String in ["Panel","PanelContainer","PopupMenu","AcceptDialog","Window","TabContainer"]:
			theme.set_stylebox("panel",kind,frame)
	if skin.get("dialog") is StyleBoxTexture: theme.set_stylebox("panel","TwilightConfirmationPanel",skin.dialog)
	var well: StyleBoxTexture = skin.get("well")
	if well != null:
		for kind: String in ["LineEdit","TextEdit"]:
			theme.set_stylebox("normal",kind,well)
		for kind: String in ["ItemList","ScrollContainer"]:
			theme.set_stylebox("panel",kind,well)
		for margin: int in UI.INSET_MARGINS:
			var inset: StyleBoxTexture = well.duplicate()
			for side: int in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: inset.set_content_margin(side,margin)
			UI.set_inset_variant(theme,margin,inset)
	var states: Dictionary = skin.get("confirm",{})
	for kind: StringName in [&"Button",&"OptionButton",UI.PRIMARY,UI.REFERENCE_ACTION]:
		for state: String in states: theme.set_stylebox(state,kind,states[state])
	var cancel: Dictionary = skin.get("cancel",{})
	for state: String in cancel: theme.set_stylebox(state,"TwilightCancelButton",cancel[state])

static func apply_button(button: Button, states: Dictionary) -> void:
	for state: String in states: button.add_theme_stylebox_override(state,states[state])
