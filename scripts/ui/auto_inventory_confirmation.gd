extends "res://scripts/ui/renewal_confirmation.gd"
## Scrollable multi-item cart; uses the existing modal's single-commit/cancel flow.
var cart_scroll: ScrollContainer
const TouchButton = preload("res://scripts/ui/native_touch_button.gd")
const SOURCE_IMAGES = preload("res://scripts/ui/source523_image_assets.gd")

func configure(title: String, description: String, action: String, accept: Callable, maximum: int = 0) -> void:
	super.configure(title,description,action,accept,maximum)
	for button: Button in [confirm_button,cancel_button]:
		button.set_script(TouchButton)
		# The base modal already added these nodes to the tree before attaching
		# the touch script. Enable its global release handler explicitly.
		button.set_process_input(true)
		var cancel: Callable = Callable(button,"_cancel_touch")
		if not button.visibility_changed.is_connected(cancel): button.visibility_changed.connect(cancel)
		if not get_window().focus_exited.is_connected(cancel): get_window().focus_exited.connect(cancel)
	var col: VBoxContainer = panel.get_child(0)
	var body: Label = col.get_child(2)
	col.remove_child(body)
	cart_scroll = ScrollContainer.new()
	cart_scroll.name = "AutoCartScroll"
	cart_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(cart_scroll)
	col.move_child(cart_scroll,2)
	cart_scroll.add_child(body)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func bind_source_cart(world: Node, cart: Array) -> void:
	confirm_button.icon = null
	if confirm_button.has_meta("source523_cart_image"): confirm_button.remove_meta("source523_cart_image")
	if not SOURCE_IMAGES.selected() or cart.size() != 1 or not is_instance_valid(world): return
	var entry: Variant = cart[0]
	if not entry is Dictionary or not entry.get("name") is String or not entry.get("id") is String: return
	var amount: Variant = entry.get("quantity")
	if not SOURCE_IMAGES.PACK._integer(amount) or int(amount) <= 0 or entry.get("mode") not in ["deposit","sell"]: return
	var record: Dictionary = {}
	if not entry.id.is_empty():
		var physical: Variant = world.item_instances.get(entry.id)
		if not physical is Dictionary or physical.get("name") != entry.name or not physical.get("record") is Dictionary: return
		record = physical.record
	elif world.has_method("_find_catalog_item_record"):
		record = world._find_catalog_item_record(entry.name)
	if record.get("name") != entry.name or int(world.inventory.get(entry.name,0)) < int(amount) or not SOURCE_IMAGES.handles_item(record): return
	var image: Dictionary = SOURCE_IMAGES.describe_item(record,entry.name)
	confirm_button.icon = image.get("texture") as Texture2D
	confirm_button.expand_icon = true
	var evidence: Dictionary = image.duplicate(true)
	evidence.erase("texture")
	evidence["source_cart_entry"] = {"name":entry.name,"instance_id":entry.id,"quantity":int(amount),"mode":entry.mode}
	confirm_button.set_meta("source523_cart_image",evidence)

func _fit() -> void:
	if cart_scroll != null:
		cart_scroll.custom_minimum_size = Vector2(0,clampf(size.y-250,80,300))
	super._fit()
