extends RefCounted
## Contextual source invokes. No passive flattening, persistence or nested attacks.
const DATA=preload("res://data/cards/base508_option_extensions.json")
const Cards=preload("res://scripts/card_draw_fusion.gd")
var runtime_ref: WeakRef
var runtime: RefCounted:
	get:return runtime_ref.get_ref() if runtime_ref!=null else null
var cooldowns: Dictionary:
	get:return runtime.world.skill_cooldowns if runtime!=null and runtime.world!=null else {}
var targets: Array[WeakRef]=[]
var busy: bool=false
var fired: Array[int]=[]
var visual_results: Dictionary={}
func configure(value: RefCounted) -> void:runtime_ref=weakref(value)
func active() -> Dictionary:
	var out: Dictionary={}
	if runtime==null or not is_instance_valid(runtime.world) or runtime.save_blocked or not runtime.problem.is_empty() or not runtime.core.native_mode:return out
	runtime._sync_native_context()
	for category: String in Cards.CATEGORIES:
		var record: Dictionary=runtime.world.equipped_catalog.get(category,{})
		if record.get("source","")!="lineagem_base508":continue
		var identity: String=Cards.card_id(record)
		if runtime.is_awakened(category,identity):out[identity]=runtime.core.definition(category,identity)
	return out
func tick(_delta: float) -> void:
	var enabled: Dictionary=active()
	var retained: Array[WeakRef]=[]
	for ref: WeakRef in targets:
		var target: Node=ref.get_ref()
		if not is_instance_valid(target):continue
		if target.has_method("prune_source_option_debuffs"):target.prune_source_option_debuffs(enabled)
		if not bool(target.get("dead")) and not target.source_option_debuffs.is_empty():retained.append(ref)
	targets=retained
func effects(rows: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for identity: String in rows:
		for effect: Dictionary in rows[identity].native_source.effects:
			if effect.type.Name!="InvokeOption" or int(effect.link.Level)!=1 or effect.unit.Name!="Percentage":continue
			for option: Dictionary in DATA.data.invoke_options:
				if int(option.ID)==int(effect.bonus.BonusApplicationTargetID):result.append({"origin":identity,"option":option,"weight":int(effect.bonus.Value)})
	return result
func roll(weight: int) -> bool:
	# Percentage has 10,000 raw units per percent: 80,000 = 8%.
	return runtime.world.rng.randi_range(0,999999)<clampi(weight,0,1000000)
func incoming(attacker: Node,kind: String,amount: int) -> Dictionary:
	var result: Dictionary={"damage":maxi(0,amount),"heal":0}
	fired.clear()
	if busy or amount<=0 or not is_instance_valid(attacker) or bool(attacker.get("dead")):return result
	busy=true
	for effect: Dictionary in effects(active()):
		var option: Dictionary=effect.option
		if int(option.InvokeOptionTypeID)==5:
			if int(option.MaterialAmount)!=0 or int(option.Param3)!=0:continue
			if roll(int(effect.weight)):
				result.damage=maxi(0,int(result.damage)-int(option.Param1));fired.append(int(option.ID));emit_sprite(int(option.TargetEffectSpriteID),runtime.world.player)
		elif int(option.InvokeOptionTypeID)==2:
			if bool(option.BySpellAttack)!=(kind=="magic") or amount<int(option.Param2) or int(option.Param3)!=0 or int(option.MaterialAmount)!=0:continue
			var key: String="native_option|"+str(effect.origin)+"|"+str(int(option.Param1))
			if float(cooldowns.get(key,0))>0:continue
			var spell: Dictionary=DATA.data.invoke_spells.get(str(int(option.Param1)),{})
			if spell.is_empty() or spell.effects.size()!=1:continue
			var bonus: Dictionary=spell.effects[0]
			if bonus.type.Name!="HPRestoration" or int(bonus.bonus.BonusApplicationTypeID)!=0 or int(bonus.bonus.BonusApplicationTargetID)!=0:continue
			if roll(int(effect.weight)):
				result.heal+=int(bonus.bonus.Value);cooldowns[key]=float(spell.source_spell.CastDelay)/1000.0;fired.append(int(option.ID));emit_spell(spell.source_spell,runtime.world.player)
	busy=false
	return result
func on_hit(target: Node) -> void:
	fired.clear()
	if busy or not is_instance_valid(target) or bool(target.get("dead")) or not target.has_method("apply_source_option_debuff"):return
	busy=true
	for effect: Dictionary in effects(active()):
		var option: Dictionary=effect.option
		if int(option.InvokeOptionTypeID)!=1 or int(option.MaterialAmount)!=0 or int(option.Param6)!=0:continue
		var key: String="native_option|"+str(effect.origin)+"|"+str(int(option.Param1))
		if float(cooldowns.get(key,0))>0:continue
		var spell: Dictionary=DATA.data.invoke_spells.get(str(int(option.Param1)),{})
		if spell.is_empty():continue
		var buffs: Array=[];var low: int=0;var high: int=0
		for bonus: Dictionary in spell.effects:
			match str(bonus.type.Name):
				"SpellDebuffMinDuration":low=int(bonus.bonus.Value)
				"SpellDebuffMaxDuration":high=int(bonus.bonus.Value)
				"BuffClassID":buffs=DATA.data.invoke_buffs.get(str(int(bonus.bonus.Value)),[])
		if low<=0 or high!=low or buffs.is_empty():continue
		if not roll(int(effect.weight)):continue
		if target.apply_source_option_debuff(str(effect.origin),low,buffs):
			cooldowns[key]=float(spell.source_spell.CastDelay)/1000.0;fired.append(int(option.ID));emit_spell(spell.source_spell,target)
			var found: bool=false
			for ref: WeakRef in targets:
				if ref.get_ref()==target:found=true;break
			if not found:targets.append(weakref(target))
	busy=false
func emit_spell(spell: Dictionary,target: Node2D) -> void:
	for field: String in ["EffectSpriteID","SuccessEffectSpriteID"]:
		emit_sprite(int(spell.get(field,0)),target)
func emit_sprite(sprite: int,target: Node2D) -> void:
	# Existing private source compositor only. Missing bindings remain absent.
	if sprite<=0 or not is_instance_valid(target):return
	visual_results[str(sprite)]="original_binding_unavailable"
	var player: Node=runtime.world.player
	var preview: Variant=null
	for property: Dictionary in player.get_property_list():
		if property.name=="original_source_preview":preview=player.get(property.name);break
	if preview!=null and preview.has_method("spawn_source_overlay"):
		# Shared compositor cleanup must accept freed handles before its typed filter.
		var live: Array=[]
		for node: Variant in preview._overlay_nodes:
			if is_instance_valid(node):live.append(node)
		preview._overlay_nodes=live
		if preview.spawn_source_overlay(sprite,5,target.global_position):visual_results[str(sprite)]="played_original"
