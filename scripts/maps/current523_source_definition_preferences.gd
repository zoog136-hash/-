extends RefCounted
## A verified definition selection is separate from game saves and map cursors.
const PATH="user://current523_source_definitions.cfg"
const PIN="2de8cebbcf486e5c2afa3e471ddc0cceeebe20ab8389916291eb24a5739ffa90"
const MAX_BYTES=16384
static func read() -> Dictionary:
	if DirAccess.dir_exists_absolute(PATH):return {"ok":false,"configured":true,"problem":"원문 정의 설정 경로가 파일이 아닙니다."}
	if not FileAccess.file_exists(PATH):return {"ok":true,"configured":false}
	var file:=FileAccess.open(PATH,FileAccess.READ)
	if file==null or file.get_length()<1 or file.get_length()>MAX_BYTES:return {"ok":false,"configured":true,"problem":"원문 정의 설정을 읽을 수 없습니다."}
	var config:=ConfigFile.new()
	if config.parse(file.get_as_text())!=OK:return {"ok":false,"configured":true,"problem":"원문 정의 설정 형식이 올바르지 않습니다."}
	var enabled: Variant=config.get_value("definitions","enabled",true)
	if not enabled is bool:return {"ok":false,"configured":true,"problem":"원문 정의 연결 상태가 올바르지 않습니다."}
	if not enabled:return {"ok":true,"configured":false}
	var directory: Variant=config.get_value("definitions","directory",null)
	var pin: Variant=config.get_value("definitions","manifest_sha256",null)
	if not directory is String or directory.strip_edges().is_empty() or directory.length()>4096 or directory.to_utf8_buffer().has(0) or pin!=PIN:
		return {"ok":false,"configured":true,"problem":"원문 정의 폴더 또는 검증값이 올바르지 않습니다."}
	return {"ok":true,"configured":true,"directory":directory.strip_edges(),"manifest_sha256":PIN}
static func write(directory: String, pin: String, enabled: bool=true) -> Error:
	if pin!=PIN or directory.length()>4096 or directory.to_utf8_buffer().has(0) or (enabled and directory.strip_edges().is_empty()):return ERR_INVALID_PARAMETER
	var config:=ConfigFile.new()
	config.set_value("definitions","enabled",enabled)
	config.set_value("definitions","directory",directory.strip_edges())
	config.set_value("definitions","manifest_sha256",PIN)
	var pending: String=PATH+".pending-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())
	var result: Error=config.save(pending)
	if result==OK:result=DirAccess.rename_absolute(pending,PATH)
	if result!=OK:DirAccess.remove_absolute(pending)
	return result
static func disable() -> Error:return write("",PIN,false)
