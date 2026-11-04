extends SceneTree
const Growth=preload("res://scripts/growth/growth_runtime.gd")
const Fixtures=preload("res://tests/symbol_source523_test.gd")
var host
var rt
var clock: Dictionary={"unix":2000000000}
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("SYMBOL_HISTORY_FAIL "+label)
func same(a: Dictionary,b: Dictionary) -> bool:return rt.History.fingerprint(a)==rt.History.fingerprint(b)
func act(action: String,id: String="eva") -> Dictionary:return rt.execute(action,id,1,int(rt.state.revision))
func give_scroll() -> void:
	var row: Dictionary=rt.source523.item_record(231772)
	host.inventory[row.name]=int(host.inventory.get(row.name,0))+1
	host.item_instances[str(host.item_instances.size()+100)]={"name":row.name,"record":row}
func run() -> void:
	host=Fixtures.Host.new();root.add_child(host);rt=Growth.new();rt.configure(host)
	rt.history.test_now=func() -> int:return int(clock.unix)
	rt.state.points=100000
	check(act("enhance","sayha").ok,"real independent second emblem")
	var other: Dictionary=rt.progress("sayha")
	check(not act("restore_emblem").ok and not act("save_emblem").ok,"empty legacy save cannot manufacture past progress")
	for i: int in range(2):check(act("enhance").ok,"real enhancement before snapshot")
	var actual: Dictionary=rt.progress("eva")
	var wallet: int=int(rt.state.points)
	check(act("save_emblem").ok and rt.history.record("eva").progress==actual and rt.state.points==wallet,"save copies only actual current progress at configured zero fee")
	var ticket: int=int(rt.history.record("eva").ticket)
	check(not act("save_emblem").ok and not act("restore_emblem").ok,"same record cannot mint another ticket or restore itself")
	check(act("enhance").ok,"advance beyond checkpoint")
	var before: Dictionary=rt.state.duplicate(true)
	host.reject_save=true
	check(not act("restore_emblem").ok and same(rt.state,before),"failed restore preserves wallet, checkpoint, quota and used flag")
	check(not act("save_emblem").ok and same(rt.state,before),"failed snapshot overwrite preserves prior checkpoint")
	host.reject_save=false
	wallet=int(rt.state.points)+int(rt.progress("eva").spent)
	check(act("restore_emblem").ok and rt.progress("eva")==actual,"restore exact existing checkpoint")
	check(same(rt.progress("sayha"),other),"selected restore never copies or erases other emblem progression")
	check(rt.state.points+rt.progress("eva").spent==wallet-int(rt.history.policy.restore_fee_points),"wallet plus invested principal decreases only fee; no duplicated principal")
	check(rt.history.record("eva").used and rt.history.record("eva").ticket==ticket and not act("restore_emblem").ok,"ticket is consumed exactly once")
	check(not act("save_emblem").ok,"consumed identical checkpoint cannot be saved as a fresh ticket")
	var reloaded: Dictionary=JSON.parse_string(JSON.stringify(rt.state))
	check(rt.validate(reloaded).is_empty(),"JSON history and day state validate")
	rt.restore(reloaded)
	check(not act("save_emblem").ok and not act("restore_emblem").ok,"int/float reload cannot mint duplicate checkpoint or replay restore")
	give_scroll()
	check(not act("reset").ok,"restore shares configured daily reset quota")
	clock.unix+=86400
	check(act("reset").ok and rt.progress("eva").attempts==0,"next existing game-day permits one reset")
	for i: int in range(3):check(act("enhance").ok,"new actual progress")
	give_scroll();check(not act("reset").ok,"second same-day reset denied without consuming scroll")
	clock.unix+=86400
	check(act("save_emblem").ok and int(rt.history.record("eva").ticket)>ticket,"different real progress overwrites used slot with unique newer ticket")
	check(act("reset").ok,"reset refunds only current principal")
	clock.unix+=86400
	var balance: int=int(rt.state.points);rt.state.points=0
	check(not rt.quote("restore_emblem","eva").ok,"after refund saved principal must be paid again; insufficient wallet denied")
	rt.state.points=balance;wallet=balance
	var principal: int=int(rt.history.record("eva").progress.spent)
	check(act("restore_emblem").ok and rt.state.points==wallet-principal-int(rt.history.policy.restore_fee_points),"restore after reset charges saved principal plus fee")
	clock.unix-=86400
	before=rt.state.duplicate(true)
	for action: String in ["save_emblem","restore_emblem","reset"]:check(not act(action).ok and same(rt.state,before),"backward date preserves high-water and blocks "+action)
	rt.restore(JSON.parse_string(JSON.stringify(before)))
	check(not act("reset").ok,"reconnect never clamps future high-water down to wall clock")
	clock.unix+=2*86400
	give_scroll()
	var offer: Dictionary=rt.quote("reset","eva")
	check(offer.ok,"future valid quota quote")
	clock.unix+=86400
	check(not rt.execute("reset","eva",1,int(rt.state.revision),int(offer.day)).ok and same(rt.state,before),"confirmation from previous day rejected atomically")
	var malformed: Dictionary=before.duplicate(true);malformed.symbol_history.records.eva.progress.stage=30
	check(not rt.validate(malformed).is_empty(),"completed or inconsistent stored records rejected")
	malformed=before.duplicate(true);malformed.symbol_history.records.sayha=malformed.symbol_history.records.eva.duplicate(true)
	check(not rt.validate(malformed).is_empty(),"duplicate receipt ticket rejected")
	malformed=before.duplicate(true);malformed.symbol_daily.counts.eva=-1
	check(not rt.validate(malformed).is_empty(),"negative quota count rejected")
	var completed: Dictionary=rt.state.duplicate(true)
	completed.emblems.eva={"stage":30,"attempts":10,"spent":100,"guaranteed":false,"absolute":0}
	rt.restore(completed)
	check(not rt.quote("save_emblem","eva").ok and not rt.quote("restore_emblem","eva").ok,"source stage30 prohibits both save and restoration")
	rt.restore(before)
	var policy: Dictionary=rt.history.policy.duplicate(true)
	rt.history.policy.restore_fee_points=-1
	check(not rt.quote("restore_emblem","eva").ok,"negative local fee never grants currency")
	rt.history.policy=policy.duplicate(true);rt.history.policy.history_enabled=false
	check(rt.validate(before).is_empty() and not rt.quote("save_emblem","eva").ok,"disable never invalidates existing records")
	rt.history.policy=policy.duplicate(true);rt.history.policy.daily_reset_limit_per_emblem=0
	check(rt.history.daily_offer("eva").ok,"configured unlimited quota still uses existing day API")
	rt.history.policy=policy
	print("SYMBOL_HISTORY_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	host.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
