extends RefCounted
## Exact private original bytes. Installation changes presentation settings only.
const INDEX=preload("res://data/growth/guardian_media.json")
const STORE="user://guardian_original_media_v1"
const SETTINGS="user://guardian_original_media_v1.cfg"
static var page: Image
static var frames: Dictionary={}
static var missing: String=""
static func root_path() -> String:
 return STORE+"/"+str(INDEX.data.pack.sha256)
static func installed() -> bool:
 var config:=ConfigFile.new()
 if config.load(SETTINGS)!=OK or config.get_value("pack","sha256","")!=INDEX.data.pack.sha256:return false
 return FileAccess.file_exists(root_path().path_join(str(INDEX.data.page)))
static func install(path: String) -> Dictionary:
 var file:=FileAccess.open(path,FileAccess.READ)
 if file==null:return {"ok":false,"message":"원본 팩을 열 수 없습니다"}
 var length: int=file.get_length();file.close()
 var kind: String=""
 var hash: String=FileAccess.get_sha256(path) if length in [int(INDEX.data.pack.bytes),int(INDEX.data.container_bytes),int(INDEX.data.source_archive.bytes)] else ""
 if length==int(INDEX.data.pack.bytes) and hash==INDEX.data.pack.sha256:kind="pack"
 elif length==int(INDEX.data.container_bytes) and hash==INDEX.data.container_sha256:kind="container"
 elif length==int(INDEX.data.source_archive.bytes) and hash==INDEX.data.source_archive.sha256:kind="source_archive"
 if kind.is_empty():return {"ok":false,"message":"확인된 UI551 원본 ZIP / UI128.dat와 바이트가 다릅니다"}
 var zip:=ZIPReader.new()
 if zip.open(path)!=OK:return {"ok":false,"message":"원본 ZIP을 열 수 없습니다"}
 var temporary: String=""
 if kind=="source_archive":
  var container: PackedByteArray=zip.read_file(str(INDEX.data.source_archive.member));zip.close()
  if container.size()!=int(INDEX.data.container_bytes) or preload("res://scripts/lineagem_pack_install.gd").sha(container)!=INDEX.data.container_sha256:return {"ok":false,"message":"원본 UI128 바이트 검증 실패"}
  if DirAccess.make_dir_recursive_absolute(STORE)!=OK:return {"ok":false,"message":"원본 설치 경로 생성 실패"}
  temporary=STORE+"/UI128.dat.tmp"
  var input:=FileAccess.open(temporary,FileAccess.WRITE)
  if input==null:return {"ok":false,"message":"원본 입력 읽기 준비 실패"}
  input.store_buffer(container);input.close()
  if FileAccess.get_sha256(temporary)!=INDEX.data.container_sha256 or zip.open(temporary)!=OK:
   DirAccess.remove_absolute(temporary);return {"ok":false,"message":"원본 UI128 읽기 실패"}
 if kind=="pack" and zip.get_files().size()!=INDEX.data.members.size():zip.close();return {"ok":false,"message":"원본 파일 수 불일치"}
 var verified: Dictionary={}
 for name: String in INDEX.data.members:
  var bytes: PackedByteArray=zip.read_file(name)
  var spec: Dictionary=INDEX.data.members[name]
  if bytes.size()!=int(spec.bytes) or preload("res://scripts/lineagem_pack_install.gd").sha(bytes)!=spec.sha256:
   zip.close()
   if not temporary.is_empty():DirAccess.remove_absolute(temporary)
   return {"ok":false,"message":"원본 파일 해시 불일치"}
  verified[name]=bytes
 zip.close()
 if not temporary.is_empty():DirAccess.remove_absolute(temporary)
 var folder: String=root_path()
 for name: String in verified:
  var output: String=folder.path_join(name)
  if DirAccess.make_dir_recursive_absolute(output.get_base_dir())!=OK:return {"ok":false,"message":"원본 설치 경로 생성 실패"}
  if FileAccess.file_exists(output) and FileAccess.get_sha256(output)==INDEX.data.members[name].sha256:continue
  var destination:=FileAccess.open(output,FileAccess.WRITE)
  if destination==null:return {"ok":false,"message":"원본 파일 저장 실패"}
  destination.store_buffer(verified[name]);destination.flush()
  var error: Error=destination.get_error();destination.close()
  if error!=OK or FileAccess.get_sha256(output)!=INDEX.data.members[name].sha256:return {"ok":false,"message":"설치 파일 검증 실패"}
 # Existing activation remains intact until both exact files are durable.
 var config:=ConfigFile.new();config.set_value("pack","sha256",INDEX.data.pack.sha256)
 var candidate: String=SETTINGS+".tmp"
 if config.save(candidate)!=OK:return {"ok":false,"message":"설치 설정 저장 실패"}
 if DirAccess.rename_absolute(candidate,SETTINGS)!=OK:return {"ok":false,"message":"설치 설정 활성화 실패"}
 page=null;frames.clear();missing=""
 return {"ok":true,"message":"수호성 원본 광원 40프레임 설치 완료 · 게임 진행/재화는 변경하지 않았습니다"}
static func texture(key: String) -> Texture2D:
 if frames.has(key):return frames[key]
 if not INDEX.data.frames.has(key) or not installed():return null
 if page==null:
  var path: String=root_path().path_join(str(INDEX.data.page))
  if FileAccess.get_sha256(path)!=INDEX.data.members[str(INDEX.data.page)].sha256:missing="page_hash_mismatch";return null
  page=Image.load_from_file(path)
  if page==null or page.is_empty():missing="page_decode_failed";page=null;return null
 var spec: Dictionary=INDEX.data.frames[key]
 var raw: Array=spec.rect
 var region:=Rect2i(raw[0],raw[1],raw[2],raw[3])
 if not Rect2i(Vector2i.ZERO,page.get_size()).encloses(region):missing="frame_out_of_bounds";return null
 var crop: Image=page.get_region(region)
 var original:=Image.create(spec.source_size[0],spec.source_size[1],false,Image.FORMAT_RGBA8)
 original.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i(spec.source_rect[0],spec.source_rect[1]))
 frames[key]=ImageTexture.create_from_image(original)
 return frames[key]
