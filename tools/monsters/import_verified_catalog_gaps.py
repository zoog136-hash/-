#!/usr/bin/env python3
"""Import independently reviewed SQL identities from the existing pinned pack.
No source executables, invented tick conversion, or cross-source pixel fallback.
"""
import argparse, hashlib, importlib.util, json, zipfile
from pathlib import Path
from PIL import Image, ImageDraw
ARCHIVE_SHA='fcc4daa36165d5046275a1cb11f7a6bf9a9e4bac67571a3a861abdfd6f8f8d4c'
PREFIX='transformation_source_candidates_v1/'
SELECTION=[('45082','오크 전사','PB0025','72'),('45131','해골 창병','PB0084','70'),('45143','두다-마라 오크','PB0059','71'),('45191','다크엘프 시프','PB0168','157'),('45379','다크엘프 위자드','PB0162','74'),('45405','블랙 위자드','PB0186','19'),('45464','세마','PB0048','294')]
ROLES=['idle','walk','run','attack','hit','death']
def sha(b):return hashlib.sha256(b).hexdigest()
def jl(b):return [json.loads(l) for l in b.decode().splitlines()]
def build(archive,source,kr_path,root,work):
 assert sha(archive.read_bytes())==ARCHIVE_SHA
 work.mkdir(parents=True,exist_ok=True)
 npcs={r['fields']['npcid']:r for r in jl((source/'source_npcs.jsonl').read_bytes())}
 kr=json.loads(kr_path.read_text());entries=json.loads((root/'data/source_transform_visuals.json').read_text())['entries']
 records=[];assets={};previews=[]
 with zipfile.ZipFile(archive) as z:
  assert z.testzip() is None
  inventory={r['path']:r for r in json.loads(z.read(PREFIX+'package_files.json'))['files']}
  def read(rel):
   b=z.read(PREFIX+rel);spec=inventory[rel];assert len(b)==spec['bytes'] and sha(b)==spec['sha256'];return b
  decoder_bytes=read('decoder/spr_decode.py')
  decoder_path=work/'spr_decode.py';decoder_path.write_bytes(decoder_bytes)
  spec=importlib.util.spec_from_file_location('reviewed_gap_decoder',decoder_path);decoder=importlib.util.module_from_spec(spec);spec.loader.exec_module(decoder)
  bindings={b['binding_id']:b for b in jl(read('action_bindings.jsonl'))}
  requests={(r['source'],r['model_prefix'],r['variant_context'],r['file_suffix']):r for r in jl(read('asset_requests.jsonl'))}
  blobs={r['sha256']:r for r in jl(read('content_blobs.jsonl'))}
  for ident,name,bid,transform in SELECTION:
   row=npcs[ident];raw=row['fields'];translated=kr['rows'][ident]
   assert raw['impl']==translated['impl']=='L1Monster'
   assert (raw['gfxid'],raw['nameid'])==(translated['gfxid'],translated['nameid'])
   assert translated['name'].replace('위저드','위자드')==name
   binding=bindings[bid];assert binding['source']=='source1' and binding['definition_id'].endswith(':'+raw['gfxid'])
   codes={a['code'] for a in binding['actions']};idle=3 if 3 in codes else 0
   actions=dict(idle=idle,walk=0 if 0 in codes else idle,run=0 if 0 in codes else idle,attack=1 if 1 in codes else idle,hit=2 if 2 in codes else idle,death=8 if 8 in codes else idle)
   sprites={};tracks={};raw_refs={}
   for role,code in actions.items():
    action=next(a for a in binding['actions'] if a['code']==code)
    for facing in range(8):
     refs=[]
     for ref in action['references']:
      assert ref['group']>=0
      suffix=ref['group']+(facing+3)%8
      request=requests.get((binding['source'],binding['body_model_prefix'],binding['variant'],suffix))
      sparse_death=ident=='45464' and role=='death' and (not request or request['status']!='present')
      if sparse_death:
       assert ref['group']==32 and suffix in range(33,40)
       suffix=32;request=requests[(binding['source'],binding['body_model_prefix'],binding['variant'],suffix)]
      assert request['status']=='present' and len(request['blob_sha256'])==1
      digest=request['blob_sha256'][0];blob=blobs[digest]
      assert ref['frame']<blob['prior_frame_count']
      if digest not in sprites:
       b=read(blob['package_path']);assert sha(b)==digest and len(b)==blob['bytes'];sprites[digest]=decoder.Sprite(b)
      refs.append(dict(blob_sha256=digest,frame_index=ref['frame'],duration_raw=ref['duration_raw'],file_suffix=suffix,requested_heading=(facing+3)%8,source_heading=0 if sparse_death else (facing+3)%8,explicit_same_body_death_heading0_alias=sparse_death))
     tracks[f'{role}_{facing}']=refs
   bounds=[s.file_bounds() for s in sprites.values()];canvas=[min(b[0] for b in bounds),min(b[1] for b in bounds),max(b[2] for b in bounds),max(b[3] for b in bounds)];width,height=canvas[2]-canvas[0],canvas[3]-canvas[1]
   ident_game='l1j_tw380_npc_'+ident;directory=root/'assets/monsters/reviewed_source'/ident_game;directory.mkdir(parents=True,exist_ok=True);resource='res://'+directory.relative_to(root).as_posix()+'/'
   ext=[];ext_ids={};sub=[];animations=[];frame_count=0;phase_files={};all_pixel_hashes={};empty=[]
   prior=entries.get('transform:'+transform,{'frames_path':'res://assets/local_source_transforms/pending_'+ident+'/SpriteFrames.tres'})
   prior_dir=root/Path(prior['frames_path'][6:]).parent
   provenance=json.loads((prior_dir/'provenance.json').read_text()) if (prior_dir/'provenance.json').exists() else {'entry':{'canvas_original_grid':canvas},'tracks':[]}
   old_canvas=provenance['entry']['canvas_original_grid'];old_width=old_canvas[2]-old_canvas[0];old_height=old_canvas[3]-old_canvas[1]
   old_images={};old_poses={};counters={}
   for pose in provenance['tracks']:
    role=pose['role'];facing=pose['game_direction'];counter=(role,facing);step=counters.get(counter,0);counters[counter]=step+1
    path=prior_dir/(role+'.png')
    if path not in old_images:
     with Image.open(path) as image:old_images[path]=image.convert('RGBA')
    dx,dy=canvas[0]-old_canvas[0],canvas[1]-old_canvas[1]
    if dx<0 or dy<0 or dx+width>old_width or dy+height>old_height:continue
    region=[old_width*facing+dx,old_height*step+dy,width,height]
    image=old_images[path].crop((region[0],region[1],region[0]+width,region[1]+height))
    old_poses.setdefault((pose['blob_sha256'],pose['frame_index']),[]).append((path,region,sha(image.tobytes())))
   newly_rendered_poses={}
   for role in ['idle','walk','attack','hit','death']:
    refs_by_direction=[tracks[f'{role}_{f}'] for f in range(8)];count=len(refs_by_direction[0]);resolved={};missing=[];pending={};pixels=[]
    for facing,refs in enumerate(refs_by_direction):
     for step,ref in enumerate(refs):
      image,_=sprites[ref['blob_sha256']].render(ref['frame_index'],canvas_bounds=canvas)
      digest=sha(image.tobytes());pixels.append(digest)
      if image.getbbox() is None:empty.append(dict(role=role,facing=facing,step=step))
      if role=='idle' and step==0 and facing in [0,2,6]:previews.append((ident,name,facing,image.copy()))
      candidates=old_poses.get((ref['blob_sha256'],ref['frame_index']),[])
      exact=next(((p,r) for p,r,h in candidates if h==digest),None) or newly_rendered_poses.get(digest)
      if exact:resolved[facing,step]=exact
      else:
       pending.setdefault(digest,[]).append((facing,step))
       if len(pending[digest])==1:missing.append((facing,step,image))
    reused_count=len(resolved)
    output=directory/(role+'.png')
    if missing:
     columns=min(8,len(missing));atlas=Image.new('RGBA',(width*columns,height*((len(missing)+columns-1)//columns)))
     for index,(facing,step,image) in enumerate(missing):
      x,y=(index%columns)*width,(index//columns)*height;atlas.paste(image,(x,y));placement=(output,[x,y,width,height]);digest=sha(image.tobytes())
      newly_rendered_poses[digest]=placement
      for f,s in pending[digest]:resolved[f,s]=placement
     atlas.save(output);assets[output.relative_to(root).as_posix()]=sha(output.read_bytes())
    elif output.exists():output.unlink() # Only this tool's previously generated untracked duplicate.
    phase_files[role]=dict(reused_frames=reused_count,new_frames=len(missing),same_body_pose_aliases=8*count-reused_count-len(missing))
    all_pixel_hashes[role]=pixels
    for facing in range(8):
     refs=[]
     for step in range(count):
      path,region=resolved[facing,step];resource_path='res://'+path.relative_to(root).as_posix()
      if resource_path not in ext_ids:
       ext_ids[resource_path]=len(ext_ids)+1;ext.append(f'[ext_resource type="Texture2D" path="{resource_path}" id="{ext_ids[resource_path]}"]')
      extid=ext_ids[resource_path];key='F'+str(frame_count);frame_count+=1
      sub.append(f'[sub_resource type="AtlasTexture" id="{key}"]\natlas = ExtResource("{extid}")\nregion = Rect2({region[0]}, {region[1]}, {region[2]}, {region[3]})')
      refs.append('{"duration": 1.0, "texture": SubResource("'+key+'")}')
      tracks[f'{role}_{facing}'][step].update(texture_path=resource_path,texture_sha256=sha(path.read_bytes()),texture_region=region,rgba_sha256=pixels[facing*count+step])
     for animation_role in ([role,'run'] if role=='walk' else [role]):
      loop=str(animation_role in ['idle','walk','run']).lower();animations.append('{"name": &"'+animation_role+'_'+str(facing)+'", "speed": 8.0, "loop": '+loop+', "frames": ['+', '.join(refs)+']}')
   for facing in range(8):tracks[f'run_{facing}']=tracks[f'walk_{facing}']
   tres='\n\n'.join([f'[gd_resource type="SpriteFrames" load_steps={frame_count+len(ext)+1} format=3]',*ext,*sub,'[resource]\nanimations = [\n'+',\n'.join(animations)+'\n]'])+'\n'
   (directory/'frames.tres').write_text(tres)
   portrait_ref=tracks['idle_2'][0];portrait,_=sprites[portrait_ref['blob_sha256']].render(portrait_ref['frame_index'],canvas_bounds=canvas);portrait.save(directory/'portrait.png')
   for file in [directory/'frames.tres',directory/'portrait.png']:assets[file.relative_to(root).as_posix()]=sha(file.read_bytes())
   record=dict(name=name,sourceId=ident_game,source_id='source3:l1j-tw-99nets:L1J-TW_3.80c:Taiwan:npc:npcid:'+ident,source_npc_id=ident,source_name_original=raw['name'],source_version='3.80c',source_locale='Taiwan',source_raw_fields=raw,import_enabled=True,catalog_only=True,identity_approval='USER_REVIEWED_SQL_AND_EXISTING_BYTES_20261030',source_portrait=resource+'portrait.png',lv=int(raw['lvl']),hp=int(raw['hp']),mp=int(raw['mp']),ac=int(raw['ac']),mr=int(raw['mr']),xp=int(raw['exp']),undead=raw['undead']!='0',grade='일반',drop=[],animation_profile=dict(frames_path=resource+'frames.tres',layout='directional8',pixel_scale=1.0,authored_motion_weight=0.0,body_kind='special',sprite_offset=[canvas[0]+width/2-24,canvas[1]+height/2-18]),source_animation=dict(source='source1',binding_id=bid,body_gfx=binding['body_model_prefix'],source_gfxid=int(raw['gfxid']),anchor_is_foot=False,canvas_original_grid=canvas,tracks=tracks,actions=actions,phase_files=phase_files,phase_rgba_sha256=all_pixel_hashes,transparent_poses=empty,attachments=binding['attachments'],composition='body only; existing common shadow retained; no guessed cloth blending'),identity_review_evidence=dict(SQL=row['provenance'],korean_reference=dict(url=kr['source_url'],blob=kr['source_blob'],npc_id=ident,gfxid=raw['gfxid'],nameid=raw['nameid'],name=translated['name']),source_definition=binding['definition_id'],package_sha256=ARCHIVE_SHA,source_namespace_policy='No numeric-ID-only or cross-source image selection; exact source1 definition and literal body references',existing_catalog_dedup='Canonical species/weapon/caster role checked; region and phase variants not added'))
   if ident=='45464':record['local_named_encounter']=True
   if ident in ['45379','45405','45464']:
    record['attack_type']='magic';record['attack_range']=280;record['runtime_design']={'attack_type':'TWILIGHT caster adaptation; source spell formula and timing not converted','attack_range':'TWILIGHT existing default magic range'}
   record['runtime_limits']='Source HP/MP/AC/MR/level/XP retained; existing actor clamps/defaults remain. Presentation 8fps, original raw durations retained; no source speed/unit conversion. Explicit habitats only.'
   record['visual_grounding']={'foot_original_grid':[24,18],'policy':'TWILIGHT fixed cosmetic ground point reviewed across grounded humanoid views; not an authenticated original actor anchor'}
   record['identity_review_evidence']['actual_visual_review']={'45082':'Red crest and paired curved blades; distinct from plain island orc','45131':'Exposed skeleton with a long spear; distinct weapon from existing sword skeleton variants','45143':'Green armored orc with staff, distinct from the paired-blade fighter','45191':'White hood, dark leather and paired short blades','45379':'White hair, pale trim and long staff; visually distinct from hooded black wizard','45405':'Dark pointed hood, robe and glowing staff tip','45464':'Black hood and robe with gold trim and tall staff; source death has slot0 only, explicitly reused without generating other facings'}[ident]
   records.append(record);print(ident,name,'canvas',canvas,'sprites',len(sprites),'reused_frames',sum(f['reused_frames'] for f in phase_files.values()),'new_frames',sum(f['new_frames'] for f in phase_files.values()))
 out=dict(schema=1,texture_comparison_policy='Normalize RGB to zero under fully transparent alpha when comparing Godot fix_alpha_border output; PNG original bytes and visible RGBA remain exact',input_archive_sha256=ARCHIVE_SHA,decoder_sha256=sha(decoder_bytes),records=records,assets=assets)
 (root/'data/monsters/reviewed_source_additions.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
 preview=Image.new('RGBA',(900,len(SELECTION)*230),(35,42,48,255));draw=ImageDraw.Draw(preview)
 for i,(_,_,facing,image) in enumerate(previews):
  row=i//3;column=i%3;preview.alpha_composite(image,(column*300+150-image.width//2,row*230+150-image.height//2));draw.text((column*300+10,row*230+10),SELECTION[row][0]+' facing '+str(facing),fill='white')
 preview.save(work/'six-preview.png')
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--archive',type=Path,required=True);p.add_argument('--source-input',type=Path,required=True);p.add_argument('--korean-reference',type=Path,required=True);p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2]);p.add_argument('--work',type=Path,required=True);a=p.parse_args();build(a.archive,a.source_input,a.korean_reference,a.root,a.work)
