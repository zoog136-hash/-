extends SceneTree
## Nonvisual source caller protocol. No templates, pixels or original UI render
## are claimed by these synthetic interaction/ownership boundary fixtures.
const Caller = preload("res://scripts/unconfirmed523/source_ui_service.gd")
const Events = preload("res://scripts/unconfirmed523/events_domain.gd")
const Source = preload("res://scripts/unconfirmed523/source523.gd")
var checks: int = 0
var failures: Array[String] = []

class Tables extends Source:
	var tables: Dictionary = {}
	var row_reads: Array = []
	func rows(table: String) -> Array: return tables.get(table,[])
	func row(table: String, id: int) -> Dictionary:
		row_reads.append([table,id])
		for value: Dictionary in rows(table):
			if int(value.get("ID",0)) == id: return value
		return {}

class Backend extends RefCounted:
	const DOMAIN_PATHS = {"events":1,"jade_grail":1,"challenge":1}
	var world: Node
	var source = Tables.new()
	var state: Dictionary = {"revision":0,"rng":12,"domains":{"events":{"rng_state":1234,"passes":{"724":{"experience":60}}}}}
	var busy: bool = false
	var domains: Dictionary = {}
	var rows: Array = []
	var wallet: int = 50
	var writes: int = 0
	var fail_writer: bool = false
	var requests: Array = []
	func page(_section: String) -> Dictionary: return {"title":"source fixture","notes":[],"rows":rows.duplicate(true)}
	func context() -> Dictionary: return {"class_id":1,"instances":{},"owned":{},"nowUnix":1793800800}
	func fingerprint() -> String: return str([wallet,state.revision])
	func execute(section: String, request: Dictionary, revision: int, expected: String) -> Dictionary:
		if revision != state.revision or expected != fingerprint(): return {"ok":false}
		if fail_writer: return {"ok":false,"error":"writer_failure"}
		requests.append({"section":section,"request":request.duplicate(true)})
		writes += 1; wallet -= 10; state.revision += 1; state.rng += 1
		return {"ok":true}
	func request_presentation(_section: String, _focus: Dictionary = {}) -> Dictionary:
		return {"ok":false,"code":"presentation_unavailable"}

func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("UI_CALLER_FAIL: "+label)

func fixture() -> Backend:
	var host := Backend.new()
	host.world = Node.new()
	host.source.tables = {
		"Reward":[{"ID":100,"RewardTypeID":111,"RewardClassID":10},{"ID":200,"RewardTypeID":111,"RewardClassID":20},{"ID":1,"RewardTypeID":2,"RewardClassID":1,"Amount":1}],
		"SelectReward":[{"ID":10,"SelectMaxCount":1},{"ID":20,"SelectMaxCount":1}],
		"SelectRewardEntity":[{"ID":101,"SelectRewardID":10,"RewardID":200},{"ID":102,"SelectRewardID":10,"RewardID":1},{"ID":201,"SelectRewardID":20,"RewardID":1}],
		"ItemClass":[{"ID":1,"Name":"fixture"}]
	}
	var events = Events.new(); events.setup(host.source); host.domains.events = events
	host.rows = [{"id":"pass:724","actions":[{"request":{"action":"pass_purchase","pass_id":724,"premium":false},"costs":[{"kind":"currency","id":1,"amount":10}]}]},
		{"id":"container:1000","actions":[{"request":{"action":"consume_item","item_id":1000},"reward_root_ids":[100]}]},
		{"id":"container:2000","actions":[{"request":{"action":"consume_item","item_id":2000},"required_choices":[{"key":"instance_id","value_shape":"scalar","count":1,"options":[{"value":"physical:A"},{"value":"physical:B"}]}]}]},
		{"id":"blocked","actions":[{"request":{"action":"blocked"},"disabled":true}]}]
	return host

func reference(model: Dictionary, row_id: String) -> String:
	for row: Dictionary in model.get("content",{}).get("rows",[]):
		if row.id == row_id: return str(row.action_refs[0].action_ref)
	return ""

func run() -> void:
	var host: Backend = fixture()
	var caller = Caller.new(); caller.configure(host)
	var opening: Dictionary = caller.open_section("events")
	check(opening.get("ok",false) and host.writes == 0 and host.state.rng == 12,"opening source data never purchases or rolls")
	check(opening.model.progress.passes["724"].experience == 60 and not opening.model.progress.has("rng_state") and host.state.domains.events.rng_state == 1234,"source UI receives existing pass progress without owning the saved RNG")
	var external: Dictionary = opening.model
	external.content.rows[0].actions[0].request.pass_id = 999
	var stable: Dictionary = caller.snapshot()
	check(stable.content.rows[0].actions[0].request.pass_id == 724,"renderer mutation cannot change captured source action")
	var ref: String = reference(stable,"pass:724")
	check(not caller.begin("forged").get("ok",false),"unknown action reference cannot submit arbitrary requests")
	var pending: Dictionary = caller.begin(ref)
	check(pending.get("ok",false) and pending.ready and host.writes == 0,"begin only prepares exact displayed action")
	check(caller.cancel(pending.token).get("cancelled",false) and host.writes == 0 and host.wallet == 50,"cancel preserves wallet RNG and writer")
	check(not caller.confirm(pending.token).get("ok",false),"cancelled confirmation cannot be replayed")
	pending = caller.begin(ref)
	check(caller.confirm(pending.token).get("ok",false) and host.writes == 1 and host.wallet == 40,"confirmed captured action writes exactly once")
	check(host.requests[0].request == {"action":"pass_purchase","pass_id":724,"premium":false},"source request fields survive caller without label inference")
	check(not caller.confirm(pending.token).get("ok",false) and host.writes == 1,"double-confirm does not repeat a write")
	check(not caller.begin(ref).get("ok",false),"old page invalid after committed revision")
	opening = caller.open_section("events")
	pending = caller.begin(reference(opening.model,"pass:724")); host.wallet += 1
	check(not caller.confirm(pending.token).get("ok",false) and host.writes == 1,"wallet drift invalidates confirmation before execute")
	opening = caller.open_section("events")
	pending = caller.begin(reference(opening.model,"pass:724")); host.fail_writer = true
	var before: Array = [host.wallet,host.state.duplicate(true),host.writes]
	check(not caller.confirm(pending.token).get("ok",false) and [host.wallet,host.state,host.writes] == before,"failed writer preserves transaction state")
	check(not caller.confirm(pending.token).get("ok",false),"failed confirmation token cannot be replayed")
	host.fail_writer = false
	opening = caller.open_section("events")
	check(not caller.begin(reference(opening.model,"blocked")).get("ok",false),"disabled source action never prepares")
	pending = caller.begin(reference(opening.model,"container:1000"))
	check(not pending.ready and pending.choices.size() == 1 and pending.choices[0].key == "selection.100","root source choice is requested before nested branch")
	check(not caller.confirm(pending.token).get("ok",false),"unanswered source choices cannot confirm")
	check(not caller.choose(pending.token,"selection.100",[9]).get("ok",false),"foreign option cannot enter source request")
	check(not caller.choose(pending.token,"selection.100",[0,0]).get("ok",false),"duplicate option indices cannot enter source request")
	pending = caller.choose(pending.token,"selection.100",[0])
	check(pending.get("ok",false) and not pending.ready and pending.choices[0].key == "selection.200","selected source branch exposes its child choice without rolling")
	check(host.state.rng == before[1].rng and host.writes == before[2],"nested selection preview has no source RNG or write")
	pending = caller.choose(pending.token,"selection.200",[0])
	check(pending.ready and pending.request.selection == {"100":[101],"200":[201]},"nested exact entity IDs are carried to original resolver")
	check(caller.confirm(pending.token).get("ok",false) and host.requests[-1].request.selection == {"100":[101],"200":[201]},"nested choice confirmation uses the same source keys")
	opening = caller.open_section("events")
	pending = caller.begin(reference(opening.model,"container:2000"))
	pending = caller.choose(pending.token,"instance_id",[1])
	check(pending.ready and pending.request.instance_id == "physical:B","one physical instance is a scalar UID, never an array")
	caller.cancel(pending.token)
	opening = caller.open_section("events")
	pending = caller.begin(reference(opening.model,"pass:724"))
	host.rows[0].actions.clear()
	check(not caller.confirm(pending.token).get("ok",false),"time or eligibility removal is checked again before execute")
	host.source.row_reads.clear()
	opening = caller.open_section("events",{"kind":"attendance"})
	check(opening.model.content.rows.is_empty(),"source attendance route never renders pass rows as an invented combined page")
	check(host.source.row_reads.is_empty(),"native attendance focus avoids unrelated pool or pass metadata work")
	caller.close()
	check(caller.snapshot().is_empty() and not caller.confirm(pending.token).get("ok",false),"closing source UI invalidates transient actions and confirmations")
	check(not caller.open_section("unknown").get("ok",false),"unknown UI domain is rejected")
	host.rows[0].actions = [{"request":{"action":"pass_purchase","pass_id":724,"premium":false}}]
	opening = caller.open_section("events")
	pending = caller.begin(reference(opening.model,"pass:724"))
	host.world.free()
	check(not caller.confirm(pending.token).get("ok",false),"pending source caller cannot dereference a destroyed World or write")
	check(not caller.request_menu(106).get("ok",false) and caller.snapshot().is_empty(),"destroyed World invalidates source menu calls and cached model")
	check(not caller.open_section("events").get("ok",false),"unavailable host cannot produce live actions")
	host.world = null
	host = null
	check(caller.runtime == null,"caller holds a weak backend reference without a RefCounted cycle")
	print("UNCONFIRMED523_UI_CALLER_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"scope":"NONVISUAL_SOURCE_ACTION_PROTOCOL; NO_ORIGINAL_UI_RENDER"}))
	quit(0 if failures.is_empty() else 1)
