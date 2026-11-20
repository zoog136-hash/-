extends RefCounted
## Whether the original item icons can be shown in this run (user report
## 2026-11-20: empty bag slots with no hint why). Shown like the UI pack
## version (#691): on the loading screen and in 설정 → 정보.
##
## cheap (loading screen): the selection the pack boot made and the files it
## names, without opening the image list. full (in game): also the image
## owner's own verified open.
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
const MISSING := "아이템 아이콘 리소스 없음(팩 재설치 필요)"
const OK_TEXT := "아이템 아이콘 리소스: 정상"

static func check(full: bool = false, environment: Dictionary = {}) -> Dictionary:
	var root: String = str(environment.get("root", OS.get_environment("TWILIGHT_SOURCE523_IMAGES")))
	var sha: String = str(environment.get("sha256", OS.get_environment("TWILIGHT_SOURCE523_IMAGES_SHA256")))
	if root.is_empty() or sha.length() != 64: return {"ok":false,"reason":"image_pack_not_selected"}
	if not FileAccess.file_exists(root.path_join("manifest.json")): return {"ok":false,"reason":"image_manifest_missing"}
	if not DirAccess.dir_exists_absolute(root.path_join("originals").path_join("icon")): return {"ok":false,"reason":"item_icon_folder_missing"}
	if full:
		var status: Dictionary = IMAGES.selection_status()
		if not bool(status.get("ready", false)): return {"ok":false,"reason":str(status.get("error","image_pack_unavailable"))}
	return {"ok":true,"reason":""}

static func label(info: Dictionary) -> String:
	return OK_TEXT if bool(info.get("ok", false)) else MISSING
