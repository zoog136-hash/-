extends RefCounted
## TWILIGHT local execution policy; source-server transition/RNG is not asserted.
var host_ref: WeakRef
var world: Node:
	get: return host_ref.get_ref() if host_ref != null else null
var busy := false

func configure(host: Node) -> void:
	host_ref = weakref(host)
	if not world.totems.available(): return
	# Exact source IDs get their own inventory identities. Existing locally
	# authored blessing scrolls are never renamed or silently consumed.
	var aliases := {3581:"축복 부여 주문서 (토템 제작)",65291:"축복 부여 주문서 (각인·토템 제작)",301694:"토템 초기화 두루마리"}
	for id: int in aliases:
		if not world._catalog_item_from_source_id(str(id)).is_empty(): continue
		var source: Dictionary = world.totems.row("ItemClass",id)
		if source.is_empty(): continue
		var record := {"name":aliases[id],"sourceId":str(id),"source":"lineagem_523_totem","type":"재료","slot":"material","grade":"일반","totem_source_item":source,"desc":"원본 토템 제작·초기화 재료 · 기존 자체 제작 주문서와 별도"}
		world.catalog_db["아이템"].append(record)
		world.loot_catalog.by_name[record.name] = record
	world._index_catalog_item_sources()
	world._index_item_weights()

func fail(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason}

func item(id: int) -> Dictionary:
	return world._catalog_item_from_source_id(str(id))

func quote(action: String, id: int, material_id: int, expected_revision: int) -> Dictionary:
	var runtime = world.totems
	if not runtime.available() or runtime.save_blocked: return fail("토템 자료 또는 정상 저장이 필요합니다")
	if expected_revision != runtime.revision or busy: return fail("진행 상태가 바뀌었습니다 · 다시 확인하세요")
	if runtime.revision >= 2147483647: return fail("토템 거래 기록 한도")
	var costs: Dictionary = {}
	var gold := 0
	var output: Dictionary = {}
	var stage: Dictionary = {}
	if action in ["upgrade","reset"]:
		var def: Dictionary = runtime.row("Totem",id)
		var p: Dictionary = runtime.progress(id)
		if def.is_empty() or not bool(p.active): return fail("지역 몬스터 처치로 토템을 활성화하세요")
		if action == "upgrade":
			if int(p.level) >= 10: return fail("최고 레벨입니다")
			stage = runtime.level_preview(id,int(p.level)+1)
			var found := false
			for material: Dictionary in stage.materials:
				if int(material.ItemClassID) == material_id:
					if item(material_id).is_empty(): return fail("원본 강화석 식별 누락")
					costs[str(item(material_id).name)] = int(material.Amount)
					found = true
			if not found: return fail("선택한 강화석이 이 토템에 맞지 않습니다")
		else:
			if int(p.level) == 0: return fail("이미 Lv.0입니다")
			# Offline host exposes the source scroll payment route only. It has
			# no Gem wallet; display priority is never an additive diamond fee.
			var reset_item := 0
			var amount := 0
			for cost: Dictionary in runtime.rows("TotemResetCost"):
				for unit: Dictionary in runtime.rows("CurrencyUnitClass"):
					if int(unit.CurrencyID) == int(cost.CurrencyID) and int(unit.UnitID) == 4:
						reset_item = int(unit.ClassID)
						amount = int(cost.Amount)
			if reset_item != material_id or amount <= 0 or item(reset_item).is_empty(): return fail("초기화 두루마리 식별 오류")
			costs[str(item(reset_item).name)] = amount
	elif action == "craft":
		var found := false
		for recipe: Dictionary in runtime.recipes():
			if int(recipe.view.ItemCraftID) != id: continue
			if int(recipe.view.AlwaysSuccess) != 1 or recipe.outputs.size() != 1: return fail("확정 제작식이 아닙니다")
			var slots: Dictionary = {}
			for input: Dictionary in recipe.inputs:
				var key := int(input.SlotIndex)
				if not slots.has(key): slots[key] = []
				slots[key].append(input)
			for choices: Array in slots.values():
				var selected: Dictionary = {}
				for input: Dictionary in choices:
					if choices.size() == 1 or int(input.ItemClassID) == material_id: selected = input
				if selected.is_empty(): return fail("대체 재료 한 종류를 선택하세요")
				if int(selected.Enchant) != 0 or int(selected.get("ItemHoningEpithetID",0)) != 0: return fail("지원하지 않는 제작 재료 조건")
				if int(selected.ItemClassID) == 26: gold += int(selected.Amount)
				else:
					var record := item(int(selected.ItemClassID))
					if record.is_empty(): return fail("원본 제작 재료 식별 누락")
					costs[str(record.name)] = int(costs.get(str(record.name),0))+int(selected.Amount)
			var result: Dictionary = recipe.outputs[0]
			if int(result.Probability) != 1000000 or int(result.Amount) <= 0: return fail("확정 제작 결과가 아닙니다")
			output = {"record":item(int(result.ItemClassID)),"id":int(result.ItemClassID),"amount":int(result.Amount)}
			if output.record.is_empty(): return fail("원본 제작 결과 식별 누락")
			found = true
		if not found: return fail("현재 뷰가 없는 제작식입니다")
	else: return fail("알 수 없는 토템 요청")
	if world.gold < gold: return fail("아데나가 부족합니다")
	var weight: int = world._inventory_total_weight()
	for name: String in costs:
		if int(costs[name]) <= 0 or int(world.inventory.get(name,0)) < int(costs[name]): return fail("%s 부족 · 필요 %d" % [name,int(costs[name])])
		if world._item_locked(name): return fail("잠긴 재료는 사용할 수 없습니다")
		weight -= int(costs[name])*int(world.item_weight_index.get(name,3))
	if not output.is_empty():
		var name := str(output.record.name)
		var cap := int(runtime.row("ItemClass",int(output.id)).get("MaxStackAmount",0))
		if cap <= 0 or int(world.inventory.get(name,0))+int(output.amount) > cap: return fail("제작 결과 보유 한도 초과")
		weight += int(output.amount)*int(world.item_weight_index.get(name,3))
	if weight > world._carrying_capacity(): return fail("인벤토리 무게 한도 초과")
	return {"ok":true,"costs":costs,"gold":gold,"output":output,"stage":stage,"revision":runtime.revision}

func execute(action: String, id: int, material_id: int, expected_revision: int) -> Dictionary:
	var offer := quote(action,id,material_id,expected_revision)
	if not offer.ok: return offer
	busy = true
	var rng_state: int = world.rng.state
	var next: Dictionary = world.totems.export_state()
	var inventory: Dictionary = world.inventory.duplicate(true)
	for name: String in offer.costs:
		inventory[name] = int(inventory[name])-int(offer.costs[name])
		if inventory[name] == 0: inventory.erase(name)
	var success := true
	var message := "제작 완료"
	if action == "upgrade":
		var p: Dictionary = world.totems.progress(id)
		success = world.rng.randi_range(0,999999) < int(offer.stage.level.Probability)
		if success:
			var selected: Dictionary = {}
			for slot: String in offer.stage.option_pools:
				var pool: Array = offer.stage.option_pools[slot]
				var sum_weight := 0
				for candidate: Dictionary in pool: sum_weight += int(candidate.source.Probability)
				var roll: int = world.rng.randi_range(0,sum_weight-1)
				for candidate: Dictionary in pool:
					roll -= int(candidate.source.Probability)
					if roll < 0:
						selected[slot] = int(candidate.source.BonusID)
						break
			p.level = int(offer.stage.level.Level)
			p.selected[str(int(p.level))] = selected
		next.totems[str(id)] = p
		message = "강화 성공 · Lv.%d" % int(p.level) if success else "강화 실패 · 재료 소모 · 레벨·옵션 유지"
	elif action == "reset":
		var p: Dictionary = world.totems.progress(id)
		p.level = 0
		p.selected = {}
		next.totems[str(id)] = p
		message = "Lv.0 초기화 · 활성화·처치 진행도 유지 · 재료 환급 없음"
	else:
		var name := str(offer.output.record.name)
		inventory[name] = int(inventory.get(name,0))+int(offer.output.amount)
		message = "제작 완료 · %s × %d" % [name,int(offer.output.amount)]
	next.revision = int(next.revision)+1
	var error: Error = world._save_game(true,{"inventory":inventory,"gold":world.gold-int(offer.gold),"totem_state":next})
	if error != OK:
		world.rng.state = rng_state
		busy = false
		return fail("저장 실패 · 재료·성장·추첨 상태 보존")
	world.totems.accept_state(next)
	world.inventory.clear()
	world.inventory.merge(inventory,true)
	world.gold -= int(offer.gold)
	world._invalidate_equipment_static()
	world.totem_combat.reconcile()
	busy = false
	world._update_hud()
	world.hud.refresh_totems()
	world.hud.show_message(message)
	world.hud.append_log(message)
	return {"ok":true,"success":success,"message":message,"revision":world.totems.revision}
