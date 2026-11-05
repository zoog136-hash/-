extends RefCounted
## Local economy policy, not recovered official merchant pricing or availability.
const Catalog = preload("res://scripts/shop/source523_shop_catalog.gd")
const REFERENCE_URL: String = "https://lineagem.plaync.com/board/update/view?articleId=643eb29f4c31e21977138d13"

static func defaults() -> Dictionary:
	return {"enabled":true,"currency_unit":4,"currency_class":26,"percentage_divisor":100,"tax_basis_points":0,"missing_base_price":500}

static func validate(config: Dictionary) -> String:
	if not config.get("enabled") is bool: return "자체 NPC 가격 사용 여부 오류"
	for key: String in ["currency_unit","currency_class","percentage_divisor","tax_basis_points","missing_base_price"]:
		if not Catalog._integer(config.get(key)) or int(config[key])<0:return "자체 NPC 가격 설정 오류: "+key
	if int(config.percentage_divisor)<1 or int(config.percentage_divisor)>1000000 or int(config.missing_base_price)<1 or int(config.tax_basis_points)>10000:return "자체 NPC 가격 설정 범위 오류"
	return ""

static func price(item: Dictionary, row: Dictionary, config: Dictionary) -> Dictionary:
	var error: String=validate(config)
	if not error.is_empty():return {"ok":false,"reason":error}
	if not config.enabled:return {"ok":false,"reason":"자체 NPC 가격 비활성"}
	var base: int=int(item.get("Cost",0))
	var base_origin: String="원본 Cost"
	if base<1:
		base=int(config.missing_base_price)
		base_origin="TWILIGHT 기본값"
	# Verified historical official BASE price agrees with the selected original.
	# It does not prove Percentage, currency, final tax, rounding, or activation.
	var reference: String=REFERENCE_URL if int(item.get("ID",0))==236 and base==850 else ""
	if not reference.is_empty():base_origin="원본 Cost · 공식 기본가 대조"
	var product: Dictionary=Catalog._checked_product([base,row.get("Percentage",0),row.get("Amount",0),10000+int(config.tax_basis_points)])
	if not product.ok:return {"ok":false,"reason":"NPC 자체 가격 계산 범위 오류"}
	var denominator: int=int(config.percentage_divisor)*10000
	@warning_ignore("integer_division")
	var amount: int=int(product.value)/denominator
	if int(product.value)%denominator!=0:amount+=1
	if amount<1:return {"ok":false,"reason":"NPC 가격 0 · 별도 가격 설정 필요"}
	return {"ok":true,"unit_id":int(config.currency_unit),"class_id":int(config.currency_class),"amount":amount,"origin":"TWILIGHT 자체 최종가 · "+base_origin,"reference_url":reference,"formula":"ceil(base × Percentage × Amount × (10000 + tax_basis_points) / (percentage_divisor × 10000))"}
