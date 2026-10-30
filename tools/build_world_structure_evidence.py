"""Collect actual viewport evidence and explicit map/boss/reference coverage."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/world-structure-20261011/evidence'
SOURCES={
 'aden':{'url':'https://games.app-liv.jp/archives/397568','image_url':'https://games.app-liv.jp/images/articles/2019/03/gd_397568_-1.jpg','date':'2019-03-27','scope':'relative continent geography; not current server collision or absolute scale'},
 'oman_map':{'url':'https://www.gamechosun.co.kr/webzine/article/view.php?no=145842','image_url':'https://www.gamechosun.co.kr/dataroom/article/20180126/145842/lin12.jpg','date':'2018-01-26','scope':'historical whole-floor perimeter, entrance and two pits; modern changes not verified'},
 'tower_counts':{'url':'https://lounge.plaync.com/feed/35343?country=KR&locale=ko-KR','date':'2025-06-18','scope':'official Oman 1-10 and Faith 1-4 listing; no floor dimensions or server IDs'},
 'domination':{'url':'https://lineagem-jp.com/guides/lm/guides/dungeon_TowerofDomination','scope':'official JP entrance/summit and entry conditions; Korean current geometry unverified'},
 'boss_oman1':{'url':'https://lineagem.inven.co.kr/dataninfo/guide/?idx=185439','scope':'boss/floor roster; historical schedule must not be used as current timing'},
}

def write(path,value):
 path.parent.mkdir(parents=True,exist_ok=True)
 path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')

def contact(directory,ids,path):
 im=Image.new('RGB',(1600,((len(ids)+4)//5)*204),'#13191e');d=ImageDraw.Draw(im)
 for i,id in enumerate(ids):
  source=directory/(id+'-whole.jpg')
  assert source.is_file(),source
  pic=Image.open(source);pic.thumbnail((320,180))
  x,y=i%5*320,i//5*204
  d.text((x+6,y+3),id,fill='#ede0be');im.paste(pic,(x+(320-pic.width)//2,y+24))
 im.save(path,quality=91)

def pair(id):
 im=Image.new('RGB',(1600,476),'#12191f');d=ImageDraw.Draw(im)
 for i,phase in enumerate(['before','after']):
  pic=Image.open(OUT/phase/(id+'-whole.jpg'));pic.thumbnail((800,450))
  d.text((i*800+8,5),id+' / '+phase+' / fit-to-map camera',fill='#eee3cc')
  im.paste(pic,(i*800+(800-pic.width)//2,26+(450-pic.height)//2))
 im.save(OUT/(id+'-before-after.jpg'),quality=93)

def catalog():
 entries=[]
 entries+=json.loads((ROOT/'data/maps/field_index.json').read_text())
 profiles=json.loads((ROOT/'data/monsters/world_spawn_profiles.json').read_text())
 monster_catalog=json.loads((ROOT/'data/monsters/monster_world_catalog.json').read_text())
 maps=[];bosses=[]
 for entry in entries:
  d=json.loads((ROOT/entry['path'].removeprefix('res://')).read_text())
  explicit=d.get('structure_reference',{})
  maps.append({'map_id':d['map_id'],'name':d['map_name'],'path':entry['path'],'family':d.get('family','aden'),
   'floor_id':d.get('floor'),'bounds':d['bounds'],'navigation_cell':d['navigation']['cell_size'],
   'structure_status':explicit.get('verification_status','legacy_authored_layout_unverified_against_M'),
   'source_server_map_id':explicit.get('source_server_map_id'),'absolute_scale_status':explicit.get('absolute_scale_status','unverified'),
   'entrance':d['spawn_position'],'exits':[{'id':p['id'],'position':p['position'],'target':p['target_map'],'verification':p.get('verification_status','twilight_connection_not_original_verified')} for p in d['portal']],
   'geometry_polygons':d.get('navigable_polygons',[]),'source_reference':explicit.get('reference_url')})
  for spawn in profiles['maps'].get(d['map_id'],{}).get('monster_spawn',d['monster_spawn']):
   if spawn.get('mode')!='boss':continue
   name=spawn['monster_types'][0]
   bosses.append({'boss_id':spawn.get('boss_id',name),'boss_name':name,'map_id':d['map_id'],'floor_id':d.get('floor'),
    'spawn_region':{'polygon':spawn['polygon']} if 'polygon' in spawn else {'rect':spawn['rect']},
    'spawn_coordinates':spawn.get('spawn_coordinates',[]),'spawn_conditions':spawn.get('spawn_conditions',{'policy':'existing_twilight_local_encounter'}),
    'respawn_policy':spawn.get('respawn_policy','game_seconds'),'respawn_seconds_local':spawn['respawn_time'],
    'patrol_region':spawn.get('patrol_region',{'local_roaming_radius':spawn.get('roaming_radius')}),
    'encounter_region':spawn.get('encounter_region',{'rect':spawn['rect']}),
    'source_reference':spawn.get('source_reference',[monster_catalog['sources'].get(spawn.get('roster_evidence',''),None)]),
    'verification_status':spawn.get('verification_status',{'coordinates':'unverified_local_world','exact_spawn_area':'unverified','respawn':'local_policy'})})
 result={'baseline_sha':'ba95f3797f42103c72211f87b242c795eddecb1d','sources':SOURCES,'maps':maps,'boss_bindings':bosses,
  'towers':{'oman':{'confirmed_numbered_floors':list(range(1,11)),'reconstructed_contours':['oman_01'],'remaining_unverified':[f'oman_{i:02d}' for i in range(2,11)],'source':'tower_counts'},
   'faith':{'confirmed_numbered_floors':[1,2,3,4],'reconstructed_contours':[],'source':'tower_counts'},
   'domination':{'verified_JP_sections':['entrance','summit'],'implemented_legacy_maps':['domination_summit'],'reconstructed_contours':[],
    'korean_current_full_floor_count':None,'source':'domination','note':'Do not invent M floors from PC L1J 1-100F IDs'}},
  'game_server':'none_offline_Godot','M_server_coordinate_bindings_verified':0,'M_exact_boss_spawn_areas_verified':0,
  'limits':['Reference-image affine units are not recovered server tiles','No original image or navigation pack is embedded','Whole-map viewport success does not mean original map completion']}
 write(ROOT/'data/maps/world_reference_catalog.json',result)
 return [m['map_id'] for m in maps]

def main():
 ids=catalog()
 assert len(ids)==25
 contact(OUT/'before',ids,OUT/'before-contact-sheet.jpg');contact(OUT/'after',ids,OUT/'after-contact-sheet.jpg')
 for family in ['oman','faith','domination']:
  contact(OUT/'after',[id for id in ids if id.startswith(family)],OUT/(family+'-floor-sheet.jpg'))
 for id in ['aden_world','oman_01']:pair(id)
 manifest=[]
 for phase in ['before','after']:
  captures=json.loads((OUT/phase/'captures.json').read_text())
  for row in captures['captures']:
   p=OUT/phase/row['file'];manifest.append({**row,'phase':phase,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
  for p in (OUT/phase).glob('*-map-ui.jpg'):
   manifest.append({'map_id':p.name.removesuffix('-map-ui.jpg'),'label':'map-ui','file':p.name,'phase':phase,
     'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
 write(OUT/'manifest.json',{'captures':manifest,'scope':'25 full-map before/after viewports and two playable-camera pairs. Full-map fits use each map extent; they are not identical absolute cameras.'})
 print('WORLD_STRUCTURE_EVIDENCE_OK',len(manifest))

if __name__=='__main__':main()
