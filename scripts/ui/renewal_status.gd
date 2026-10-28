extends ScrollContainer

const UI = preload("res://scripts/ui/renewal_theme.gd")
const StatusSheet=preload("res://scripts/ui/status_detail_sheet.gd")
const GROUPS = {
	"공격": [["melee_damage","근거리 대미지"],["melee_accuracy","근거리 명중"],["ranged_damage","원거리 대미지"],["ranged_accuracy","원거리 명중"],["weapon_small_damage","무기 소형 최대 대미지"],["weapon_large_damage","무기 대형 최대 대미지"],["magic_damage","마법 대미지"],["magic_accuracy","마법 명중"],["melee_critical","근거리 치명타"],["ranged_critical","원거리 치명타"],["magic_critical","마법 치명타"]],
	"방어": [["ac","물리 방어력 (AC)"],["mr","마법 방어력 (MR)"],["dg","근거리 회피 (DG)"],["er","원거리 회피 (ER)"],["damage_reduction","대미지 리덕션"],["critical_resistance","치명타 저항"]],
	"내성": [["stun_resistance","스턴 내성"],["silence_resistance","침묵 내성"],["hold_resistance","홀드 내성"],["fear_resistance","공포 내성"],["poison_resistance","독 내성"],["bleed_resistance","출혈 내성"]],
	"속도 · 회복": [["attack_speed_bonus","공격 속도 보정"],["move_speed_bonus","이동 속도 보정"],["skill_cooldown_reduction","스킬 쿨타임 감소"],["attack_interval","공격 간격"],["hp_regen","HP 회복"],["mp_regen","MP 회복"],["max_hp","최대 HP"],["max_mp","최대 MP"],["max_weight","최대 소지 무게"]]
}
var values: Dictionary = {}

func configure(state: Dictionary) -> void:
	name = "DetailedStatus"
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var columns: HBoxContainer=StatusSheet.build(self,state)
	# The status sheet lives in its own window, rather than the main workspace.
	# Reuse that window's native finger capture for this read-only table.
	var window: Node=get_parent()
	while window!=null:
		if window.has_method("register_scroll_drag"):
			window.register_scroll_drag(self,columns)
			break
		window=window.get_parent()
	refresh(state)

func refresh(state: Dictionary) -> void:
	for key: String in values:
		var number: Variant = state.get(key)
		var suffix: String = "%" if key in ["attack_speed_bonus","move_speed_bonus","skill_cooldown_reduction","melee_critical","ranged_critical","magic_critical"] else "초" if key == "attack_interval" else ""
		values[key].text = ("%.1f" % float(number) if number is float else str(number))+suffix
