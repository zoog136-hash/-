extends RefCounted

# Shared by the HTML preview and native Godot renderer. These are authored
# TWILIGHT presentation settings; no probabilities or source-game rules here.
const PATH = "res://data/presentation/card_reveal_profiles.json"
const KEYS = {"일반":"normal", "고급":"green", "희귀":"rare", "영웅":"hero", "전설":"legend", "신화":"myth", "유일":"unique"}
const SHOWCASE: Array[String] = ["희귀", "영웅", "전설", "신화", "유일"]
static var cache: Dictionary = {}

static func profile(grade: String) -> Dictionary:
	if cache.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			cache = (parsed as Dictionary).get("profiles", {})
	return (cache.get(KEYS.get(grade, grade), cache.get("normal", {})) as Dictionary).duplicate(true)

static func color(grade: String) -> Color:
	var rgb: Array = profile(grade).get("color", [144,151,151])
	return Color(float(rgb[0])/255.0, float(rgb[1])/255.0, float(rgb[2])/255.0)

static func pulse(grade: String, elapsed: float, extra_seconds: float=0.0) -> float:
	var p: Dictionary = profile(grade)
	var burst: float=float(p.get("burst",0.0))
	if elapsed < 0.0 or elapsed > burst+extra_seconds:
		return 0.0
	if extra_seconds>0 and elapsed>=burst:
		# Bounded sustained discharge; no new nodes, particles or audio voices.
		var tail: float=1.0-smoothstep(burst+extra_seconds-.25,burst+extra_seconds,elapsed)
		return (0.24+0.20*absf(sin(elapsed*PI*8.0)))*float(p.get("power",0.0))*tail
	var result: float = 0.0
	for n: int in range(int(p.get("pulses",1))):
		var center: float = 0.028 + float(n)*0.14
		var width: float = 0.020 + float(n)*0.005
		result += exp(-pow((elapsed-center)/width,2.0))*pow(0.81,n)
	return minf(1.0,result)*float(p.get("power",0.0))
