extends RefCounted
## Compatibility boundary for retired decorative lightning, not game effects.
const UI = preload("res://scripts/ui/renewal_theme.gd")
# Two short restrikes, broken remnants, then a quiet interval. Visual seconds,
# not a proc probability, combat cooldown, or measured original-game timings.
const FRAME_ENDS: Array[float] = [0.055, 0.11, 0.17, 0.22, 0.28, 0.35, 0.41, 0.49]
const CYCLE: float = 0.66

static func frame_at(_seconds: float, _reduced: bool = false) -> int:
	# No original UI/actor effect-role contract is supplied to this old
	# decoration. The real source-bank effect consumers remain independent.
	return -1

static func source_rect(_frame: int) -> Rect2:
	return Rect2()

static func color_for(grade: String) -> Color:
	# Contemporary reports identify hero red and legendary purple electricity.
	# Other grade colors retain this project's existing palette, not a fidelity claim.
	match grade:
		"영웅": return Color("ff2636")
		"전설": return Color("b649f2")
		_: return UI.grade(grade)

static func make_material(_grade: String) -> ShaderMaterial:
	return null
