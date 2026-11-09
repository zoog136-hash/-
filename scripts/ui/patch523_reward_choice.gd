extends Control
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Explicit source entity selection. Opening/cancelling never debits inventory.
const DROPS = preload("res://scripts/loot/patch523_monster_drops.gd")
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
var use_service: GDScript
var world: Node
var record: Dictionary
var choices: ItemList
var confirm: Button
var committing: bool = false

func configure(owner: Node, item: Dictionary) -> void:
	world = owner
	record = item.duplicate(true)
	use_service = load("res://scripts/loot/patch523_item_use.gd")

func _ready() -> void:
	name = "Patch523RewardChoice"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	var shade := ColorRect.new()
	shade.color = Color(0,0,0,0.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-300,-220)
	panel.size = Vector2(600,440)
	add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	margin.add_child(content)
	var title := Label.new()
	title.text = str(record.get("source_display_name",record.get("name","")))+" · 1개 선택"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title)
	var note := Label.new()
	note.text = "목록·수량·축복·직업 조건: 원본 523\n장비 초기 강화 +0: 원본 수치 없음 · TWILIGHT 설정에서 사용/해제"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)
	choices = ItemList.new()
	choices.name = "SourceRewardChoices"
	choices.custom_minimum_size.y = 260
	choices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(choices)
	var use_source_images: bool = IMAGES.selected()
	var source_images: Dictionary = {}
	for reward: Dictionary in NATIVE_FIELDS.full(record).get("source_use_spec",{}).get("rewards",[]):
		if not use_service.class_matches(reward.get("class_ids",[]),world.BASE508.source_class_id(world.job_class)): continue
		var item: Dictionary = DROPS.cached_definition(str(int(reward.item_class_id))).get("native_record",{})
		var blessing: String = str({1:"일반",2:"축복",3:"저주"}.get(int(reward.bless_raw),"미확인 상태"))
		var index: int = choices.add_item("%s ×%d · #%d · %s%s" % [str(item.get("source_display_name","?")),int(reward.amount),int(reward.item_class_id),blessing," · 자체 초기 +0" if DROPS.equipment(item) and reward.get("enchant") == null else ""])
		if use_source_images:
			# This existing provider field is ItemClass.ID. Claim identity stays
			# the separate source_entity_id stored below, never a numeric alias.
			var original: Dictionary = IMAGES.describe_item_class(int(reward.item_class_id),str(item.get("source_display_name","")))
			choices.set_item_icon(index,original.get("texture") as Texture2D)
			var presentation: Dictionary = original.duplicate(true)
			presentation.erase("texture")
			source_images[index] = presentation
		choices.set_item_metadata(index,int(reward.source_entity_id))
	if use_source_images:
		choices.set_meta("source523_reward_item_images",source_images)
	var buttons := HBoxContainer.new()
	content.add_child(buttons)
	var cancel := Button.new()
	cancel.name = "CancelSourceReward"
	cancel.text = "취소 · 상자 보존"
	cancel.pressed.connect(queue_free)
	buttons.add_child(cancel)
	confirm = Button.new()
	confirm.name = "ClaimSourceReward"
	confirm.text = "선택 보상 받기"
	confirm.expand_icon = true
	confirm.disabled = true
	confirm.pressed.connect(_claim)
	buttons.add_child(confirm)
	choices.item_selected.connect(func(index: int) -> void:
		confirm.disabled = committing
		_sync_confirm_icon(index))

func _sync_confirm_icon(index: int) -> void:
	confirm.icon = null
	if confirm.has_meta("source523_reward_item_image"): confirm.remove_meta("source523_reward_item_image")
	if not IMAGES.selected() or index < 0 or index >= choices.item_count: return
	var source_images: Dictionary = choices.get_meta("source523_reward_item_images",{})
	if not source_images.has(index): return
	confirm.icon = choices.get_item_icon(index)
	var evidence: Dictionary = source_images[index].duplicate(true)
	evidence.erase("texture")
	confirm.set_meta("source523_reward_item_image",evidence)

func _claim() -> void:
	if committing or choices.get_selected_items().size() != 1: return
	committing = true
	confirm.disabled = true
	var entity_id: int = int(choices.get_item_metadata(choices.get_selected_items()[0]))
	if use_service.claim_selection(world,record,entity_id): queue_free()
	else:
		committing = false
		confirm.disabled = false

func _exit_tree() -> void:
	if is_instance_valid(world) and is_instance_valid(world.hud) and world.hud.has_meta("patch523_reward_choice") and world.hud.get_meta("patch523_reward_choice") == self:
		world.hud.remove_meta("patch523_reward_choice")
