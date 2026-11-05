extends SceneTree
## Synthetic arithmetic contracts only. This is not a source-data/visual test.
const SOURCE = preload("res://scripts/monsters/base508_boss_combat.gd")
func _initialize() -> void:
 var rng=RandomNumberGenerator.new();rng.seed=21
 var errors:Array=[]
 if SOURCE.roll_damage({"IsSpell":true},{"damage_dice":{"base":3,"dice_count":2,"dice_spots":1}},rng)!=5:errors.append("typed spell dice")
 if SOURCE.roll_damage({"IsSpell":false,"DiceCount":3,"DiceSpots":1,"DiceBonus":7},{},rng)!=10:errors.append("typed NPC dice")
 if SOURCE.roll_damage({"IsSpell":true},{},rng)!=0:errors.append("absent damage fabricated")
 if SOURCE.roll_damage({"IsSpell":true},{"damage_dice":{"base":100,"dice_count":1,"dice_spots":0}},rng)!=0:errors.append("invalid dice accepted")
 if SOURCE.roll_damage({"IsSpell":true},{"damage_dice":{"base":1,"dice_count":1001,"dice_spots":4}},rng)!=0:errors.append("unbounded dice accepted")
 var path:String="user://synthetic_boss_catalog_invalid.bin"
 var file=FileAccess.open(path,FileAccess.WRITE)
 file.store_buffer("synthetic, not source".to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP));file.close()
 if not SOURCE.read_catalog_file(path).is_empty():errors.append("untrusted source catalog accepted")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 print("BASE508_BOSS_NUMERIC_CONTRACT ",JSON.stringify({"errors":errors,"fixture":"synthetic_numeric_contracts","source_catalog_load_or_pixel_coverage":false}))
 quit(0 if errors.is_empty() else 1)
