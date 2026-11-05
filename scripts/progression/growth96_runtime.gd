extends RefCounted
## Manual source rewards and item-consuming registration use the whole-save writer.
const Source = preload("res://scripts/progression/growth96_source.gd")
const SAVE_KEY := "growth96"
var source = Source.new()
var world
var state: Dictionary = fresh()
var save_blocked := false
var problem := ""
var busy := false
var totals: Dictionary = {}

static func fresh() -> Dictionary:
	return {"schema":1,"revision":0,"claims":{},"point_versions":{},"registrations":{},"policy":"latest_available","effects_policy":"source_only"}

static func integer(value: Variant, minimum: int = 0, maximum: int = 1000000000) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(value) and value >= minimum and value <= maximum

static func id_ok(value: Variant) -> bool:
	return value is String and value.length() <= 20 and value.is_valid_int() and int(value) > 0

func configure(host: Node) -> void:
	world = host
	source.load_source()
	_install_records()

func _install_records() -> void:
	if not source.ready or world == null: return
	for id: String in source.items:
		var row: Dictionary = source.item_record(int(id))
		if row.is_empty(): continue
		for list: Array in [world.item_db,world.catalog_db.get("아이템",[])]:
			var found := false
			for existing: Dictionary in list:
				if str(existing.get("name","")) != str(row.name): continue
				if int(existing.get("growth96_item_id",-1)) != int(id):
					problem = "성장 보상 출처 키 충돌"; save_blocked = true; return
				found = true
			if not found: list.append(row.duplicate(true))
		if world.get("item_weight_index") is Dictionary: world.item_weight_index[row.name] = int(row.weight)

func install_source(path: String) -> Dictionary:
	if busy: return fail("처리 중입니다.")
	var candidate = Source.new()
	if not candidate.load_source(path): return fail(candidate.problem)
	var target: String = Source.INSTALLED
	if ProjectSettings.globalize_path(path) != ProjectSettings.globalize_path(target):
		if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK: return fail("정의 저장 폴더를 만들 수 없습니다.")
		var stage: String = target + ".staging"
		if DirAccess.copy_absolute(path,stage) != OK or FileAccess.get_sha256(stage) != Source.ZIP_SHA: return fail("원본 정의 복사 검증에 실패했습니다. 보유 상태는 유지됩니다.")
		if DirAccess.rename_absolute(stage,target) != OK: return fail("원본 정의 전환에 실패했습니다.")
	source = candidate
	_install_records()
	var error := validate(state)
	if not error.is_empty(): problem = error
	save_blocked = not problem.is_empty()
	_rebuild()
	if world != null: world._invalidate_equipment_static(); world._update_hud()
	if save_blocked: return fail("원본 정의는 설치했지만 저장 보호는 유지됩니다. 정상 저장을 다시 불러와 주세요. " + problem)
	return {"ok":true,"message":"원본 정의를 연결했습니다. 아이템이나 수령 기록은 자동 생성하지 않았습니다."}

func validate(value: Variant) -> String:
	if not value is Dictionary or value.get("schema") != 1: return "성장 보상 저장 버전 오류"
	if not integer(value.get("revision")): return "성장 보상 저장 revision 오류"
	for field: String in ["claims","point_versions","registrations"]:
		if not value.get(field) is Dictionary: return "성장 보상 저장 구조 오류: " + field
	if value.get("policy") not in ["latest_available","hold","cap0","cap1","cap2"] or value.get("effects_policy","source_only") not in ["source_only","twilight_estimates"]: return "성장 보상 정책 저장 오류"
	for id: Variant in value.claims:
		if not id_ok(id): return "성장 보상 수령 ID 오류"
		var receipt: Variant = value.claims[id]
		# Older receipt markers and unknown future IDs remain read-only history.
		if receipt is bool and receipt: continue
		if not receipt is Dictionary or not id_ok(receipt.get("point_id")) or not integer(receipt.get("version"),0,100) or not integer(receipt.get("amount"),1) or not integer(receipt.get("item_id"),1): return "성장 보상 수령 영수증 오류"
		if source.ready and source.rewards.has(id):
			var raw: Dictionary = source.rewards[id]
			if str(receipt.point_id) != str(raw.point_id) or int(receipt.version) != int(raw.version) or int(receipt.amount) != int(raw.Amount) or int(receipt.item_id) != int(raw.RewardClassID): return "성장 보상 원본 영수증 불일치"
	for id: Variant in value.point_versions:
		if not id_ok(id) or not integer(value.point_versions[id],0,100): return "지점별 수령 버전 오류"
		if source.ready:
			for rid: String in source.by_point.get(id,[]):
				if value.claims.has(rid) and int(source.rewards[rid].version) != int(value.point_versions[id]): return "지점별 수령 버전과 기존 영수증 불일치"
	for id: Variant in value.registrations:
		if not id_ok(id) or not value.registrations[id] is bool or not value.registrations[id]: return "증표 등록 저장 오류"
	return ""

func check_load(data: Dictionary) -> String:
	var error := validate(data.get(SAVE_KEY,fresh()))
	if not error.is_empty(): save_blocked = true; problem = error
	return error

func restore(value: Dictionary) -> void:
	state = value.duplicate(true)
	if not state.has("effects_policy"): state.effects_policy = "source_only"
	problem = ""; save_blocked = not source.ready and not state.registrations.is_empty()
	_rebuild()

func fail(message: String) -> Dictionary:
	return {"ok":false,"message":message,"revision":int(state.revision)}

func selected_rewards(point: String) -> Array:
	var available: Array = source.by_point.get(point,[])
	var selected := -1
	var cap: int = source.current_version
	if str(state.policy).begins_with("cap"):
		cap = mini(cap,int(str(state.policy).trim_prefix("cap")))
	for id: String in available:
		if int(source.rewards[id].version) <= cap: selected = maxi(selected,int(source.rewards[id].version))
	# An existing receipt locks the point's version across policy/data changes.
	if state.point_versions.has(point): selected = int(state.point_versions[point])
	for id: String in available:
		if state.claims.has(id):
			selected = int(source.rewards[id].version)
			break
	return available.filter(func(id: String) -> bool: return int(source.rewards[id].version) == selected)

func reached(point: Dictionary) -> bool:
	if int(world.level) != int(point.Level): return int(world.level) > int(point.Level)
	var need := int(world.exp_need)
	if need <= 0 or not integer(world.experience,0,9000000000000000): return false
	var percent := int(point.Percent)
	var threshold: int = (need / 100) * percent + ((need % 100) * percent + 99) / 100
	return int(world.experience) >= threshold

func quote(action: String, id: String) -> Dictionary:
	if world == null: return fail("월드 연결이 없습니다.")
	if save_blocked or not problem.is_empty(): return fail("저장 보호 중입니다. 정상 저장과 원본 정의를 다시 확인해 주세요.")
	if action == "policy" and id in ["latest_available","hold","cap0","cap1","cap2"]:
		return {"ok":true,"revision":int(state.revision),"message":"TWILIGHT 보상 버전 정책을 변경합니다. 원본의 현재 버전 이하에서 지점별 최고 버전을 선택하며, 새 96레벨 Version 0도 유지합니다. 기존 수령은 초기화하지 않습니다."}
	if action == "effects_policy" and id in ["source_only","twilight_estimates"]:
		return {"ok":true,"revision":int(state.revision),"message":"원문 수치·대상은 보존합니다. TWILIGHT 추정 실행은 비율 무시를 기존 문양 전투 정책으로, 대상14를 현재 기절·침묵·홀드·공포 적중의 5% 배율로 실행합니다. 원작 공식 복원이 아닙니다. 원문 확정만을 고르면 이 추정 부분은 적용하지 않습니다."}
	if not source.ready: return fail(source.problem)
	if not world.pending_map_save_record.is_empty(): return fail("지도 이전 저장을 먼저 정상 완료해 주세요.")
	if action == "claim":
		if not source.points.has(id): return fail("알 수 없는 성장 지점입니다.")
		if state.policy == "hold": return fail("TWILIGHT 보상 수령 정책을 보류한 상태입니다.")
		if not reached(source.points[id]): return fail("필요한 레벨과 경험치 비율에 도달하지 않았습니다.")
		var remaining: Array = []
		var received_versions: Dictionary = {}
		for rid: String in source.by_point.get(id,[]):
			if state.claims.has(rid): received_versions[str(source.rewards[rid].version)] = true
		if received_versions.size() > 1: return fail("기존 수령 이력에 여러 버전이 있습니다. 기록을 보존하고 이 지점의 추가 수령을 보류합니다.")
		for rid: String in selected_rewards(id):
			if not state.claims.has(rid): remaining.append(rid)
		if remaining.is_empty(): return fail("이미 수령한 성장 보상입니다.")
		var lines: PackedStringArray = []
		for rid: String in remaining:
			var row: Dictionary = source.rewards[rid]
			var item: Dictionary = source.items[Source.sid(row.RewardClassID)]
			if item.get("TestItem") is bool and item.TestItem:
				return fail("원본 시험 선언(TestItem)이 있는 미수령 아이템을 포함하므로 이 지점의 보상 전체를 지급하지 않습니다.")
			var key := Source.item_key(int(row.RewardClassID))
			if not integer(world.inventory.get(key,0),0,1000000000-int(row.Amount)): return fail("보상 인벤토리 수량이 유효하지 않습니다.")
			lines.append("%s ×%d" % [str(item.Name),int(row.Amount)])
		return {"ok":true,"revision":int(state.revision),"ids":remaining,"message":"달성 보상을 수령합니다. 비용은 없습니다. 카드 상자는 개봉하지 않은 아이템으로 보관합니다.\n" + "\n".join(lines)}
	if action == "register":
		if not source.cards.has(id): return fail("알 수 없는 등록 요건입니다.")
		if int(world.level) < 96: return fail("증표 등록에는 96레벨이 필요합니다.")
		if state.registrations.has(id): return fail("이미 등록한 요건입니다.")
		var token: Dictionary = source.items.get(str(Source.TOKEN),{})
		if token.get("TestItem") is bool and token.TestItem:
			return fail("원본 시험 선언(TestItem)이 있는 증표는 새 등록에 사용할 수 없습니다.")
		if world.has_method("_item_locked") and world._item_locked(Source.item_key(Source.TOKEN)): return fail("잠긴 증표는 등록에 사용할 수 없습니다.")
		var count: Variant = world.inventory.get(Source.item_key(Source.TOKEN),0)
		if not integer(count) or int(count) < 1: return fail("유일의 증표 I가 부족합니다. 등록마다 실제 아이템 1개를 소비합니다.")
		var collection: Dictionary = source.collections[str(source.cards[id].collection_id)]
		return {"ok":true,"revision":int(state.revision),"message":"%s에 유일의 증표 I 1개를 소비하여 영구 등록합니다. 컬렉션의 전체 요건이 끝나면 모든 효과 슬롯을 적용합니다. 추정 효과의 적용 여부는 전투 정책 설정을 따릅니다." % str(collection.name)}
	return fail("지원하지 않는 성장 보상 요청입니다.")

func execute(action: String, id: String, expected_revision: int) -> Dictionary:
	if busy: return fail("처리 중입니다.")
	if expected_revision != int(state.revision): return fail("확인 중 상태가 변경되었습니다. 다시 선택해 주세요.")
	var offer := quote(action,id)
	if not offer.ok: return offer
	busy = true
	var next: Dictionary = state.duplicate(true)
	var inventory: Dictionary = world.inventory.duplicate(true)
	if action == "policy": next.policy = id
	elif action == "effects_policy": next.effects_policy = id
	elif action == "claim":
		for rid: String in offer.ids:
			var row: Dictionary = source.rewards[rid]
			var key := Source.item_key(int(row.RewardClassID))
			inventory[key] = int(inventory.get(key,0)) + int(row.Amount)
			next.claims[rid] = {"point_id":id,"version":int(row.version),"item_id":int(row.RewardClassID),"amount":int(row.Amount)}
			next.point_versions[id] = int(row.version)
	elif action == "register":
		var key := Source.item_key(Source.TOKEN)
		inventory[key] = int(inventory[key]) - 1
		if int(inventory[key]) == 0: inventory.erase(key)
		next.registrations[id] = true
	next.revision += 1
	var error := validate(next)
	if not error.is_empty(): busy = false; return fail(error)
	var result: Error = world._save_game(true,{"growth96":next,"inventory":inventory})
	if result != OK: busy = false; return fail("저장 실패: 아이템·수령·등록·정책을 변경하지 않았습니다 (%d)." % result)
	state = next; world.inventory = inventory
	_rebuild(); world._invalidate_equipment_static(); world._update_hud()
	busy = false
	return {"ok":true,"message":"저장 후 적용했습니다.","revision":int(state.revision)}

func _rebuild() -> void:
	totals.clear()
	if not source.ready: return
	for row: Dictionary in source.collections.values():
		var complete := true
		for id: String in row.cards:
			if not state.registrations.has(id): complete = false
		if not complete: continue
		for effect: Dictionary in row.effects:
			var key: String = str({"MeleeHit":"melee_hit:flat","RangeHit":"ranged_hit:flat","MagicHit":"magic_hit:flat","PVPMeleeAdditionDamage":"pve_melee_damage:flat","PVPRangeAdditionDamage":"pve_ranged_damage:flat","PVPMagicAdditionDamage":"pve_magic_damage:flat","CriticalMeleeDamage":"melee_critical_damage:flat","CriticalRangeDamage":"ranged_critical_damage:flat","CriticalMagicDamage":"magic_critical_damage:flat"}.get(effect.name,""))
			if key.is_empty() and state.get("effects_policy","source_only") == "twilight_estimates":
				key = str({"ResistIgnoreDamageReductionPercent":"local_reduction_efficiency:percent","IgnoreMeleeDamageReductionPercent":"local_melee_ignore:percent","IgnoreRangeDamageReductionPercent":"local_ranged_ignore:percent","IgnoreMagicDamageReductionPercent":"local_magic_ignore:percent","IgnorePVPDamageReductionPercent":"local_ignore:percent","PVPPierceDamageReductionPercent":"local_ignore:percent","HitSpecialResistanceScale":"local_status_scale:percent"}.get(effect.name,""))
			if not key.is_empty(): totals[key] = float(totals.get(key,0)) + float(effect.value)

func bonus(key: String) -> float:
	return float(totals.get(key,0)) if world != null and int(world.level) >= 96 else 0.0

func status_accuracy(amount: int) -> int:
	return clampi(int(round(float(amount) * (1.0 + bonus("local_status_scale:percent") / 100.0))),0,100)

func snapshot() -> Dictionary:
	var out: Dictionary = {"ready":source.ready,"problem":problem if not problem.is_empty() else source.problem,"revision":int(state.revision),"level":int(world.level),"percent":float(world.experience)*100.0/maxi(1,int(world.exp_need)),"policy":state.policy,"effects_policy":state.get("effects_policy","source_only"),"points":[],"collections":[],"token_name":"유일의 증표 I","token_count":int(world.inventory.get(Source.item_key(Source.TOKEN),0))}
	var all_points: Array = source.points.values()
	all_points.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:return int(a.Level)*100+int(a.Percent)<int(b.Level)*100+int(b.Percent))
	for row: Dictionary in all_points:
		var id := Source.sid(row.ID); var rewards: Array = []; var claimed := true
		for rid: String in selected_rewards(id):
			var raw: Dictionary = source.rewards[rid]
			rewards.append({"id":rid,"name":str(source.items[Source.sid(raw.RewardClassID)].Name),"amount":int(raw.Amount),"version":int(raw.version)})
			if not state.claims.has(rid): claimed = false
		out.points.append({"id":id,"level":int(row.Level),"percent":int(row.Percent),"reached":reached(row),"claimed":claimed,"rewards":rewards})
	for row: Dictionary in source.collections.values():
		var count := 0; var cards: Array = []
		for id: String in row.cards:
			var registered: bool = state.registrations.has(id)
			if registered: count += 1
			cards.append({"id":id,"registered":registered})
		out.collections.append({"id":row.id,"name":row.name,"level":96,"registered":count,"required":row.cards.size(),"complete":count==row.cards.size(),"cards":cards,"effects":row.effects.duplicate(true)})
	return out
