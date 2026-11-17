extends RefCounted
## Field camera distance for original-art fields (523 S32 maps, SP2 actors).
##
## TWILIGHT 근사: the original 523 data has no camera/zoom constant. Tiles,
## static objects and SP2 actors are all drawn 1:1 in source pixels, exactly
## like the original, so only the camera differs. Lineage M gameplay
## captures show about 375-411 world px of height on screen (the Heine
## fountain, 422 world px wide, spans 1.135 screen heights there versus
## 0.586 in TWILIGHT at zoom 1.0 with its 720 px base height).
## 720 / 411 (16:9) = 1.75 is the default; players can change it in settings
## like the original's camera distance option.
const DEFAULT_ZOOM: float = 1.75
const MIN_ZOOM: float = 1.25
const MAX_ZOOM: float = 2.25
const STEP: float = 0.05
## Saved in world.ui_preferences (part of the existing game save).
const PREFERENCE_KEY: String = "field_camera_zoom"
## World-space text/bars that keep their on-screen size under the zoom.
const GROUP: StringName = &"twilight_field_counter_scaled"

## The factor currently applied to the field camera (1.0 when not applied).
static var applied: float = 1.0

static func clamp_zoom(value: Variant) -> float:
	var number: float = float(value) if (value is float or value is int) else DEFAULT_ZOOM
	if not is_finite(number): number = DEFAULT_ZOOM
	return snappedf(clampf(number, MIN_ZOOM, MAX_ZOOM), STEP)

static func preference(preferences: Dictionary) -> float:
	return clamp_zoom(preferences.get(PREFERENCE_KEY, DEFAULT_ZOOM))

## Scale for world-space text so its screen size stays as at zoom 1.0.
static func text_scale() -> float:
	return 1.0 / maxf(0.01, applied)

## `pivot` is the local point that stays fixed (e.g. bottom-centre of a name).
static func keep_screen_size(control: Control, pivot: Vector2) -> void:
	if control == null: return
	control.pivot_offset = pivot
	control.scale = Vector2.ONE * text_scale()
	if not control.is_in_group(GROUP): control.add_to_group(GROUP)

static func set_applied(value: float, tree: SceneTree) -> void:
	applied = maxf(0.01, value)
	if tree == null: return
	for node: Node in tree.get_nodes_in_group(GROUP):
		if node is Control: (node as Control).scale = Vector2.ONE * text_scale()
