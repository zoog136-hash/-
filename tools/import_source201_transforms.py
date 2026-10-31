#!/usr/bin/env python3
"""Import reviewed same-identity source1 appearances from the selected input.
Opaque events and original duration values remain evidence, never gameplay code.
"""
import argparse,hashlib,importlib.util,json,re,statistics
from pathlib import Path
from PIL import Image
# card, literal definition, corroborating SQL NPC, fixed cosmetic ground Y.
SELECT=[('88',1158,'45064',16),('222',1477,'45079',21),('73',790,'45138',16),('155',1576,'45221',25),('30',1024,'45264',18),('57',1832,'45291',19),('272',4209,'45498',17),('270',4051,'45530',24),('165',4664,'45533',21),('82',4168,'45534',27),('271',4212,'45537',25),('104',4582,'45712',24),('221',4942,'45797',22),('329',5912,'81175',17)]
DECODER_SHA='615f9f89d8a8d847cf531f2b4214ee1613b39bdabbeec7248410e3f3e6a07449'
REVIEW={1158:'Named imp elder, small pale/tan long-limbed imp; classic source style, not modern card pixel equality.',1477:'Hyena-headed gnoll with spiked club and brown armor.',790:'Green orc with bow, hood and fur shoulder roll. Death alias 8=784 is opaque; never interpreted as another body.',1576:'Olive/brown hooded Death with scythe; burgundy Kent variant4095 excluded.',1024:'White-feathered harpy with human torso and talons. Fixed projected ground is below flying body, not wing/claw alignment.',1832:'Burning humanoid archer carrying a bow.',4209:'Large plated tomb construct with round shoulder plates and purple core.',4051:'Dark plated tomb mage construct with clawed arms and purple core.',4664:'Classic dark armored phantom knight with spiked helm, cape and sword. Modern card red fire is not synthesized or claimed present.',4168:'White mambo rabbit in red/purple formal clothing. Carrot variant4171 excluded.',4212:'Heavy hunched plated tomb knight with massive arms and pointed helm.',4582:'White Jindo dog with erect ears and raised curled tail; transformation only, no pet subsystem.',4942:'Horned armored minotaur with green/gold dress and a dark spiked mace verified in side views.',5912:'Named red orc Kuzak with pale fur shoulder trim and dark armor/shield.'}
ALIASES={'turn':'idle','ranged_attack':'attack','special':'attack','corpse':'death','recovery':'attack','summon':'idle','despawn':'death','float':'idle','energy':'idle','equip':'idle','unequip':'idle','activate':'idle'}
LIBRARIES=['libfile_a451565065d48191bc7b716bd7b40a2b','libfile_92edfa9d2a4c8191ac18c41323dd0209','libfile_12e4793a89108191b4f0222ce066467c','libfile_a1d369d2ce4c819188215a9ced430daa']
def sha(data):return hashlib.sha256(data).hexdigest()
def jl(path):return [json.loads(line) for line in path.read_text().splitlines()]
def build(root,inputs,baselines):
 assert sha((inputs/'decoder/spr_decode.py').read_bytes())==DECODER_SHA
 definitions={r['definition_id']:r for r in jl(inputs/'selected_action_definitions.jsonl')}
 records={}
 for row in jl(inputs/'raw_asset_records.jsonl'):
  path=inputs/row['package_blob'];data=path.read_bytes()
  assert len(data)==row['size'] and sha(data)==row['sha256']
  name=row['name'].lower()
  assert name not in records # Case-folded SPR identity; no base/shard precedence.
  records[name]=row
 for row in definitions.values():assert sha(row['raw_definition'].encode())==row['raw_definition_sha256']
 spec=importlib.util.spec_from_file_location('reviewed_source201_decoder',inputs/'decoder/spr_decode.py');decoder=importlib.util.module_from_spec(spec);spec.loader.exec_module(decoder)
 manifest_path=root/'data/source_transform_visuals.json';document=json.loads(manifest_path.read_text());prior=document['entries'].copy()
 cards={str(r['sourceId']):r for r in json.loads((root/'data/catalog_v19.json').read_text())['변신']}
 identities={r['npc_id']:r for r in json.loads((root/'data/monsters/source_identity_catalog.json').read_text())['entities']}
 for card_id,model,npc,foot_y in SELECT:
  card=cards[card_id];definition=definitions[model];identity=identities[npc]
  assert identity['korean_id_gfx_nameid_corroborated'] and int(identity['gfx_id'])==model
  assert re.sub(r'\s+','',card['name'])==re.sub(r'\s+','',identity['korean_name'])
  actions={a['id']:a for a in definition['action_definitions']};idle=3 if 3 in actions else 0
  role_codes={'idle':idle,'walk':0 if 0 in actions else idle,'run':0 if 0 in actions else idle,'attack':1 if 1 in actions else idle,'hit':2 if 2 in actions else idle,'death':8 if 8 in actions else idle,'cast':18 if 18 in actions else 1 if 1 in actions else idle}
  sequences={};sprites={};sources={}
  for role,code in role_codes.items():
   action=actions[code];refs=[tuple(map(int,r)) for r in re.findall(r'(-?\d+)\.(\d+):(-?\d+)',action['definition'])]
   declared=re.match(r'\s*\d+\s+(\d+),',action['definition']);assert declared and int(declared[1])==len(refs)
   for facing in range(8):
    track=[]
    for group,frame,duration in refs:
     assert group>=0 and duration>=0
     suffix=group+(facing+3)%8;row=records[f'{definition["base_sprite_id"]}-{suffix}.spr']
     if row['sha256'] not in sprites:
      sprites[row['sha256']]=decoder.Sprite((inputs/row['package_blob']).read_bytes());sources[row['sha256']]=row
     assert frame<len(sprites[row['sha256']].frames)
     track.append({'blob_sha256':row['sha256'],'frame_index':frame,'duration_raw':duration,'file_suffix':suffix,'requested_heading':(facing+3)%8,'source_heading':(facing+3)%8})
    sequences[f'{role}_{facing}']=track
  bounds=[sprite.file_bounds() for sprite in sprites.values()];canvas=[min(b[0] for b in bounds),min(b[1] for b in bounds),max(b[2] for b in bounds),max(b[3] for b in bounds)];width,height=canvas[2]-canvas[0],canvas[3]-canvas[1]
  unique={};images=[];tracks={};durations={};rgba=[];transparent=[]
  for track,refs in sequences.items():
   indices=[];weights=[]
   for ref in refs:
    if ref["duration_raw"]==0:continue # Preserve event-only step in provenance, not an invented visible hold.
    key=(ref['blob_sha256'],ref['frame_index'])
    if key not in unique:
     image,_=sprites[key[0]].render(key[1],canvas_bounds=canvas);unique[key]=len(images)
     if image.getbbox() is None:transparent.append(len(images))
     images.append(image);rgba.append(sha(image.tobytes()))
    indices.append(unique[key]);weights.append(ref["duration_raw"])
   assert indices
   tracks[track]=indices;durations[track]=weights
  folder=root/'assets/local_source_transforms'/f'reviewed201_{card_id}_source1';folder.mkdir(parents=True,exist_ok=True)
  columns=min(16,4096//width);per_page=min(8192//height*columns,(8*1024*1024//(width*height)//columns)*columns);assert columns>0 and per_page>0
  pages=[]
  for start in range(0,len(images),per_page):
   cells=images[start:start+per_page];atlas=Image.new('RGBA',(width*columns,height*((len(cells)+columns-1)//columns)))
   for index,image in enumerate(cells):atlas.paste(image,((index%columns)*width,(index//columns)*height))
   name=f'atlas_{len(pages):03}.png';atlas.save(folder/name);pages.append(name)
   # Verify packed output against every decoded source pose, including alpha.
   with Image.open(folder/name) as restored:
    for index,image in enumerate(cells):
     x,y=(index%columns)*width,(index//columns)*height
     assert restored.crop((x,y,x+width,y+height)).tobytes()==image.tobytes()
  prefix='res://'+folder.relative_to(root).as_posix();lines=[f'[gd_resource type="SpriteFrames" load_steps={len(images)+len(pages)+1} format=3]']
  for index,name in enumerate(pages):lines.append(f'[ext_resource type="Texture2D" path="{prefix}/{name}" id="{index+1}"]')
  placements=[]
  for index in range(len(images)):
   page,local=divmod(index,per_page);x,y=(local%columns)*width,(local//columns)*height
   lines.append(f'[sub_resource type="AtlasTexture" id="F{index}"]\natlas = ExtResource("{page+1}")\nregion = Rect2({x}, {y}, {width}, {height})\nmetadata/source_frame_index = {index}')
   placements.append({'atlas':pages[page],'region':[x,y,width,height],'rgba_sha256':rgba[index]})
  animation_tracks=dict(tracks)
  for role,base in ALIASES.items():
   for facing in range(8):
    animation_tracks[f'{role}_{facing}']=tracks[f'{base}_{facing}'];durations[f'{role}_{facing}']=durations[f'{base}_{facing}']
  animations=[]
  for key,indices in animation_tracks.items():
   cells=', '.join('{"duration":%d,"texture":SubResource("F%d")}'%(weight,index) for index,weight in zip(indices,durations[key]))
   fps=8.0*sum(durations[key])/len(durations[key])
   loop=str(key.startswith(('idle_','walk_','run_','float_','energy_','corpse_'))).lower()
   animations.append('{"name":&"%s","speed":%.12g,"loop":%s,"frames":[%s]}'%(key,fps,loop,cells))
  lines.append('[resource]\nanimations = [\n'+',\n'.join(animations)+'\n]');(folder/'SpriteFrames.tres').write_text('\n\n'.join(lines)+'\n')
  heights=[images[i].getbbox()[3]-images[i].getbbox()[1] for i in tracks['idle_2'] if images[i].getbbox()];scale=72/statistics.median(heights)
  foot=[24-canvas[0],foot_y-canvas[1]];center=[width/2,height/2]
  provenance={'schema':1,'input_library_ids':LIBRARIES,'decoder_sha256':DECODER_SHA,'definition':definition,'corroborating_source_identity':identity['source_sql'],'identity_visual_review':REVIEW[model],'role_action_codes':role_codes,'tracks':sequences,'visual_frame_durations_raw':durations,'unique_frames':placements,'transparent_frames':transparent,'source_records':list(sources.values()),'canvas_original_grid':canvas,'timing_policy':'Raw relative frame durations retained; zero-time references remain event-only provenance without an invented visible hold. Local presentation averages eight positive poses/second; original tick units remain unverified and are not converted. Gameplay attack/cast/projectile clocks and marker ratios unchanged.','unresolved_action_aliases':re.findall(r'\b\d+=\d+',definition['raw_definition']),'source_unit_conversion':False}
  (folder/'provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+'\n')
  entry={'name':card['name'],'grade':card['grade'],'frames_path':prefix+'/SpriteFrames.tres','required_layout':baselines[card_id]['layout'],'pixel_scale':scale,'sprite_offset':[(center[0]-foot[0])*.90*scale,(center[1]-foot[1])*scale],'source':'source1','source_model':model,'source_npc_id':npc,'binding_id':f'source201:definition:{model}','body_model_prefix':definition['base_sprite_id'],'identity_basis':REVIEW[model]+' Exact corroborated Korean NPC ID/gfx/nameid and source1 named definition; not numeric-ID-only identity.','game_to_source_heading':[3,4,5,6,7,0,1,2],'canvas_original_grid':canvas,'foot_in_canvas':foot,'foot_original_grid':[24,foot_y],'foot_review':'Fixed local cosmetic ground projection reviewed in source idle views. Flying harpy uses a projected ground point below the body. Original anatomical/client anchor remains unknown; collision/hit/projectile origins unchanged.','same_model_aliases':ALIASES,'role_action_codes':role_codes,'source_direction_limit':'All eight literal source headings retained. Missing native roles use explicit same-body idle/attack substitutions; opaque events/aliases are not interpreted.','timing_policy':provenance['timing_policy'],'composition_limits':'Body only; source opaque shadow/cloth blend semantics not inferred. Existing common actor shadow retained; modern fire aura not guessed.','files_sha256':{p.name:sha(p.read_bytes()) for p in folder.iterdir() if p.is_file() and not p.name.endswith('.import')},'source201_selected_input':True}
  pending={1832:[1834],4051:[4053,4054],4209:[4211],4212:[4214],4664:[4666]}
  if model in pending:entry['pending_attachment_models']=pending[model]
  key='transform:'+card_id
  if key in prior:assert prior[key]==entry,'Refuse to replace an existing reviewed identity'
  document['entries'][key]=entry;print('SOURCE201_TRANSFORM',card_id,card['name'],'definition',model,'frames',len(images),'pages',len(pages),'foot',foot,'scale',scale,flush=True)
 assert all(document['entries'][key]==value for key,value in prior.items())
 document['comparison_scope']['linked_cards']=len(document['entries']);document['remaining_candidates']=document['comparison_scope']['current_game_eligible_cards']-len(document['entries'])
 manifest_path.write_text(json.dumps(document,ensure_ascii=False,indent=2)+'\n')
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);p.add_argument('--input',type=Path,required=True);p.add_argument('--baselines',type=Path,required=True);a=p.parse_args();build(a.root,a.input,json.loads(a.baselines.read_text()))
