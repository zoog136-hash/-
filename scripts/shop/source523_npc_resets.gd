extends RefCounted
## NPC-only counters; never changes world time, market calendars, or item ownership.
const Catalog=preload("res://scripts/shop/source523_shop_catalog.gd")
const PATH: String="res://data/shop/source523_npc_reset_rules.json"
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PATH))

static func validate(value: Variant) -> String:
	if not value is Dictionary or value.get("schema")!="twilight.source523.npc-reset-rules.v1" or not Catalog._integer(value.get("offset_minutes")) or abs(int(value.offset_minutes))>840 or not value.get("origin") is String or value.origin.is_empty() or not value.get("refresh_types") is Dictionary:return "NPC 초기화 자체 설정 형식 오류"
	for id: Variant in value.refresh_types:
		var row: Variant=value.refresh_types[id]
		if not id is String or not id.is_valid_int() or int(id)<0 or not row is Dictionary or not Catalog._integer(row.get("unit")) or int(row.unit) not in [61,71,81,111,11311] or not Catalog._integer(row.get("hour")) or int(row.hour)<0 or int(row.hour)>23:return "NPC 초기화 주기 설정 오류"
	return ""

func calendar(at: int, unit: int, hour: int) -> Dictionary:
	if unit==111:return {"bucket":"lifetime","next":0}
	var shifted: int=at+int(rules.offset_minutes)*60-hour*3600
	var day: int=floori(float(shifted)/86400.0)
	var date: Dictionary=Time.get_datetime_dict_from_unix_time(shifted)
	var bucket: String=str(day)
	var next_day: int=day+1
	if unit in [71,11311]:
		var first: int=1 if unit==71 else 3
		var start: int=day-posmod(int(date.weekday)-first,7)
		bucket=str(start);next_day=start+7
	if unit==81:
		bucket="%04d-%02d" % [int(date.year),int(date.month)]
		var month: int=int(date.month)+1
		var year: int=int(date.year)
		if month>12:month=1;year+=1
		var next_month: int=int(Time.get_unix_time_from_datetime_dict({"year":year,"month":month,"day":1,"hour":0,"minute":0,"second":0}))
		return {"bucket":bucket,"next":next_month-int(rules.offset_minutes)*60+hour*3600}
	return {"bucket":bucket,"next":next_day*86400-int(rules.offset_minutes)*60+hour*3600}

func allowance(row: Dictionary, history: Array, quantity: int, now: int, saved_identity: String) -> Dictionary:
	var error: String=validate(rules)
	if not error.is_empty():return {"ok":false,"reason":error}
	var policy: Dictionary=rules.refresh_types.get(str(int(row.LimitCountRefreshTypeID)),{})
	if policy.is_empty():return {"ok":false,"reason":"NPC 초기화 코드 자체 연결 미설정"}
	var effective: Dictionary={"offset":int(rules.offset_minutes),"unit":int(policy.unit),"hour":int(policy.hour),"account":bool(row.LimitCountPerAccount),"limit":int(row.LimitCount)}
	var identity: String=JSON.stringify(effective,"",true,true).sha256_text()
	if not saved_identity.is_empty() and saved_identity!=identity:return {"ok":false,"reason":"NPC 구매 한도 규칙 변경 감지 · 기존 규칙 확인 필요"}
	var current: Dictionary=calendar(now,int(policy.unit),int(policy.hour))
	var count: int=0
	for purchase: Dictionary in history:
		if calendar(int(purchase.at),int(policy.unit),int(policy.hour)).bucket==current.bucket:
			if count>Catalog.MAX_EXACT_INTEGER-int(purchase.quantity):return {"ok":false,"reason":"NPC 구매 한도 이력 범위 초과"}
			count+=int(purchase.quantity)
	var remaining: int=maxi(0,int(row.LimitCount)-count)
	var scope: String="저장 프로필" if row.LimitCountPerAccount else "현재 캐릭터 저장"
	var reset: String="초기화 없음" if int(current.next)==0 else "다음 초기화 %s UTC" % Time.get_datetime_string_from_unix_time(int(current.next))
	var text: String="%s 잔여 %d/%d회 · %s · %s" % [scope,remaining,int(row.LimitCount),reset,str(rules.origin)]
	return {"ok":quantity<=remaining,"reason":"NPC 구매 한도 초과 · "+text if quantity>remaining else "","remaining":remaining,"next_reset_at":int(current.next),"quota_text":text,"reset_identity":identity}
