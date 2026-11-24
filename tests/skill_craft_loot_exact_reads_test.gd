extends SceneTree
const Skills=preload("res://scripts/skills/player_skills523.gd")
const Rules=preload("res://scripts/crafting/patch523_rules.gd")
const Enhancements=preload("res://scripts/crafting/patch523_enhancement.gd")
const CraftCatalog=preload("res://scripts/crafting/patch523_craft_catalog.gd")
const Loot=preload("res://scripts/loot/base508_monster_drops.gd")
const Extensions=preload("res://scripts/loot/source3_drop_extensions.gd")
const SHA=preload("res://scripts/lineagem_pack_install.gd")

var failures: Array[String]=[]
var checks: int=0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("SKILL_CRAFT_LOOT_EXACT_READS_FAIL ", label)

func write(path: String,bytes: PackedByteArray) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file!=null:
		file.store_buffer(bytes)
		file.close()

func craft(path: String) -> void:
	var rules:=Rules.new()
	var parsed: Dictionary={"schema":Rules.SCHEMA,"snapshot":"patch523","catalog_sha256":FileAccess.get_sha256("res://data/catalog_v19.json"),
		"recipes":{},"raw_recipes":{},"items":{},"bonuses":{},"bonus_types":{},"enchantment":{},"source_files":{},"label":"제작 가죽 신화"}
	var text: String=JSON.stringify(parsed,"\t").replace("\n","\r\n")+"\r\n"
	var bytes: PackedByteArray=text.to_utf8_buffer()
	write(path,bytes)
	var old_text: String=FileAccess.get_file_as_string(path)
	var pin: String=FileAccess.get_sha256(path)
	check(old_text==bytes.get_string_from_utf8() and pin==SHA.sha(bytes),"Korean JSON with CRLF has identical old read/text and raw pin")
	check(rules.load_file(path,pin) and rules.data.label=="제작 가죽 신화" and rules.digest==pin,"production crafting loader accepts the pinned UTF-8")
	write(path,text.replace("가죽","철").to_utf8_buffer())
	check(not rules.load_file(path,pin) and "SHA" in rules.problem and rules.data.label=="제작 가죽 신화","changed bytes fail closed with live model unchanged")
	var invalid: PackedByteArray="안녕하세요".to_utf8_buffer()
	write(path,invalid)
	check(not rules.load_file(path,SHA.sha(invalid)) and "JSON" in rules.problem and rules.digest==pin,"matching raw SHA does not bypass parser failure")
	parsed.label="제작 가죽 일반"
	parsed.catalog_sha256="0".repeat(64)
	bytes=JSON.stringify(parsed).to_utf8_buffer()
	write(path,bytes)
	check(not rules.load_file(path,SHA.sha(bytes)) and rules.data.label=="제작 가죽 신화","independent catalog pin is still mandatory")
	var blank:=PackedByteArray()
	write(path,blank)
	check(not rules.load_file(path,SHA.sha(blank)) and "JSON" in rules.problem and rules.digest==pin,"empty matching raw bytes still fail as JSON")
	check(CraftCatalog.install_zip(path).is_empty() and "SHA" in CraftCatalog.problem,"unrecognized ZIP edition cannot reach installer")

func skill(path: String) -> void:
	var rules:=Skills.new()
	var text: String=FileAccess.get_file_as_string(Skills.BINDINGS_PATH)
	var pack: Dictionary={"schema_version":1,"patch":523,"source_zip_sha256":Skills.SOURCE_SHA,"bindings_sha256":text.sha256_text(),"profiles":{}}
	var bytes: PackedByteArray=JSON.stringify(pack).to_utf8_buffer()
	write(path,bytes)
	rules.profiles={"sentinel":{}}
	check(not rules.load_pack(path,SHA.sha(bytes)) and rules.last_error=="incomplete profile set" and rules.profiles.has("sentinel"),"production skill loader passes the unchanged binding pin then checks coverage")
	pack.bindings_sha256="0".repeat(64)
	bytes=JSON.stringify(pack).to_utf8_buffer()
	write(path,bytes)
	check(not rules.load_pack(path,SHA.sha(bytes)) and rules.last_error=="binding revision mismatch" and rules.profiles.has("sentinel"),"wrong binding pin fails before live replacement")

func loot(path: String) -> void:
	var doc: Dictionary={"kind":"base508_monster_drop_membership","source_snapshot":"base508","name":"몬스터 가죽"}
	var bytes: PackedByteArray=JSON.stringify(doc).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	write(path,bytes)
	var pin: String=FileAccess.get_sha256(path)
	check(Loot._read_pinned(path,pin)==doc,"bounded base508 path verifies compressed bytes, then consumes the exact buffer")
	bytes[bytes.size()-1]=bytes[bytes.size()-1]^1
	write(path,bytes)
	check(Loot._read_pinned(path,pin).is_empty(),"changed compressed bytes fail before decoding")
	doc.source_snapshot="patch523"
	bytes=JSON.stringify(doc).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	write(path,bytes)
	check(Loot._read_pinned(path,SHA.sha(bytes)).is_empty(),"matching compressed SHA does not bypass original membership identity")
	var registry: Variant=JSON.parse_string(FileAccess.get_file_as_string(Extensions.PATH))
	check(registry is Dictionary and not registry.entries.is_empty() and registry.entries==Extensions.registry(),"real pinned source3 repository data retains identical entries")
	var policy: Dictionary=Enhancements.policy()
	check(not policy.is_empty() and policy==JSON.parse_string(FileAccess.get_file_as_string(Enhancements.POLICY)) and Enhancements._policy_digest==FileAccess.get_sha256(Enhancements.POLICY),"real bundled enhancement policy and provenance digest match")

func run() -> void:
	var path: String="user://exact-domain-read-test-%d.json"%Time.get_ticks_usec()
	craft(path)
	skill(path)
	loot(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("SKILL_CRAFT_LOOT_EXACT_READS_RESULT ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
