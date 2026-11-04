extends SceneTree
const Fixture=preload("res://tests/guardian_followup_test.gd")
const Runtime=preload("res://scripts/growth/growth_runtime.gd")
const IDS=["source523_2192","source523_2742","source523_2752","source523_3202","source523_3382"]
const ROWS=[2392,3152,3162,3172,4492,4502,4762]
var checks: int=0
var failures: int=0
func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func grant(rt,id: String) -> void:
	for parent: String in rt.node(id).prerequisites:grant(rt,parent)
	if not rt.state.nodes.has(id):rt.state.nodes.append(id)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var host=Fixture.Host.new();root.add_child(host);host.add_child(host.player);host.add_child(host.monsters_root)
	var rt=Runtime.new();rt.configure(host)
	var target=Fixture.Actor.new();host.monsters_root.add_child(target)
	var combat=rt.guardian_combat
	expect(combat.outgoing(target,100,false,"melee")==100,"no owned source rewards means no compatibility bonus")
	for id: String in IDS:grant(rt,id)
	var seen: Array[int]=[]
	for reward: Dictionary in combat.enabled_rows():
		if not ROWS.has(int(reward.row.ID)):continue
		seen.append(int(reward.row.ID))
		expect(float(reward.value)==1 and float(reward.bonus.Value)==1,"source magnitude stays one for row "+str(reward.row.ID))
	seen.sort();expect(seen==ROWS,"exact seven source row identities consumed")
	expect(combat.pvp_numeric_value("PVPMeleeAdditionDamage",{})==2,"two melee rows consumed without PvP context")
	expect(combat.pvp_numeric_value("PVPRangeAdditionDamage",{})==2,"two ranged rows consumed without PvP context")
	expect(combat.pvp_numeric_value("PiercePVPDamageReduction",{})==2,"two numeric pierce rows consumed without PvP context")
	expect(combat.pvp_numeric_value("PVPDamageReduction",{})==1,"one incoming reduction row consumed without PvP context")
	expect(combat.outgoing(target,100,false,"melee")==104,"default existing-game flat conversion in melee")
	expect(combat.outgoing(target,100,false,"ranged")==104,"default existing-game flat conversion in ranged")
	expect(combat.outgoing(target,100,false,"magic")==102,"typed physical additions do not leak to magic")
	for id: String in IDS:expect(combat.pve_numeric_detail(id).contains("TWILIGHT") and combat.pve_numeric_detail(id).contains("PvE"),"visible local policy detail "+id)
	var on: Dictionary=combat.incoming(target,"magic",100)
	var policy: Dictionary=combat.pve_numeric_policy();policy.enabled=false
	var off: Dictionary=combat.incoming(target,"magic",100)
	expect(off.damage-on.damage==1,"source reduction improves ordinary incoming monster damage by one")
	expect(combat.outgoing(target,100,false,"melee")==100,"configuration can disable conversion")
	expect(combat.pve_numeric_detail(IDS[0]).contains("꺼짐"),"disabled configuration accurately shown")
	var scoped: int=combat.outgoing(target,100,false,"melee",{"pvp":true})
	expect(scoped==102,"original scoped addition applies once without flat-converted pierce")
	policy.enabled=true;policy.pierce_mode="bounded_restoration"
	expect(combat.outgoing(target,100,false,"melee")==102,"optional bounded mode adds no pierce without reduction")
	var general: float=combat.value("PierceDamageReduction")+combat.value("PierceMeleeDamageReduction")
	expect(combat.outgoing(target,100,false,"melee",{"flat_reduction":1})==102+int(minf(1,general+2)),"optional bounded mode caps exact combined source pierce")
	policy.pierce_mode="flat_addition"
	var baseline: int=combat.outgoing(target,100,false,"melee")
	# Even a stored locked-node ID cannot activate server-only source rows.
	for group: Dictionary in rt.config.guardians:
		if int(group.server_limit_set_id)!=0:
			for node: Dictionary in group.nodes:rt.state.nodes.append(str(node.id))
	expect(combat.outgoing(target,100,false,"melee")==baseline,"server60 stay inactive even when present in legacy state")
	host.queue_free();await create_timer(.1).timeout
	print("GUARDIAN_PVE_NUMERIC_RESULT: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
