extends RefCounted
## User policy: retire exact quest-only original items, not rewards that
## happen to be granted by a quest. Generated from the pinned 523 archive
## by tools/audit_quest_only_items523.py. The raw source and saves survive.
const IDS := {
	772:true,773:true,774:true,775:true,872:true,873:true,874:true,875:true,876:true,877:true,891:true,892:true,
	893:true,897:true,898:true,899:true,900:true,941:true,1092:true,1093:true,1094:true,1095:true,1096:true,1097:true,
	1098:true,1099:true,1100:true,1101:true,1102:true,1103:true,1104:true,1105:true,1106:true,1107:true,1108:true,1109:true,
	1110:true,1111:true,1112:true,1113:true,1114:true,1115:true,1116:true,1117:true,1118:true,1120:true,1121:true,1134:true,
	1214:true,1215:true,1661:true,1671:true,1681:true,1691:true,1701:true,1711:true,1721:true,1731:true,1741:true,1751:true,
	1761:true,1771:true,1781:true,1791:true,1801:true,1811:true,1821:true,1831:true,1841:true,1851:true,1861:true,1871:true,
	1891:true,1901:true,1911:true,1921:true,1931:true,1941:true,1951:true,1961:true,1991:true,2001:true,2011:true,2021:true,
	2031:true,2041:true,2051:true,2061:true,2071:true,2081:true,2091:true,2101:true,2111:true,2121:true,2131:true,2141:true,
	2151:true,2161:true,2171:true,2181:true,2191:true,2201:true,2211:true,2221:true,2231:true,2241:true,2251:true,2261:true,
	2271:true,2281:true,2291:true,2301:true,2311:true,2321:true,95634:true,95644:true,97394:true,97404:true,97524:true,97984:true,
	97994:true,99892:true,110653:true,111563:true,113432:true,113442:true,113452:true,116592:true,116602:true,116612:true,116622:true,116632:true,
	119572:true,119582:true,119592:true,119602:true,119612:true,119722:true,119732:true,119742:true,119752:true,119762:true,120392:true,122562:true,
	122934:true,122944:true,122954:true,122964:true,122974:true,123344:true,124282:true,125452:true,125462:true,125472:true,125482:true,125492:true,
	125783:true,126303:true,126404:true,126562:true,126622:true,126632:true,127124:true,127134:true,127841:true,127851:true,128013:true,128014:true,
	128023:true,128033:true,128043:true,128053:true,128063:true,128073:true,128083:true,128093:true,128103:true,128113:true,128123:true,128133:true,
	128143:true,128153:true,128163:true,128173:true,128183:true,128193:true,128203:true,128503:true,128513:true,128523:true,128533:true,128543:true,
	128553:true,128563:true,128573:true,128583:true,128593:true,128603:true,128613:true,128623:true,128633:true,128643:true,128653:true,128663:true,
	128673:true,128683:true,128693:true,129284:true,129294:true,129304:true,129314:true,129324:true,129691:true,129771:true,129921:true,129931:true,
	129941:true,129951:true,129961:true,133523:true,133533:true,133543:true,133553:true,133563:true,133743:true,133753:true,133763:true,133773:true,
	133833:true,133843:true,133853:true,133863:true,133873:true,137724:true,137811:true,138641:true,138961:true,139081:true,139181:true,139191:true,
	139201:true,139211:true,139221:true,139601:true,140431:true,141273:true,141813:true,141823:true,141833:true,141843:true,142882:true,143561:true,
	146064:true,146074:true,146084:true,146332:true,147452:true,147462:true,147472:true,147482:true,147492:true,152942:true,152992:true,153002:true,
	153012:true,153022:true,153032:true,153242:true,153252:true,153262:true,153272:true,153282:true,155223:true,155233:true,155243:true,155253:true,
	155263:true,155273:true,155283:true,155293:true,155303:true,155313:true,155323:true,155463:true,155623:true,155633:true,155762:true,155772:true,
	155782:true,156881:true,157301:true,157311:true,157321:true,157331:true,157341:true,158441:true,158451:true,158461:true,158471:true,158531:true,
	158601:true,158621:true,158631:true,158641:true,158651:true,158731:true,160322:true,160332:true,160733:true,160743:true,160753:true,162132:true,
	162142:true,162152:true,162162:true,170104:true,170124:true,170134:true,170144:true,170154:true,170224:true,172391:true,172401:true,173584:true,
	173614:true,173624:true,173634:true,175892:true,175902:true,175922:true,175932:true,175942:true,175952:true,175982:true,176282:true,176292:true,
	176302:true,179653:true,181904:true,181914:true,181924:true,181934:true,182054:true,185684:true,186121:true,186131:true,186141:true,186151:true,
	186161:true,190804:true,192141:true,192151:true,192161:true,196631:true,197601:true,197611:true,197621:true,197631:true,197641:true,197651:true,
	200764:true,200774:true,200784:true,200794:true,200804:true,200814:true,205131:true,205201:true,207051:true,211301:true,211351:true,212961:true,
	214801:true,218951:true,219001:true,220581:true,223401:true,228032:true,228082:true,229662:true,231882:true,238561:true,238611:true,240591:true,
	240991:true,249732:true,249782:true,252722:true,255823:true,260418:true,262548:true,267152:true,270162:true,276758:true,279323:true,281523:true,
	285622:true,287722:true,290022:true,300051:true,301591:true,305001:true,307431:true,315371:true,319501:true,322253:true,324383:true,326593:true,
	333652:true,334162:true,335952:true,339744:true,340214:true,343954:true,350384:true,350854:true,352554:true,357362:true,357832:true,360332:true,
	365952:true,367462:true,367932:true,369652:true,
}
## Five previously admitted, uniquely named legacy keys lack modern suffix
## or receipt metadata in some saves. Canonical different IDs always win.
const LEGACY_ONLY := {
	"[퀘스트] 죽은 모험가의 일지":1214,
	"[퀘스트] 하딘의 일지 1":1991,
	"[퀘스트] 하딘의 일지 2":2001,
	"[퀘스트] 수상한 쪽지":2011,
	"[퀘스트] 맹세의 잔":122562,
}

static func item(value: Variant) -> bool:
	if value is int:return IDS.has(value)
	return value is float and is_finite(value) and value>=772 and value<=369652 and value==floorf(value) and IDS.has(int(value))

static func matches_reference(record: Dictionary,key: String) -> bool:
	if record.has("source_item_class_id"):return item(record.source_item_class_id)
	var ref: Variant=record.get("sourceId",record.get("source_id",""))
	if ref is String and ref.begins_with("m523:item:"):
		var tokens: PackedStringArray=ref.split(":")
		if tokens.size()!=3 and (tokens.size()!=5 or tokens[3]!="bless" or tokens[4] not in ["1","2","3"]):return false
		return tokens[2].is_valid_int() and tokens[2]==str(int(tokens[2])) and item(int(tokens[2]))
	if ref is String and ref.is_valid_int():return ref==str(int(ref)) and item(int(ref))
	var text: String=key.get_slice("@@@",0)
	var mark: int=text.rfind(" · 원본#")
	if mark>=0:
		var old_id: String=text.substr(mark+6).trim_suffix(" · 축복").trim_suffix(" · 저주")
		return old_id.is_valid_int() and old_id==str(int(old_id)) and item(int(old_id))
	return LEGACY_ONLY.has(text.trim_prefix("[원본 보상] "))
