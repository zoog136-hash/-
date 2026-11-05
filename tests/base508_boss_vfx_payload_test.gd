extends SceneTree
## Synthetic metadata/hash fixture; no source pixels or native playback claim.
const INSTALL=preload("res://scripts/lineagem_pack_install.gd")
var fixture_root:String
var model:Dictionary
var effect_manifest:Dictionary
var monster_manifest:Dictionary
var errors:Array=[]
func write(relative:String,bytes:PackedByteArray)->String:
 var path:String=fixture_root.path_join(relative)
 DirAccess.make_dir_recursive_absolute(path.get_base_dir())
 var file=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(bytes);file.close()
 return FileAccess.get_sha256(path)
func refresh()->void:
 effect_manifest.models["1"].sha256=write("boss_vfx/effects/1.json",JSON.stringify(model).to_utf8_buffer())
 monster_manifest={"boss_vfx":{"path":"boss_vfx/boss_vfx.json","sha256":write("boss_vfx/boss_vfx.json",JSON.stringify(effect_manifest).to_utf8_buffer())}}
func rejected(label:String,manifest:Dictionary)->void:
 if INSTALL.validate_boss_vfx_payload(fixture_root,manifest).is_empty():errors.append(label)
func _initialize()->void:
 fixture_root=ProjectSettings.globalize_path("user://boss_vfx_validator_synthetic_"+str(OS.get_process_id()))
 var packet:Dictionary={"path":"sp2/1-0.bin","sha256":write("boss_vfx/sp2/1-0.bin","synthetic hash fixture; not SP2 pixels".to_utf8_buffer())}
 var layer:Dictionary=packet.duplicate(true);layer.codec="base508_sp2_v1"
 var directions:Array=[[{"layers":[layer]}]]
 for index:int in range(7):directions.append([])
 model={"source_snapshot":"base508","source_sprite_id":1,"source_pixels_complete":false,"source_gaps":[{"layer_id":2}],"tracks":{"effect":{"source_sprite_id":1,"source_action_id":0,"directions":directions}}}
 effect_manifest={"kind":"base508_boss_literal_sp2_effects","source_snapshot":"base508","models":{"1":{"path":"effects/1.json"}},"source_files":{"Sprite/1-0.sp2":packet}}
 refresh()
 if not INSTALL.validate_boss_vfx_payload(fixture_root,{}).is_empty():errors.append("legacy optional absence rejected")
 if not INSTALL.validate_boss_vfx_payload(fixture_root,monster_manifest).is_empty():errors.append("declared partial fixture rejected")
 var bad:Dictionary=monster_manifest.duplicate(true);bad.boss_vfx.sha256="z".repeat(64);rejected("malformed SHA accepted",bad)
 bad=monster_manifest.duplicate(true);bad.boss_vfx.path="../boss_vfx.json";rejected("unsafe root path accepted",bad)
 write("boss_vfx/sp2/1-0.bin","changed".to_utf8_buffer());rejected("packet hash mismatch accepted",monster_manifest)
 write("boss_vfx/sp2/1-0.bin","synthetic hash fixture; not SP2 pixels".to_utf8_buffer())
 effect_manifest.source_files["Sprite/1-0.sp2"].path="sp2/missing.bin";refresh();rejected("missing packet accepted",monster_manifest)
 effect_manifest.source_files["Sprite/1-0.sp2"].path="sp2/1-0.bin"
 effect_manifest.kind="other";refresh();rejected("wrong kind accepted",monster_manifest)
 effect_manifest.kind="base508_boss_literal_sp2_effects"
 effect_manifest.models["1"].path="effects/../../outside.json";refresh();rejected("model traversal accepted",monster_manifest)
 effect_manifest.models["1"].path="effects/1.json"
 model.source_sprite_id=2;refresh();rejected("wrong model sprite accepted",monster_manifest)
 model.source_sprite_id=1;model.tracks.effect.directions[0][0].layers[0].path="sp2/undeclared.bin";refresh();rejected("undeclared layer accepted",monster_manifest)
 print("BASE508_BOSS_VFX_PAYLOAD ",JSON.stringify({"errors":errors,"synthetic_hash_contract":true,"source_pixel_decode_or_native_clock_proof":false}))
 quit(0 if errors.is_empty()else 1)
