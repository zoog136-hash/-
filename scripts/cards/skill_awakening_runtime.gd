extends RefCounted
## TWILIGHT-local save namespace, not an original RPC/key. No unpriced debit.
const Core=preload("res://scripts/cards/skill_awakening_service.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const SAVE_KEY: String="card_skill_awakening"
var core=Core.new()
var world: Node
var progress: Dictionary=Core.fresh_state()
var save_blocked: bool=false
var problem: String=""
var proc_counts: Dictionary={}
var _signature: int=0
var _has_cache: bool=false
var _records: Array[Dictionary]=[]
var _proc_busy: bool=false
var _reroll_busy: bool=false
var selection_rng=RandomNumberGenerator.new()

func _init() -> void:selection_rng.randomize()

func configure(host: Node) -> bool:
	world=host;problem=core.problem;return problem.is_empty()
func export_state() -> Dictionary:return progress.duplicate(true)
func check_load(data: Dictionary) -> String:
	return core.validate_state(data[SAVE_KEY]) if data.has(SAVE_KEY) else ""
func accept_load(data: Dictionary) -> bool:
	var error: String=check_load(data)
	if not error.is_empty():save_blocked=true;return false
	progress=core.normalized_state(data.get(SAVE_KEY,Core.fresh_state()))
	if not str(progress.get("rng_state","")).is_empty():selection_rng.state=int(progress.rng_state)
	save_blocked=false;_has_cache=false
	if world!=null:world.set("equipment_records_dirty",true)
	return true
func _context() -> void:
	var runtime: Variant=world.get("card_collections") if world!=null else null
	core.source_server_context=runtime.source_server_context() if runtime!=null and runtime.has_method("source_server_context") else {}
func view(identity: String,preview_level: int=1) -> Dictionary:
	_context()
	var snapshot: Dictionary=core.view(progress,world.card_draw_fusion.owned,identity,preview_level)
	if snapshot.ok:
		var category: String=snapshot.card.category
		for record: Dictionary in world.catalog_db.get(category,[]):
			if Cards.card_id(record)==identity:snapshot.target_record=record.duplicate(true);break
		snapshot.save_blocked=save_blocked
	return snapshot
func request_operation(identity: String,materials: Dictionary={}) -> Dictionary:
	# Deliberately does not touch inventory, gold, RNG, progress or the save writer.
	return core.request_operation(progress,world.card_draw_fusion.owned,identity,materials)
func bonus_records() -> Array[Dictionary]:
	_context()
	if world==null or save_blocked or not problem.is_empty():return []
	var signature: int=hash([progress,world.equipped_catalog,world.card_draw_fusion.owned,core.source_server_context])
	if _has_cache and signature==_signature:return _records.duplicate(true)
	_signature=signature;_has_cache=true;_records.clear()
	for category: String in Cards.CATEGORIES:
		var record: Dictionary=world.equipped_catalog.get(category,{})
		if record.get("source","")!="lineagem_base508":continue
		var identity: String=Cards.card_id(record)
		if world.card_draw_fusion.owned.get(category,{}).get(identity,false)!=true or not core.eligibility(identity).ok:continue
		var entry: Dictionary=progress.cards.get(identity,{})
		if not core.spell_allowed(identity,int(entry.get("spell_id",0))):continue
		var profile: Dictionary=core.profile(identity,int(entry.get("level",0)))
		if profile.is_empty():continue
		_records.append({"_card_skill_awakening_bonus":true,"origin":identity,"hpFlat":int(profile.hp)})
	return _records.duplicate(true)

func on_successful_hit(target: Node) -> void:
	# Explicit local integration: existing successful-hit dispatcher. Source data
	# supplies the selection/proc weights and damage, not a client event handler.
	if _proc_busy or save_blocked or world==null or target==null or not is_instance_valid(target) or bool(target.get("dead")):return
	_context();_proc_busy=true
	for category: String in Cards.CATEGORIES:
		if bool(target.get("dead")):break
		var record: Dictionary=world.equipped_catalog.get(category,{})
		if record.get("source","")!="lineagem_base508":continue
		var identity: String=Cards.card_id(record)
		if world.card_draw_fusion.owned.get(category,{}).get(identity,false)!=true:continue
		var entry: Dictionary=progress.cards.get(identity,{})
		if not core.spell_allowed(identity,int(entry.get("spell_id",0))) or not core.eligibility(identity).ok:continue
		var key: String="card_skill_awaken:"+identity+":"+str(int(entry.spell_id))
		if float(world.skill_cooldowns.get(key,0))>0:continue
		var result: Dictionary=core.invoke(identity,entry,world.rng.randi_range(0,9999))
		if not result.ok or not result.invoked:continue
		var spell: Dictionary=result.spell.source_spell
		if int(spell.TargettingTypeID)!=2 or int(spell.TargetAreaRadius)!=0 or bool(spell.TestSpell):continue
		var amount: int=int(result.damage.SpellDamageBase)
		for die: int in range(int(result.damage.SpellDamageDiceNumber)):
			amount+=world.rng.randi_range(1,int(result.damage.SpellDamageDiceSpotCount))
		if bool(target.get("dead")):break
		# FixedMagicDamage is an explicit source boolean. Do not add SP, critical,
		# lifesteal, equipment amplification or recursively trigger this proc.
		target.take_damage(amount,false,"magic")
		world.skill_cooldowns[key]=maxf(0,float(spell.CastDelay)-float(result.profile.invoke.CastDelayBonus))/1000.0
		proc_counts[identity]=int(proc_counts.get(identity,0))+1
		if world.get("hud")!=null:world.hud.append_log(str(result.spell.name)+" · 카드 스킬 각성 · "+str(amount)+" 고정 마법 피해")
	_proc_busy=false


func _commit_confirmed_reroll(identity: String,expected_revision: int,operation_id: String) -> Dictionary:
	# Internal result/persistence stage for a future verified cost transaction.
	# Public request_operation remains blocked and never dispatches here while
	# source book quantities/fees are unresolved. This stage invents no debit.
	if _reroll_busy:return Core.fail("busy","이전 각성 거래 처리 중")
	if save_blocked or not problem.is_empty():return Core.fail("save_blocked","각성 저장 보호 중")
	_context();_reroll_busy=true
	var staged:=RandomNumberGenerator.new();staged.state=selection_rng.state
	var prepared: Dictionary=core.prepare_reroll(progress,world.card_draw_fusion.owned,identity,staged.randi_range(0,99999),expected_revision,operation_id)
	if not prepared.ok:_reroll_busy=false;return prepared
	prepared.state.rng_state=str(staged.state)
	var error: Error=world._save_game(true,{SAVE_KEY:prepared.state})
	if error!=OK:
		_reroll_busy=false
		return Core.fail("save_failed","저장 실패 · 기존 스킬·레벨·경험치·난수 보존")
	progress=prepared.state.duplicate(true);selection_rng.state=staged.state
	_has_cache=false;world.set("equipment_records_dirty",true);_reroll_busy=false
	prepared.erase("state")
	return prepared
