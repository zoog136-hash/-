extends RefCounted
## Local save namespace; user-policy debit and source-weighted result save together.
const Core=preload("res://scripts/cards/skill_awakening_service.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const SourceVFX=preload("res://scripts/cards/skill_awakening_source_vfx.gd")
const Growth=preload("res://scripts/cards/skill_awakening_growth.gd")
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
var source_vfx=SourceVFX.new()

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
		snapshot.growth_progress=Growth.view(core,progress,world.card_draw_fusion.owned,identity,world.card_draw_fusion.spare,int(world.gold))
		snapshot.can_feed=bool(snapshot.growth_progress.get("can_feed",false)) and not save_blocked
	return snapshot

func _save_staged_state(next: Dictionary,override: Dictionary={}) -> Error:
	var staged: Dictionary=override.duplicate(true);staged[SAVE_KEY]=next
	if world.has_method("_skill_awakening_vitals_for_state"):staged.merge(world._skill_awakening_vitals_for_state(next))
	var error: Error=world._save_game(true,staged)
	if error==OK:
		for key: String in ["hp","mp"]:
			if staged.has(key):world.set(key,staged[key])
	return error

func request_experience_feed(identity: String,material_id: String,expected_revision: int=-1) -> Dictionary:
	if _reroll_busy:return Core.fail("busy","이전 각성 거래 처리 중")
	if save_blocked or not problem.is_empty():return Core.fail("save_blocked","각성 저장 보호 중")
	_context();_reroll_busy=true
	var revision: int=int(progress.revision) if expected_revision<0 else expected_revision
	var prepared: Dictionary=Growth.prepare_feed(core,progress,world.card_draw_fusion.export_state(),int(world.gold),identity,material_id,revision)
	if not prepared.ok:_reroll_busy=false;return prepared
	var error: Error=_save_staged_state(prepared.state,{"card_draw_fusion":prepared.card_state,"gold":prepared.gold})
	if error!=OK:_reroll_busy=false;return Core.fail("save_failed","저장 실패 · 중복 카드·아데나·경험치·레벨 보존")
	progress=prepared.state;world.card_draw_fusion.import_state(prepared.card_state);world.gold=int(prepared.gold)
	_has_cache=false;world.set("equipment_records_dirty",true);_reroll_busy=false
	prepared.erase("state");prepared.erase("card_state");prepared.erase("gold");prepared.committed=true
	if world.has_method("_update_hud"):world.call_deferred("_update_hud")
	return prepared

func on_hunt_experience(amount: int) -> Dictionary:
	if _reroll_busy or save_blocked or not problem.is_empty():return Core.fail("save_blocked","스킬 각성 성장 보호 중")
	_context()
	var prepared: Dictionary=Growth.prepare_hunt(core,progress,world.card_draw_fusion.owned,world.equipped_catalog,amount)
	if not prepared.ok or not bool(prepared.get("changed",false)):return prepared
	var error: String=core.validate_state(prepared.state)
	if not error.is_empty():return Core.fail("invalid_state",error)
	# Earned hunt EXP shares the player's existing deferred save transaction.
	progress=prepared.state;_has_cache=false;world.set("equipment_records_dirty",true)
	return prepared
func request_operation(identity: String,materials: Dictionary={}) -> Dictionary:
	if _reroll_busy:return Core.fail("busy","이전 각성 거래 처리 중")
	if save_blocked or not problem.is_empty():return Core.fail("save_blocked","각성 저장 보호 중")
	_context()
	var revision: int=int(materials.get("expected_revision",progress.revision))
	var operation: String=str(materials.get("operation_id",str(Time.get_ticks_usec())+":"+str(revision)))
	var requirement: Dictionary=core.book_requirement(identity)
	if requirement.is_empty() or int(requirement.fee)<=0:return Core.fail("identity","각성 수수료 정책 연결 없음")
	if int(world.gold)<int(requirement.fee):return Core.fail("insufficient_gold","아데나 부족")
	var selected: String="";var item_name: String="";var locked_book: bool=false
	for key: String in world.item_instances:
		var physical: Variant=world.item_instances[key]
		if not physical is Dictionary or not physical.get("record") is Dictionary:continue
		var record: Dictionary=physical.record
		if record.get("source","")!="lineagem_base508" or record.get("source_snapshot","")!="base508":continue
		if record.get("source_item_class_id",0)!=int(requirement.item_class_id) or record.get("sourceId","")!="m508:item:"+str(int(requirement.item_class_id)):continue
		if physical.get("name","")!=record.get("name","") or str(physical.get("name","")).is_empty():continue
		if world.has_method("_item_locked") and (world._item_locked(str(physical.name)) or world._item_locked(str(physical.name),key)):
			locked_book=true;continue
		selected=key;item_name=str(physical.name);break
	if selected.is_empty():return Core.fail("book_locked" if locked_book else "insufficient_book","잠긴 각성서는 사용할 수 없습니다" if locked_book else "해당 등급 원본 각성서 1장 필요")
	var count: Variant=world.inventory.get(item_name,0)
	if not Core.integer(count) or int(count)<1:return Core.fail("book_quantity","각성서 보유 수량 오류")
	var physical_count: int=0
	for physical: Variant in world.item_instances.values():
		if physical is Dictionary and physical.get("name","")==item_name:physical_count+=1
	if physical_count>int(count):return Core.fail("book_quantity","각성서 물리 보유 정보 불일치")
	_reroll_busy=true
	var staged:=RandomNumberGenerator.new();staged.state=selection_rng.state
	var prepared: Dictionary=core.prepare_reroll(progress,world.card_draw_fusion.owned,identity,staged.randi_range(0,99999),revision,operation)
	if not prepared.ok:_reroll_busy=false;return prepared
	var bag: Dictionary=world.inventory.duplicate(true)
	var physicals: Dictionary=world.item_instances.duplicate(true)
	if int(count)==1:bag.erase(item_name)
	else:bag[item_name]=int(count)-1
	physicals.erase(selected)
	var remaining: int=int(world.gold)-int(requirement.fee)
	prepared.state.rng_state=str(staged.state)
	var error: Error=_save_staged_state(prepared.state,{"inventory":bag,"item_instances":physicals,"gold":remaining})
	if error!=OK:
		_reroll_busy=false
		return Core.fail("save_failed","저장 실패 · 재화·각성서·스킬·난수 보존")
	progress=prepared.state.duplicate(true);selection_rng.state=staged.state
	world.inventory=bag;world.item_instances=physicals;world.gold=remaining
	_has_cache=false;world.set("equipment_records_dirty",true);_reroll_busy=false
	prepared.erase("state");prepared.consumed_quantity=1;prepared.consumed_gold=int(requirement.fee)
	prepared.fee_provenance="explicit_user_policy"
	if world.has_method("_update_hud"):world.call_deferred("_update_hud")
	return prepared
func bonus_records() -> Array[Dictionary]:
	_context()
	if world==null or save_blocked or not problem.is_empty():return []
	var signature: int=hash([progress,world.equipped_catalog,world.card_draw_fusion.owned,core.source_server_context])
	if _has_cache and signature==_signature:return _records.duplicate(true)
	_signature=signature;_has_cache=true;_records.clear()
	for category: String in Cards.CATEGORIES:
		var record: Dictionary=world.equipped_catalog.get(category,{})
		if not preload("res://scripts/lineagem_base508.gd").native(record):continue
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
	if _proc_busy or save_blocked or world==null or target==null or not is_instance_valid(target) or bool(target.get("dead")) or int(SourceVFX.property(world,"hp",1))<=0:return
	_context();_proc_busy=true
	for category: String in Cards.CATEGORIES:
		if bool(target.get("dead")):break
		var record: Dictionary=world.equipped_catalog.get(category,{})
		if not preload("res://scripts/lineagem_base508.gd").native(record):continue
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
		source_vfx.emit_spell(world,spell,target)
		target.take_damage(amount,false,"magic")
		world.skill_cooldowns[key]=maxf(0,float(spell.CastDelay)-float(result.profile.invoke.CastDelayBonus))/1000.0
		proc_counts[identity]=int(proc_counts.get(identity,0))+1
		if world.get("hud")!=null:world.hud.append_log(str(result.spell.name)+" · 카드 스킬 각성 · "+str(amount)+" 고정 마법 피해"+(" · 원본 효과 일부 연결" if not bool(source_vfx.last_result.get("source_visual_complete",false)) else ""))
	_proc_busy=false


func _commit_confirmed_reroll(identity: String,expected_revision: int,operation_id: String) -> Dictionary:
	# Internal persistence fixture retained for isolated regression tests.
	# Public UI always enters request_operation with physical inventory debit.
	if _reroll_busy:return Core.fail("busy","이전 각성 거래 처리 중")
	if save_blocked or not problem.is_empty():return Core.fail("save_blocked","각성 저장 보호 중")
	_context();_reroll_busy=true
	var staged:=RandomNumberGenerator.new();staged.state=selection_rng.state
	var prepared: Dictionary=core.prepare_reroll(progress,world.card_draw_fusion.owned,identity,staged.randi_range(0,99999),expected_revision,operation_id)
	if not prepared.ok:_reroll_busy=false;return prepared
	prepared.state.rng_state=str(staged.state)
	var error: Error=_save_staged_state(prepared.state)
	if error!=OK:
		_reroll_busy=false
		return Core.fail("save_failed","저장 실패 · 기존 스킬·레벨·경험치·난수 보존")
	progress=prepared.state.duplicate(true);selection_rng.state=staged.state
	_has_cache=false;world.set("equipment_records_dirty",true);_reroll_busy=false
	prepared.erase("state")
	return prepared
