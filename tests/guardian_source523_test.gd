extends SceneTree
const Runtime = preload("res://scripts/growth/growth_runtime.gd")
var checks: int = 0
var failures: int = 0
class Host extends Node:
	var inventory: Dictionary = {"수호석":10000}
	var hp: int = 100
	var mp: int = 100
	var save_error: Error = OK
	var saved: Dictionary = {}
	func _save_game(_silent: bool, payload: Dictionary) -> Error:
		if save_error == OK: saved=payload.duplicate(true)
		return save_error
	func _invalidate_equipment_static() -> void: pass
	func _effective_max_hp() -> int: return 10000
	func _effective_max_mp() -> int: return 10000
	func _update_hud() -> void: pass

func expect(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func execute(rt, action: String, id: String = "", count: int = 1) -> Dictionary:
	return rt.execute(action,id,count,int(rt.state.revision))

func grant_path(rt, id: String) -> void:
	for parent: String in rt.node(id).prerequisites: grant_path(rt,parent)
	if not rt.state.nodes.has(id): rt.state.nodes.append(id)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var host := Host.new()
	root.add_child(host)
	var rt = Runtime.new()
	rt.configure(host)
	var count: int = 0
	for group: Dictionary in rt.config.guardians: count+=group.nodes.size()
	expect(count==172,"all original slots present")
	expect(rt.node("source523_3272").server_limit_set_id==0,"523 Crister category has no 1294 reference")
	expect(not rt.quote("activate","source523_3778").ok,"unresolved 1294 server semantics fail closed")
	expect(not rt.quote("activate","source523_2032").ok,"source prerequisite enforced")
	var before: int = int(host.inventory["수호석"])
	expect(execute(rt,"activate","source523_2022").ok,"root can start in ordinary play")
	expect(host.inventory["수호석"]==before and rt.state.searches.source523_2022.attempts==0,"no payment until selecting a card")
	rt.state.searches.source523_2022.winner=0
	var revision: int = int(rt.state.revision)
	expect(execute(rt,"choose","",1).ok,"failed card is a completed paid attempt")
	expect(host.inventory["수호석"]==before-1 and rt.state.searches.source523_2022.failed==[1],"failed card costs 1 source stone and persists")
	expect(not rt.execute("choose","",1,revision).ok,"stale duplicate transaction rejected")
	var restored: Dictionary=JSON.parse_string(JSON.stringify(rt.state))
	expect(rt.validate(restored).is_empty(),"source failure state survives JSON reload")
	rt.restore(restored)
	expect(execute(rt,"activate","source523_2022").ok,"can retry failed slot")
	expect(not rt.quote("choose","",1).ok,"reloaded failed card cannot be selected")
	expect(execute(rt,"choose","",0).ok and rt.state.nodes.has("source523_2022"),"winning card unlocks source slot")
	expect(host.inventory["수호석"]==before-2 and rt.state.points==0,"source currency is separate from blessing points")
	expect(rt.quote("activate","source523_2032").ok,"direct child unlocks without predecessor Lv3")
	expect(execute(rt,"activate","source523_2032").ok,"stat slot search starts")
	rt.state.searches.source523_2032.winner=0
	before=int(host.inventory["수호석"])
	host.save_error=ERR_CANT_CREATE
	var snapshot: Dictionary=rt.state.duplicate(true)
	expect(not execute(rt,"choose","",0).ok,"failed save rejects paid card result")
	expect(rt.state==snapshot and host.inventory["수호석"]==before,"failed save rolls back cost, card history and unlock")
	host.save_error=OK
	expect(execute(rt,"choose","",0).ok,"retry after save failure succeeds")
	expect(rt.bonus("melee_hit:flat")==1 and rt.bonus("ranged_hit:flat")==1,"ordinary stat rewards apply without any representative")
	var malformed: Dictionary=rt.state.duplicate(true)
	malformed.searches.source523_2032.cards=99
	expect(not rt.validate(malformed).is_empty(),"source card count cannot be altered in saves")
	malformed=rt.state.duplicate(true);malformed.nodes.erase("source523_2022")
	expect(not rt.validate(malformed).is_empty(),"source prerequisite also enforced on saves")
	var old: Dictionary=Runtime.fresh()
	old.nodes=["joe_0"];old.representative="joe_0"
	expect(rt.validate(old).is_empty(),"legacy 41-node save IDs still accepted")
	rt.restore(old)
	expect(rt.state.nodes==["joe_0"] and rt.state.representative=="joe_0","legacy IDs preserved without guessed source migration")
	rt.restore(Runtime.fresh())
	grant_path(rt,"source523_2112")
	expect(rt.validate(rt.state).is_empty(),"original prerequisite path is valid")
	var offer: Dictionary=rt.quote("guardian_enchant","source523_2112")
	expect(offer.ok and offer.costs["수호석"]==10 and rt.guardian_source.upgrade("source523_2112",1).Probability==150000,"source level1 enchant cost and 15 percent preserved")
	var upgrade: Dictionary=rt.guardian_source.upgrade("source523_2112",1)
	var original_probability: float=float(upgrade.Probability)
	upgrade.Probability=0
	before=int(host.inventory["수호석"])
	expect(execute(rt,"guardian_enchant","source523_2112").ok and rt.guardian_level("source523_2112")==0,"failed enchant retains level")
	expect(host.inventory["수호석"]==before-10,"failed enchant consumes source materials")
	upgrade.Probability=1000000
	expect(execute(rt,"guardian_enchant","source523_2112").ok and rt.guardian_level("source523_2112")==1,"successful enchant advances one level")
	upgrade.Probability=original_probability
	expect(rt.guardian_rewards("source523_2112").size()==1 and int(rt.guardian_rewards("source523_2112")[0].row.Level)==1,"upgraded rewards replace base rather than stacking")
	grant_path(rt,"source523_2592")
	expect(execute(rt,"representative","source523_2022").ok,"Joewoo invocation selection")
	expect(execute(rt,"representative","source523_2592").ok,"Atune invocation selection independent of Joewoo")
	expect(rt.state.guardian_representatives.size()==2,"representatives stored per category")
	expect(not rt.quote("representative","source523_2032").ok,"stats cannot become invocation selection")
	var reduction: Dictionary=rt.guardian_rewards("source523_2592")[0]
	expect(int(reduction.invoke.InvokeOptionTypeID)==5 and int(reduction.invoke.Param1)==5 and not reduction.has("spell"),"Type5 reduction magnitude is not a cast spell ID")
	grant_path(rt,"source523_2852")
	var branches: Array=rt.guardian_rewards("source523_2852")
	expect(branches.size()==2 and branches[0].invoke.BySpellAttack!=branches[1].invoke.BySpellAttack,"physical/magic defence rewards not merged")
	grant_path(rt,"source523_3001")
	var active: Dictionary=rt.guardian_rewards("source523_3001")[0]
	expect(int(active.spell.SpellMaterialTypeID)==41 and int(active.spell.SpellMaterialItemAmount)==10 and int(active.spell.CastDelay)==900000,"active skill costs and raw delay separate from unlock currency")
	expect(rt.node("source523_4078").prerequisites==["source523_4068"],"Kerenis actual prerequisite, not numerical predecessor")
	expect(rt.validate(JSON.parse_string(JSON.stringify(rt.state))).is_empty(),"new optional levels/representatives survive JSON")
	print("GUARDIAN_SOURCE523_TEST: %d checks, %d failures" % [checks,failures])
	host.queue_free()
	quit(0 if failures==0 else 1)
