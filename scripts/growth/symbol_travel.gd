extends RefCounted
## Selected locations are validated against the current field and layout.
static var POLICY: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/growth/symbol_travel_policy.json"))
const View = preload("res://scripts/growth/symbol_travel_view.gd")
const Maps = preload("res://scripts/maps/source_map_runtime.gd")
const Migration = preload("res://scripts/maps/source_map_save_migration.gd")
const Transit = preload("res://scripts/npc/teleport_policy.gd")
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

func layout_key(field: Variant = null) -> String:
	if field==null:field=world.field_map
	if field==null: return ""
	if field.get_meta("current523_source_field",false)==true:
		# Shared geometry is not shared logical Land identity. Retain the old
		# row schema, but never resolve an M bookmark with a legacy layout key.
		var c: RefCounted=field.coordinates
		var identity: Dictionary={"definition":field.definition.duplicate(true),"origin":[c.origin.x,c.origin.y],"dimensions":[c.dimensions.x,c.dimensions.y],"basis_x":[c.basis_x.x,c.basis_x.y],"basis_y":[c.basis_y.x,c.basis_y.y],"translation":[c.translation.x,c.translation.y]}
		return "m523:"+JSON.stringify(identity).sha256_text()
	return str(field.data.get("layout_revision",0))+":"+str(field.definition.get("source_sha256","")) if field is OriginalPlayableField else str(field.data.get("layout_revision",0))

func destination(mark: Dictionary) -> Dictionary:
	# Source keys can be used only in that exact live source context; no
	# cross-host load may reinterpret their canvas position as legacy data.
	if str(mark.layout_key).begins_with("m523:") and (world.field_map==null or world.field_map.get_meta("current523_source_field",false)!=true or mark.layout_key!=layout_key()):return runtime.fail("현재 원문 Land·지형·좌표 기준과 다른 기억 장소입니다")
	var point:=Vector2(float(mark.position[0]),float(mark.position[1]))
	if mark.map_id==world.active_map_id:
		if mark.layout_key!=layout_key():return runtime.fail("지도가 변경되었습니다 · 장소를 다시 기억하세요")
		if world.field_map.get_meta("current523_source_field",false)==true:
			if not world.has_method("current523_source_bookmark_destination_status"):return runtime.fail("원문 기억 이동 조건 소비자가 없습니다")
			var source_status: Dictionary=world.current523_source_bookmark_destination_status(point)
			if not source_status.get("ok",false):return runtime.fail(str(source_status.get("reason","원문 기억 이동 조건 미확인")))
		if not world.field_map.point_clear(point,4) or not world._is_walkable_world(point):return runtime.fail("기억한 위치로 이동할 수 없습니다")
		return {"ok":true,"destination":point,"gold":0,"cross":false}
	if not Maps.supports(str(mark.map_id)) or world.player.is_held() or not world.pending_map_save_record.is_empty():return runtime.fail("이 지역의 기억 장소 이동을 지금 사용할 수 없습니다")
	var entry: Dictionary=Transit.quote(str(mark.map_id),world.maps_by_id,world.active_map_id,world.level,world.gold)
	if not entry.ok:return runtime.fail(str(entry.reason))
	var field=Maps.load_field(str(mark.map_id))
	if field==null:return runtime.fail("목적지 원본 맵 팩을 검증할 수 없습니다")
	var valid: bool=mark.layout_key==layout_key(field) and field.point_clear(point,4) and field.walkable(point)
	var original: Dictionary={"source_map_id":int(field.definition.source_map_id),"grid_sha256":str(field.definition.source_sha256),"source":field.coordinates.source_components(point)}
	var revision: int=int(field.data.layout_revision)
	field.close()
	if not valid:return runtime.fail("목적지 지형·착지점이 변경되었습니다 · 장소를 다시 기억하세요")
	return {"ok":true,"destination":point,"gold":int(entry.price),"cross":true,"map_id":str(mark.map_id),"map_layout_revision":revision,"original_position":original}

func allowed() -> bool:
	if world.field_map==null or world.source_save_blocked or world.hp<=0 or world.player.motion.dead: return false
	if world.player.is_stunned() or world.player.is_feared(): return false
	if world.field_map is OriginalPlayableField and world.field_map.uses_original_gameplay_rules():
		return bool(world.field_map.definition.rules.get("teleportable",0))
	return true

func marks() -> Array:
	return runtime.state.get("teleport_bookmarks",[]).duplicate(true)

func open(source: Dictionary = {}) -> void:
	world.hud._open_window("teleport","기억 장소","에바 III · 기억한 지역·위치 선택 · 기존 입장 조건 적용")
	var view=View.new();world.hud.workspace.mount(view);view.configure(self,source)

func remember(label: String, revision: int) -> Dictionary:
	if not allowed() or not world._is_walkable_world(world.player.global_position): return runtime.fail("현재 위치를 기억할 수 없습니다")
	if world.field_map.get_meta("current523_source_field",false)==true:
		if not world.has_method("current523_source_bookmark_status"):return runtime.fail("원문 기억 제한 소비자가 없습니다")
		var restriction: Dictionary=world.current523_source_bookmark_status()
		if not restriction.get("ok",false) or restriction.get("allowed")!=true:return runtime.fail(str(restriction.get("reason","원문 기억 제한을 확인할 수 없습니다")))
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
	var landing: Dictionary=destination(mark)
	if not landing.ok:return landing
	var destination: Vector2=landing.destination
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
	if int(landing.gold)>0:payment.append("지역 입장 %d 아데나" % int(landing.gold))
	return {"ok":true,"message":"%s → %s · 소모: %s" % [name,str(mark.name),", ".join(payment) if not payment.is_empty() else "없음"],"costs":costs,"mana":mana,"health":health,"cooldown":maxf(0,cooldown),"global_cooldown":maxf(0,global_cooldown),"name":name,"destination":destination,"landing":landing}

func travel(index: int, source: Dictionary, origin: String, revision: int) -> Dictionary:
	var offer: Dictionary=quote(index,source,origin,revision)
	if not offer.ok: return offer
	if bool(offer.landing.cross):return _cross(offer,source)
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

func _cross(offer: Dictionary, source: Dictionary) -> Dictionary:
	runtime.busy=true
	var old_map: String=world.active_map_id
	var old_position: Vector2=world.player.global_position
	# Publish a complete pre-travel checkpoint before creating a separate candidate.
	# The old save and its SHA-proven backup never become the destination payload.
	if world._save_game(true,{"inventory":world.inventory,"growth":runtime.state})!=OK:
		runtime.busy=false;return runtime.fail("저장 실패 · 이동과 재료 소모를 취소했습니다")
	var old_path: String=world.save_path()
	var old_sha: String=FileAccess.get_sha256(old_path)
	var backup: Dictionary=Migration.backup(old_path,old_sha)
	if not backup.ok:runtime.busy=false;return runtime.fail(str(backup.error))
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(old_path))
	var landing: Dictionary=offer.landing
	data.map_id=landing.map_id;data.map_layout_revision=landing.map_layout_revision
	data.position=[offer.destination.x,offer.destination.y];data.original_position=landing.original_position
	data.source_map84_layouts=Maps.saved_layouts()
	data.gold=int(data.gold)-int(landing.gold);data.mp=int(data.mp)-int(offer.mana);data.hp=int(data.hp)-int(offer.health)
	for item: String in offer.costs:data.inventory[item]=int(data.inventory.get(item,0))-int(offer.costs[item])
	if source.kind!="scroll":
		data.skill_cooldowns[offer.name]=offer.cooldown;data.skill_global_cooldown=maxf(float(data.skill_global_cooldown),float(offer.global_cooldown))
	if source.kind=="original":
		for key: String in data.active_skill_buffs.keys():
			if bool(data.active_skill_buffs[key].get("stealth",false)):data.active_skill_buffs.erase(key)
	data.growth.revision=int(data.growth.revision)+1
	if not data.growth.has("economy"):data.growth.economy={}
	data.growth.economy["travel_gold_spent"]=int(data.growth.economy.get("travel_gold_spent",0))+int(landing.gold)
	for key: String in ["native_png_plan_sha256","native_png_review_sha256","oman_png_index_sha256"]:data.erase(key)
	var field=Maps.load_field(str(landing.map_id))
	var problem: String="목적지 원본 맵 팩을 다시 검증할 수 없습니다"
	if field!=null:
		problem=Maps.validate_save(data,field);field.close()
	if not problem.is_empty() or not runtime.validate(data.growth).is_empty():runtime.busy=false;return runtime.fail("이동 저장 검증 실패 · "+problem)
	var payload_sha: String=JSON.stringify(data,"",true,true).sha256_text()
	var target: String=world.base_save_path()+".source-map-symbol-"+payload_sha+".json"
	if FileAccess.file_exists(target) and FileAccess.get_sha256(target)!=payload_sha:
		runtime.busy=false;return runtime.fail("이동 저장 후보가 변경되었습니다 · 기존 파일 보존")
	var written: Error=OK if FileAccess.file_exists(target) else world.equipment_collections.write_save(target,data)
	if written!=OK or FileAccess.get_sha256(target)!=payload_sha or FileAccess.get_sha256(old_path)!=old_sha:
		runtime.busy=false;return runtime.fail("이동 저장 실패 · 기존 저장·재료 보존")
	world.migrated_save_path=target;world._load_game(true)
	var loaded: bool=world.active_map_id==str(landing.map_id) and world.player.global_position.is_equal_approx(offer.destination) and not world.source_save_blocked and FileAccess.get_sha256(old_path)==old_sha
	var activation: Error=Migration.activate(world.base_save_path(),{"target_path":target,"source_save_sha256":old_sha,"backup_path":backup.path}) if loaded else ERR_UNAVAILABLE
	if not loaded or activation!=OK:
		world.migrated_save_path=old_path;world.source_save_blocked=false;world._load_game(true)
		var restored: bool=world.active_map_id==old_map and world.player.global_position.is_equal_approx(old_position) and not world.source_save_blocked
		if not restored:world.source_save_blocked=true
		runtime.busy=false;return runtime.fail("이동 활성화 실패 · 이전 저장으로 복구했습니다" if restored else "이동 복원 보류 · 원본과 후보를 보존하고 저장을 차단했습니다")
	runtime.busy=false
	if source.kind=="original":
		var record: Dictionary=world.original_skills.catalog.record_for(str(source.id))
		world.original_skills.vfx.emit_skill(str(source.id),"impact",world.player.global_position)
		world.original_skills.trigger("on_skill",null,world.original_skills.catalog.resolve(record))
		world._update_hud()
	return {"ok":true,"message":"기억한 지역·위치로 이동했습니다 · 입장 %d 아데나" % int(landing.gold)}
