extends RefCounted
## Interactive host simulation using original difficulty and AI parameters.
var rules: RefCounted
var rng := RandomNumberGenerator.new()
var fish: Dictionary = {}
var difficulty: Dictionary = {}
var phase: String = "idle"
var elapsed: float = 0.0
var wait_seconds: float = 0.0
var cursor: float = 300.0
var target: float = 450.0
var target_goal: float = 450.0
var target_speed: float = 200.0
var progress: float = 300.0
var ai_elapsed: float = 0.0
var power_cooldown: float = 0.0
var power_remaining: float = 0.0
var held: bool = false
var auto_catch: bool = false
var manual_play: bool = false
var rod_power: int = 0
var gauge_rate_scale: float = 10.0
var auto_power_probability_step: int = 10000
var timeout_seconds: float = 120.0 # Adjustable TWILIGHT safety limit, not a source constant.

func start(source_rules: RefCounted, territory: int, rod: int, hour: int) -> bool:
	rules = source_rules
	rng.randomize()
	var distribution: Dictionary = rules.distribution(territory, rod, hour)
	if distribution.is_empty(): return false
	fish = rules.choose_fish(int(distribution.FishPoolID), rng)
	if fish.is_empty() or int(fish.get("ItemClassID", 0)) <= 0: return false
	var rod_stats: Dictionary = rules.rods.get(str(rod), {})
	rod_power = int(rod_stats.get("FishingPower", 0))
	var gap: int = int(fish.StandardPower) - rod_power
	for entry: Dictionary in rules.rows("FishMiniGameDifficulty"):
		if gap >= int(entry.MinGap) and gap <= int(entry.MaxGap): difficulty = entry
	if difficulty.is_empty(): return false
	var reduction: int = int(rod_stats.get("FishingDifficultyReduce", 0))
	if reduction > 0:
		var number: int = maxi(1, int(difficulty.DifficultyNum) - reduction)
		for entry: Dictionary in rules.rows("FishMiniGameDifficulty"):
			if int(entry.DifficultyNum) == number: difficulty = entry
	wait_seconds = float(fish.WaitTime) / 1000.0 * (1.0 - float(rod_stats.get("FishingWaitTimeDecPercent", 0)) / 1000000.0)
	cursor = float(difficulty.GaugeInitPos)
	target = float(difficulty.FishInitPos)
	target_goal = target
	progress = 300.0
	elapsed = 0.0
	phase = "waiting"
	return true

func hook() -> void:
	if phase == "bite":
		phase = "playing"
		manual_play = true
		elapsed = 0.0

func power() -> void:
	if phase == "playing" and power_cooldown <= 0.0:
		power_remaining = float(difficulty.SkillDuration) / 1000.0
		power_cooldown = float(difficulty.SkillCoolTime) / 1000.0

func tick(delta: float) -> void:
	if phase not in ["waiting", "bite", "playing"]: return
	elapsed += delta
	if phase == "waiting":
		if elapsed >= wait_seconds:
			phase = "bite"
			elapsed = 0.0
		return
	if phase == "bite":
		if elapsed >= float(rules.constant("FishMiniGameNoticeWaitTime", 3000)) / 1000.0:
			if auto_catch:
				# Explicit host interpolation, bounded by the source skip limits.
				var probability: int = clampi(int(fish.StandardSkipProb) + (rod_power - int(fish.StandardPower)) * auto_power_probability_step, int(fish.MinSkipProb), int(fish.MaxSkipProb))
				phase = "caught" if rng.randi_range(0, 999999) < probability else "failed"
			else: phase = "failed"
		return
	power_cooldown = maxf(0.0, power_cooldown - delta)
	power_remaining = maxf(0.0, power_remaining - delta)
	cursor = clampf(cursor + delta * (float(difficulty.PressMoveSpeed) if held else -float(difficulty.ReleaseMoveSpeed)), 0.0, 1000.0)
	ai_elapsed += delta
	var ai_id: int = -1
	for entry: Dictionary in rules.rows("FishMiniGameAI"):
		if int(entry.FishAIType) == int(fish.MiniGameAIType) and int(entry.FishDifficulty) == int(difficulty.ID): ai_id = int(entry.ID)
	for entry: Dictionary in rules.rows("FishMiniGameAIList"):
		if int(entry.FishMiniGameAI) != ai_id or progress < float(entry.MinGauge) or progress > float(entry.MaxGauge): continue
		if ai_elapsed >= float(entry.CheckDelay) / 1000.0:
			ai_elapsed = 0.0
			if rng.randi_range(0, 999999) < int(entry.MoveProb):
				var direction: float = -1.0 if rng.randi_range(0, 999999) < int(entry.MoveLeftProb) else 1.0
				target_goal = clampf(target + direction * float(entry.MoveValue), float(difficulty.TargetZoneBegin), float(difficulty.TargetZoneEnd))
				target_speed = float(entry.MoveSpeed)
		break
	target = move_toward(target, target_goal, target_speed * delta)
	if power_remaining > 0.0: cursor = target
	var inside: bool = absf(cursor - target) <= float(difficulty.TargetZoneSize) / 2.0
	# Client tables do not establish the exact server integration formula.
	# Explicit host policy: original gauge rates scaled to a 0..1000 meter.
	progress += delta * (float(difficulty.GaugeUpPower) if inside else -float(difficulty.GaugeDownPower)) / gauge_rate_scale
	if progress >= 1000.0: phase = "caught"
	elif progress <= 0.0 or elapsed >= timeout_seconds: phase = "failed"
