extends Resource
class_name TwilightAnimationProfile

## Visual metadata only. Movement, collision, damage and equipment stats stay on actors.
@export var profile_id: String = "base"
@export var resource_path_hint: String = ""
@export_file("*.tres", "*.res") var frames_path: String = ""
@export var layout: String = "still" # class5, directional4, directional8, still
@export var motion_style: String = "slash"
@export var movement_fps: float = 9.0
@export var reference_speed: float = 210.0
@export_range(0.1, 0.85) var attack_hit_ratio: float = 0.45
@export var attack_hit_frame: int = 3
## Different authored attacks can release on different source poses.
@export var action_hit_frames: Dictionary = {}
@export var color_tint: Color = Color.WHITE
@export var native_width_ratio: float = 1.0 # explicit per-monster native presentation; no collider change
@export var use_profile_hit_ratio: bool = false
@export var attack_animation_speed: float = 1.0
@export var sprite_offset: Vector2 = Vector2(0, -46)
@export var collision_offset: Vector2 = Vector2.ZERO
@export var projectile_origin: Vector2 = Vector2(14, -42)
@export var hit_position: Vector2 = Vector2(0, -38)
@export var shadow_size: Vector2 = Vector2(19, 6)
@export var floating: bool = false
@export var dedicated_attack: bool = false
## Optional explicit scale for padded, foot-anchored native sprite frames.
## Zero keeps the existing automatic sizing of portraits / legacy sheets.
@export var pixel_scale: float = 0.0
@export var embedded_shadow: bool = false
@export var death_duration: float = 0.35
@export var animation_names: Dictionary = {}
## Presentation amplitudes; never used by attack clocks or damage calculations.
@export var body_kind: String = "humanoid"
@export var idle_amplitude: float = 0.4
@export var stride_bob: float = 2.0
@export var stride_lean: float = 0.022
@export var attack_recoil: float = 1.0
@export var hit_recoil: float = 2.5
@export var death_tilt: float = 1.25
@export var authored_motion_weight: float = 0.18
@export var presentation: Dictionary = {}

func marker_for(style: String) -> float:
	return clampf(attack_hit_ratio, 0.1, 0.85) if use_profile_hit_ratio else hit_ratio(style)

func hit_frame_for(role: String) -> int:
	return int(action_hit_frames.get(role, attack_hit_frame))

func projectile_offset(aim: Vector2) -> Vector2:
	# The Y anchor is torso height, not a screen-space aim component. Native
	# eight-view weapons release ahead of that anchor in the actual facing.
	# East/west retain their existing offsets; legacy art keeps its old anchor.
	if layout == "directional8":
		var direction_value: Vector2 = aim.normalized() if not aim.is_zero_approx() else Vector2.DOWN
		return Vector2(0, projectile_origin.y) + direction_value * absf(projectile_origin.x)
	return Vector2(projectile_origin.x * (-1.0 if aim.x < 0.0 else 1.0), projectile_origin.y)

static func weapon_style(weapon: String, attack_kind: String = "melee") -> String:
	if attack_kind == "magic": return "magic"
	if attack_kind == "ranged": return "bow"
	if weapon in ["창", "단검", "체인소드"]: return "thrust"
	if weapon in ["도끼", "둔기", "양손검", "그레이트소드"]: return "heavy"
	return "slash"

static func hit_ratio(style: String) -> float:
	match style:
		"thrust": return 0.34
		"heavy": return 0.56
		"bow": return 0.38
		"magic": return 0.52
		_: return 0.44
