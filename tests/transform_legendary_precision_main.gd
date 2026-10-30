extends "res://tests/transform_mythic_precision_main.gd"
## Explicit current-main expected routes; never infer success from for_record output.
## Source reuse is recorded separately from dedicated RUN/art completion.
const EXPECTED: Dictionary = {
	"402": {
		"name": "세계수의 현신",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_402/r001/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_402/r001/SpriteFrames.tres",
		"sha256": "a8f81ef378d57a03cda7b5d7aa946f054f7ad0ba186d479f6ec8c1bc7fae2735",
		"explicit_source_override": false
	},
	"387": {
		"name": "벨라",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_387/r001/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_387/r001/SpriteFrames.tres",
		"sha256": "05a6ef7ca491ee6ed7e6cc0b6d34fc2989b170fc569de1aabb09d5a743a2b7bf",
		"explicit_source_override": false
	},
	"375": {
		"name": "전설의 낚시왕 폴",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_375/r001/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_375/r001/SpriteFrames.tres",
		"sha256": "0b24f6810b3d1594c0956227749f0d1bbcf42223577327a98d1694bfb4c57c62",
		"explicit_source_override": false
	},
	"368": {
		"name": "대장로 폴카",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_368/r001/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_368/r001/SpriteFrames.tres",
		"sha256": "6dd434d6f28129d583550ed2e468eda01c7bd16ca9eee94ba3f1df7763849779",
		"explicit_source_override": false
	},
	"339": {
		"name": "실렌의 파수꾼",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_339/r159/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_339/r159/SpriteFrames.tres",
		"sha256": "6db66b9f247c7585ca9dca702b2543fe93d052668f0085c43d7af9cb32b92cba",
		"explicit_source_override": false
	},
	"338": {
		"name": "그랑카인의 역린",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_338/r163/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_338/r163/SpriteFrames.tres",
		"sha256": "a4a146aa3cb82feb68a25f3e6de59a604c0522cab51561469e9e51121a81b9f9",
		"explicit_source_override": false
	},
	"337": {
		"name": "아인하사드의 그림자",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_337/r163/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_337/r163/SpriteFrames.tres",
		"sha256": "7ebeb51afdcc0e75037112a7cf6f6e60459cf383eaf3c37d47d89a42623918d5",
		"explicit_source_override": false
	},
	"332": {
		"name": "암흑룡 조우",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_332/r006/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_332/r006/SpriteFrames.tres",
		"sha256": "646419ae7a521eba528c6fa9caffe0e987878b6f3a020ac90e3fcd88c11850e2",
		"explicit_source_override": false
	},
	"331": {
		"name": "암흑룡 질리언",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_331/r163/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_331/r163/SpriteFrames.tres",
		"sha256": "903549fbf247c3b9a1e07073b1bdba2e3869527bddd0e623a19b05a9d32f4e70",
		"explicit_source_override": false
	},
	"330": {
		"name": "암흑룡 아툰",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_330/r008/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_330/r008/SpriteFrames.tres",
		"sha256": "05cf2a0248e8e23648a0c83c7dd89ca26cfa42c00a2e9808d553b899dd7ed6d3",
		"explicit_source_override": false
	},
	"282": {
		"name": "젠",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_282/r163/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_282/r163/SpriteFrames.tres",
		"sha256": "0ea88cb40e605356a176fe66ddce96494564940d74d010c6e820e5b27eff76c4",
		"explicit_source_override": false
	},
	"275": {
		"name": "Mr. 스모커",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_275/r163/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_275/r163/SpriteFrames.tres",
		"sha256": "4e694fd8092504a57bbc749103046c293bbe139f069d40404c066ea9807bd2ad",
		"explicit_source_override": false
	},
	"274": {
		"name": "암살의 아리아 울프",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_274/r163/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_274/r163/SpriteFrames.tres",
		"sha256": "6fffbda403f2c4c747479a82bf0a6a9f035411e0ecaef3301c8beeb0c12fe8f5",
		"explicit_source_override": false
	},
	"273": {
		"name": "과거의 나이트발드",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_273/r001/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_273/r001/SpriteFrames.tres",
		"sha256": "c9da88d7df27f14661279daef8ac77adf1470b23dc8afa96c2db399637420f06",
		"explicit_source_override": false
	},
	"259": {
		"name": "국왕 에오딘",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_259/r001/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_259/r001/SpriteFrames.tres",
		"sha256": "a7a0d5f2072d6938299a6f074e101707a1fa43c6a62e8a1283c12ad2123b4eeb",
		"explicit_source_override": false
	},
	"245": {
		"name": "베리스",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_245/r163/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_245/r163/SpriteFrames.tres",
		"sha256": "69f306e894fc8370b60d6ff29a4995311f18f14e6b8fb3dfb1c32d7ab6e04646",
		"explicit_source_override": false
	},
	"244": {
		"name": "로데마이",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_244/r163/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_244/r163/SpriteFrames.tres",
		"sha256": "58fafe2be8a228b7860f7bc7ed0cb35c3d1279c6c11f24d39181e512eb072f3a",
		"explicit_source_override": false
	},
	"243": {
		"name": "화염의 데스나이트",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_243/r159/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_243/r159/SpriteFrames.tres",
		"sha256": "c98609522bad265c56ae54e01811497fd542043d6828314f3434033bbb8cb9be",
		"explicit_source_override": false
	},
	"227": {
		"name": "게렝",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_227/r005/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_227/r005/SpriteFrames.tres",
		"sha256": "e3e8cb4df011e82f49801c9ae46d9017ba20c1688f959af374fb3c4ef3c6db1c",
		"explicit_source_override": false
	},
	"226": {
		"name": "가드리아",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_226/r001/SpriteFrames.tres",
		"actual_expected_path": "res://assets/local_source_transforms/gadria_source2/SpriteFrames.tres",
		"sha256": "81eb819676f24f085eeb6400d1841ca53e943777ad9fd7d4ad11caa3197f3392",
		"explicit_source_override": true
	},
	"225": {
		"name": "불패의 군터",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_225/r159/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_225/r159/SpriteFrames.tres",
		"sha256": "da851825c5a7cf06e543dcfd46fc1d00177bb43e8b712f74026df6bfc5d98e49",
		"explicit_source_override": false
	},
	"213": {
		"name": "1세대 드루가",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_213/r159/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_213/r159/SpriteFrames.tres",
		"sha256": "3844d56fb2cea1925150dde8ab125742fd8e3b9323bc5d21b19d0b3ef3b54b5c",
		"explicit_source_override": false
	},
	"194": {
		"name": "군단장 엑스터",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_194/r001/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_194/r001/SpriteFrames.tres",
		"sha256": "b3461c816747c93b6e8111e4e39746259b2394e65c5e18384907b9c807559366",
		"explicit_source_override": false
	},
	"193": {
		"name": "공작 마커스",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_193/r159/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_193/r159/SpriteFrames.tres",
		"sha256": "ced9714bf4627dbbc4341d1ac3f16293b593306ee40036cf84b68b1b00d82b4b",
		"explicit_source_override": false
	},
	"192": {
		"name": "칠흑의 데스나이트",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_192/r163/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_192/r163/SpriteFrames.tres",
		"sha256": "927035c5728d44315247db683e356949d08937a528d3cb19ddcfd3d1970e7e30",
		"explicit_source_override": false
	},
	"191": {
		"name": "하딘의 영혼",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_191/r159/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_191/r159/SpriteFrames.tres",
		"sha256": "f98a1ea46b6952d60bf14720b336fccbeb2b007b5fa13b4f8c5f4e1a745719f0",
		"explicit_source_override": false
	},
	"190": {
		"name": "백조의 로엔그린",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_190/r001/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_190/r001/SpriteFrames.tres",
		"sha256": "e76d8327ec4ea4daf2bb8a2fea554ac473003abe8c41785a32245cca714b9e60",
		"explicit_source_override": false
	},
	"178": {
		"name": "디바인 크루세이더",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_178/r159/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_178/r159/SpriteFrames.tres",
		"sha256": "54e15213ec3c3da1d99aafc3d9f4c2c56babe9ddc71a5acf20435a75a6e7e819",
		"explicit_source_override": false
	},
	"177": {
		"name": "경비병(활) 대장",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_177/r163/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_177/r163/SpriteFrames.tres",
		"sha256": "e69a36690ed37c0796751d7f461e572dea5de217b4405279f483b413a739668f",
		"explicit_source_override": false
	},
	"176": {
		"name": "경비병(창) 대장",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_176/r163/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_176/r163/SpriteFrames.tres",
		"sha256": "50163b70c88cbf7338023a3d27c1f7de4be13aed2fb1e70e6be270f86cea035f",
		"explicit_source_override": false
	},
	"175": {
		"name": "증오의 데스나이트",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_175/r001/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_175/r001/SpriteFrames.tres",
		"sha256": "e49cc4a7b4020249c6f34af23e5412b4bb1b976df155499c091b42283334d6e9",
		"explicit_source_override": false
	},
	"166": {
		"name": "다크 하딘",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_166/r159/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_166/r159/SpriteFrames.tres",
		"sha256": "5cc8d1182e69cabc3c24ee3eb90d71d3681df0e2342401b4edbbb910445ab598",
		"explicit_source_override": false
	},
	"165": {
		"name": "팬텀 나이트",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_165/r159/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_165/r159/SpriteFrames.tres",
		"sha256": "460857b9216842378014f9575e49ec59c9041cd1dad167dd73a0ba22700c05c1",
		"explicit_source_override": false
	},
	"160": {
		"name": "지옥의 데스나이트",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_160/r002/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_160/r002/SpriteFrames.tres",
		"sha256": "75ddb5f45d5965a7dac93ea8cf3a33cb5aeaa0f9ea8fec8b4accd4e883fda573",
		"explicit_source_override": false
	},
	"143": {
		"name": "나이트 슬레이셔",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_143/r163/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_143/r163/SpriteFrames.tres",
		"sha256": "0c6ccd2b152a94cfa5ac96baaf047ce21114d19ffa2669777cb60e60d36a4da6",
		"explicit_source_override": false
	},
	"122": {
		"name": "다크 슬레이어",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_122/r159/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_122/r159/SpriteFrames.tres",
		"sha256": "26900589579e470303c0c57f29d0fb71420c542893b0c9903eebd73b1ca4cc08",
		"explicit_source_override": false
	},
	"114": {
		"name": "다크스타 조우",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_114/r159/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_114/r159/SpriteFrames.tres",
		"sha256": "df20d4ef7205fcb5e6a3f3cffe5518c5bb8175467056d50b411174f6c114db8e",
		"explicit_source_override": false
	},
	"113": {
		"name": "달의 질리언",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_113/r159/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_113/r159/SpriteFrames.tres",
		"sha256": "dae82a2cccd36cc65d142a9a35291ef59ddfa3272aa8211447767d97ed64121a",
		"explicit_source_override": false
	},
	"112": {
		"name": "철의 아툰",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_112/r001/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_112/r001/SpriteFrames.tres",
		"sha256": "703ccfd1a16f61df738eac740eed253f5998add278709b3e9cfb948359e79b36",
		"explicit_source_override": false
	},
	"1": {
		"name": "드래곤 슬레이어",
		"grade": "전설",
		"catalog_path": "res://assets/actors/eight_direction/legendary_production/transform_1/r001/SpriteFrames.tres",
		"actual_expected_path": "res://assets/actors/eight_direction/legendary_production/transform_1/r001/SpriteFrames.tres",
		"sha256": "8721531ef0f92a004f6c52df90fbf837cd8ebadd1dbbe48463be8524af38545e",
		"explicit_source_override": false
	}
}
const SOURCE_MANIFEST_SHA256 = "dc9b13612e064502e2bf31661a07eca1b9ac46db8604b5c6aa9d8850aeeeb98f"
const OVERRIDE_226: Dictionary = {
	"name": "가드리아",
	"grade": "전설",
	"frames_path": "res://assets/local_source_transforms/gadria_source2/SpriteFrames.tres",
	"required_layout": "directional8",
	"input_sha256": "fcc4daa36165d5046275a1cb11f7a6bf9a9e4bac67571a3a861abdfd6f8f8d4c",
	"source_model": "SPR-U-205c5187d4cd97fd505b",
	"game_to_source_heading": [
		3,
		4,
		5,
		6,
		7,
		0,
		1,
		2
	]
}

func precision_actor_ids(world:Node) -> Array:
	# Pure-list regression: retain the original base mythic scope without GPU replay.
	var mythic:Array=super.precision_actor_ids(world)
	var expected_mythic=[]
	for row:Dictionary in world.catalog_db["변신"]:
		if str(row.get("grade",""))=="신화":expected_mythic.append(str(row.sourceId))
	check(mythic.size()==29 and mythic.slice(0,3)==["413","412","258"],"Base helper preserves mythic29 and original priority three")
	var base_set=mythic.duplicate();var expected_set=expected_mythic.duplicate();base_set.sort();expected_set.sort()
	check(base_set==expected_set,"Base helper retains exact original mythic catalog ID set")
	check(FileAccess.get_sha256("res://data/source_transform_visuals.json")==SOURCE_MANIFEST_SHA256,"Independent main source-transform manifest SHA")
	var actual=[]
	for row:Dictionary in world.catalog_db["변신"]:
		if str(row.get("grade",""))=="전설":actual.append(str(row.sourceId))
	check(actual.size()==40 and EXPECTED.size()==40,"Exactly forty actual legendary catalog IDs")
	for id:String in actual:check(EXPECTED.has(id),"No omitted/new unpinned legendary ID "+id)
	var ordered=["226"]
	for id:String in EXPECTED:
		if id!="226":ordered.append(id)
	verify_override_conditions(world)
	return ordered

func verify_override_conditions(world:Node) -> void:
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/source_transform_visuals.json"))
	var entry:Dictionary=manifest.entries["transform:226"]
	for field:String in OVERRIDE_226:
		if field=="game_to_source_heading":
			var actual:Variant=entry[field]
			var exact:bool=actual is Array and actual.size()==8
			if exact:
				for index in range(8):
					var value:Variant=actual[index]
					exact=exact and (value is int or value is float) and is_finite(float(value)) and float(value)==float(OVERRIDE_226[field][index]) and float(value)==floor(float(value))
			check(exact,"Exact independent source226 binding field "+field)
		else:check(entry[field]==OVERRIDE_226[field],"Exact independent source226 binding field "+field)
	check(entry.get("canonical_alias_clocks",false)==true,"Only reviewed source226 canonical alias clock opt-in")
	var selected={}
	for row:Dictionary in world.catalog_db["변신"]:
		if str(row.get("sourceId",""))=="226":selected=row
	check(selected.name==entry.name and selected.grade==entry.grade and selected.animation_profile.layout==entry.required_layout,"Independent name/grade/required layout triggers match source226")
	var original=JSON.stringify(selected)
	for changed_field in ["name","grade","sourceId"]:
		var invalid=selected.duplicate(true)
		invalid[changed_field]="__QA_wrong_binding__" if changed_field=="name" else ("영웅" if changed_field=="grade" else "-226")
		var profile=world.ANIMATION_CATALOG.for_record("transform",invalid,world._directional_image_path("transform",invalid))
		check(profile.frames_path==str(selected.animation_profile.frames_path),"Source override requires exact independent "+changed_field)
	check(JSON.stringify(selected)==original,"Source-trigger negative controls do not mutate catalog")
	for id:String in EXPECTED:
		if id!="226":check(not manifest.entries.has("transform:"+id),"Only declared226 source override allowed in legendary scope")

func expected_visual_route(selected:Dictionary) -> Dictionary:
	var id=str(selected.sourceId)
	check(EXPECTED.has(id),"Explicit route pin exists "+id)
	var expected:Dictionary=EXPECTED[id]
	check(selected.grade==expected.grade and selected.name==expected.name and str(selected.animation_profile.frames_path)==str(expected.catalog_path),"Current catalog identity/profile matches independently pinned route "+id)
	return {"path":expected.actual_expected_path,"sha256":expected.sha256,"source_override":expected.explicit_source_override}

func precision_source_phase(id:String,d:int,role:String,clip:String) -> int:
	var sprite:AnimatedSprite2D=actor.transform_sprite
	# The reviewed source226 explicitly aliases recovery to the same complete
	# attack texture sequence. Count actual source coverage across both names;
	# the authoritative impact assertion still requires the primary attack key.
	if id=="226" and role=="attack" and str(sprite.animation)=="recovery_"+str(d):
		var frames=sprite.sprite_frames
		check(frames.get_frame_count(sprite.animation)==frames.get_frame_count(clip) and frames.get_frame_texture(sprite.animation,sprite.frame)==frames.get_frame_texture(clip,sprite.frame),"Exact pinned source226 recovery/attack source identity")
		return sprite.frame
	return super.precision_source_phase(id,d,role,clip)

func precision_actor_finished(id:String) -> void:
	if id!="226":return
	var frames=actor.transform_sprite.sprite_frames
	var reused=[]
	for direction in range(8):
		var run_key="run_"+str(direction)
		var walk_key="walk_"+str(direction)
		var identical=frames.get_frame_count(run_key)==frames.get_frame_count(walk_key)
		for phase in range(frames.get_frame_count(run_key)):
			identical=identical and frames.get_frame_texture(run_key,phase)==frames.get_frame_texture(walk_key,phase)
		if identical:reused.append(direction)
	report["authoring_residue"]={"226":{"RUN_WALK_SOURCE_ALIAS_VIEWS":reused,"dedicated_authored_RUN_completion_claimed":false,"actual_motion_requires_visual_review":true,"source_override_is_explicit_not_catalog_fallback":true}}
	print("PRECISION_SOURCE_REUSE_RESIDUE id=226 RUN/WALK shared source views=",reused," dedicated_RUN_completion=false")

func precision_output_name() -> String:
	return "legendary40-actual-Main-overview.jpg"
