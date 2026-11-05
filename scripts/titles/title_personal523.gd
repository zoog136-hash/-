extends RefCounted
## Source thresholds/colors/word lists; explicit host Unicode and match policy.
var runtime_ref: WeakRef
var runtime:
	get: return runtime_ref.get_ref() if runtime_ref!=null else null
	set(value): runtime_ref=weakref(value)
var name_cache: Dictionary={}

static func fresh() -> Dictionary:
	return {"names":[],"active":-1,"color_rule":0,"changed_at_ms":0}

func data(value: Dictionary) -> Dictionary:
	return value.get("personal",fresh())

func owned(value: Dictionary, id: int) -> bool:
	for stage: Variant in value.get("achieved",[]):
		if int(stage)==id: return true
	return false

func unlocked(value: Dictionary) -> bool:
	return runtime.source.problem.is_empty() and owned(value,int(runtime.source.personal.get("title_limit",278)))

func colors(value: Dictionary) -> Array:
	var result: Array=[]
	for color: Dictionary in runtime.source.personal.get("colors",[]):
		if owned(value,int(color.stage)): result.append(color)
	return result

func name_error(text: String) -> String:
	if name_cache.has(text): return str(name_cache[text])
	var result: String=""
	if text.is_empty() or text!=text.strip_edges(): result="앞뒤 공백 없이 호칭을 입력해 주세요."
	var ascii_only:=true
	for i: int in text.length():
		var code:=text.unicode_at(i)
		if not (code>=48 and code<=57 or code>=65 and code<=90 or code>=97 and code<=122): ascii_only=false
		if code<32 or code>=127 and code<=159 or code>=0x200b and code<=0x200f or code>=0x202a and code<=0x202e or code>=0x2060 and code<=0x206f or code==0xfeff:
			result="제어·비표시 문자는 사용할 수 없습니다."
	if ascii_only:
		if text.length()<2 or text.length()>16: result="영문·숫자는 2~16자로 입력해 주세요."
	elif text.length()<1 or text.length()>int(runtime.policy.get("personal_mixed_max_codepoints",8)): result="한글·특수·혼합 문자는 자체 정책 범위로 입력해 주세요."
	if result.is_empty():
		var lowered:=text.to_lower()
		# TextMatchingTypeID is preserved in source metadata. Its enum/execution
		# was not supplied: conservative case-insensitive substring is host policy.
		for word: Dictionary in runtime.source.personal.get("banned_words",[]):
			var term: String=word.text
			if not term.is_empty() and term.length()<=lowered.length() and lowered.contains(term):
				result="원본 금칙어 목록과 자체 부분일치 정책으로 사용할 수 없는 호칭입니다."
				break
	if name_cache.size()>=512: name_cache.clear()
	name_cache[text]=result
	return result

func validate(value: Dictionary) -> String:
	var p: Variant=value.get("personal",fresh())
	if not p is Dictionary or not p.get("names") is Array: return "개인 호칭 저장 구조 오류"
	if not runtime.integer(p.get("active"),-1,4) or not runtime.integer(p.get("color_rule"),0,1000000) or not runtime.integer(p.get("changed_at_ms"),0,9007199254740991): return "개인 호칭 저장 숫자 오류"
	if p.names.size()>int(runtime.source.personal.get("max_names",5)): return "개인 호칭 보관 수 초과"
	if (not p.names.is_empty() or int(p.active)>=0 or int(p.changed_at_ms)>0) and not unlocked(value): return "개인 호칭 남작I 조건·원본 확인 실패"
	var seen: Dictionary={}
	for text: Variant in p.names:
		if not text is String: return "개인 호칭 이름 형식 오류"
		if not name_error(text).is_empty() or seen.has(text.to_lower()): return "개인 호칭 이름·중복 오류"
		seen[text.to_lower()]=true
	if int(p.changed_at_ms)>(int(value.last_clock)+1)*1000: return "개인 호칭 시각 불일치"
	if int(p.active)==-1:
		if int(p.color_rule)!=0: return "개인 호칭 비활성 색상 오류"
	else:
		if int(p.active)>=p.names.size(): return "개인 호칭 활성 슬롯 오류"
		var available:=false
		for color: Dictionary in colors(value):
			if int(color.id)==int(p.color_rule): available=true
		if not available: return "개인 호칭 색상 해금 조건 오류"
	return ""

func now_ms() -> int:
	return runtime.now()*1000 if runtime.clock.is_valid() else int(Time.get_unix_time_from_system()*1000.0)

func gate(revision: int, activation: bool=false) -> String:
	if runtime.busy or runtime.blocked or not runtime.source.problem.is_empty(): return "개인 호칭 원본·저장 보호 중"
	if revision!=int(runtime.state.revision): return "작위 정보가 변경되었습니다. 다시 확인해 주세요."
	var error: String=runtime.validate(runtime.state)
	if not error.is_empty(): return error
	if not unlocked(runtime.state): return "개인 호칭은 남작I 달성 후 사용할 수 있습니다."
	var p:=data(runtime.state)
	if runtime.now()<int(runtime.state.last_clock) or now_ms()<int(p.changed_at_ms): return "시계 역행 중에는 개인 호칭을 변경할 수 없습니다."
	if activation and now_ms()<int(p.changed_at_ms)+int(runtime.source.personal.activation_delay_raw)*1000: return "호칭 변경 대기 중입니다. 2초 이후 다시 시도해 주세요."
	return ""

func edit(index: int, text: String, revision: int) -> Dictionary:
	var p:=data(runtime.state)
	var error:=gate(revision,index==int(p.active))
	if error.is_empty(): error=name_error(text)
	if not error.is_empty(): return {"ok":false,"message":error}
	if index<0 or index>p.names.size() or index>=int(runtime.source.personal.max_names): return {"ok":false,"message":"개인 호칭 보관 슬롯 오류"}
	for i: int in p.names.size():
		if i!=index and str(p.names[i]).to_lower()==text.to_lower(): return {"ok":false,"message":"이미 보관한 개인 호칭입니다."}
	var candidate: Dictionary=runtime.state.duplicate(true)
	candidate.personal=p.duplicate(true)
	if index==p.names.size(): candidate.personal.names.append(text)
	else: candidate.personal.names[index]=text
	if index==int(p.active): candidate.personal.changed_at_ms=now_ms()
	return runtime.commit(candidate)

func activate(index: int, color_rule: int, revision: int) -> Dictionary:
	var error:=gate(revision,true)
	if not error.is_empty(): return {"ok":false,"message":error}
	var p:=data(runtime.state)
	if index<0 or index>=p.names.size(): return {"ok":false,"message":"보관한 개인 호칭을 선택해 주세요."}
	var available:=false
	for color: Dictionary in colors(runtime.state):
		if int(color.id)==color_rule: available=true
	if not available: return {"ok":false,"message":"아직 해금되지 않은 호칭 색상입니다."}
	var candidate: Dictionary=runtime.state.duplicate(true)
	candidate.personal=p.duplicate(true); candidate.personal.active=index; candidate.personal.color_rule=color_rule; candidate.personal.changed_at_ms=now_ms(); candidate.display=true
	return runtime.commit(candidate)

func remove(index: int, revision: int) -> Dictionary:
	var p:=data(runtime.state)
	var error:=gate(revision,index==int(p.active))
	if not error.is_empty(): return {"ok":false,"message":error}
	if index<0 or index>=p.names.size(): return {"ok":false,"message":"삭제할 보관 호칭을 선택해 주세요."}
	var candidate: Dictionary=runtime.state.duplicate(true)
	candidate.personal=p.duplicate(true); candidate.personal.names.remove_at(index)
	if int(p.active)==index: candidate.personal.active=-1; candidate.personal.color_rule=0; candidate.personal.changed_at_ms=now_ms()
	elif int(p.active)>index: candidate.personal.active=int(p.active)-1
	return runtime.commit(candidate)

func use_highest(revision: int) -> Dictionary:
	var error:=gate(revision,true)
	if not error.is_empty(): return {"ok":false,"message":error}
	var candidate: Dictionary=runtime.state.duplicate(true)
	candidate.personal=data(runtime.state).duplicate(true); candidate.personal.active=-1; candidate.personal.color_rule=0; candidate.personal.changed_at_ms=now_ms(); candidate.display=true
	return runtime.commit(candidate)

func display_name() -> String:
	var p:=data(runtime.state)
	if int(p.active)>=0 and int(p.active)<p.names.size(): return str(p.names[int(p.active)])
	return str(runtime.source.stages[runtime.state.achieved.size()-1].display_name) if not runtime.state.achieved.is_empty() and not runtime.source.stages.is_empty() else ""

func display_color() -> Color:
	var p:=data(runtime.state)
	if int(p.active)>=0:
		for color: Dictionary in colors(runtime.state):
			if int(color.id)==int(p.color_rule): return Color("#"+str(color.hex))
	if not runtime.state.achieved.is_empty() and not runtime.source.stages.is_empty(): return Color("#"+str(runtime.source.stages[runtime.state.achieved.size()-1].display_color))
	return Color("efd792")
