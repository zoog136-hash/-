extends RefCounted
## Explicit local training consumer, not a claim of native/network PvP.
## Only the relic spell-level PvP delta is measured. Monster damage stays separate.
const RULES = preload("res://scripts/cards/relic_spell_levels.gd")
static func settings() -> Dictionary:
	RULES.EFFECTS.policy()
	return RULES.EFFECTS._policy_document.get("pvp_training", {})
static func preview(world: Node, requested: int) -> Dictionary:
	var config: Dictionary = settings()
	if not bool(config.get("enabled", false)): return {"ok":false,"error":"훈련 설정이 꺼져 있습니다."}
	if not RULES.ensure_loaded(): return {"ok":false,"error":"검증된 원본 규칙 자료가 필요합니다."}
	var maximum: int = clampi(int(config.get("maximum_raw_damage", 1000)), 1, 10000)
	var raw: int = clampi(requested, 1, maximum)
	var reduction: int = maxi(0, int(world.original_skills.stat("pvpDamageReduction")))
	var floor_hp: int = maxi(1, int(config.get("minimum_hp", 1)))
	var before: int = int(world.hp)
	if before <= floor_hp: return {"ok":false,"error":"HP가 훈련 하한에 도달했습니다."}
	var damage: int = mini(before-floor_hp, maxi(0,raw-reduction))
	return {"ok":true,"classification":"CUSTOM_RULE","raw":raw,"reduction":reduction,"damage":damage,"before":before,"after":before-damage,"minimum_hp":floor_hp}
static func apply(world: Node, requested: int) -> Dictionary:
	var result: Dictionary = preview(world, requested)
	if not result.ok: return result
	# Commit the full staged snapshot before changing live HP. The existing
	# modal's once-only accept guard and this atomic writer prevent replay debit.
	var error: Error = world._save_training_hp(int(result.after))
	if error != OK: return {"ok":false,"error":"저장 실패 · 훈련 피해를 적용하지 않았습니다.","save_error":int(error)}
	world.hp = int(result.after)
	world.player.show_received_damage(int(result.damage),false,"melee",world.player.global_position)
	world._update_hud()
	world.hud.append_log("자체 PvP 훈련 · 기본 %d / 성물 스킬 감소 %d / 실제 HP -%d" % [int(result.raw),int(result.reduction),int(result.damage)])
	return result
static func description(world: Node, requested: int) -> String:
	var result: Dictionary = preview(world, requested)
	if not result.ok: return str(result.error)
	return "성물 스킬의 PvP 감소 증가분만 시험하는 자체 규칙입니다.\n기본 피해 %d · 감소 증가분 %d · HP 피해 %d\nHP %d → %d (하한 %d)\n추가 아이템·재화 소모 및 보상 없음. 저장 성공 후 HP에 적용합니다." % [int(result.raw),int(result.reduction),int(result.damage),int(result.before),int(result.after),int(result.minimum_hp)]
