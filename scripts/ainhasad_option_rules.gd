extends RefCounted
class_name TwilightAinOptionRules

# Generic equipped-card/item blessing-consumption passive.
# Original numeric sourceOptions are used only when an explicit typed field is
# absent. One record is counted once even if both representations are present.
const TYPED_KEYS: Array[String] = [
	"blessing_consumption_reduction_pct",
	"ain_consumption_reduction_pct",
	"blessing_spend_reduction_pct"
]
const LABELS: Array[String] = ["축복 소모량 감소", "축복 소모 감소"]

static func option_percent(raw: String) -> float:
	var text: String = raw.strip_edges().replace("％", "%").replace("＋", "+")
	var start: int = -1
	var prefix_length: int = 0
	for label: String in LABELS:
		start = text.find(label)
		if start >= 0:
			prefix_length = label.length()
			break
	if start < 0:
		return -1.0
	var rest: String = text.substr(start + prefix_length).strip_edges()
	if rest.begins_with(":"):
		rest = rest.substr(1).strip_edges()
	if rest.begins_with("+"):
		rest = rest.substr(1).strip_edges()
	if not rest.ends_with("%"):
		return -1.0
	var number: String = rest.trim_suffix("%").strip_edges()
	if number.is_empty() or not number.is_valid_float():
		return -1.0
	return clampf(float(number), 0.0, 100.0)

static func reduction_percent(record: Dictionary) -> float:
	for key: String in TYPED_KEYS:
		if record.has(key):
			return clampf(float(record.get(key, 0.0)), 0.0, 100.0)
	var options_value: Variant = record.get("sourceOptions", [])
	if not (options_value is Array):
		return 0.0
	var highest: float = 0.0
	for option: Variant in options_value as Array:
		var parsed: float = option_percent(str(option))
		if parsed >= 0.0:
			# Spelling duplicates in the same record must not stack.
			highest = maxf(highest, parsed)
	return highest
