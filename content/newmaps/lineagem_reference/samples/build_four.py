#!/usr/bin/env python3
"""Build a separate playable TWILIGHT project with four reference-inspired 2D maps.
NO original Lineage M map tiles/coordinates were recovered for these four maps.
The normal checkout, user save directory and other 21 maps are never modified.
"""
from __future__ import annotations
import argparse
from collections import deque
import copy
import hashlib
import json
import math
from pathlib import Path
import random
import shutil
import sys

BASE = Path("content/newmaps/lineagem_reference/samples")
IDS = ("domination_summit", "faith_04", "albino_03", "escaros_01")
NAMES = {
    "domination_summit": "지배의 탑 정상 · 확대 후 지형 연구 샘플",
    "faith_04": "신념의 탑 4층 · 라즈엘 테마 샘플",
    "albino_03": "알비노 분지 · 유황 지대 샘플",
    "escaros_01": "에스카로스 · 협곡 입구 샘플",
}
SOURCES = {
    "domination_summit": ["nc_jp_2026_domination_enlarged", "domination_2021_map"],
    "faith_04": ["nc_jp_faith_04_scene", "nc_kr_2024_faith_04", "nc_jp_faith_4floors_guide"],
    "albino_03": ["nc_kr_2024_albino_sulfur", "albino_2024_three_zones_annotated"],
    "escaros_01": ["escaros_2022_zone_1", "nc_jp_2026_escaros_touchdown"],
}

def rect(x, y, width, height):
    return [[int(x), int(y)], [int(x + width), int(y)],
            [int(x + width), int(y + height)], [int(x), int(y + height)]]

def path_rect(a, b, width):
    # All corridors are orthogonal. Overlapping room footprints make a continuous walk network.
    if a[0] == b[0]:
        return rect(a[0] - width / 2, min(a[1], b[1]) - width / 2,
                    width, abs(b[1] - a[1]) + width)
    if a[1] == b[1]:
        return rect(min(a[0], b[0]) - width / 2, a[1] - width / 2,
                    abs(b[0] - a[0]) + width, width)
    raise ValueError("Non-orthogonal corridor")

def region(id_, point, radius, type_="combat", color="bd8065"):
    return {"id": id_, "name": id_.replace("_", " "), "type": type_,
            "center": list(point), "radius": radius, "color": color}

def zone(points, material, tint):
    return {"polygon": points, "material": material, "tint": tint}

def model(map_id):
    if map_id == "domination_summit":
        boundary = [[780,900],[2110,660],[3620,820],[5420,550],[7110,910],
                    [7500,1800],[7320,3010],[7740,3970],[7200,5930],
                    [5860,6630],[3900,6370],[2710,6780],[880,6180],[550,4200],[900,2680]]
        return {
            "bounds": [0,0,8192,7168], "areas": [boundary],
            "entry": (1590,5940), "center": (3940,3910), "boss": (6130,1610),
            "roads": [
                [(1590,5940),(2760,5300),(3940,3910),(5100,2810),(6130,1610)],
                [(3940,3910),(2080,2880),(1740,1410)],
                [(5100,2810),(6790,4070),(6200,5600)]],
            "decor": [
                (1700,4760,"obelisk"),(2190,4420,"pillar"),(5800,1120,"statue"),
                (6440,1170,"pillar"),(5780,2150,"pillar"),(6650,2270,"pillar"),
                (2390,2010,"statue"),(3120,1970,"rock"),(4930,4900,"obelisk")],
            "blockers": [
                [950,3380,910,140],[2450,3260,700,160],[4800,4700,800,150],
                [5700,5900,700,140],[7100,3000,130,800]],
            "zones": [
                zone(rect(4780,900,2150,1710),3,"756087"),
                zone(rect(1090,4650,1840,1220),2,"61586c"),
                zone(rect(3120,3280,1740,1400),3,"69516c")],
            "palette": {"palette":"756785","wall_tint":"48414e","prop_tint":"a18b9f","accent":"b58cd1"},
            "floor": 2, "void": "101018",
            "foci": [(3000,5040),(4900,2950)], "safety_color": "bbad81"
        }
    if map_id == "faith_04":
        centers = [(1360,5500),(3330,5500),(3330,3470),(1390,3470),
                   (3330,1430),(5550,1430),(5550,3470)]
        room_sizes = [(1360,1160),(1530,1210),(1510,1280),(1210,1050),
                      (1480,1210),(1760,1440),(1430,1120)]
        areas = [rect(c[0]-sz[0]/2,c[1]-sz[1]/2,*sz)
                 for c,sz in zip(centers,room_sizes)]
        areas += [path_rect(centers[a],centers[b],440) for a,b in
                  ((0,1),(1,2),(2,3),(2,4),(4,5),(2,6),(6,5))]
        return {
            "bounds":[0,0,7168,6656], "areas":areas,
            "entry":centers[0], "center":centers[2], "boss":centers[5],
            "roads":[[(1360,5500),(3330,5500),(3330,3470),(3330,1430),(5610,1430)],
                     [(3330,3470),(5550,3470),(5550,1430)]],
            "decor":[(1030,5150,"pillar"),(1670,5150,"pillar"),
                     (2950,5150,"pillar"),(3710,5150,"pillar"),
                     (2940,3110,"pillar"),(3730,3110,"pillar"),
                     (2940,1780,"pillar"),(3700,1780,"pillar"),
                     (4930,930,"pillar"),(6220,930,"pillar"),
                     (4940,1920,"pillar"),(6220,1920,"pillar"),
                     (5620,2340,"statue"),(1380,3120,"statue"),
                     (5530,3140,"waystone")],
            "blockers":[[2900,2670,300,110],[3710,3970,250,110],
                        [5150,2600,180,140]],
            "zones":[zone(rect(3190,1650,260,3780),3,"8d3c46"),
                     zone(rect(3370,1300,2190,245),3,"933946"),
                     zone(rect(4730,730,1800,1300),2,"726778"),
                     zone(rect(2640,2860,1440,1230),2,"635a69")],
            "palette":{"palette":"c1aca7","wall_tint":"69616a","prop_tint":"a19b93","accent":"3fa9af"},
            "floor":2, "void":"100f17",
            "foci":[centers[1],centers[4]],"safety_color":"c0ae84"
        }
    if map_id == "albino_03":
        boundary = [[700,1110],[1970,620],[2950,950],[4250,450],[5750,730],
                    [6510,1620],[6340,3060],[6790,4320],[5890,5950],
                    [4610,6310],[3370,6010],[2300,6520],[710,5950],[450,4130],[900,2780]]
        pools=[[[1680,2290],[2350,2060],[2860,2440],[2710,3140],[1930,3330],[1510,2800]],
               [[4330,4360],[5000,4170],[5470,4610],[5270,5240],[4500,5350],[4070,4720]]]
        return {
            "bounds":[0,0,7168,6656], "areas":[boundary],
            "entry":(1330,5490),"center":(3440,3730),"boss":(5660,1420),
            "roads":[[(1330,5490),(2380,4870),(3440,3730),(4390,2900),(5660,1420)],
                     [(3440,3730),(3310,1650),(4040,1320)]],
            "decor":[(2020,4650,"rocks"),(2440,4180,"rock"),
                     (3580,5030,"rocks"),(4190,3660,"rock"),
                     (4830,2020,"pillar"),(6040,2110,"rocks"),
                     (5360,980,"obelisk"),(6170,3620,"rock"),
                     (1620,1670,"bush"),(1290,2090,"bush")],
            "blockers":[], "pool_polygons":pools,
            "zones":[zone(rect(3820,690,2440,2770),3,"aeaa57"),
                     zone(rect(830,3610,2420,2280),1,"708a71"),
                     zone(rect(2400,2990,2420,2030),2,"92936d")],
            "palette":{"palette":"a5a38a","wall_tint":"807a5a","prop_tint":"b3ac6d","accent":"c4c866"},
            "floor":2, "void":"141b16",
            "foci":[(2450,4920),(4400,2900)],"safety_color":"c0b17a"
        }
    if map_id == "escaros_01":
        boundary = [[480,4940],[1760,3680],[3160,3040],[4270,2110],[6050,1490],
                    [7400,700],[8620,1350],[8810,2480],[8070,3670],[7520,4880],
                    [6100,4600],[4550,5770],[2900,6150],[940,6480]]
        return {
            "bounds":[0,0,9216,7168], "areas":[boundary],
            "entry":(1270,5440),"center":(4320,3240),"boss":(7360,1770),
            "roads":[[(1270,5440),(2480,4600),(3560,3610),(4320,3240),
                      (5530,2680),(6670,2150),(7360,1770)],
                     [(4320,3240),(5340,4150),(6540,4070),(7520,3450)]],
            "decor":[(1810,5340,"rocks"),(2550,5180,"obelisk"),
                     (3470,2930,"rock"),(4350,2630,"rocks"),
                     (5560,2030,"pillar"),(5870,2060,"pillar"),
                     (6190,2260,"statue"),(6680,1660,"obelisk"),
                     (7890,1350,"rocks"),(7100,3040,"waystone")],
            "blockers":[[3200,4830,740,140],[5800,3580,700,160]],
            "zones":[zone(rect(5300,1500,2060,1660),3,"8a5b49"),
                     zone(rect(900,3900,2320,1980),1,"90715a"),
                     zone(rect(6810,900,1300,1860),2,"7b6262")],
            "palette":{"palette":"b39b83","wall_tint":"62534d","prop_tint":"ad957d","accent":"d39b63"},
            "floor":1, "void":"171414",
            "foci":[(3100,4020),(5580,2790)],"safety_color":"bfa77e"
        }
    raise ValueError("Not a permitted sample ID: " + map_id)

def inside(p, polygon):
    x, y = p
    hits = False
    a = polygon[-1]
    for b in polygon:
        if (a[1] > y) != (b[1] > y):
            cross = (b[0]-a[0]) * (y-a[1]) / (b[1]-a[1]) + a[0]
            if x < cross:
                hits = not hits
        a = b
    return hits

def geometry_clear(p, cfg):
    if not any(inside(p, polygon) for polygon in cfg["areas"]):
        return False
    if any(inside(p, poly) for poly in cfg.get("pool_polygons", [])):
        return False
    for x,y,w,h in cfg["blockers"]:
        if x-47 <= p[0] <= x+w+47 and y-47 <= p[1] <= y+h+47:
            return False
    return True

def route_reachable(cfg, stride=64):
    start, goal = cfg["entry"], cfg["boss"]
    b = cfg["bounds"]; w, h = b[2]//stride, b[3]//stride
    def cell(p):
        return (int(p[0]//stride), int(p[1]//stride))
    def valid(node):
        x,y=node
        return 0 <= x < w and 0 <= y < h and geometry_clear(((x+.5)*stride,(y+.5)*stride),cfg)
    begin, target=cell(start),cell(goal)
    if not valid(begin) or not valid(target):
        raise ValueError("Sample entry/boss is blocked "+str((begin,target)))
    queue=deque([begin]); visited={begin}
    while queue:
        x,y=queue.popleft()
        if (x,y)==target: return len(visited)
        for c in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
            if c not in visited and valid(c):
                visited.add(c);queue.append(c)
    raise ValueError("Sample entry disconnected from boss: "+str((begin,target)))

def generate(original, map_id):
    cfg=model(map_id)
    entry=cfg["entry"]; center=cfg["center"]; boss=cfg["boss"]
    if len(cfg["areas"]) < 1 or not original.get("monster_spawn"):
        raise ValueError("Missing main template metadata for "+map_id)
    visit=route_reachable(cfg)
    data=copy.deepcopy(original)
    data["map_name"]=NAMES[map_id]
    data["short_name"]=NAMES[map_id]
    data["bounds"]=cfg["bounds"]
    data["layout_revision"]=12104
    data["navigable_polygons"]=cfg["areas"]
    data["navigation"]["use_baked_cache"]=False
    data["navigation"]["cell_size"]=32
    data["navigation"]["clearance"]=47.0
    data["camera"]={"zoom":0.78,"follow_speed":7.0,"offset":[0,42]}
    data["spawn_position"]=list(entry)
    data["world_geometry"]={
        "boundary_height":92 if map_id=="faith_04" else 110,
        "floor_material":cfg["floor"],
        "terrain_zones":cfg["zones"],
        "void_color":cfg["void"],
        "verification":"PR121_PROTOTYPE_2026_KR_GEOMETRY_UNVERIFIED"}
    data["render_style"]={**data.get("render_style",{}),**cfg["palette"]}
    data["roads"]=[{"id":"prototype_road_"+str(i),"points":[list(p) for p in pts],
                    "width":310 if map_id!="faith_04" else 260,
                    "material":cfg["floor"],"opacity":0.18}
                   for i,pts in enumerate(cfg["roads"])]
    data["surfaces"]=[]
    data["water"]=[{"polygon":poly,"deep_color":"4e6953","shallow_color":"94a05f"}
                   for poly in cfg.get("pool_polygons",[])]
    data["bridges"]=[]
    collisions=[{"shape":"rect","rect":r,"kind":"dungeon_wall" if map_id=="faith_04" else "fortress_wall"}
                for r in cfg["blockers"]]
    collisions += [{"shape":"polygon","points":poly,"kind":"water"}
                   for poly in cfg.get("pool_polygons",[])]
    props=[]
    # Hand-placed recognisable landmarks from the research, plus low-cost original-layout dressing.
    for i,(x,y,kind) in enumerate(cfg["decor"]):
        props.append({"kind":kind,"position":[x,y],"scale":1.0+(i%3)*0.18,"flip":bool(i%2)})
        if kind in ("pillar","obelisk","rock","rocks","statue"):
            collisions.append({"shape":"circle","center":[x,y],
                               "radius":43 if kind=="pillar" else 31,"kind":kind})
    rng=random.Random(12120261016+list(IDS).index(map_id)*733)
    kinds=("rocks","rock","grass","bush","statue") if map_id in ("albino_03","escaros_01") else ("pillar","rock","statue","waystone")
    for i in range(90):
        x=rng.randrange(640,cfg["bounds"][2]-650,128)
        y=rng.randrange(570,cfg["bounds"][3]-630,128)
        if not geometry_clear((x,y),cfg):
            continue
        if math.dist((x,y),entry)<650 or math.dist((x,y),boss)<420:
            continue
        # Dressing deliberately non-colliding; never call a reference-inspired decoration an original obstacle.
        props.append({"kind":kinds[i%len(kinds)],"position":[x,y],
                      "scale":round(0.42+(i%4)*0.13,2),"flip":bool(i%2)})
    data["props"]=props
    data["collision"]=collisions
    data["regions"]=[
        region("sample_entry",entry,420,"safe",cfg["safety_color"]),
        region("sample_mid",center,700,"combat",cfg["palette"]["accent"]),
        region("sample_north",cfg["foci"][0],550,"combat",cfg["palette"]["accent"]),
        region("sample_south",cfg["foci"][1],550,"combat",cfg["palette"]["accent"]),
        region("sample_boss",boss,570,"combat","d75c5c")]
    data["safe_zone"]=["sample_entry"]
    data["combat_zone"]=["sample_mid","sample_north","sample_south"]
    data["boss_zone"]=["sample_boss"]
    data["npc_spawn"]=[{"id":"guide","name":"샘플 지역 안내자",
                        "position":[entry[0]+180,entry[1]+125],"role":"guide"}]
    data["portal"]=[{"id":"prototype_return","name":"아덴 귀환 · 샘플",
                     "position":[entry[0]-190,entry[1]+100],
                     "target_map":"aden_world","radius":56}]
    data["teleport"]=[]
    # Keep existing battle DB identifiers, but use only ONE sample group and ONE
    # current-game boss record. They are NOT confirmed Lineage M spawn positions.
    normal=next(row for row in original["monster_spawn"] if row.get("id")!="boss")
    boss_record=next(row for row in original["monster_spawn"] if row.get("id")=="boss")
    normal=copy.deepcopy(normal);boss_record=copy.deepcopy(boss_record)
    normal.update(id="sample_mid",rect=[center[0]-370,center[1]-370,740,740],
                  max_count=5,respawn_time=40,roaming_radius=120,
                  provenance="TWILIGHT_DB_TEST_SPAWN_NOT_OFFICIAL")
    boss_record.update(id="sample_boss",rect=[boss[0]-280,boss[1]-280,560,560],
                       max_count=1,respawn_time=180,roaming_radius=90,
                       provenance="TWILIGHT_DB_TEST_BOSS_NOT_OFFICIAL")
    data["monster_spawn"]=[normal,boss_record]
    data["minimap"]={"title":"PR121 2D SAMPLE","show_roads":True,"show_regions":True,"show_monsters":True}
    data["review_points"]={"entrance":list(entry),"central":list(center),"boss":list(boss)}
    data["route_checks"]=[list(center),list(boss)]
    data["hunting_paths"]={"version":0,"verification":"NOT_SOURCE_VERIFIED"}
    data["sample_metadata"]={
        "preview_only":True,"art_source":"TWILIGHT_OWNED_EXISTING_ATLAS",
        "geometry_source":"PR121_SEPARATELY_AUTHORED_PROTOTYPE",
        "korean_lineagem_2026_terrain_match":"UNVERIFIED",
        "research_source_ids":SOURCES[map_id],
        "reachable_64px_cells_offline":visit,"copied_original_polygons":False,
        "sample_boss_location_official":False}
    data["art_note"]="Original TWILIGHT reference-inspired 2D test terrain; NOT actual 2026 Lineage M geography."
    assert data["navigable_polygons"] != original["navigable_polygons"]
    assert data["collision"] != original["collision"]
    assert data["spawn_position"] != original["spawn_position"]
    assert data["navigation"]["use_baked_cache"] is False
    assert not any("albino_04" in json.dumps(p) for p in data["portal"])
    return data

def dump(path, payload):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(payload,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")

def self_test():
    sample={"navigation":{"cell_size":32},"render_style":{},
            "monster_spawn":[{"id":"normal","monster_types":["test"]},{"id":"boss","monster_types":["test_boss"]}],
            "navigable_polygons":[[[0,0],[1,0],[1,1]]],
            "collision":[{"shape":"rect","rect":[1,1,1,1]}],"spawn_position":[0,0]}
    for id_ in IDS:
        j=generate(sample,id_)
        assert j["sample_metadata"]["reachable_64px_cells_offline"]>30
        assert j["map_name"]==NAMES[id_]
        assert j["monster_spawn"][-1]["max_count"]==1
        assert len(j["props"])>=9
        assert j["layout_revision"]==12104
        print("PR121_GENERATOR_OK",id_,len(j["navigable_polygons"]),
              len(j["collision"]),len(j["props"]))
    assert len(IDS)==4 and "faith_04" in IDS and "albino_04" not in IDS

def build(root, output):
    if output.exists(): raise ValueError("Output already exists; refuse overwrite")
    if output==root or root in output.parents:
        raise ValueError("Output must be a fresh sibling outside source checkout")
    if not (root/"project.godot").is_file() or not (root/"Main.tscn").is_file():
        raise ValueError("Source must be full TWILIGHT checkout")
    # Validate source definitions BEFORE creating the copy.
    maps={}
    for id_ in IDS:
        target=root/"data/maps"/(id_+".json")
        maps[id_]=generate(json.loads(target.read_text(encoding="utf-8")),id_)
    # Do not copy git or test evidence. Do not symlink mutable source files.
    output.mkdir(parents=True)
    for name in ("project.godot","Main.tscn","assets","data","scripts",
                 "scenes","addons","content"):
        path=root/name
        if path.is_dir():
            shutil.copytree(path,output/name,
                            ignore=shutil.ignore_patterns(".godot","__pycache__","evidence","*.log"))
        else: shutil.copy2(path,output/name)
    config=output/"project.godot"
    text=config.read_text(encoding="utf-8")
    text=text.replace("[application]","[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name=\"TWILIGHT_PR121_4REGION_SAMPLE\"",1)
    config.write_text(text,encoding="utf-8")
    hashes={}
    for id_,data in maps.items():
        out=output/"data/maps"/(id_+".json")
        dump(out,data)
        hashes[id_]=hashlib.sha256(out.read_bytes()).hexdigest()
    evidence=output/BASE/"evidence";evidence.mkdir(parents=True,exist_ok=True)
    report={"status":"BUILT_NOT_GODOT_VERIFIED","maps":list(IDS),
            "map_definition_sha256":hashes,"source_main_files_mutated":False,
            "original_map_geometry_recovered":False,"current_korean_edition_match":"NOT_VERIFIED",
            "runtime":"NOT_RUN","android":"NOT_RUN",
            "geometry_provenance":"NEW_PR121_HAND_AUTHORED_2D_PROTOTYPE",
            "sample_data_only":True,"original_reference_images_redistributed":False}
    dump(evidence/"build_provenance.json",report)
    return report

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root",type=Path,default=Path(__file__).resolve().parents[4])
    parser.add_argument("--output",type=Path)
    parser.add_argument("--self-test",action="store_true")
    args=parser.parse_args()
    self_test()
    if args.self_test:return
    if args.output is None: parser.error("--output is required")
    result=build(args.root.resolve(),args.output.resolve())
    print("PR121_SAMPLE_BUILD",json.dumps(result,ensure_ascii=False))
if __name__=="__main__":
    try: main()
    except (ValueError,AssertionError,OSError) as e:
        print("PR121_SAMPLE_BLOCKED",e,file=sys.stderr)
        sys.exit(2)
