extends RefCounted
class_name TwilightConsumableRules

# Data-only rules for user consumables; no map, HUD, monster or animation dependencies.
# Lineage M reference: 2017 official powerbook (duration/effects), adjusted for offline game.
# Community-reported legacy 1–3 chances: 30/10/5. Stage 4–5: TWILIGHT placeholders, NOT official rates.
const ELEMENT_CHANCES: Array[float] = [30.0, 10.0, 5.0, 2.0, 1.0]
const ELEMENT_NAMES: Dictionary = {"fire":"화령", "water":"수령", "earth":"지령", "wind":"풍령"}
const STAT_KEYS: Array[String] = ["STR", "DEX", "CON", "INT", "WIS", "CHA"]
const STATUS_CLEANSERS: Array[String] = ["상태이상 해제 물약", "상태 이상 해제 물약", "만능 해독제", "해독제", "해독 물약", "정화의 물약"]

static func normalize_name(item_name: String) -> String:
	return item_name.replace(" (각인)", "").replace("(각인)", "").strip_edges()

static func is_removed_item(item_name: String) -> bool:
	var normalized: String = normalize_name(item_name)
	return normalized in STATUS_CLEANSERS or normalized.contains("상태이상 해제 물약")

static func records() -> Array[Dictionary]:
	return [
		{"name":"드래곤의 루비", "grade":"고급", "type":"축복충전", "slot":"consumable", "kind":"ain_charge", "amount":30,
		 "desc":"아인하사드 축복 +30 · 85레벨부터 레벨별 충전 증가"},
		{"name":"드래곤의 사파이어", "grade":"희귀", "type":"축복충전", "slot":"consumable", "kind":"ain_charge", "amount":50,
		 "desc":"아인하사드 축복 +50 · 85레벨부터 레벨별 충전 증가"},
		{"name":"드래곤의 다이아몬드", "grade":"희귀", "type":"축복충전", "slot":"consumable", "kind":"ain_charge", "amount":100,
		 "desc":"아인하사드 축복 +100 · 85레벨부터 레벨별 충전 증가"},
		{"name":"드래곤의 고급 다이아몬드", "grade":"영웅", "type":"축복충전", "slot":"consumable", "kind":"ain_charge", "amount":500,
		 "desc":"아인하사드 축복 +500 · 85레벨부터 레벨별 충전 증가"},
		{"name":"드래곤의 성수", "grade":"영웅", "type":"축복충전", "slot":"consumable", "kind":"ain_charge", "amount":1500,
		 "desc":"45레벨 이상 · 아인하사드 축복 +1,500 · 경험치 +31,920,000"},
		{"name":"드래곤의 용옥", "grade":"희귀", "type":"축복버프", "slot":"consumable", "kind":"ain_orb",
		 "desc":"30일간 드래곤의 보호 · 축복 0에서도 EXP 400% / 아데나 150% · 캐릭터별 실제 시간 적용"},
		{"name":"마나 회복 물약", "grade":"일반", "type":"회복물약", "slot":"consumable", "kind":"regen",
		 "duration":300.0, "group":"mana_potion", "buff":{"mp_regen_tick":5, "tick_interval":30.0},
		 "desc":"지속 시간 300초 · 30초마다 MP 5 회복 (TWILIGHT 밸런스)"},
		{"name":"MP 회복 물약", "grade":"일반", "type":"회복물약", "slot":"consumable", "kind":"regen",
		 "duration":300.0, "group":"mana_potion", "buff":{"mp_regen_tick":5, "tick_interval":30.0},
		 "desc":"지속 시간 300초 · 30초마다 MP 5 회복 (TWILIGHT 밸런스)"},
		{"name":"마녀의 마력 회복제", "grade":"고급", "type":"회복물약", "slot":"consumable",
		 "kind":"instant_mp", "amount":1000, "cooldown":1800.0,
		 "desc":"MP 즉시 1000 회복 · 재사용 30분"},
		{"name":"힘센 한우 스테이크", "grade":"일반", "type":"요리", "slot":"consumable", "kind":"food",
		 "duration":1800.0, "group":"cooking", "classes":["기사", "군주"],
		 "buff":{"melee_damage":2, "melee_accuracy":1, "mp_regen_tick":2, "hp_regen_tick":2, "tick_interval":30.0, "mr":10, "damage_reduction":2},
		 "desc":"지속 시간 1800초 · 근거리 대미지 +2 · 근거리 명중 +1 · HP/MP 회복 틱 +2 · MR +10 · 리덕션 +2"},
		{"name":"날쌘 연어 찜", "grade":"일반", "type":"요리", "slot":"consumable", "kind":"food",
		 "duration":1800.0, "group":"cooking", "classes":["요정"],
		 "buff":{"ranged_damage":2, "ranged_accuracy":1, "mp_regen_tick":2, "hp_regen_tick":2, "tick_interval":30.0, "mr":10, "damage_reduction":2},
		 "desc":"지속 시간 1800초 · 원거리 대미지 +2 · 원거리 명중 +1 · HP/MP 회복 틱 +2 · MR +10 · 리덕션 +2"},
		{"name":"영리한 칠면조 구이", "grade":"일반", "type":"요리", "slot":"consumable", "kind":"food",
		 "duration":1800.0, "group":"cooking", "classes":["마법사"],
		 "buff":{"sp":2, "mp_regen_tick":3, "hp_regen_tick":2, "tick_interval":30.0, "mr":10, "damage_reduction":2},
		 "desc":"지속 시간 1800초 · SP +2 · MP 회복 틱 +3 · HP 회복 틱 +2 · MR +10 · 리덕션 +2"},
		{"name":"전투 강화의 주문서", "grade":"일반", "type":"소모품", "slot":"consumable", "kind":"buff",
		 "duration":1800.0, "group":"combat_scroll",
		 "buff":{"melee_damage":3, "melee_accuracy":3, "ranged_damage":3, "ranged_accuracy":3, "sp":3},
		 "desc":"지속 시간 1800초 · 근거리/원거리 대미지/명중 +3 · SP +3"},
		{"name":"귀환 주문서", "grade":"일반", "type":"이동주문서", "slot":"consumable",
		 "kind":"return", "desc":"가장 가까운 안전 마을로 귀환 (던전은 아덴 마을)"},
		{"name":"순간이동 주문서", "grade":"일반", "type":"이동주문서", "slot":"consumable",
		 "kind":"teleport", "desc":"현재 맵 안의 도달 가능한 무작위 위치로 순간이동"},
		{"name":"속성 강화 주문서", "grade":"고급", "type":"강화주문서", "slot":"consumable",
		 "kind":"element", "element":"", "desc":"일반 무기 최대 3단계 · 고강화 무기 추가 단계 · 실패 시 무기 유지 · 확률 일부 임시값"},
		{"name":"화령의 무기 강화 주문서", "grade":"고급", "type":"강화주문서", "slot":"consumable",
		 "kind":"element", "element":"fire", "desc":"무기 불 속성 강화 · 일반 최대 3단계 · 실패 시 무기 유지"},
		{"name":"수령의 무기 강화 주문서", "grade":"고급", "type":"강화주문서", "slot":"consumable",
		 "kind":"element", "element":"water", "desc":"무기 물 속성 강화 · 일반 최대 3단계 · 실패 시 무기 유지"},
		{"name":"지령의 무기 강화 주문서", "grade":"고급", "type":"강화주문서", "slot":"consumable",
		 "kind":"element", "element":"earth", "desc":"무기 땅 속성 강화 · 일반 최대 3단계 · 실패 시 무기 유지"},
		{"name":"풍령의 무기 강화 주문서", "grade":"고급", "type":"강화주문서", "slot":"consumable",
		 "kind":"element", "element":"wind", "desc":"무기 바람 속성 강화 · 일반 최대 3단계 · 실패 시 무기 유지"},
		{"name":"엘릭서", "grade":"희귀", "type":"성장소모품", "slot":"consumable", "kind":"elixir",
		 "desc":"50레벨 이상 · 선택한 기본 스탯 영구 +1 · TWILIGHT 최대 10회 / 스탯 45 제한"},
		{"name":"힘의 엘릭서", "grade":"희귀", "type":"성장소모품", "slot":"consumable", "kind":"elixir", "stat":"STR",
		 "desc":"50레벨 이상 · STR 영구 +1 · 엘릭서 제한 공유"},
		{"name":"민첩의 엘릭서", "grade":"희귀", "type":"성장소모품", "slot":"consumable", "kind":"elixir", "stat":"DEX",
		 "desc":"50레벨 이상 · DEX 영구 +1 · 엘릭서 제한 공유"},
		{"name":"체력의 엘릭서", "grade":"희귀", "type":"성장소모품", "slot":"consumable", "kind":"elixir", "stat":"CON",
		 "desc":"50레벨 이상 · CON 영구 +1 · 엘릭서 제한 공유"},
		{"name":"지식의 엘릭서", "grade":"희귀", "type":"성장소모품", "slot":"consumable", "kind":"elixir", "stat":"INT",
		 "desc":"50레벨 이상 · INT 영구 +1 · 엘릭서 제한 공유"},
		{"name":"지혜의 엘릭서", "grade":"희귀", "type":"성장소모품", "slot":"consumable", "kind":"elixir", "stat":"WIS",
		 "desc":"50레벨 이상 · WIS 영구 +1 · 엘릭서 제한 공유"},
		{"name":"매력의 엘릭서", "grade":"희귀", "type":"성장소모품", "slot":"consumable", "kind":"elixir", "stat":"CHA",
		 "desc":"50레벨 이상 · CHA 영구 +1 · 엘릭서 제한 공유"},
		{"name":"하프 엘릭서 (근거리)", "grade":"희귀", "type":"성장소모품", "slot":"consumable", "kind":"half_elixir", "bonus":"melee_damage",
		 "desc":"50레벨 이상 · 근거리 대미지 영구 +1 · 하프 엘릭서 최대 10회"},
		{"name":"하프 엘릭서 (원거리)", "grade":"희귀", "type":"성장소모품", "slot":"consumable", "kind":"half_elixir", "bonus":"ranged_damage",
		 "desc":"50레벨 이상 · 원거리 대미지 영구 +1 · 하프 엘릭서 최대 10회"},
		{"name":"하프 엘릭서 (마법)", "grade":"희귀", "type":"성장소모품", "slot":"consumable", "kind":"half_elixir", "bonus":"magic_damage",
		 "desc":"50레벨 이상 · 마법 대미지 영구 +1 · 하프 엘릭서 최대 10회"}
	]

static func definition(item_name: String) -> Dictionary:
	var name: String = normalize_name(item_name)
	for record: Dictionary in records():
		if str(record["name"]) == name:
			return record.duplicate(true)
	return {}

static func element_success_chance(current_level: int) -> float:
	return ELEMENT_CHANCES[current_level] if current_level >= 0 and current_level < ELEMENT_CHANCES.size() else 0.0
