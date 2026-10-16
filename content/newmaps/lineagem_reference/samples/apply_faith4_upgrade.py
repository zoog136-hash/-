#!/usr/bin/env python3
"""Safely wire the Faith 4F 2D architecture into PR121's isolated sample builder.
This patches PR121 files ONLY. Never changes TWILIGHT's main scene or real map data.
"""
from pathlib import Path
import sys

HERE=Path(__file__).resolve().parent
BUILD=HERE/'build_four.py'
RUN=HERE/'run_four.gd'
NEEDLE = '    data["props"]=props\n    data["collision"]=collisions\n'
INSERT = '''    data["props"]=props
    data["collision"]=collisions
    if map_id == "faith_04":
        # No recycled placeholder props. All visible scenery uses a bespoke
        # Godot 2D sprite hierarchy with collision-aligned world coordinates.
        architecture=json.loads((Path(__file__).resolve().parent/"faith4_layout.json").read_text(encoding="utf-8"))
        assert architecture["id"]=="faith_04"
        fresh=[]
        for row in architecture["walls"]+architecture["rails"]:
            fresh.append({"shape":"rect","rect":row["collision"],"kind":"dungeon_wall"})
        for x,y,scale in architecture["pillars"]:
            fresh.append({"shape":"circle","center":[x,y],"radius":43*scale,"kind":"pillar"})
        for x,y,scale in architecture["statues"]:
            fresh.append({"shape":"circle","center":[x,y],"radius":42*scale,"kind":"statue"})
        for x,y,scale in architecture["altars"]:
            fresh.append({"shape":"circle","center":[x,y],"radius":44*scale,"kind":"altar"})
        data["props"]=[]
        data["collision"]=fresh
        data["sample_art_status"]="FAITH4_DEDICATED_ARCHITECTURE_V3"
'''
RENDER_ORIGINAL='\t\telif field_map is AuthoredRemakeField: field_renderer = preload("res://scripts/maps/authored_remake_renderer.gd").new()'
RENDER_REPLACEMENT='\t\telif field_map is AuthoredRemakeField: field_renderer = preload("res://content/newmaps/lineagem_reference/samples/faith4_renderer.gd").new() if map_id == "faith_04" else preload("res://scripts/maps/authored_remake_renderer.gd").new()'
MARKER='    config=output/"project.godot"\n'
WORLD_PATCH='''    # Only rewrite the isolated copy. Original scripts/world.gd remains byte-identical.
    world_src=output/"scripts/world.gd"
    world_text=world_src.read_text(encoding="utf-8")
    old='\t\telif field_map is AuthoredRemakeField: field_renderer = preload("res://scripts/maps/authored_remake_renderer.gd").new()'
    new='\t\telif field_map is AuthoredRemakeField: field_renderer = preload("res://content/newmaps/lineagem_reference/samples/faith4_renderer.gd").new() if map_id == "faith_04" else preload("res://scripts/maps/authored_remake_renderer.gd").new()'
    if world_text.count(old) != 1: raise ValueError("TWILIGHT world renderer call changed: do not patch blind")
    world_src.write_text(world_text.replace(old,new,1),encoding="utf-8")
    # Recreate all original authored 2D sprites from source. This allows PR121
    # to hold only small text files; unlicensed original game images are not used.
    import subprocess
    import sys
    assets_dir=output/"content/newmaps/lineagem_reference/samples/assets/faith04"
    subprocess.run([sys.executable,str(output/"content/newmaps/lineagem_reference/samples/make_faith_art.py"),str(assets_dir)],check=True)
    # Stop rather than render a placeholder if a visual source is absent.
    for required in ("floor_tile.png","carpet_tile.png","teal_pillar.png","gothic_wall.png","balustrade.png","ritual_ring.png","teal_glow.png"):
        if not (output/"content/newmaps/lineagem_reference/samples/assets/faith04"/required).is_file():
            raise ValueError("Missing authored sprite atlas: " + required)
'''
CHECK='''\t\tif id == "faith_04":
\t\t\tvar art: Node = world.field_renderer.get_node_or_null("Faith4ArchitecturalEnvironment")
\t\t\tcheck(art != null,"Faith4 bespoke 2D architecture attached to Main")
\t\t\tif art != null:
\t\t\t\tcheck(int(art.get("sprites_spawned")) >= 45,"Faith4 rendered architectural objects")
\t\t\t\tcheck(int(art.get("floor_surfaces")) >= 19,"Faith4 stone/carpet layers")
\t\t\tcheck(field.blockers.size() >= 24,"Faith4 navigation collision matches art")
'''
CHECK_POINT='\t\tworld.portal_cooldown = 9999.0\n'

def replace_once(text,source,dest,path):
    if dest in text:return text,False
    n=text.count(source)
    if n!=1:raise RuntimeError(f"{path}: expected exactly one anchor but got {n}")
    return text.replace(source,dest,1),True

def main():
    for needed in (BUILD,RUN,HERE/'faith4_scene_art.gd',HERE/'faith4_renderer.gd',HERE/'faith4_layout.json'):
        if not needed.is_file():raise FileNotFoundError(needed)
    edits=[]
    s=BUILD.read_text(encoding='utf-8')
    s,changed=replace_once(s,NEEDLE,INSERT,str(BUILD));edits.append((BUILD,s,changed))
    # Place copy-side integration after the copied project exists, before project.godot customization.
    s,changed=replace_once(s,MARKER,WORLD_PATCH+MARKER,str(BUILD));edits.append((BUILD,s,changed))
    r=RUN.read_text(encoding='utf-8')
    r,changed=replace_once(r,CHECK_POINT,CHECK+CHECK_POINT,str(RUN));edits.append((RUN,r,changed))
    # No writes until ALL patch anchoring checks pass.
    bypath={}
    for path,text,changed in edits:bypath[path]=text
    for path,text in bypath.items():path.write_text(text,encoding='utf-8')
    print('FAITH4_2D_ARCHITECTURE_WIRED',str(BUILD),str(RUN))

if __name__=='__main__':
    try:main()
    except (OSError,RuntimeError) as e:
        print('FAITH4_PATCH_BLOCKED',e,file=sys.stderr)
        raise SystemExit(2)
