extends SceneTree
const P=preload("res://scripts/protection/protection523_source.gd")
const S=preload("res://scripts/resources/current523_definition_rows.gd")
var checks: int=0
var failures: Array[String]=[]
func check(ok: bool,label: String)->void:
 checks+=1
 if not ok:failures.append(label)
func same(actual: Dictionary,expected: Dictionary,label: String)->void:
 check(actual.get("ok",false),label+": compile succeeds")
 check(var_to_bytes(actual)==var_to_bytes(expected),label+": every result byte preserved")
 check(actual.get("capsule",{}).size()>0 and JSON.stringify(actual.capsule,"",true).sha256_text()==P.CAPSULE_SHA,label+": fixed complete capsule digest preserved")
func _initialize()->void:run.call_deferred()
func run()->void:
 var path: String=OS.get_environment("TWILIGHT_PATCH523_CONTENT")
 check(S.identity().get("source_sha256")==P.SOURCE_SHA,"actual original source pin accepted")
 var raw: Dictionary=P.extract(path)
 check(raw.get("ok",false),"unchanged public ZIP extractor succeeds")
 if not raw.get("ok",false):finish();return
 same(P._extract(path,true),raw,"shared verified original")
 var old_meta: Dictionary=S._metadata["content/Bonus.json"].duplicate(true)
 S._metadata["content/Bonus.json"]["sha256"]="0".repeat(64)
 same(P._extract(path,true),raw,"altered member hash retries original ZIP")
 S._metadata["content/Bonus.json"]=old_meta
 var old_store: Dictionary=S._tables["ItemCategory"]
 var rows: Array=S.rows("ItemCategory")
 for row: Dictionary in rows:
  if int(row.ID)==10204:row.IsConsumable=true
 S._tables["ItemCategory"]={"count":rows.size(),"rows":rows}
 same(P._extract(path,true),raw,"altered cached value retries original ZIP")
 S._tables["ItemCategory"]=old_store
 var bad: String="user://not-original.zip";var file:=FileAccess.open(bad,FileAccess.WRITE);file.store_string("invalid");file.close()
 check(not P._extract(bad,true).get("ok",true),"shared mode never bypasses original file size/SHA")
 check(not P.extract(bad).get("ok",true),"public invalid-source rejection unchanged")
 finish()
func finish()->void:
 print("PROTECTION_SHARED_ROWS_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"actual original and explicit in-memory cache tampering, no game save"}))
 quit(0 if failures.is_empty() else 1)
