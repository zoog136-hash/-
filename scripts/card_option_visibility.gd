extends RefCounted
class_name TwilightCardOptionVisibility

const SKILL = preload("res://scripts/transform_skill_options.gd")

# Only distinct unresolved mechanics are tagged; working generic stats remain
# unmarked. Unknown unique procs have already been removed from game catalog.
static func unresolved(category: String, option: String, card: Dictionary) -> bool:
	var s: String = option.strip_edges()
	match category:
		"변신":
			return s.begins_with("속성 치명타") or (
				(s.begins_with("불 속성 대미지") or s.begins_with("물 속성 대미지") or
				 s.begins_with("바람 속성 대미지") or s.begins_with("땅 속성 대미지")))
		"마법인형":
			return s.contains("축복 소모") or s == "디스펠 면역" or (
				s.contains("절대회복") or s.contains("회복(틱)") or
				s.contains("회복 (틱)") or s.begins_with("MP회복") or
				s == "HP 흡수" or s.contains("회복율") or s.contains("회피율"))
		"성물":
			if s.contains("스킬 레벨") or s.contains("마법 관통"):
				return true
			if s.begins_with("스킬 쿨타임 감소"):
				return float(card.get("skillCooldownPct", 0.0)) <= 0.0
			return s == "HP 흡수" or s.contains("절대회복") or (
				s.contains("회복(틱)") or s.contains("회복 (틱)") or
				s.begins_with("PVE ") and s.contains("명중") or
				s.begins_with("PVE 대미지 증가") or
				s.contains("치명타 대미지") or s.contains("원거리 회피력") or
				s.contains("대미지 리덕션 무시") and s.begins_with("마법"))
	return false

static func suffix(category: String, option: String, card: Dictionary) -> String:
	if unresolved(category, option, card):
		return " (원작 특수효과 미구현)"
	if category == "변신" and SKILL.is_named_skill_option(option):
		return " (해당 PvE 스킬 사용 시 적용)"
	return ""
