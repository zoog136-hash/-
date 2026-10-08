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
@export var use_profile_hit_ratio: bool = false
@export var attack_animation_speed: float = 1.0
@export var sprite_offset: Vector2 = Vector2(0, -46)
@export var collision_offset: Vector2 = Vector2.ZERO
@export var projectile_origin: Vector2 = Vector2(14, -42)
@export var hit_position: Vector2 = Vector2(0, -38)
@export var shadow_size: Vector2 = Vector2(19, 6)
@export var floating: bool = false
@export var dedicated_attack: bool = false
@export var animation_names: Dictionary = {}

func marker_for(style: String) -> float:
	return clampf(attack_hit_ratio, 0.1, 0.85) if use_profile_hit_ratio else hit_ratio(style)

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
