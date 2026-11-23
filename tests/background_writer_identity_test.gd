extends SceneTree
const WRITER=preload("res://scripts/skills/save_writer.gd")
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool,label: String)->void:
 checks+=1
 if not ok:failures.append(label)
func _initialize()->void:
 var path: String="user://writer-identity-"+str(Time.get_ticks_usec())+".json"
 check(WRITER.write_text_if_unchanged(path,"first","")==OK,"create absent expected path")
 var first: String=FileAccess.get_sha256(path)
 check(WRITER.write_text_if_unchanged(path,"second",first)==OK,"matching prior identity commits")
 var second: String=FileAccess.get_sha256(path)
 check(WRITER.write_text_if_unchanged(path,"stale",first)==ERR_BUSY,"changed prior file rejects stale snapshot")
 check(FileAccess.get_sha256(path)==second and not FileAccess.file_exists(path+".tmp"),"changed file preserved and own temp removed")
 check(WRITER.write_text_if_unchanged(path,"unexpected","")==ERR_BUSY,"appeared file never replaced as absent")
 DirAccess.remove_absolute(path)
 check(WRITER.write_text_if_unchanged(path,"deleted",second)==ERR_BUSY and not FileAccess.file_exists(path),"deleted prior file remains absent")
 check(WRITER.write_text(path,"ordinary")==OK,"existing ordinary writer API unchanged")
 DirAccess.remove_absolute(path)
 print("BACKGROUND_WRITER_IDENTITY_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
