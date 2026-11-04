extends RefCounted
## Only the units/bonus values are native; estimated execution is explicit.
static var policy: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/growth/symbol_combat_policy.json"))
var owner_ref: WeakRef
var owner:
	get:return owner_ref.get_ref()
var last_hit_ms: int=-1
var veil_fired: bool=false
func configure(value) -> void:owner_ref=weakref(value)
static func estimates() -> bool:return bool(policy.estimates_enabled)
func outgoing(amount: int,kind: String) -> int:
	if not estimates():return amount
	var death: float=owner.bonus("local_death:flat")*float(policy.death_damage_per_point)
	var percent: float=(owner.bonus("local_ignore:percent")+owner.bonus("local_"+kind+"_ignore:percent"))*float(policy.ignore_percent_damage_scale)
	return maxi(1,int(round((amount+death)*(1+clampf(percent,0,float(policy.outgoing_percent_cap))/100.0))))
func incoming(damage: int,flat: int,percent: float,context: Dictionary) -> int:
	veil_fired=false
	var chance: float=owner.bonus("veil_proc:percent")
	if chance>0 and owner.world.rng.randf()*100<chance:
		var invoke: Dictionary=owner.source523.data.get("veil_invoke",{})
		if not invoke.is_empty():flat+=int(invoke.option.Param1);veil_fired=true
	if estimates():
		var boss_kind: String=str(context.get("boss_kind",""))
		if policy.rapid_fire_boss_kinds.has(boss_kind):flat+=int(owner.bonus("local_rapid_reduction:flat"))
		var now: int=int(context.get("now_ms",Time.get_ticks_msec()))
		if owner.bonus("local_damage_damp:percent")>0:
			if last_hit_ms>=0 and now>=last_hit_ms and now-last_hit_ms<=int(policy.damage_damp_window_ms):percent+=owner.bonus("local_damage_damp:percent")
			last_hit_ms=now
		if policy.armor_break_boss_kinds.has(boss_kind):
			var channel: String=str(context.get("channel","melee"))
			percent+=owner.bonus("local_armorbreak_"+channel+":percent")
		var ignored: float=maxf(0,float(context.get("ignore_percent",policy.npc_ignore_percent_by_boss_kind.get(boss_kind,0))))
		# Efficiency counters only bypass, never grants extra defense above own reduction.
		percent=maxf(0,percent-maxf(0,ignored-owner.bonus("local_reduction_efficiency:percent")))
	return maxi(1,int(round(float(maxi(1,damage-flat))*(1-clampf(percent,0,90)/100.0))))
