extends RefCounted
## Registration boundary for the original UI owner. No renderer or fallback UI.
## Metadata/atlas availability is not registration of an interactive source scene.
const AWAKENING: String="card_skill_awakening"
const GROWTH: String="card_skill_growth"
const CRAFT: String="native_card_craft"

static func capability(operation: String) -> Dictionary:
	var source: Dictionary={}
	match operation:
		AWAKENING:source={"container":"Client/Data/UI117.dat","member":"UI/Change/Change_Awaken_Skill.csb","bytes":52292,"crc32":"77cf6bf9","sha256":"aa50bea00b320c43f01112cca2c49aee65293a7fc40852a78b7c23b6c5f99fdd","layout_metadata":true}
		GROWTH:source={"container":"Client/Data/UI117.dat","member":"UI/Change/Change_Awaken_SkillExp.csb","bytes":87632,"crc32":"e939b3dc","sha256":"c1e7cdef5f9b8090f2741dcf27d724723606d2642092a4763eab45e09a70d821","layout_metadata":true}
		CRAFT:source={"container":"Client/Data/UI1.dat","member":"UI/ProductionScene.csb","candidate_only":true,"layout_metadata":false,"recipe_node_binding_verified":false}
	return {"operation":operation,"known":not source.is_empty(),"presentation_registered":false,"original_renderer_registered":false,"source":source,"supplied_player":{"artifact_sha256":"92f98b580cb8692d203d4173516bbdbd59d4c560c2dfeb4c14d86d688145f653","code_received":true,"full_source_screens_supported":false,"unsupported_classes":["Button","ImageView","LoadingBar","Particle","ScrollView","Text"],"original_pixel_pack_received":false}}

static func available(_operation: String) -> bool:
	# Intentionally unregistered. The original UI owner must supply its verified
	# existing player and node/action bindings; a setting cannot enable a form.
	return false

static func request(operation: String) -> Dictionary:
	return {"handled":true,"ok":false,"committed":false,"code":"source_presentation_unregistered","operation":operation,"error":"원본 화면 재생·동작 연결 대기 · 소유품·재화 보존","presentation":capability(operation)}
