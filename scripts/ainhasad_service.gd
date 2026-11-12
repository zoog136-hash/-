extends RefCounted
class_name TwilightAinhasadService
const RULES = preload("res://scripts/einasad/einasad523_rules.gd")

# Lineage M inspired single-player rules. The precise post-rebalance cost per
# monster EXP is unpublished: keep this ONE tuning constant editable.
const EXP_PER_BLESSING_POINT: float = 42000.0
const NATURAL_REGEN_SECONDS: int = 120
const NATURAL_REGEN_CAP: int = 200
const MAX_BLESSING: int = 999999
const DRAGON_ORB_SECONDS: int = 30 * 24 * 60 * 60
const DRAGON_ORB_PRICE: int = 1000000

var blessing: int = 200
var spend_remainder: float = 0.0
var last_regen_at: int = 0
var dragon_orb_expires_at: int = 0
var auto_recharge: bool = false
var last_orb_purchase_month: String = ""
# Derived from the installed source523 subscription adapter; the existing
# expiry is the only timer. -1 retains the established monthly-shop behavior.
var source_jade_level_override: int = -1

static func charge_multiplier(player_level: int) -> int:
	if player_level >= 89:
		return 5
	if player_level >= 88:
		return 4
	if player_level >= 87:
		return 3
	if player_level >= 85:
		return 2
	return 1

static func charge_amount(item_name: String, player_level: int) -> int:
	var base: int = 0
	match item_name:
		"드래곤의 루비":
			base = 30
		"드래곤의 사파이어":
			base = 50
		"드래곤의 다이아몬드":
			base = 100
		"드래곤의 고급 다이아몬드":
			base = 500
		"드래곤의 성수":
			return 1500
		_:
			return 0
	return base * charge_multiplier(player_level)

func orb_active(now: int = 0) -> bool:
	if now <= 0:
		now = int(Time.get_unix_time_from_system())
	return dragon_orb_expires_at > now

## Benefit stage: the original EinasadLevel stage of the balance, raised to
## stage 1 by the existing 드래곤의 보호 timer (BuffClass 54252,
## EinasadFixedLevel 1 = "축복이 없어도 1~200구간 혜택"). Without the original
## rows the existing thresholds (0 / 1..200 / 201+) are used.
func stage() -> int:
	var ordinary: int = RULES.stage_for_points(blessing)
	if ordinary < 0:
		ordinary = 2 if blessing >= 201 else 1 if blessing > 0 else 0
	if ordinary == 0 and orb_active() and source_jade_level_override != 0:
		return 1
	return ordinary

func experience_rate() -> float:
	var level: int = stage()
	var source: float = RULES.experience_multiplier(level)
	if source > 0.0:
		return source
	return [1.0, 4.0, 7.0][clampi(level, 0, 2)]

func adena_rate() -> float:
	var level: int = stage()
	var source: float = RULES.adena_multiplier(level)
	if source > 0.0:
		return source
	return [1.0, 1.5, 2.0][clampi(level, 0, 2)]

## EinasadBenefit GetItem: stage 0 "거래 불가 장비 획득 가능", stage 1/2 "모든
## 장비 및 아이템 획득 가능" (world._roll_drop keeps only 각인 equipment at 0).
func protected_drops() -> bool:
	return stage() > 0

func consume_for_kill(base_exp: int, reduction_percent: float = 0.0) -> int:
	if blessing <= 0:
		return 0
	var reduction: float = clampf(reduction_percent, 0.0, 100.0)
	spend_remainder += float(maxi(0, base_exp)) / EXP_PER_BLESSING_POINT * (1.0 - reduction / 100.0)
	var spent: int = mini(blessing, int(floor(spend_remainder)))
	if spent > 0:
		blessing -= spent
		spend_remainder -= float(spent)
	if blessing <= 0:
		spend_remainder = 0.0
	return spent

## Highest balance a charge reaches: the last original stage's CumulativeValue
## (EinasadLevel2 599994000 / 6000 = 99999) when installed, else MAX_BLESSING.
## A saved balance above it is kept as is; it only receives no further charge.
static func charge_cap() -> int:
	var source: int = RULES.max_points()
	return mini(MAX_BLESSING, source) if source > 0 else MAX_BLESSING

func charge(points: int) -> int:
	var cap: int = charge_cap()
	if points <= 0 or blessing >= cap:
		return 0
	var added: int = mini(points, cap - blessing)
	blessing += added
	return added

func start_dragon_orb() -> bool:
	if orb_active():
		return false
	dragon_orb_expires_at = int(Time.get_unix_time_from_system()) + DRAGON_ORB_SECONDS
	return true

static func month_key() -> String:
	var date: Dictionary = Time.get_datetime_dict_from_system()
	return "%04d-%02d" % [int(date.get("year", 2026)), int(date.get("month", 1))]

func may_purchase_orb() -> bool:
	return last_orb_purchase_month != month_key()

func register_orb_purchase() -> void:
	last_orb_purchase_month = month_key()

func advance_time(now: int = 0) -> bool:
	if now <= 0:
		now = int(Time.get_unix_time_from_system())
	if last_regen_at <= 0:
		last_regen_at = now
		return false
	# Never give bonus charge for a backwards clock change or while over cap.
	if now < last_regen_at or blessing >= NATURAL_REGEN_CAP:
		last_regen_at = now
		return false
	var ticks: int = (now - last_regen_at) / NATURAL_REGEN_SECONDS
	if ticks < 1:
		return false
	var before: int = blessing
	blessing = mini(NATURAL_REGEN_CAP, blessing + ticks)
	last_regen_at += ticks * NATURAL_REGEN_SECONDS
	if blessing >= NATURAL_REGEN_CAP:
		last_regen_at = now
	return blessing != before

func export_state() -> Dictionary:
	return {
		"blessing": blessing,
		"spend_remainder": spend_remainder,
		"last_regen_at": last_regen_at,
		"dragon_orb_expires_at": dragon_orb_expires_at,
		"auto_recharge": auto_recharge,
		"last_orb_purchase_month": last_orb_purchase_month
	}

func import_state(value: Variant) -> void:
	if not (value is Dictionary):
		last_regen_at = int(Time.get_unix_time_from_system())
		return
	var state: Dictionary = value as Dictionary
	blessing = clampi(int(state.get("blessing", 200)), 0, MAX_BLESSING)
	spend_remainder = clampf(float(state.get("spend_remainder", 0.0)), 0.0, 0.999999)
	last_regen_at = maxi(0, int(state.get("last_regen_at", 0)))
	dragon_orb_expires_at = maxi(0, int(state.get("dragon_orb_expires_at", 0)))
	auto_recharge = bool(state.get("auto_recharge", false))
	last_orb_purchase_month = str(state.get("last_orb_purchase_month", ""))
	advance_time()

func snapshot() -> Dictionary:
	var now: int = int(Time.get_unix_time_from_system())
	var remaining: int = maxi(0, dragon_orb_expires_at - now)
	var source: Dictionary = RULES.describe(blessing, stage())
	return {
		"blessing": blessing,
		"stage": stage(),
		"source_stage": source,
		"charge_cap": charge_cap(),
		"exp_rate": experience_rate(),
		"adena_rate": adena_rate(),
		"dragon_orb_active": remaining > 0,
		"dragon_orb_remaining": remaining,
		"auto_recharge": auto_recharge,
		"natural_regen_seconds": NATURAL_REGEN_SECONDS,
		"next_regen_seconds": maxi(0, NATURAL_REGEN_SECONDS - (now - last_regen_at)) if blessing < NATURAL_REGEN_CAP else 0,
		"monthly_orb_available": may_purchase_orb()
	}
