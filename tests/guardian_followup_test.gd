extends SceneTree
const Runtime=preload("res://scripts/growth/growth_runtime.gd")
const Status=preload("res://scripts/skills/status_service.gd")
var checks: int=0
var failures: int=0
class Actor extends Node2D:
 var hp: int=10000
 var mp: int=100
 var dead: bool=false
 var life_id: int=1
 var stun_remaining: float=0
 var source_m_original: Dictionary={"Str":20,"Dex":20,"Con":20,"Wis":20,"Cha":20,"Int":20}
 var received: int=0
 func take_damage(amount: int,_critical: bool=false,_source: String="") -> void:
  received+=amount;hp-=amount
  if hp<=0:dead=true
 func show_status_text(_text: String) -> void:pass
class Art extends RefCounted:
 func emit_sprite(_sprite: int,_target: Node) -> void:pass
 func emit_spell(_spell: Dictionary,_target: Node) -> void:pass
class Catalog extends RefCounted:
 var current_official: Dictionary={"local_design":{"reagent_prices":{"명예 코인":100}}}
 func record_for(_id: String) -> Dictionary:return {"owned":false}
class Skills extends RefCounted:
 var catalog=Catalog.new()
 var status=Status.new()
 func target_damage(amount: int,_target: Node) -> int:return amount
class Host extends Node2D:
 var inventory: Dictionary={"수호석":10000,"명예 코인":100}
 var hp: int=100
 var mp: int=100
 var gold: int=10000
 var skill_cooldowns: Dictionary={}
 var player=Actor.new()
 var field_map=null
 var rng=RandomNumberGenerator.new()
 var original_skills=Skills.new()
 var monsters_root=Node.new()
 var saved: Dictionary={}
 var save_error: Error=OK
 func _save_game(_silent: bool,payload: Dictionary) -> Error:
  if save_error==OK:saved=payload.duplicate(true)
  return save_error
 func _invalidate_equipment_static() -> void:pass
 func _effective_max_hp() -> int:return 10000
 func _effective_max_mp() -> int:return 10000
 func _update_hud() -> void:pass
 func _world_to_cell(point: Vector2) -> Vector2i:return Vector2i(point/32)
 func _has_line_of_sight_world(_a: Vector2,_b: Vector2) -> bool:return true
 func _stat_step_bonus(value: int,baseline: int,step: float) -> int:return int(floor((value-baseline)/step))
 func _all_equipped_records() -> Array:return []
func expect(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func execute(rt,action: String,id: String="",count: int=1) -> Dictionary:return rt.execute(action,id,count,int(rt.state.revision))
func grant(rt,id: String) -> void:
 for parent: String in rt.node(id).prerequisites:grant(rt,parent)
 if not rt.state.nodes.has(id):rt.state.nodes.append(id)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var host=Host.new();root.add_child(host);host.add_child(host.player);host.add_child(host.monsters_root)
 var rt=Runtime.new();rt.configure(host);rt.combat.visuals=Art.new()
 grant(rt,"source523_3001")
 var offer: Dictionary=rt.quote("guardian_cast","source523_3001")
 expect(offer.ok and offer.costs["명예 코인"]==10,"active quote uses source ten coins")
 host.save_error=ERR_CANT_CREATE
 var before: Dictionary=rt.state.duplicate(true)
 expect(not execute(rt,"guardian_cast","source523_3001").ok,"active save failure rejects action")
 expect(host.hp==100 and host.mp==100 and host.inventory["명예 코인"]==100 and rt.state==before,"active rollback covers vitals materials and cooldown")
 host.save_error=OK
 expect(execute(rt,"guardian_cast","source523_3001").ok,"active heal executes")
 expect(host.hp==4600 and host.mp==550 and host.inventory["명예 코인"]==90,"active uses exact HP4500 MP450")
 expect(host.saved.hp==4600 and host.saved.mp==550 and host.saved.inventory["명예 코인"]==90,"vitals and cost in same saved transaction")
 expect(not rt.quote("guardian_cast","source523_3001").ok,"shared cooldown prevents repeated cast")
 var persisted: Dictionary=JSON.parse_string(JSON.stringify(rt.state));rt.restore(persisted)
 expect(not rt.quote("guardian_cast","source523_3001").ok and host.skill_cooldowns["guardian:source523_3001"]>898,"cooldown restored from absolute deadline")
 expect(rt.guardian_skill_record("guardian:source523_3001").heal==4500,"stable quickslot record resolves")
 rt.state.guardian_levels={"source523_3001":1}
 expect(rt.guardian_skill_record("guardian:source523_3001").heal==6000,"same quickslot ID resolves upgraded source profile")
 expect(not rt.quote("guardian_cast","source523_3001").ok,"upgrade cannot reset shared cooldown")
 var coins: int=host.inventory["명예 코인"]
 expect(execute(rt,"guardian_buy_coins").ok and host.gold==9000 and host.inventory["명예 코인"]==coins+10,"existing reagent vendor price used atomically")
 host.save_error=ERR_CANT_CREATE;var gold: int=host.gold
 expect(not execute(rt,"guardian_buy_coins").ok and host.gold==gold,"vendor save rollback")
 host.save_error=OK
 rt.restore(Runtime.fresh());grant(rt,"source523_2022");grant(rt,"source523_2032")
 expect(execute(rt,"representative","source523_2022").ok,"representative usable")
 grant(rt,"source523_2052")
 expect(not rt.quote("representative","source523_2052").ok,"representative three second wait applies")
 rt.state.guardian_switch_until["222"]=Time.get_unix_time_from_system()-1
 expect(execute(rt,"representative","source523_2052").ok,"representative can change after deadline")
 rt.restore(Runtime.fresh());grant(rt,"source523_2112");grant(rt,"source523_2592")
 rt.state.nodes.append("joe_0")
 var upgrade: Dictionary=rt.guardian_source.upgrade("source523_2112",1);var probability: float=upgrade.Probability;upgrade.Probability=0
 expect(execute(rt,"guardian_enchant","source523_2112").ok,"failed enchant completes")
 upgrade.Probability=probability
 expect(rt.guardian_spent(222)==10,"failed enchant cost recorded for refund")
 expect(not rt.quote("guardian_reset","joe").ok,"reset requires source diamond currency")
 rt.state.guardian_wallet={"4":2400};rt.state.guardian_cast_until={"311":Time.get_unix_time_from_system()+900}
 host.save_error=ERR_CANT_CREATE;before=rt.state.duplicate(true);var stones: int=host.inventory["수호석"]
 expect(not execute(rt,"guardian_reset","joe").ok and rt.state==before and host.inventory["수호석"]==stones,"reset failure restores nodes wallet and refund")
 host.save_error=OK
 expect(execute(rt,"guardian_reset","joe").ok,"reset completes")
 expect(host.inventory["수호석"]==stones+10 and rt.state.guardian_wallet["4"]==1200,"actual failed enchant spending refunded source reset1200 charged")
 expect(not rt.state.nodes.has("source523_2112") and rt.state.nodes.has("source523_2592") and rt.state.nodes.has("joe_0"),"reset affects chosen source category preserves others and legacy")
 expect(float(rt.state.guardian_cast_until["311"])>Time.get_unix_time_from_system()+898,"reset preserves shared heal cooldown")
 expect(rt.validate(JSON.parse_string(JSON.stringify(rt.state))).is_empty(),"reset optional ledger survives JSON")
 rt.state.guardian_spent={"222":9};rt.guardian_local_rules.reset.refund_rate=.5
 expect(rt.guardian_refund(222)==4,"local refund rate is configurable with conservative floor")
 rt.restore(Runtime.fresh());rt.state.searches={"source523_2022":{"cards":3,"winner":0,"attempts":2,"failed":[1]}};grant(rt,"source523_2022")
 expect(rt.guardian_spent(222)==2,"legacy refund uses provable search receipts only")
 var target=Actor.new();host.monsters_root.add_child(target)
 expect(rt.combat.cast_spell(rt.combat.profile(45332),target) and target.received==71,"source damage70 plus one die consumed")
 target.position=Vector2(16*32,0)
 expect(not rt.combat.cast_spell(rt.combat.profile(45332),target),"source cell range enforced")
 target.position=Vector2.ZERO;var other=Actor.new();host.monsters_root.add_child(other);other.position=Vector2(32,0)
 var far=Actor.new();host.monsters_root.add_child(far);far.position=Vector2(64,0)
 rt.combat.cast_spell(rt.combat.profile(45362),target)
 expect(other.received==36 and far.received==0,"source area uses one-cell radius")
 rt.combat.apply_buff(rt.combat.profile(45422),target)
 expect(host.original_skills.status.modifier(target,"mr")==-3 and host.original_skills.status.modifier(target,"ac")==3 and host.original_skills.status.modifier(target,"status_resistance_6")==-3,"source debuff signs units target scopes")
 rt.combat.apply_buff(rt.combat.profile(66973),target)
 expect(rt.combat.attribute(target,"str").after==19 and rt.combat.attribute(target,"cha").after==19,"all six source attributes connected")
 expect(rt.combat.npc_max_hp_delta(target)==-10 and rt.combat.npc_mr_delta(target)==-2,"existing local CON WIS derivation responds")
 target.life_id+=1
 expect(rt.combat.attribute(target,"str").after==20,"pooled new life does not inherit debuff")
 expect(not rt.combat.spell_allowed(57601,[241]) and rt.combat.spell_allowed(57601,[]),"source region ban only applies in matching group")
 expect(not rt.combat.roll(0) and rt.combat.roll(100),"zero and certain chance boundaries")
 # Force only test-owned original chance fields; production JSON remains untouched.
 rt.restore(Runtime.fresh());grant(rt,"source523_2022");rt.state.guardian_representatives={"222":"source523_2022"}
 var reward: Dictionary=rt.guardian_rewards("source523_2022")[0];var chance: float=reward.bonus.Value;reward.bonus.Value=1000000
 var initial: int=target.received
 rt.combat.after_hit(target,false,"melee",false)
 expect(target.received==initial,"main-target guard prevents splash proc")
 rt.combat.after_hit(target,false,"melee",true,true)
 expect(target.received==initial,"physical-only source proc excludes spell attacks")
 rt.combat.after_hit(target,false,"melee",true,false)
 expect(target.received==initial+71,"selected representative proc applies source profile")
 reward.bonus.Value=chance
 rt.restore(Runtime.fresh());grant(rt,"source523_2592");rt.state.guardian_representatives={"232":"source523_2592"}
 reward=rt.guardian_rewards("source523_2592")[0];chance=reward.bonus.Value;reward.bonus.Value=1000000
 var result: Dictionary=rt.combat.incoming(target,"melee",20)
 expect(result.damage==15 and rt.combat.fired==[6092],"Type5 is reduction5 never spell5")
 reward.bonus.Value=chance
 rt.restore(Runtime.fresh())
 expect(rt.combat.outgoing(target,100,false,"melee")==100,"no owned bonuses leaves damage unchanged")
 # Own every available stat path; branch guards use exact source magnitudes.
 for group: Dictionary in rt.config.guardians:
  if int(group.server_limit_set_id)!=0:continue
  for row: Dictionary in group.nodes:
   if row.kind=="stat":grant(rt,str(row.id))
 rt._rebuild()
 expect(rt.bonus("weight_bonus:flat")==200,"Weight44 source denominator100 yields200 available carry capacity")
 var combat=rt.combat
 var plain: int=combat.outgoing(target,100,false,"melee")
 var pvp: int=combat.outgoing(target,100,false,"melee",{"pvp":true})
 expect(plain==100 and pvp==100+int(combat.value("PVPMeleeAdditionDamage")),"PvP addition not flattened into PvE")
 expect(combat.outgoing(target,100,false,"melee",{"flat_reduction":2})==102,"pierce capped at actual reduction budget")
 expect(combat.outgoing(target,100,false,"melee",{"flat_reduction":100})==100+int(combat.value("PierceDamageReduction")+combat.value("PierceMeleeDamageReduction")),"pierce uses source amount")
 var percent: float=combat.value("IgnoreDamageReductionPercent")+combat.value("IgnoreMeleeDamageReductionPercent")
 expect(combat.outgoing(target,100,false,"melee",{"percent_reduction":50})==int(round(100*(1-maxf(0,50-percent)/100))),"ignore reduces actual percentage budget")
 expect(combat.outgoing(target,100,false,"melee",{"final_blow":true})==int(round(100*(1+combat.value("FinalBlowAdditionalScale")/100)+combat.value("FinalBlowAdditionalDmg"))),"decisive modifiers require actual decisive event")
 expect(combat.final_blow_chance()==0,"no equipped decisive probability means no invented proc chance")
 expect(combat.status_hit("stun")>0 and combat.status_hit("poison")==0,"target-specific status hit never affects unrelated status")
 # Avoid weapon-block RNG to examine deterministic incoming branches.
 var blocks: Array=[]
 for reward_row: Dictionary in combat.enabled_rows():
  if reward_row.bonus_type.Name=="WeaponBlock":blocks.append([reward_row.bonus,reward_row.bonus.Value]);reward_row.bonus.Value=0
 var ordinary: Dictionary=combat.incoming(target,"ranged",100)
 var critical: Dictionary=combat.incoming(target,"ranged",100,true)
 expect(critical.damage<ordinary.damage,"critical reduction applies only to critical hit")
 host.player.stun_remaining=1
 var stunned: Dictionary=combat.incoming(target,"ranged",100)
 host.player.stun_remaining=0
 expect(stunned.damage<ordinary.damage,"stunned reduction conditional")
 var tagged: Dictionary=combat.incoming(target,"ranged",100,false,{"spell_tags":[1]})
 expect(tagged.damage<ordinary.damage,"source tag221 rapid-fire reduction scoped to tag1")
 for block: Array in blocks:block[0].Value=1000000
 expect(blocks.is_empty() and combat.value("WeaponBlock")==0,"weapon-block rewards behind unresolved server categories remain inactive")
 for block: Array in blocks:block[0].Value=block[1]
 var previous_hp: int=host.hp;var previous_mp: int=host.mp
 combat.after_hit(target,true,"melee",true,false,1,1)
 expect(host.hp==previous_hp+mini(1,int(combat.value("CriticalDrainHP"))) and host.mp==previous_mp+mini(1,int(combat.value("CriticalDrainMP"))),"critical drains capped by available target resources")
 expect(combat.poison_damage(100)==int(round(100*(1-combat.value("PoisonDamageReductionPercent")/100))),"poison reduction uses percentage units")
 # Existing game inventory diamonds pay source reset cost without debug credit.
 rt.restore(Runtime.fresh());grant(rt,"source523_2022");rt.state.guardian_spent={"222":7}
 host.inventory["다이아"]=1200;before=rt.state.duplicate(true);stones=int(host.inventory["수호석"])
 offer=rt.quote("guardian_reset","joe")
 expect(offer.ok and offer.costs["다이아"]==1200 and offer.debug_gem_cost==0,"existing inventory currency pays original reset cost")
 host.save_error=ERR_CANT_CREATE
 expect(not execute(rt,"guardian_reset","joe").ok and host.inventory["다이아"]==1200 and rt.state==before,"earned currency reset rolls back on save error")
 host.save_error=OK
 expect(execute(rt,"guardian_reset","joe").ok and host.inventory["다이아"]==0 and host.inventory["수호석"]==stones+3,"earned diamond reset uses same atomic inventory/refund path")
 expect(not rt.state.has("guardian_wallet"),"ordinary payment does not fabricate debug wallet")
 rt.restore(Runtime.fresh());grant(rt,"source523_2022");rt.state.guardian_spent={"222":1};host.inventory["다이아"]=1200;rt.state.guardian_wallet={"4":1200}
 expect(execute(rt,"guardian_reset","joe").ok and rt.state.guardian_wallet["4"]==1200,"earned currency spent before manual debug credit")
 print("GUARDIAN_FOLLOWUP_TEST: %d checks, %d failures" % [checks,failures])
 host.queue_free();quit(0 if failures==0 else 1)
