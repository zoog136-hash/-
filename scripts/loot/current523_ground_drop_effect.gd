extends Node2D
## Original 523 floor drop effect ("빛기둥") of one ground item, played from the
## pinned SP2 bank: sprite from UIItemDropEffect / Grade.DropItemEffectSpriteID
## (current523_item_grade.gd), its declared action 3 "breath" (12 frames) with
## the SPR-declared body + clothes layers. The ground item stays on the floor
## until picked up, so the idle "breath" action repeats (caller loop policy;
## the bank leaves loop to the caller). No sprite, frame or color is substituted:
## without the original the node stays empty and reports why.
signal effect_status_changed(status: Dictionary)
const GRADE = preload("res://scripts/loot/current523_item_grade.gd")
const VIEW = preload("res://scripts/animation/original_source_preview.gd")
const SOURCE = preload("res://scripts/resources/current523_source_bank.gd")
const POLICY = preload("res://scripts/animation/source_playback_policy.gd")
const ACTION: int = 3
var status: Dictionary = {"ok":false,"reason":"not_configured"}
var visual: Node2D

func _init() -> void:
	set_process(false)
	name = "SourceDropEffect"

func configure(original_item: Dictionary, context: Dictionary = {}, mode_override: String = "") -> bool:
	_clear()
	var effect: Dictionary = GRADE.drop_effect(original_item)
	if not effect.get("ok",false): return _done(effect)
	return play(effect,context,mode_override)

## An item body sprite that the SPR declares with an action 3 ("breath"/"br"/
## "effect", e.g. 가이아의 격노 14440) instead of the static no-action branch:
## the same floor idle role as the drop effect. Other actions (0 "fly" of
## arrows/stings) are flight, not a floor role, and stay pending.
func configure_body(original_item: Dictionary, context: Dictionary = {}, mode_override: String = "") -> bool:
	_clear()
	var sprite: Variant = original_item.get("SpriteID")
	if typeof(sprite) not in [TYPE_INT,TYPE_FLOAT] or int(sprite) <= 0: return _done({"ok":false,"reason":"source_ground_sprite_missing"})
	name = "SourceGroundBodyAction"
	return play({"ok":true,"sprite_id":int(sprite),"basis":"ItemClass.SpriteID action 3"},context,mode_override)

func play(effect: Dictionary, context: Dictionary, mode_override: String) -> bool:
	var supplied: Dictionary = SOURCE.options(context)
	if not supplied.get("ok",false): return _done({"ok":false,"reason":str(supplied.get("reason","current523_source_bank_unavailable")),"sprite_id":effect.sprite_id})
	var options: Dictionary = supplied.options
	visual = VIEW.new()
	var mode: String = mode_override if mode_override in ["strict","compatible"] else POLICY.mode(str(options.manifest_path).get_base_dir())
	visual.playback_mode_override = mode
	add_child(visual)
	if not visual._configure_reference_bank(str(options.manifest_path),str(options.manifest_sha256),int(effect.sprite_id),{"drop":ACTION},{"drop":true},"drop","overlay"):
		var problem: String = str(visual.reference_bank_status.get("error","source_drop_effect_unavailable"))
		_clear()
		return _done({"ok":false,"reason":"source_drop_effect_unavailable","error":problem,"sprite_id":effect.sprite_id})
	effect.merge({"ok":true,"status":"playing_original","action":ACTION,"loop":true,"loop_basis":"SPR action 3 breath on a persistent floor object; bank loop is caller policy","playback_mode":mode,"manifest_sha256":str(options.manifest_sha256)},true)
	set_process(true)
	return _done(effect)

func _done(value: Dictionary) -> bool:
	status = value.duplicate(true)
	effect_status_changed.emit(status.duplicate(true))
	return bool(status.get("ok",false))

func _clear() -> void:
	set_process(false)
	if is_instance_valid(visual):
		visual.clear()
		visual.queue_free()
	visual = null

func _process(delta: float) -> void:
	if not is_instance_valid(visual) or not visual.advance_reference_source(delta,"drop",0):
		status = {"ok":false,"reason":"source_drop_effect_frame_unavailable","sprite_id":status.get("sprite_id",0)}
		_clear()
