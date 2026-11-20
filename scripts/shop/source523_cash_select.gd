extends Node
## The choice of an original 523 SelectReward box (source523_cash_packages):
## the owner the original 선택 보상 window (source_main_reward_select_window,
## RewardSelectBoxScene / Common_Reward_SelectBox) reads and claims through,
## like patch523_reward_choice for the native boxes. 확인 opens one box with
## the chosen row (source523_cash_packages.open); 취소 frees this owner and
## keeps the box. Without the UI pack the same rows are offered in a plain
## chooser with 확인 / 취소.
const CashPackages = preload("res://scripts/shop/source523_cash_packages.gd")
var world: Node
var item_name: String = ""
var box_item_class_id: int = 0
var choices: Array = []
var committing: bool = false
var last_result: Dictionary = {}
## "original" (the 523 window), "fallback" (plain chooser) or "".
var shown: String = ""
var present_result: Dictionary = {}

func configure(owner: Node, box_name: String, rows: Array) -> void:
	world = owner
	item_name = box_name
	choices = rows.duplicate(true)
	box_item_class_id = CashPackages.definition_id_of(owner, box_name)
	name = "Source523CashSelect"

## The rows the original window lists, in the original SelectRewardEntity
## order: {entity_id, item_class_id, name, amount, blessing, enchant}.
func original_rows() -> Array:
	var rows: Array = []
	for entry: Dictionary in choices:
		rows.append({"entity_id":int(entry.entity_id), "item_class_id":int(entry.item_class_id), "name":CashPackages.label(int(entry.item_class_id)),
			"amount":int(entry.amount), "blessing":int(entry.get("bless", 1)), "enchant":0})
	return rows

func box_info() -> Dictionary:
	var title: String = CashPackages.label(box_item_class_id) if box_item_class_id > 0 else ""
	return {"name":title if not title.is_empty() else item_name, "item_class_id":box_item_class_id}

## Opens one box with row `entity_id`; true when it was opened (this owner
## then closes). A refusal keeps the box and the window.
func claim_entity(entity_id: int) -> bool:
	if committing: return false
	var chosen: Dictionary = {}
	for entry: Dictionary in choices:
		if int(entry.entity_id) == entity_id: chosen = entry
	if chosen.is_empty(): return false
	committing = true
	last_result = CashPackages.open(world, item_name, [chosen])
	committing = false
	if is_instance_valid(world) and world.get("hud") != null:
		world.hud.show_message(str(last_result.get("message", last_result.get("reason", ""))))
	if last_result.get("ok", false):
		queue_free()
		return true
	return false

## Shows the original window, else the plain chooser.
func present() -> Dictionary:
	var hud: Variant = world.get("hud") if is_instance_valid(world) else null
	var controller: Variant = hud.get("original_main_ui_controller") if is_instance_valid(hud) else null
	if is_instance_valid(controller) and controller.has_method("try_open_feature_window"):
		var native: Dictionary = controller.try_open_feature_window("reward_select", [self])
		present_result = native
		if native.get("handled", false) or native.get("ok", false):
			shown = "original"
			return native
	_fallback()
	shown = "fallback"
	return {"ok":true, "fallback":true}

func _fallback() -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.name = "Source523CashSelectFallback"
	dialog.title = str(box_info().name)
	var column: VBoxContainer = preload("res://scripts/ui/dialog_korean_texts.gd").content(dialog, "받을 구성품을 고르세요. 확인 전에는 상자가 소모되지 않습니다.")
	dialog.ok_button_text = "확인"
	dialog.cancel_button_text = "취소"
	var selector: OptionButton = OptionButton.new()
	selector.name = "Source523CashSelectChoices"
	selector.custom_minimum_size = Vector2(360, 44)
	for row: Dictionary in original_rows():
		selector.add_item("%s ×%d" % [str(row.name), int(row.amount)])
	column.add_child(selector)
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		var rows: Array = original_rows()
		if selector.selected >= 0 and selector.selected < rows.size(): claim_entity(int(rows[selector.selected].entity_id))
		if is_instance_valid(self) and not is_queued_for_deletion(): queue_free())
	dialog.canceled.connect(queue_free)
	dialog.popup_centered()
