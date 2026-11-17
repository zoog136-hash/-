extends RefCounted
## The repository's own res://assets/ pictures were retired (user rules
## 2026-11-10 and 2026-11-17): the game shows only original 523 resources from
## the installed pack, and an unconnected slot stays empty.
##
## An OTA update pack can add and replace files but cannot delete files that an
## older APK (or an older copied project folder) still carries. A guard such as
## `if ResourceLoader.exists(old_path): load(old_path)` therefore keeps showing
## the removed art on such phones. Every loader that can receive a res://assets/
## path asks `retired()` first and treats a retired path as missing.
##
## Kept: the font, the Android launcher icons (user decision 2026-11-17) and
## shader code. Original 523 resources never live under res://assets/.
const ROOT: String = "res://assets/"
const KEPT_PREFIXES: Array[String] = ["res://assets/fonts/", "res://assets/boot/twilight_icon"]
const KEPT_SUFFIXES: Array[String] = [".gdshader"]

static func retired(path: String) -> bool:
	if not path.begins_with(ROOT): return false
	for suffix: String in KEPT_SUFFIXES:
		if path.ends_with(suffix): return false
	for prefix: String in KEPT_PREFIXES:
		if path.begins_with(prefix): return false
	return true

## A loadable, non-retired path (the drop-in for ResourceLoader.exists()).
static func usable(path: String, type_hint: String = "") -> bool:
	return not path.is_empty() and not retired(path) and ResourceLoader.exists(path, type_hint)
