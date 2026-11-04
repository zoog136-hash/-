extends RefCounted
## Selected locations are validated against the current field and layout.
static var POLICY: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/growth/symbol_travel_policy.json"))
const View = preload("res://scripts/growth/symbol_travel_view.gd")
var _runtime: WeakRef
var runtime:
	get: return _runtime.get_ref()
var world:
	get: return runtime.world

func configure(owner) -> void:
	_runtime=weakref(owner)

static func validate(value: Variant) -> String:
	if not value is Array or value.size()>int(POLICY.bookmark_limit): return "기억 장소 저장 목록 오류"
	for row: Variant in value:
		if not row is Dictionary: return "기억 장소 저장 형식 오류"
		if not row.get("map_id") is String or row.map_id.is_empty() or row.map_id.length()>100: return "기억 장소 지역 오류"
		if not row.get("name") is String or row.name.is_empty() or row.name.length()>int(POLICY.name_limit): return "기억 장소 이름 오류"
		if not row.get("layout_key") is String or row.layout_key.length()>200: return "기억 장소 지도 정보 오류"
		var p: Variant=row.get("position")
		if not p is Array or p.size()!=2: return "기억 장소 좌표 오류"
		for axis: Variant in p:
			if not (axis is int or axis is float) or not is_finite(float(axis)) or absf(float(axis))>100000000: return "기억 장소 좌표 오류"
	return ""

func enabled() -> bool:
	return not runtime.development and runtime.bonus("teleport_control:flag")>0

func layout_key() -> String:
	if world.field_map==null: return ""
	return str(world.field_map.data.get("layout_revision",0))+":"+str(world.field_map.definition.get("source_sha256","")) if world.field_map is OriginalPlayableField else str(world.field_map.data.get("layout_revision",0))

func allowed() -> bool:
	if world.field_map==null or world.source_save_blocked or world.hp<=0 or world.player.motion.dead: return false
	if world.player.is_stunned() or world.player.is_feared(): return false
	if world.field_map is OriginalPlayableField and world.field_map.uses_original_gameplay_rules():
		return bool(world.field_map.definition.rules.get("teleportable",0))
	return true

func marks() -> Array:
	return runtime.state.get("teleport_bookmarks",[]).duplicate(true)

func open(source: Dictionary = {}) -> void:
	world.hud._open_window("teleport","기억 장소","에바 III · 현재 맵 기억 장소 선택")
	var view=View.new();world.hud.workspace.mount(view);view.configure(self,source)

func remember(label: String, revision: int) -> Dictionary:
	if not allowed() or not world._is_walkable_world(world.player.global_position): return runtime.fail("현재 위치를 기억할 수 없습니다")
	var values: Array=marks()
	if values.size()>=int(POLICY.bookmark_limit): return runtime.fail("기억 장소가 가득 찼습니다")
	label=label.strip_edges().left(int(POLICY.name_limit))
	if label.is_empty(): label="기억 장소 "+str(values.size()+1)
	values.append({"name":label,"map_id":world.active_map_id,"layout_key":layout_key(),"position":[world.player.global_position.x,world.player.global_position.y]})
	return _commit_marks(values,revision,"현재 위치를 기억했습니다")

func forget(index: int, revision: int) -> Dictionary:
	var values: Array=marks()
	if index<0 or index>=values.size(): return runtime.fail("기억 장소를 다시 선택하세요")
	values.remove_at(index)
	return _commit_marks(values,revision,"기억 장소를 삭제했습니다")

func _commit_marks(values: Array, revision: int, message: String) -> Dictionary:
	if runtime.busy or revision!=int(runtime.state.revision): return runtime.fail("오래된 요청 · 다시 확인하세요")
	var next: Dictionary=runtime.state.duplicate(true);next.teleport_bookmarks=values;next.revision+=1
	if not runtime.validate(next).is_empty(): return runtime.fail("기억 장소 검증 실패")
	runtime.busy=true
	var error: Error=world._save_game(true,{"growth":next})
	runtime.busy=false
	if error!=OK: return runtime.fail("저장 실패 · 기존 기억 장소를 보존했습니다")
	runtime.state=next
	return {"ok":true,"message":message}

func quote(index: int, source: Dictionary, origin: String, revision: int) -> Dictionary:
	if runtime.busy or revision!=int(runtime.state.revision): return runtime.fail("오래된 요청 · 다시 확인하세요")
	if not enabled(): return runtime.fail("에바 절대 옵션 III이 필요합니다")
	if origin!=world.active_map_id or not allowed(): return runtime.fail("현재 상태·지역에서는 순간이동할 수 없습니다")
	var values: Array=marks()
	if index<0 or index>=values.size(): return runtime.fail("기억 장소를 선택하세요")
	var mark: Dictionary=values[index]
	if mark.map_id!=world.active_map_id: return runtime.fail("현재 맵의 기억 장소만 이동할 수 있습니다")
	if mark.layout_key!=layout_key(): return runtime.fail("지도가 변경되었습니다 · 장소를 다시 기억하세요")
	var destination:=Vector2(float(mark.position[0]),float(mark.position[1]))
	if not world.field_map.point_clear(destination,4) or not world._is_walkable_world(destination): return runtime.fail("기억한 위치로 이동할 수 없습니다")
	var costs: Dictionary={};var mana: int=0;var health: int=0;var cooldown: float=0;var global_cooldown: float=0;var name: String=""
	match str(source.get("kind","")):
		"scroll":
			name=str(source.get("name",""))
			if str(world.CONSUMABLE_RULES.definition(name).get("kind",""))!="teleport": return runtime.fail("순간이동 주문서를 선택하세요")
			costs[name]=1
		"original":
			var record: Dictionary=world.original_skills.catalog.record_for(str(source.get("id","")))
			if record.is_empty() or str(record.get("mode",""))!="teleport" or not world.original_skills.ready(record): return runtime.fail("텔레포트 마법을 지금 사용할 수 없습니다")
			var skill: Dictionary=world.original_skills.catalog.resolve(record)
			if bool(skill.get("local_design",false)) and str(skill.get("local_kind",""))!="generic": return runtime.fail("이 이동 기술은 기억 장소를 사용하지 않습니다")
			name=str(skill.name);mana=int(skill.get("mp",0));health=int(skill.get("hp",0));costs=skill.get("items",{}).duplicate(true)
			cooldown=float(skill.get("cooldown",0))*world._skill_cooldown_factor()*clampf(1-world.original_skills.equipment_modifier(skill,"cooldown_percent")/100.0,.1,1)
			global_cooldown=float(skill.get("global_cooldown",.3))
		"job":
			var skill: Dictionary=world._skill_record(str(source.get("name","")))
			if str(skill.get("origin","")) in ["LINEAGEM_20250617","LINEAGEM_CURRENT_LOCAL_20261029","OFFICIAL_REFERENCE_20261029"]: return runtime.fail("현재 스킬의 원본 소비 경로를 사용하세요")
			if skill.is_empty() or world.SKILL_RULES.effect_kind(skill)!="teleport" or not world._skill_ready(skill,false): return runtime.fail("텔레포트 마법을 지금 사용할 수 없습니다")
			if bool(skill.get("safe_zone_only",false)) and not world._teleport_landing_clear(destination): return runtime.fail("안전하게 이동할 수 없는 장소입니다")
			name=str(skill.name);mana=maxi(0,int(skill.get("mp",0)))
			var ammo: int=maxi(0,int(skill.get("ammo_per_hit",0)))*maxi(1,int(skill.get("hits",1)))
			if ammo>0:costs["화살"]=ammo
			cooldown=world.SKILL_RULES.cooldown_seconds(skill)*world._skill_cooldown_factor();global_cooldown=world.SKILL_RULES.global_cooldown_seconds(skill)
		_: return runtime.fail("주문서나 텔레포트 마법을 먼저 사용하세요")
	for item: String in costs:
		if int(world.inventory.get(item,0))<int(costs[item]): return runtime.fail(item+" 부족")
	if world.mp<mana or world.hp<=health: return runtime.fail("HP 또는 MP가 부족합니다")
	var payment: Array[String]=[]
	for item: String in costs:payment.append("%s %d개" % [item,int(costs[item])])
	if mana>0:payment.append("MP %d" % mana)
	if health>0:payment.append("HP %d" % health)
	return {"ok":true,"message":"%s → %s · 소모: %s" % [name,str(mark.name),", ".join(payment) if not payment.is_empty() else "없음"],"costs":costs,"mana":mana,"health":health,"cooldown":maxf(0,cooldown),"global_cooldown":maxf(0,global_cooldown),"name":name,"destination":destination}

func travel(index: int, source: Dictionary, origin: String, revision: int) -> Dictionary:
	var offer: Dictionary=quote(index,source,origin,revision)
	if not offer.ok: return offer
	runtime.busy=true
	var inventory: Dictionary=world.inventory.duplicate(true)
	for item: String in offer.costs: inventory[item]=int(inventory.get(item,0))-int(offer.costs[item])
	var next: Dictionary=runtime.state.duplicate(true);next.revision+=1
	var old_position: Vector2=world.player.global_position;var old_mp: int=world.mp;var old_hp: int=world.hp
	var old_cooldowns: Dictionary=world.skill_cooldowns;var old_global: float=world.skill_global_cooldown
	var old_buffs: Dictionary=world.active_skill_buffs
	# Stage all save fields synchronously, then restore live state even on failure.
	world.player.global_position=offer.destination;world.mp-=int(offer.mana);world.hp-=int(offer.health)
	world.skill_cooldowns=old_cooldowns.duplicate(true)
	world.active_skill_buffs=old_buffs.duplicate(true)
	if source.kind=="original":
		for key: String in world.active_skill_buffs.keys():
			if bool(world.active_skill_buffs[key].get("stealth",false)): world.active_skill_buffs.erase(key)
	if source.kind!="scroll": world.skill_cooldowns[offer.name]=offer.cooldown;world.skill_global_cooldown=maxf(old_global,offer.global_cooldown)
	var staged_cooldowns: Dictionary=world.skill_cooldowns;var staged_global: float=world.skill_global_cooldown
	var staged_buffs: Dictionary=world.active_skill_buffs
	var error: Error=world._save_game(true,{"inventory":inventory,"growth":next})
	world.player.global_position=old_position;world.mp=old_mp;world.hp=old_hp;world.skill_cooldowns=old_cooldowns;world.skill_global_cooldown=old_global
	world.active_skill_buffs=old_buffs
	runtime.busy=false
	if error!=OK: return runtime.fail("저장 실패 · 이동과 재료·MP 소모를 취소했습니다")
	world.inventory=inventory;runtime.state=next;world.mp-=int(offer.mana);world.hp-=int(offer.health)
	world.skill_cooldowns=staged_cooldowns;world.skill_global_cooldown=staged_global
	world.active_skill_buffs=staged_buffs
	# Cancel pending hits without destroying shields, summons or skill buffs.
	world.combat_generation+=1;world.pending_attack.clear();world.player.cancel_attack()
	if is_instance_valid(world.combat_flights):world.combat_flights.clear()
	world.consumable_service._teleport_player(offer.destination)
	if source.kind=="original":
		var record: Dictionary=world.original_skills.catalog.record_for(str(source.id))
		world.original_skills.vfx.emit_skill(str(source.id),"impact",world.player.global_position)
		world.original_skills.trigger("on_skill",null,world.original_skills.catalog.resolve(record))
		world.player.pulse_attack()
	world._refresh_skill_stealth_visual();world._update_hud()
	return {"ok":true,"message":"기억 장소로 순간이동했습니다 · "+str(marks()[index].name)}
