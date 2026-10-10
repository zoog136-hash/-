extends RefCounted
# Visual-only theme. These are original TWILIGHT color choices; no L1J map
# bit masks, collision data, world coordinates or proprietary textures imported.
const TWILIGHT: String = "twilight"
const CLASSIC: String = "classic"

static func normalize(mode: String) -> String:
	return CLASSIC if mode == CLASSIC else TWILIGHT

static func palette_tint(mode: String) -> Color:
	return Color("d7c8a5") if normalize(mode) == CLASSIC else Color.WHITE

static func ground_tint(mode: String) -> Color:
	return Color("f4eedf") if normalize(mode) == CLASSIC else Color.WHITE

static func prop_tint(mode: String) -> Color:
	return Color("eee4d1") if normalize(mode) == CLASSIC else Color.WHITE

static func saturation_multiplier(mode: String) -> float:
	return 0.85 if normalize(mode) == CLASSIC else 1.0

static func npc_class_art(role: String) -> String:
	match role:
		"shop","teleport":
			return "res://assets/sprites/classes/mage.png"
		"warehouse":
			return "res://assets/sprites/classes/archer.png"
		"buyback":
			return "res://assets/sprites/classes/assassin.png"
		_:
			return "res://assets/sprites/classes/warrior.png"

static func npc_role_tint(role: String) -> Color:
	match role:
		"shop": return Color("f2d9ad")
		"warehouse": return Color("bde8cc")
		"teleport": return Color("b7d9ff")
		"craft": return Color("e9be8a")
		"buyback": return Color("dbb0cf")
		"guide": return Color("e7e1bc")
		_: return Color.WHITE

static func npc_render_tint(role: String,mode: String) -> Color:
	return npc_role_tint(role) * (Color("eee2c8") if normalize(mode) == CLASSIC else Color.WHITE)
