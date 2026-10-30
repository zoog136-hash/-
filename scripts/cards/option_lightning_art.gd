extends RefCounted
## Authored electrical flipbook, shared only by option-awakening presentation.
const ATLAS = preload("res://assets/effects/awakening/lightning_arc_frames.png")
const SHADER = preload("res://assets/effects/awakening/lightning_arc.gdshader")
const UI = preload("res://scripts/ui/renewal_theme.gd")
# Two short restrikes, broken remnants, then a quiet interval. Visual seconds,
# not a proc probability, combat cooldown, or measured original-game timings.
const FRAME_ENDS: Array[float] = [0.055, 0.11, 0.17, 0.22, 0.28, 0.35, 0.41, 0.49]
const CYCLE: float = 0.66

static func frame_at(seconds: float, reduced: bool = false) -> int:
	if reduced: return 3
	var phase := fposmod(seconds, CYCLE)
	for index: int in range(FRAME_ENDS.size()):
		if phase < FRAME_ENDS[index]: return index
	return -1

static func source_rect(frame: int) -> Rect2:
	var cell := ATLAS.get_size() / Vector2(4, 2)
	return Rect2(Vector2(frame % 4, floori(float(frame) / 4.0)) * cell + Vector2.ONE, cell - Vector2(2,2))

static func color_for(grade: String) -> Color:
	# Contemporary reports identify hero red and legendary purple electricity.
	# Other grade colors retain this project's existing palette, not a fidelity claim.
	match grade:
		"영웅": return Color("ff2636")
		"전설": return Color("b649f2")
		_: return UI.grade(grade)

static func make_material(grade: String) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = SHADER
	result.set_shader_parameter("grade_color", color_for(grade))
	return result
