extends RefCounted
## Original cash-store offers sold for game diamonds at the user's stated rate.
## KRW prices come from public NC notices (or the App Store list) recorded in the
## data file. The original offer/goods rows stay authoritative; only the payment
## is replaced, and the store-duplicate rows of one offer are not sold twice.
const PATH: String = "res://data/shop/source523_cash_market.json"
const SCHEMA: String = "twilight.source523.cash-market.v1"
const STORE_UNIT: int = 37
## Offline default for original per-period purchase limits of these offers.
const RESET_HOUR: int = 5
const CALENDAR_OFFSET_MINUTES: int = 540
static var _doc: Dictionary = {}
static var _duplicates: Dictionary = {}

static func data() -> Dictionary:
	if not _doc.is_empty(): return _doc
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary or parsed.get("schema") != SCHEMA or parsed.get("enabled") != true or not parsed.get("entries") is Dictionary: return {}
	var rate: Dictionary = parsed.get("rate", {})
	if int(rate.get("diamonds", 0)) <= 0 or int(rate.get("krw", 0)) <= 0: return {}
	_duplicates.clear()
	for key: String in parsed.entries:
		var row: Dictionary = parsed.entries[key]
		# The recorded diamond amount must equal the stated conversion.
		if int(row.get("diamonds", -1)) != diamonds_for(int(row.get("krw", 0)), rate): return {}
		for other: Variant in row.get("duplicate_store_purchase_ids", []): _duplicates[int(other)] = int(key)
	_doc = parsed
	return _doc

static func diamonds_for(krw: int, rate: Dictionary) -> int:
	if krw <= 0: return 0
	var numerator: int = krw * int(rate.diamonds)
	var denominator: int = int(rate.krw)
	return int((numerator + denominator - 1) / denominator)

static func entry(purchase_id: int) -> Dictionary:
	return data().get("entries", {}).get(str(purchase_id), {})

static func listed(purchase_id: int) -> bool:
	return not entry(purchase_id).is_empty()

## Another store's copy of a listed offer (Google/iOS/web rows share one offer).
static func duplicate_of(purchase_id: int) -> int:
	data()
	return int(_duplicates.get(purchase_id, 0))

static func hidden(purchase_id: int, payment: Dictionary) -> bool:
	if int(payment.get("UnitID", 0)) != STORE_UNIT: return false
	return not listed(purchase_id)

static func payment_quote(purchase_id: int, quantity: int) -> Dictionary:
	var found: Dictionary = entry(purchase_id)
	if found.is_empty():
		if duplicate_of(purchase_id) > 0: return {"ok":false, "reason":"같은 상품의 다른 스토어 행입니다 · 상품 #%d에서 구매하세요" % duplicate_of(purchase_id)}
		return {"ok":false, "reason":"외부 결제 상품 · TWILIGHT 다이아 환산가 미등록"}
	var payment: Dictionary = data().payment
	var amount: int = int(found.diamonds)
	if amount <= 0 or quantity < 1 or quantity > 1000: return {"ok":false, "reason":"상품 또는 수량 오류"}
	return {"ok":true, "unit_id":int(payment.unit_id), "class_id":int(payment.class_id), "unit_amount":amount,
		"quantity":quantity, "total":amount * quantity, "can_purchase":false,
		"twilight_cash_conversion":{"krw":int(found.krw), "diamonds":amount, "rate":data().rate.duplicate(true), "origin":found.get("origin", {}).duplicate(true)}}

static func strip(purchase_id: int, product: Dictionary) -> bool:
	if not listed(purchase_id): return false
	for rule: Dictionary in data().get("strip_products", []):
		if int(product.get("UnitID", -1)) == int(rule.unit_id) and int(product.get("ClassID", -1)) == int(rule.class_id): return true
	return false

static func describe(purchase_id: int) -> String:
	var found: Dictionary = entry(purchase_id)
	if found.is_empty(): return ""
	var origin: Dictionary = found.get("origin", {})
	return "TWILIGHT 환산가: 다이아 %d (원작 %s원 · 2000다이아=55,000원 기준)\n가격 출처: %s %s" % [int(found.diamonds), _comma(int(found.krw)), str(origin.get("title", "")), str(origin.get("posted", ""))]

static func _comma(value: int) -> String:
	var text: String = str(value)
	var out: String = ""
	while text.length() > 3:
		out = "," + text.substr(text.length() - 3) + out
		text = text.substr(0, text.length() - 3)
	return text + out
