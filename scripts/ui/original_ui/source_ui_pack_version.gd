extends RefCounted
## The installed original UI add-on (twilight523-addon-ui.zip) by its "ui"
## section manifest SHA-256: a readable name for the 설정 정보 tab and the
## loading screen, and whether it is older than the add-on this code expects.
## The manifest carries no version number, so the names are the published
## add-on builds. An unknown SHA (a newer or a local build) counts as current
## when it has every scene the expected add-on added; otherwise it is old.
## An old pack never blocks the game: the windows it lacks keep their
## TWILIGHT fallback; the player is told once to reinstall.
const EXPECTED_NAME: String="ui42"
const EXPECTED_SHA256: String="335af82d2794bafa4a9273cb309cde3a59f06a764467e66b58e29321c98eebaa"
const KNOWN: Dictionary={
	"335af82d2794bafa4a9273cb309cde3a59f06a764467e66b58e29321c98eebaa":"ui42",
	"1137ccbca08c61fb64607c01bb4ccd1b19d06dd58b34b95320b0ab74656b87ef":"ui41",
	"21daecf510dc83ca9b155c80227b2d6812dd34155a3a69dbbbdd3b4354092d3d":"ui40",
	"a573fdf94784f51ec97dfb016a92ed47c7796ae92ea32e5d7db1a7f48b4113ca":"ui39",
	"ae1c2cf492492d10bfb0fba173374963bc1daf8c87d08985c29bf7403568868a":"ui38",
	"697a90518879ac8d00a70f884426373e3f5944d2d61707699f1c996789efc605":"ui37",
	"cf1d58f94b0c282ec2b103f357ac62ac91776818d6b7a5c39b93caaaa5c055fc":"ui36",
	"9cb718404e61ed1685b8522e1bfe8661a49fd1ac8d9cb542f3f7f3c3c880c0c2":"ui35",
	"075e5a757611e52237032ea30bebb0301ff75183acafb85b6919c0c50a69fe12":"ui34",
	"1b4e352118731d9951db9e5e00458c2b8a9069e92cab3892526883b7e11a9da7":"ui33",
	"e1e8295c1105e786706b7ce4ef6fa97ca253be985d5b73882e48c8f2428beb88":"ui32",
	"d587efcb87cd7bcfa1b6a2bdd5fa31619595d4c7d450e5fc9d1c165d04417e10":"ui31",
}
## Scenes ui42 added over ui41 (레벨업 연출, 보스 이름표).
const EXPECTED_SCENES: Array[String]=["UI/Effect/Effect_Source/Fx_Level_Up_Bottom.csb","UI/Effect/Effect_Source/Fx_Level_Up_Top.csb","UI/Main/Hud_LevelUp.csb","UI/Overhead/NameCardLayout_BossMonster.csb"]
const WARNING: String="UI 리소스 팩이 오래됐습니다. twilight523-addon-ui.zip(최신)을 다시 설치하세요"
static var _warned: bool=false

## {installed, name, sha8, outdated, missing_scenes}. `scenes` is the
## manifest's scene table when known (only an unknown SHA needs it).
static func describe(sha256: String, scenes: Variant=null) -> Dictionary:
	var sha: String=sha256.strip_edges().to_lower()
	if sha.is_empty():return {"installed":false,"name":"설치 안 됨","sha8":"","outdated":false,"missing_scenes":[]}
	if sha==EXPECTED_SHA256:return {"installed":true,"name":EXPECTED_NAME,"sha8":sha.left(8),"outdated":false,"missing_scenes":[]}
	if KNOWN.has(sha):return {"installed":true,"name":str(KNOWN[sha]),"sha8":sha.left(8),"outdated":true,"missing_scenes":[]}
	var missing: Array[String]=[]
	if scenes is Dictionary:
		for member: String in EXPECTED_SCENES:
			if not (scenes as Dictionary).has(member):missing.append(member)
	else:missing.assign(EXPECTED_SCENES)
	return {"installed":true,"name":"확인되지 않은 팩","sha8":sha.left(8),"outdated":not missing.is_empty(),"missing_scenes":missing}

## One line: "UI 팩 ui42 (335af82d)" (+ " · 오래됨").
static func label(info: Dictionary) -> String:
	if not bool(info.get("installed",false)):return "UI 팩 설치 안 됨"
	return "UI 팩 %s (%s)%s" % [str(info.name),str(info.sha8)," · 오래됨" if bool(info.outdated) else ""]

## The installed pack of the current run: the boot selection's environment
## (TWILIGHT_SOURCE_UI / _SHA256, set by source523_pack). The manifest is read
## only for an unknown SHA.
static func installed() -> Dictionary:
	var sha: String=OS.get_environment("TWILIGHT_SOURCE_UI_SHA256")
	var scenes: Variant=null
	if not sha.is_empty() and not KNOWN.has(sha.to_lower()):
		var path: String=OS.get_environment("TWILIGHT_SOURCE_UI").path_join("original_ui.json")
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		if parsed is Dictionary:scenes=parsed.get("scenes",{})
	return describe(sha,scenes)

## Shows WARNING once per run through `hud.show_message` when the pack is old.
static func warn_once(hud: Object, info: Dictionary) -> bool:
	if _warned or not bool(info.get("outdated",false)) or hud==null or not hud.has_method("show_message"):return false
	_warned=true
	hud.call("show_message",WARNING)
	return true
