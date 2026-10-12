extends RefCounted

# One routing catalogue for the drawer and capability screens. "unavailable"
# never authorizes a local transaction or invents remote ownership.
const EXCLUDED_PVE_FEATURES := ["quest", "chat", "party", "clan", "exchange"]
const GROUPS := ["캐릭터", "게임 플레이", "커뮤니티", "시스템"]
const ENTRIES := [
	["character", "캐릭터 · 장비", 0, "local"], ["inventory", "인벤토리", 0, "local"],
	["skills", "스킬", 0, "local"], ["변신", "변신", 0, "local_catalog"],
	["마법인형", "마법인형", 0, "local_catalog"], ["성물", "성물", 0, "local_catalog"],
	["enhance", "장비 강화", 0, "local"], ["growth", "성장", 0, "unavailable"],
	["map", "월드맵", 1, "local"],
	["teleport", "지역 이동", 1, "local"], ["dungeon", "던전", 1, "local"],
	["special_dungeon", "특수 던전", 1, "local"], ["crafting", "제작", 1, "local"],
	["shop", "상점", 1, "local"], ["sell", "아이템 매입", 1, "local"],
	["warehouse", "창고", 1, "local"],
	["collection", "아이템 컬렉션", 1, "unavailable"], ["아이템", "아이템 도감", 1, "local"],
	["friends", "친구", 2, "unavailable"],
	["mail", "우편", 2, "unavailable"], ["ranking", "랭킹", 2, "unavailable"],
	["events", "이벤트 · 알림", 2, "unavailable"],
	["settings", "환경 설정", 3, "local"], ["auto", "자동사냥 · 전투", 3, "local"],
	["quickslots", "퀵슬롯 설정", 3, "local"], ["controls", "조작 · 단축키", 3, "local"],
	["log", "전투 기록", 3, "local"], ["info", "게임 정보", 3, "local"],
	["class_select", "클래스 선택", 3, "local"], ["exit", "저장 후 종료", 3, "local"]
]

static func entry(id: String) -> Array:
	for record: Array in ENTRIES:
		if record[0] == id: return record
	return [id, id, 3, "unavailable"]

static func requirement(id: String) -> String:
	match id:
		"mail": return "우편함과 첨부 보상 수령 서비스가 연결되지 않았습니다."
		"friends": return "친구 목록·접속 상태·요청 서비스가 연결되지 않았습니다."
		"ranking": return "서버 순위 데이터가 없습니다."
		"collection": return "아이템 도감은 조회할 수 있습니다. 수집 등록과 보상 시스템은 아직 지원하지 않습니다."
		"growth": return "추가 성장 시스템은 아직 지원하지 않습니다. 현재 능력치는 캐릭터 창에서 확인하세요."
		_: return "이 로컬 버전에는 연결된 콘텐츠가 없습니다."
