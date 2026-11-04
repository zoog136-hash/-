extends SceneTree
const AUTO = preload("res://scripts/warehouse/inventory_automation.gd")
const BASE = preload("res://tests/inventory_maintenance_test.gd")
const DAY = preload("res://scripts/quests/quest_service.gd")
var checks: int = 0
var failures: Array[String] = []
class Player extends BASE.Player:
	var auto_enabled: bool = false
	var manual: bool = false
	func set_auto_enabled(enabled: bool) -> void: auto_enabled = enabled
	func has_manual_movement() -> bool: return manual
class Host extends BASE.Host:
	var writes: int = 0
	func _init() -> void:
		player.free()
		player = Player.new()
		now = 2000000000
	func _save_game(quiet: bool,override: Dictionary = {}) -> Error:
		writes += 1
		return super._save_game(quiet,override)
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("AUTOMATIC_EXEC_FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var host := Host.new();root.add_child(host)
	var auto = AUTO.new();auto.configure(host)
	var m = auto.maintenance
	m.test_unix_time = func() -> int: return host.now
	host.player.global_position = Vector2(50,0)
	check(auto.set_target("deposit","HP 물약","",true,7).ok and auto.set_target("sell","HP 물약","",true,2).ok,"existing explicit target and retention settings")
	auto.state["native_prices"] = {"117173":123}
	var before: String = host.snapshot(auto)
	check(m.arm("approved",true,true,120,false,{"setup":true,"resume_auto":true}).ok and m.automatic_enabled() and not m.settings().armed and host.inventory["HP 물약"] == 250,"configuring automatic execution saves policy but never starts or trades")
	check(not m.try_automatic(),"existing AUTO-off mode never starts automatic maintenance")
	host.player.set_auto_enabled(true);m.mode_changed(true)
	host.player.manual = true
	check(not m.try_automatic(),"manual movement retains priority")
	host.player.manual = false;m.next_automatic_check_ms = 0
	check(m.try_automatic() and m.settings().armed and not host.player.auto_enabled and not host.player.click_path.is_empty(),"AUTO consumer durably reserves one run before using existing walk API")
	var today: int = DAY.korean_daily_key(host.now)
	check(int(m.settings().automatic.last_started_day) == today,"existing game-date API reserves current day")
	var writes: int = host.writes
	check(m.try_automatic() and host.writes == writes,"repeated hunting ticks cannot reserve or spend twice")
	check(not m.before_portal("approved").ok,"automatic consumer cannot remotely transact before arrival")
	host.player.global_position = Vector2.ZERO
	var arrived: Dictionary = m.before_portal("approved")
	check(arrived.get("performed",false) and host.inventory["HP 물약"] == 2 and host.warehouse.stacks["HP 물약"] == 243 and host.gold == 10200,"arrival stores then sells exactly once; existing local travel cost zero")
	check(int(m.settings().automatic.last_completed_day) == today and not m.settings().armed,"completion day and consumed run token saved with transaction")
	m.after_portal(arrived)
	check(host.player.auto_enabled,"explicit selected mode resumes existing AUTO after successful portal")
	m.next_automatic_check_ms = 0
	check(not m.try_automatic() and host.gold == 10200,"same game date cannot pay or process twice")
	host.now -= 30;m.next_automatic_check_ms = 0
	check(not m.try_automatic() and host.gold == 10200,"wall-clock rollback cannot duplicate the game-date run")
	host.now += 86430
	host.inventory["HP 물약"] = 250
	auto.restore(JSON.parse_string(JSON.stringify(auto.state)))
	check(m.reconnect_wait and not m.try_automatic(),"reconnect waits for explicit AUTO selection even if old player mode was true")
	m.mode_changed(true);m.next_automatic_check_ms = 0
	check(m.try_automatic() and int(m.settings().automatic.last_started_day) == DAY.korean_daily_key(host.now),"next game date uses same configured route after explicit AUTO selection")
	host.fail_write = true
	before = host.snapshot(auto)
	check(not m.before_portal("approved").ok and host.snapshot(auto) == before and host.gold == 10200,"actual callback failure leaves both phases and pending token unchanged")
	host.fail_write = false
	auto.restore(JSON.parse_string(JSON.stringify(auto.state)))
	check(m.paused and m.reconnect_wait and not m.before_portal("approved").ok,"saved in-flight run never replays automatically after reconnect")
	check(m.disable_automatic().ok and not m.automatic_enabled() and not m.settings().armed,"turning off cancels active automatic intent and route")
	host.now += 86400
	host.player.global_position = Vector2(50,0)
	check(m.arm("approved",true,true,120,false,{"setup":true,"resume_auto":false}).ok,"explicit reconfiguration preserves game-date usage history")
	host.player.set_auto_enabled(true);m.mode_changed(true)
	host.fail_write = true
	before = host.snapshot(auto);writes = host.writes
	check(not m.try_automatic() and host.snapshot(auto) == before and host.player.click_path.is_empty(),"failed reservation save cannot start walking or publish a run token")
	check(not m.try_automatic() and host.writes == writes+1,"failed reservation pauses rather than retrying every hunting frame")
	host.fail_write = false
	m.mode_changed(true)
	check(m.try_automatic(),"explicit mode selection may retry a known failed unexecuted reservation")
	host.now -= 1;m.tick()
	check(m.paused and host.player.click_path.is_empty() and not m.before_portal("approved").ok,"clock rollback during walk stops owned route without spending")
	host.now += 2
	check(m.disable_automatic().ok,"explicit cancel after rollback")
	check(m.arm("approved",true,true,120,false,{"setup":true}).ok,"configure route again")
	check(auto.set_target("sell","HP 물약","",true,3).ok and not m.automatic_enabled(),"changing selected scope automatically disables prior automatic approval")
	host.now += 86400
	check(m.arm("approved",true,true,120,false,{"setup":true}).ok,"approve current map revision before automatic execution")
	host.field_map.data.layout_revision = 5
	host.field_map.data.portal[0].target_layout_revision = 5
	host.player.set_auto_enabled(true);m.mode_changed(true)
	check(not m.try_automatic() and m.paused and not m.settings().armed,"even a newly valid map revision requires renewed user route approval")
	check(DAY.korean_daily_key(20*3600-1)+1 == DAY.korean_daily_key(20*3600),"same existing Korean05 reset boundary; no new local clock")
	var bad_day: Dictionary = m.settings().automatic.duplicate(true)
	bad_day["last_completed_day"] = int(bad_day.last_started_day)+1
	var huge_day: Dictionary = m.settings().automatic.duplicate(true)
	huge_day["configured_day"] = 1e100
	for malformed: Variant in [{"enabled":true},bad_day,huge_day]:
		check(not AUTO.valid({"maintenance":m.settings().merged({"automatic":malformed},true)}),"malformed automatic save metadata rejected")
	host.free()
	print("INVENTORY_AUTOMATIC_EXECUTION: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
