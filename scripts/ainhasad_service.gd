extends RefCounted
class_name TwilightAinhasadService

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

func experience_rate() -> float:
	if blessing >= 201:
		return 7.0
	if blessing > 0 or orb_active():
		return 4.0
	return 1.0

func adena_rate() -> float:
	if blessing >= 201:
		return 2.0
	if blessing > 0 or orb_active():
		return 1.5
	return 1.0

func protected_drops() -> bool:
	return blessing > 0 or orb_active()

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

func charge(points: int) -> int:
	if points <= 0 or blessing >= MAX_BLESSING:
		return 0
	var added: int = mini(points, MAX_BLESSING - blessing)
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
	return {
		"blessing": blessing,
		"exp_rate": experience_rate(),
		"adena_rate": adena_rate(),
		"dragon_orb_active": remaining > 0,
		"dragon_orb_remaining": remaining,
		"auto_recharge": auto_recharge,
		"natural_regen_seconds": NATURAL_REGEN_SECONDS,
		"next_regen_seconds": maxi(0, NATURAL_REGEN_SECONDS - (now - last_regen_at)) if blessing < NATURAL_REGEN_CAP else 0,
		"monthly_orb_available": may_purchase_orb()
	}
