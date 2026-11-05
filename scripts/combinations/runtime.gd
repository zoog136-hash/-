extends RefCounted
const Catalog=preload("res://scripts/combinations/source_catalog.gd")
const Source=preload("res://scripts/resources/current523_definition_rows.gd")
const Requirements=preload("res://scripts/combinations/requirements.gd")
const Effects=preload("res://scripts/combinations/effects.gd")
const Policy=preload("res://scripts/combinations/policy.gd")
const Writer=preload("res://scripts/skills/save_writer.gd")
const SAVE_KEY: String="combination523"
const PRIVATE_PATH: String="user://combination523/catalog.json"
var world: Node
var policy: Dictionary=Policy.defaults()
var progress: Dictionary=fresh_state()
var save_blocked: bool=false
var problem: String=""
var catalog: Dictionary={}
var rows: Dictionary={}
var requirements=Requirements.new()
var _dirty: bool=true
var _busy: bool=false
var _active: Dictionary={}
var _record: Dictionary={}
var _context_hash: int=0
var _regen_elapsed: float=0
var rebuilds: int=0
static func fresh_state() -> Dictionary:return {"version":1,"selected_id":0,"revision":0,"last_operation_id":""}
static func fail(code: String,message: String) -> Dictionary:return {"ok":false,"code":code,"error":message}
static func validate(value: Variant) -> String:
	if not value is Dictionary or value.get("version",0)!=1:return "조합 저장 버전 또는 형식 오류"
	for key: String in ["selected_id","revision"]:
		if not Requirements.integer(value.get(key)) or int(value[key])<0 or int(value[key])>9007199254740000:return "조합 저장 정수 필드 오류"
	if not value.get("last_operation_id","") is String:return "조합 저장 거래 ID 오류"
	return ""
func configure(host: Node) -> void:
	world=host
	if FileAccess.file_exists(PRIVATE_PATH):
		var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(PRIVATE_PATH))
		if not value is Dictionary or not accept_catalog(value):problem="조합 원본 캐시 손상 · 다시 설치하세요"
	else:
		# UNVERIFIED: reuse the existing parser only when no private cache
		# exists. A damaged cache or invalid explicit source is not bypassed.
		var path: String=Source.archive_path()
		if path.is_empty():
			problem=Source.problem() if not Source.problem().is_empty() else "최신523 조합 원본 자료를 설치하세요"
			return
		var imported: Dictionary=Catalog.from_zip(path)
		if not imported.get("ok",false):
			problem=str(imported.get("error","조합 원본 자료를 읽을 수 없습니다"))
			return
		# accept_catalog publishes definitions and invalidates the existing
		# read cache only. No selection, reconcile, migration, or save here.
		if not accept_catalog(imported.catalog):problem="조합 전체 원본 계약을 읽을 수 없습니다 · 기존 상태 보존"
func accept_catalog(value: Dictionary) -> bool:
	if value.get("schema",0)!=1 or value.get("source_version",0)!=523 or not value.get("combinations") is Array or value.combinations.size()!=62 or not value.get("tables") is Dictionary:return false
	for key: String in Catalog.COUNTS:
		if not value.tables.get(key) is Array or value.tables[key].size()!=int(Catalog.COUNTS[key]):return false
	var checked: Dictionary={};var requirements_count: int=0;var effects_count: int=0
	for row: Variant in value.combinations:
		if not row is Dictionary or not Requirements.integer(row.get("id")) or int(row.id)<=0 or checked.has(int(row.id)) or not row.get("slots") is Array or not row.get("effects") is Array or not row.get("source") is Dictionary or not row.get("name") is String:return false
		for slot: Variant in row.slots:
			if not slot is Dictionary or not Requirements.integer(slot.get("index")) or not slot.get("candidates") is Array or slot.candidates.is_empty():return false
			for candidate: Variant in slot.candidates:
				if not candidate is Dictionary or int(candidate.get("kind",0)) not in [14,4,24] or not Requirements.integer(candidate.get("class_id")) or not Requirements.integer(candidate.get("min_enchant")) or int(candidate.min_enchant)<0 or not candidate.get("target") is Dictionary or not candidate.get("source") is Dictionary or not candidate.get("name") is String:return false
				requirements_count+=1
		for effect: Variant in row.effects:
			if not effect is Dictionary or not effect.get("type") is String or not effect.get("unit") is String or not effect.get("label") is String or not Requirements.integer(effect.get("target")) or not (effect.get("value") is int or effect.get("value") is float) or not is_finite(float(effect.value)) or not Effects.supported(effect):return false
			effects_count+=1
		checked[int(row.id)]=row
	if requirements_count!=272 or effects_count!=91:return false
	catalog=value;rows=checked;requirements.configure(catalog,world.catalog_db,policy);problem="";invalidate();return true
func install_source(path: String) -> Dictionary:
	if _busy:return fail("busy","이전 조합 작업 처리 중")
	_busy=true
	var imported: Dictionary=Catalog.from_zip(path)
	if not imported.ok:_busy=false;return imported
	# Validate with an isolated adapter before replacing an existing private cache.
	var probe=get_script().new();probe.world=world;probe.policy=policy.duplicate(true)
	if not probe.accept_catalog(imported.catalog):_busy=false;return fail("catalog","조합 전체 원본 계약 검증 실패")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PRIVATE_PATH).get_base_dir())
	var error: Error=Writer.write(PRIVATE_PATH,imported.catalog)
	if error!=OK:_busy=false;return fail("pack_save_failed","원본 캐시 저장 실패 · 기존 자료 보존")
	accept_catalog(imported.catalog);_busy=false;_publish_change();return {"ok":true}
func export_state() -> Dictionary:return progress.duplicate(true)
func check_load(data: Dictionary) -> String:return validate(data.get(SAVE_KEY,fresh_state()))
func accept_load(data: Dictionary) -> bool:
	var error: String=check_load(data)
	if not error.is_empty():save_blocked=true;return false
	progress=data.get(SAVE_KEY,fresh_state()).duplicate(true)
	progress.version=1;progress.selected_id=int(progress.selected_id);progress.revision=int(progress.revision)
	save_blocked=false;invalidate();return true
func context() -> Dictionary:
	var runtime: Variant=world.get("card_collections")
	return runtime.source_server_context() if runtime!=null and runtime.has_method("source_server_context") else {}
func invalidate() -> void:_dirty=true
func evaluate(id: int) -> Dictionary:
	if save_blocked:return fail("save_blocked","조합 저장 보호 중")
	if not problem.is_empty() or not rows.has(id):return fail("source_missing",problem if not problem.is_empty() else "조합 원본 정의 없음")
	var view: Dictionary=requirements.evaluate(rows[id],world.card_draw_fusion.owned,world.inventory,world.item_instances,context())
	view.code="eligible" if view.ok else "requirements";view.error=view.reason;return view
func reconcile() -> void:
	if world==null:return
	var current_context: int=hash(context())
	if current_context!=_context_hash:_dirty=true;_context_hash=current_context
	if not _dirty:return
	_dirty=false;rebuilds+=1
	var before: int=hash(_record);_active={};_record={}
	var id: int=int(progress.selected_id)
	if id>0 and rows.has(id) and evaluate(id).ok:_active=rows[id];_record=Effects.record(_active.effects)
	if hash(_record)!=before:
		world.set("equipment_records_dirty",true);world.set("equipment_effects_dirty",true);_regen_elapsed=0
func stat_record() -> Dictionary:reconcile();return _record
func amount(kind: String,target: int=0) -> float:
	reconcile();return Effects.amount(_active.get("effects",[]),kind,target)
func charge_step_duration(seconds: float) -> float:
	reconcile();return Effects.charge_step(seconds,_active.get("effects",[]))
func catalog_bonus(key: String) -> int:
	reconcile()
	return int(_record.get(key,0)) if key in ["strFlat","dexFlat","conFlat","intFlat","dthFlat","sp","weightBonus","pve_damage_reduction"] else 0
func snapshot() -> Array:
	reconcile();var out: Array=[]
	for id: int in rows:
		var status: Dictionary=evaluate(id)
		out.append({"id":id,"name":rows[id].name,"slots":rows[id].slots,"effects":rows[id].effects,"status":status,"selected":id==int(progress.selected_id),"active":id==int(_active.get("id",0))})
	out.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return bool(a.status.ok) if a.status.ok!=b.status.ok else int(a.id)<int(b.id))
	return out
func quote(id: int) -> Dictionary:
	var fee: Variant=policy.get("selection_fee_adena",0)
	if not Requirements.integer(fee) or int(fee)<0:return fail("policy","조합 수수료 설정 오류")
	var status: Dictionary={"ok":true} if id==0 else evaluate(id)
	if not status.ok:return status
	return {"ok":true,"id":id,"fee":int(fee),"revision":int(progress.revision),"signature":hash([id,int(progress.revision),int(fee),status]),"policy":"twilight_selection_no_material_debit"}
func request_selection(id: int,revision: int,operation_id: String,expected_signature: Variant=null) -> Dictionary:
	if _busy:return fail("busy","이전 조합 거래 처리 중")
	if save_blocked:return fail("save_blocked","조합 저장 보호 중")
	if operation_id.is_empty() or operation_id==str(progress.last_operation_id):return fail("duplicate_operation","누락 또는 중복 조합 거래")
	if revision!=int(progress.revision):return fail("stale_revision","조합 상태가 변경됐습니다")
	if id==int(progress.selected_id):return fail("unchanged","이미 선택한 조합입니다")
	var prepared: Dictionary=quote(id)
	if not prepared.ok:return prepared
	if expected_signature!=null and expected_signature!=prepared.signature:return fail("stale_quote","보유 조건 또는 비용이 변경됐습니다")
	if int(world.gold)<int(prepared.fee):return fail("insufficient_gold","조합 선택 아데나 부족")
	_busy=true
	var next: Dictionary=export_state();next.selected_id=id;next.revision=int(next.revision)+1;next.last_operation_id=operation_id
	var remaining: int=int(world.gold)-int(prepared.fee)
	var error: Error=world._save_game(true,{SAVE_KEY:next,"gold":remaining})
	if error!=OK:_busy=false;return fail("save_failed","저장 실패 · 기존 조합·아데나·장비·카드 보존")
	progress=next;world.gold=remaining;_busy=false;invalidate();_publish_change()
	return {"ok":true,"selected_id":id,"consumed_gold":int(prepared.fee),"consumed_materials":0}
func _publish_change() -> void:
	world.set("equipment_records_dirty",true);world.set("equipment_effects_dirty",true)
	if world.has_method("_update_hud"):world.call_deferred("_update_hud")
func tick(delta: float) -> void:
	var gain: int=int(amount("RegenMP"))
	if gain<=0 or int(world.get("hp"))<=0:_regen_elapsed=0;return
	var interval: float=maxf(1.0,float(policy.get("regen_interval_seconds",30)))
	_regen_elapsed+=maxf(0,delta)
	if _regen_elapsed>=interval:
		var cycles: int=floori(_regen_elapsed/interval);_regen_elapsed=fmod(_regen_elapsed,interval)
		world.set("mp",mini(int(world._effective_max_mp()),int(world.get("mp"))+gain*cycles))
