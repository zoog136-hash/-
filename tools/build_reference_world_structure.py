"""Build authored geometry from inspected public Lineage M map references.

No reference pixels, original client bytes or legacy L1J navigation are shipped.
The reference-image coordinate scale is explicit and provisional. It is NOT a
decoded Lineage M server coordinate system. Run on the preserved PR84 baseline.
"""
import copy
import hashlib
import json
import math
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADEN_SOURCE = "https://games.app-liv.jp/archives/397568"
OMAN_SOURCE = "https://www.gamechosun.co.kr/webzine/article/view.php?no=145842"

# Hand-authored contour/control points in the inspected 1200 x 628 public map.
# These describe relative geography, not cadastral or server collision precision.
ADEN_LAND = [[0,0],[1200,0],[1200,329],[1170,345],[1143,352],[1109,367],
 [1071,389],[1094,414],[1080,451],[1030,445],[1000,404],[966,405],
 [926,416],[891,386],[871,380],[849,402],[803,425],[751,424],[734,449],
 [708,470],[672,485],[645,506],[618,528],[604,559],[563,583],[516,584],
 [481,563],[470,545],[480,525],[448,508],[416,495],[372,480],[332,478],
 [296,467],[267,448],[236,451],[222,424],[194,434],[181,417],[155,421],
 [120,410],[105,388],[119,356],[98,343],[85,325],[66,321],[44,334],
 [29,313],[11,303],[0,272]]
TOWNS = {"gludio":("글루디오",[260,408]),"kent":("켄트",[493,286]),
 "giran":("기란",[646,231]),"aden":("아덴",[1120,212]),
 "heine":("하이네",[1030,365]),"oren":("오렌",[755,54]),
 "weldan":("웰던",[534,150]),"windawood":("윈다우드",[488,479]),
 "silver_knight":("은기사 마을",[716,409]),"fire_village":("화전민 마을",[155,275]),
 "elf_village":("요정 숲",[244,192])}
ADEN_ZONES = [
 ("elf_forest",0,[[57,146],[172,126],[267,131],[348,165],[360,246],[288,274],[184,285],[87,244]],"4d6550"),
 ("western_forest",0,[[0,111],[65,122],[90,203],[65,240],[0,231]],"566347"),
 ("dragon_valley",3,[[176,0],[420,0],[462,104],[424,161],[339,160],[304,111],[202,114]],"746e61"),
 ("fire_land",1,[[448,0],[611,0],[664,86],[614,162],[554,175],[479,136]],"74614b"),
 ("oren_snow",2,[[578,0],[1020,0],[999,52],[951,87],[873,77],[811,85],[729,61],[651,45]],"bcc5be"),
 ("twilight_mountains",3,[[1050,0],[1200,0],[1200,135],[1129,131],[1090,107],[1013,58]],"79664d"),
 ("eastern_forest",0,[[803,122],[1010,110],[1062,183],[1038,251],[899,274],[791,244],[802,205]],"4c624c"),
 ("heine_wetlands",0,[[828,275],[945,263],[1068,299],[1106,358],[1043,389],[963,392],[891,375],[837,354]],"607365"),
 ("southern_desert",1,[[310,379],[384,364],[481,390],[561,367],[677,386],[697,446],[642,507],[605,552],[525,558],[481,518],[410,483],[333,466]],"b8a678"),
 ("western_hills",3,[[155,324],[238,307],[285,328],[288,387],[237,416],[180,394]],"928366"),
]
RIVERS = [
 [[330,304],[349,291],[356,276],[372,258],[389,248],[401,243],[406,224],[425,210],[458,204],[489,207],[514,199],[548,188],[579,174],[607,164],[623,137],[671,110],[714,108],[743,109],[789,107],[831,108],[870,86],[912,73]],
 [[341,307],[352,323],[384,332],[417,337],[443,346],[461,371],[485,382],[516,385],[550,377],[572,362],[599,349],[646,345],[700,351],[752,340],[782,330],[808,338],[823,348],[827,373],[849,390]],
 [[939,78],[974,111],[1014,123],[1057,130],[1101,138],[1148,142],[1200,151]],
]
ADEN_ROUTES = [
 ("gludio_kent",[[260,408],[293,389],[321,363],[347,342],[382,327],[430,318],[493,286]]),
 ("kent_giran",[[493,286],[526,273],[572,270],[605,246],[646,231]]),
 ("giran_aden",[[646,231],[708,269],[781,271],[854,292],[927,298],[1004,285],[1051,262],[1120,212]]),
 ("kent_windawood",[[493,286],[471,326],[461,371],[475,416],[488,479]]),
 ("giran_heine",[[646,231],[692,276],[727,313],[782,330],[861,344],[947,340],[1030,365]]),
 ("giran_weldan",[[646,231],[616,203],[589,181],[554,173],[534,150]]),
 ("weldan_oren",[[534,150],[577,119],[623,137],[676,123],[714,108],[747,85],[755,54]]),
 ("kent_elf",[[493,286],[450,280],[406,268],[372,258],[348,232],[299,211],[244,192]]),
 ("gludio_fire_village",[[260,408],[226,378],[201,349],[186,315],[155,275]]),
 ("silver_knight",[[716,409],[708,380],[703,350],[700,313],[692,276]]),
 ("oman_approach",[[1120,212],[1110,175],[1090,149],[1072,133],[1074,111],[1101,101],[1125,124],[1136,156]])
]

# External wall and entrance of the inspected 600 x 300 Oman 1F image.
OMAN_FLOOR = [[8,146],[68,116],[76,120],[120,96],[126,90],[159,76],
 [166,59],[187,58],[201,49],[242,26],[249,14],[297,0],[358,27],
 [367,48],[409,56],[419,54],[482,85],[483,97],[523,118],[533,115],
 [593,145],[593,157],[559,174],[529,182],[523,180],[484,200],
 [483,210],[436,235],[435,228],[398,249],[396,254],[317,295],
 [259,272],[252,267],[239,267],[232,259],[214,263],[210,252],
 [211,238],[198,231],[183,227],[152,241],[137,245],[112,238],
 [137,225],[144,217],[114,202],[101,196],[87,196],[76,188],
 [67,187],[68,179],[8,155]]
OMAN_PITS = [[[113,154],[124,149],[143,158],[133,164]],
 [[279,235],[289,231],[306,239],[298,246]]]

def dump(path, data):
    (ROOT/path).parent.mkdir(parents=True,exist_ok=True)
    (ROOT/path).write_text(json.dumps(data,ensure_ascii=False,separators=(",",":"))+"\n")

def scaled(points, factor):
    return [[round(x*factor,2),round(y*factor,2)] for x,y in points]

def box(points):
    xs,ys=zip(*points)
    return [min(xs),min(ys),max(xs)-min(xs),max(ys)-min(ys)]

def inside(p, polygon):
    c=False
    for a,b in zip(polygon,polygon[1:]+polygon[:1]):
        if (a[1]>p[1]) != (b[1]>p[1]) and p[0]<(b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0]: c=not c
    return c

def ribbon(points,width):
    left,right=[],[]
    for i,p in enumerate(points):
        a,b=points[max(0,i-1)],points[min(len(points)-1,i+1)]
        dx,dy=b[0]-a[0],b[1]-a[1]; length=math.hypot(dx,dy)
        nx,ny=-dy/length*width/2,dx/length*width/2
        left.append([p[0]+nx,p[1]+ny]);right.append([p[0]-nx,p[1]-ny])
    return left+right[::-1]

def boundary(points,kind,width=32):
    return [{"shape":"polygon","points":ribbon([a,b],width),"kind":kind}
            for a,b in zip(points,points[1:]+points[:1])]

def region(id,name,polygon,type="combat",color="829572"):
    b=box(polygon)
    return {"id":id,"name":name,"polygon":polygon,"type":type,"color":color,
            "center":[b[0]+b[2]/2,b[1]+b[3]/2],"radius":0}

def reference(physical_size,image_size,url,status):
    return {"reference_url":url,"reference_image_dimensions":image_size,
        "image_to_world_scale":[physical_size[0]/image_size[0],physical_size[1]/image_size[1]],
        "image_to_world_offset":[0,0],"source_server_map_id":None,
        "verification_status":status,"absolute_scale_status":"provisional_not_server_calibrated",
        "server_coordinates_status":"not_recovered"}

def build_oman(definition,profiles):
    d=copy.deepcopy(definition);s=16
    floor=scaled(OMAN_FLOOR,s)
    d.update(schema_version=3,layout_revision=3,bounds=[0,0,9600,4800],
             map_name="오만의 탑 1층 · 왜곡",short_name="오만 1층",
             spawn_position=[171*s,214*s],navigable_polygons=[floor],
             surfaces=[],roads=[],water=[],bridges=[])
    d["structure_reference"]=reference([9600,4800],[600,300],OMAN_SOURCE,"historical_reference_contour_reconstructed")
    d["world_geometry"]={"void_color":"090b10","floor_material":2,
        "terrain_zones":[],"boundary_height":112,"boundary_kind":"dungeon_boundary"}
    d["collision"]=boundary(floor,"dungeon_boundary",48)
    for pit in OMAN_PITS:d["collision"].append({"shape":"polygon","points":scaled(pit,s),"kind":"dungeon_pit"})
    # Reuse the earlier authored props at perimeter stations; no new artwork.
    d["props"]=[]
    old_props=definition["props"]
    for i,(x,y) in enumerate(OMAN_FLOOR):
        if i%3:continue
        cx,cy=300,155
        v=math.hypot(cx-x,cy-y);x+=(cx-x)/v*12;y+=(cy-y)/v*12
        kind="pillar" if i%2==0 else "torch"
        original=next((r for r in old_props if r["kind"]==kind),{"kind":kind,"scale":1.0})
        p=copy.deepcopy(original);p["position"]=[round(x*s),round(y*s)];d["props"].append(p)
    for id,position in [("stairs",[133,236]),("waystone",[181,208]),("waystone",[292,160])]:
        p=copy.deepcopy(next(r for r in old_props if r["kind"]==id));p["position"]=scaled([position],s)[0];d["props"].append(p)
    entry=scaled([[149,203],[171,192],[197,207],[176,223]],s)
    d["regions"]=[region("entry","오만 1층 진입부",entry,"safe","c0b179"),region("distortion","왜곡의 전장",floor)]
    d["portal"]=[{"id":"previous","name":"황혼 산맥으로 나가기","position":[133*s,236*s],"target_map":"aden_world","target_position":[1136*40,156*40],"radius":56},
        {"id":"aden_return","name":"아덴 귀환","position":[153*s,213*s],"target_map":"aden_world","radius":56},
        {"id":"next","name":"오만 2층 이동","position":[320*s,155*s],"target_map":"oman_02","radius":56,"verification_status":"twilight_provisional_not_verified_stairs"},
        {"id":"advance_waystone","name":"지배의 균열 지점","position":[181*s,208*s],"target_map":"oman_01","target_position":[293*s,165*s],"radius":56},
        {"id":"entry_waystone","name":"진입부 이동","position":[293*s,165*s],"target_map":"oman_01","target_position":d["spawn_position"],"radius":56}]
    d["teleport"]=copy.deepcopy(d["portal"][3:]);d["npc_spawn"][0]["position"]=[185*s,223*s]
    d["route_checks"]=scaled([[90,151],[200,120],[300,80],[425,124],[511,151],[410,209],[317,252],[293,165]],s)
    d["review_points"]={"entrance":d["spawn_position"],"central":[293*s,165*s],"boss":[385*s,161*s]}
    d["safe_zone"]=["entry"];d["combat_zone"]=["distortion"];d["boss_zone"]=[]
    patch=profiles["maps"]["oman_01"]
    # Gameplay sampling sectors partition the verified floor, not invented rooms.
    sectors=[[[70,115],[160,90],[187,147],[157,187],[80,173]],
        [[170,86],[250,49],[290,98],[268,148],[193,142]],
        [[266,41],[305,20],[354,57],[345,120],[284,115]],
        [[211,150],[299,113],[366,149],[351,204],[271,232],[213,207]],
        [[361,77],[433,96],[480,127],[470,172],[388,177],[350,133]],
        [[469,128],[537,136],[559,152],[508,176],[473,188]],
        [[296,213],[365,181],[431,200],[383,237],[319,267],[269,247]]]
    for spawn,sector in zip(patch["monster_spawn"][:-1],sectors):
        poly=scaled(sector,s);spawn.update(rect=box(poly),polygon=poly,coordinate_evidence="reference_contour_sector_local_coordinates",spawn_radius=0)
    boss=patch["monster_spawn"][-1]
    boss.update(rect=box(floor),polygon=floor,spawn_radius=0,spawn_coordinates=[],spawn_region="distortion_floor",
        map_id="oman_01",floor_id=1,boss_name="왜곡의 제니스 퀸",patrol_region={"polygon":floor},encounter_region={"polygon":floor},
        source_reference=[OMAN_SOURCE,"https://lineagem.inven.co.kr/dataninfo/guide/?idx=185439"],
        verification_status={"boss_and_floor":"public_reference_confirmed","exact_spawn_area":"unverified","coordinates":"local_only","respawn":"twilight_game_seconds_not_original_schedule"},
        spawn_conditions={"policy":"twilight_local_test_encounter","original_conditions":None},
        coordinate_evidence="provisional_floor_wide_encounter_not_original_spawn_coordinates")
    patch["coordinate_note"]="참고 지도 전체 외곽 기반 로컬 다각형 구역. 정확한 M 서버 좌표·보스 리젠 구역·리젠 시간은 미확인."
    d["monster_spawn"]=copy.deepcopy(patch["monster_spawn"])
    d["art_note"]="Public historical map contour reconstructed using existing authored art. Absolute scale and server coordinates are unverified."
    return d

def build_aden(definition,profiles):
    d=copy.deepcopy(definition);s=40
    land=scaled(ADEN_LAND,s)
    d.update(schema_version=3,layout_revision=3,bounds=[0,0,48000,25120],map_name="아덴 대륙",navigable_polygons=[land])
    d["navigation"]["cell_size"]=64
    d["structure_reference"]=reference([48000,25120],[1200,628],ADEN_SOURCE,"public_worldmap_relative_geography")
    d["world_geometry"]={"void_color":"1c3840","floor_material":0,
        "terrain_zones":[{"id":id,"polygon":scaled(p,s),"material":m,"tint":t} for id,m,p,t in ADEN_ZONES],
        "boundary_height":0,"boundary_kind":"coast_boundary"}
    # Existing authored scenery remains as local clusters, relocated to matching geography.
    old_centers={r["id"]:r["center"] for r in definition["regions"]}
    targets={"town":[260*s,408*s],"meadow":[716*s,409*s],"forest":[244*s,192*s],
        "riverbank":[1030*s,365*s],"ruins":[1120*s,212*s],"boss":[365*s,80*s],"east":[920*s,198*s]}
    def relocate(p):
        id=min(old_centers,key=lambda k:math.dist(p,old_centers[k]))
        return [round(p[0]-old_centers[id][0]+targets[id][0],2),round(p[1]-old_centers[id][1]+targets[id][1],2)]
    prop_moves={}
    for pi,p in enumerate(d["props"]):
        target=relocate(p["position"])
        before=list(target)
        if not inside([target[0]/s,target[1]/s],ADEN_LAND):
            anchor=min(targets.values(),key=lambda a:math.dist(target,a))
            for i in range(1,21):
                candidate=[target[j]+(anchor[j]-target[j])*i/20 for j in range(2)]
                if inside([candidate[0]/s,candidate[1]/s],ADEN_LAND):target=candidate;break
        p["position"]=target
        prop_moves[tuple(before)]=[target[0]-before[0],target[1]-before[1]]
        if p['kind']=='house' and definition['props'][pi]['position']==[1630,3610]:
            p['asset']='aden_stone_cottage_v1'
    d["collision"]=[r for r in d["collision"] if r["kind"] not in ["water","river","mountain","bridge_rail"]]
    for c in d["collision"]:
        if c["shape"]=="circle":
            c["center"]=relocate(c["center"])
            shift=prop_moves.get(tuple(c['center']),[0,0]);c['center']=[c['center'][i]+shift[i] for i in range(2)]
        elif c["shape"]=="rect":c["rect"][:2]=relocate(c["rect"][:2])
        elif c["shape"]=="polygon":c["points"]=[relocate(p) for p in c["points"]]
    d["collision"].extend(boundary(land,"coast_boundary",32))
    d["water"]=[];d["bridges"]=[]
    for i,route in enumerate(RIVERS):
        poly=scaled(ribbon(route,5),s);d["water"].append({"polygon":poly,"deep_color":"294c58","shallow_color":"57828a"})
        # Leave navigable bridge openings at inspected road/river intersections.
        for j,(a,b) in enumerate(zip(route,route[1:])):
            if (i,j) in [(0,4),(0,11),(0,14),(1,4),(1,11),(1,12)]:continue
            d["collision"].append({"shape":"polygon","points":scaled(ribbon([a,b],4),s),"kind":"water"})
    d["roads"]=[{"id":id,"points":scaled(p,s),"width":220,"material":1,"opacity":.94} for id,p in ADEN_ROUTES]
    for x,y in [[372,258],[623,137],[714,108],[461,371],[782,330],[823,348]]:
        d["bridges"].append({"rect":[x*s-180,y*s-180,360,360],"verification_status":"reference_route_crossing_local_deck"})
    d["surfaces"]=[];d["regions"]=[]
    # Town districts use bounded polygons; broader regional labels are the terrain polygons.
    for id,(name,(x,y)) in TOWNS.items():
        poly=scaled([[x-16,y-12],[x+13,y-13],[x+20,y],[x+13,y+14],[x-18,y+12],[x-22,y]],s)
        d["regions"].append(region(id,name,poly,"safe","c5b386"))
        d["surfaces"].append({"polygon":poly,"material":2})
    names={'elf_forest':'요정 숲','western_forest':'서부 숲','dragon_valley':'용의 계곡','fire_land':'화룡의 둥지',
        'oren_snow':'오렌 설벽','twilight_mountains':'황혼 산맥','eastern_forest':'아덴 동부 숲',
        'heine_wetlands':'하이네 늪지','southern_desert':'사막 지대','western_hills':'글루디오 구릉'}
    for id,m,p,t in ADEN_ZONES:d["regions"].append(region(id,names[id],scaled(p,s),"combat",t))
    d["spawn_position"]=[260*s+850,408*s]
    for npc in d["npc_spawn"]:npc["position"]=relocate(npc["position"])
    d["portal"]=[{"id":"town_waystone","name":"기란 이동석","position":[260*s+650,408*s+220],"target_map":"aden_world","target_position":[646*s,231*s+700],"radius":56},
        {"id":"ruin_waystone","name":"글루디오 이동석","position":[646*s+700,231*s+300],"target_map":"aden_world","target_position":d["spawn_position"],"radius":56},
        {"id":"oman_gate","name":"황혼 산맥 · 오만의 탑 입구","position":[1136*s,156*s],"target_map":"oman_01","radius":68,
         "verification_status":"public_geographical_approach_local_position_not_server_coordinate"}]
    d["teleport"]=copy.deepcopy(d["portal"][:2])
    d["route_checks"]=[d["spawn_position"],[493*s,286*s],[646*s,231*s],[755*s,54*s],[1120*s,212*s],[1030*s-320,365*s+320],[488*s,479*s],[1136*s,156*s]]
    d["safe_zone"]=list(TOWNS);d["combat_zone"]=[r[0] for r in ADEN_ZONES];d["boss_zone"]=[]
    # Reuse existing vegetation in large mapped forests, with roads kept clear.
    rng=random.Random(8401011)
    for id,m,polygon,t in ADEN_ZONES:
        if "forest" not in id and id!="heine_wetlands":continue
        b=box(polygon)
        for y in range(int(b[1]),int(b[1]+b[3]),9):
            for x in range(int(b[0]),int(b[0]+b[2]),9):
                p=[x+rng.uniform(-3,3),y+rng.uniform(-3,3)]
                if not inside(p,polygon) or not inside(p,ADEN_LAND):continue
                if any(math.dist(p,v)<30 for _,v in TOWNS.values()):continue
                # Segments, not just road vertices, leave continuous lanes open.
                blocked=False
                for _,route in ADEN_ROUTES:
                    for a,bp in zip(route,route[1:]):
                        dx,dy=bp[0]-a[0],bp[1]-a[1]
                        u=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/(dx*dx+dy*dy)))
                        if math.dist(p,[a[0]+u*dx,a[1]+u*dy])<7:blocked=True;break
                    if blocked:break
                if blocked:continue
                d["props"].append({"kind":rng.choice(["oak","oak2","pine"]),"position":scaled([p],s)[0],"scale":rng.uniform(.8,1.35),"flip":bool(rng.randrange(2))})
    patch=profiles["maps"]["aden_world"]
    patch["region_labels"]=[]
    centers={"meadow":[730,390],"forest":[162,198],"riverbank":[966,326],"ruins":[285,345],
        "east":[840,203],"desert":[490,431],"bandits":[370,282],"dragon_valley":[375,78],
        "oren":[746,30],"fire_land":[553,79],"wind_land":[319,102],"boss":[365,80],
        "desert_boss":[507,439],"fire_boss":[558,76],"dragon_dense":[385,75]}
    for spawn in patch["monster_spawn"]:
        id=spawn["id"];x,y=centers[id]
        a=10 if spawn.get("mode")=="boss" else (8 if spawn.get("mode")=="dense" else 25)
        poly=scaled([[x-a,y-a*.7],[x+a,y-a],[x+a*1.1,y+a*.6],[x-a*.6,y+a]],s)
        spawn.update(rect=box(poly),polygon=poly,spawn_radius=0,coordinate_evidence="relative_geography_local_encounter_unverified_server_coordinates")
        if spawn.get("mode")=="boss":
            spawn.update(map_id="aden_world",floor_id=None,boss_name=spawn["monster_types"][0],
                spawn_coordinates=[],spawn_region=id,patrol_region={"polygon":poly},encounter_region={"polygon":poly},
                spawn_conditions={"policy":"twilight_existing_local_encounter","original_conditions":None},source_reference=[ADEN_SOURCE],
                verification_status={"exact_spawn_area":"unverified","coordinates":"local_only","respawn":"twilight_game_seconds"})
    patch["coordinate_note"]="공개 아덴 지리 지도 기준 상대 배치. 절대 축척·M 서버 좌표·보스 리젠 구역은 미검증."
    d["monster_spawn"]=copy.deepcopy(patch["monster_spawn"])
    d["minimap"]["title"]="ADEN CONTINENT"
    d["art_note"]="Reference-worldmap relative geography with preserved authored assets. Not recovered original M collision or server coordinates."
    return d

def main():
    profiles=json.loads((ROOT/'data/monsters/world_spawn_profiles.json').read_text())
    oman=json.loads((ROOT/'data/maps/oman_01.json').read_text())
    assert oman['layout_revision']==2,"Run once from the preserved PR84 baseline; do not rerun over finished maps"
    dump(Path('data/maps/oman_01.json'),build_oman(oman,profiles))
    (ROOT/'data/monsters/world_spawn_profiles.json').write_text(json.dumps(profiles,ensure_ascii=False,indent=2)+'\n')
    index=json.loads((ROOT/'data/maps/field_index.json').read_text())
    index[0]['bounds']=[0,0,9600,4800];index[0]['map_name']='오만의 탑 1층 · 왜곡'
    (ROOT/'data/maps/field_index.json').write_text(json.dumps(index,ensure_ascii=False,indent=2)+'\n')
    print('REFERENCE_WORLD_STRUCTURE_BUILT')

if __name__=='__main__':main()
