from PIL import Image,ImageDraw,ImageChops
from pathlib import Path
import json,hashlib,statistics
root=Path(__file__).resolve().parents[2]
out=root/'assets/actors/shared_skin_pilot'
# Source-space polygons are explicit authoring cutouts, not recovered original joints.
skins={
'warrior':{'row':3,'hip':[72,76],'body_scale':0.8,'body':[(64,20),(85,20),(86,54),(89,62),(121,85),(119,89),(81,70),(78,79),(65,78),(60,76),(54,82),(47,94),(42,94),(36,86),(36,73),(46,59),(58,43)],'legs':[
 {'hip':[69,75],'knee':[59,83],'ankle':[46,97],'toe':[50,102], 'thigh':[(65,69),(73,73),(69,82),(61,88),(55,86),(56,79)], 'shin':[(56,79),(63,83),(58,91),(50,100),(43,98),(43,94)],'foot':[(43,95),(50,96),(51,100),(54,103),(52,106),(45,104),(42,100)]},
 {'hip':[76,75],'knee':[81,84],'ankle':[82,98],'toe':[91,100], 'thigh':[(72,71),(80,72),(85,79),(85,86),(78,89),(74,83)],'shin':[(77,82),(85,82),(86,91),(86,99),(79,101),(77,92)],'foot':[(79,96),(86,96),(89,99),(94,99),(94,102),(87,105),(80,105),(78,102)]}]},
'assassin':{'row':2,'hip':[75,79],'body_scale':0.95,'body':[(69,32),(82,33),(88,38),(88,47),(83,53),(83,64),(87,73),(88,80),(81,84),(73,86),(67,83),(60,86),(52,90),(42,94),(38,99),(37,92),(42,82),(54,73),(43,75),(52,67),(61,59),(66,48)],'legs':[
 {'hip':[70,83],'knee':[65,92],'ankle':[60,101],'toe':[64,104], 'thigh':[(65,79),(74,82),(71,89),(67,96),(61,94),(60,89)],'shin':[(61,89),(68,93),(65,98),(63,103),(58,104),(56,100)],'foot':[(57,100),(64,100),(64,103),(68,105),(67,108),(60,107),(56,104)]},
 {'hip':[80,79],'knee':[89,84],'ankle':[88,96],'toe':[94,99], 'thigh':[(77,75),(84,76),(93,82),(94,87),(87,91),(82,86)],'shin':[(86,83),(93,84),(93,91),(91,98),(85,100),(84,94)],'foot':[(85,94),(91,94),(92,97),(97,98),(98,101),(90,102),(84,100)]}]}}
# Legacy forearm masks remain available; the shared rig below splits visible upper arm, forearm and hand/weapon.
arms = {
 'warrior': {'pivot':[70,55], 'polygon':[(66,52),(72,51),(77,55),(81,57),(87,58),(90,63),(125,82),(125,93),(116,93),(79,70),(76,66),(70,63),(65,59)], 'underlay_polygon':[(65,54),(77,54),(80,58),(80,65),(72,66),(66,61)], 'underlay_source':[76,48,80,54]},
 'assassin': {'pivot':[70,69], 'polygon':[(66,66),(72,65),(74,69),(76,75),(78,80),(78,86),(72,88),(68,82),(67,76),(65,71)], 'underlay_polygon':[(67,68),(73,68),(76,75),(76,82),(71,84),(67,78)], 'underlay_source':[77,58,83,68]}
}
capes = {
 'warrior': {'pivot':[57,63], 'keep_y':67, 'polygon':[(52,61),(62,59),(61,68),(56,78),(52,84),(47,94),(42,94),(36,86),(36,73),(45,63)]},
 'assassin': {'pivot':[54,79], 'keep_y':82, 'polygon':[(48,76),(59,76),(62,79),(58,85),(51,90),(43,95),(38,99),(36,94),(39,85),(44,80)]}
}
rigs = {
 'warrior': {'waist':[72,61], 'neck':[75,40], 'shoulder':[72,45], 'elbow':[70,55], 'wrist':[80,62],
 'upper':[(68,39),(77,40),(80,46),(77,53),(74,58),(67,57),(65,51),(65,45)],
 'forearm':[(66,52),(72,51),(77,55),(80,58),(79,61),(74,64),(70,63),(65,59)],
 'weapon':[(76,57),(84,57),(90,63),(125,82),(125,93),(116,93),(79,70),(75,65)],'weapon_pivot':[80,62],'weapon_tip':[119,87],
 'upper_fill':[(67,44),(77,44),(79,52),(77,58),(68,58),(65,51)],'blade_cut':[]},
 'assassin': {'waist':[75,67], 'neck':[77,53], 'shoulder':[73,56], 'elbow':[70,69], 'wrist':[73,79],
 'upper':[(68,50),(77,51),(79,56),(75,63),(73,69),(66,69),(65,64),(66,56)],
 'forearm':[(66,66),(72,65),(74,69),(75,75),(75,79),(71,81),(67,76),(65,71)],
 'weapon':[(59,59),(65,60),(66,64),(60,68),(44,76),(39,75),(42,70),(55,62)],'weapon_pivot':[60,64],'weapon_tip':[43,73],
 'upper_fill':[(68,53),(77,54),(78,61),(75,68),(67,69),(66,62)],
 'blade_cut':[(39,75),(42,69),(57,61),(60,64),(54,71),(44,77)]}
}
far_arms = {
 'warrior': {'pivot':[82,45], 'polygon':[(79,42),(85,43),(87,49),(86,54),(89,58),(88,63),(84,67),(79,65),(78,59),(80,54),(78,48)], 'underlay':[(79,45),(83,45),(83,58),(81,63),(78,59)]},
 'assassin': {'pivot':[65,56], 'polygon':[(61,54),(68,55),(69,60),(66,64),(63,68),(57,69),(54,65),(58,61)], 'underlay':[(64,56),(68,57),(68,63),(64,66),(62,62)]}
}
manifest={'schema':5,'direction':'E','scope':'two humanoid skins, shared idle/run/attack pilot; authored visible-part rig, not source-game motion or recovered hidden anatomy','skins':{}}
for name,s in skins.items():
 source=root/f'assets/sprites/classes/{name}.png';im=Image.open(source).convert('RGBA').crop((0,s['row']*116,148,(s['row']+1)*116));folder=out/name;folder.mkdir(exist_ok=True)
 entry={'source':str(source.relative_to(root)),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'source_cell':[0,s['row']*116,148,116],'hip':s['hip'],'body_scale':s['body_scale'],'parts':{}}
 def savepart(key,poly,pivot,end=None):
  mask=Image.new('L',im.size);ImageDraw.Draw(mask).polygon(poly,fill=255);part=im.copy();part.putalpha(ImageChops.multiply(im.getchannel('A'),mask));path=folder/(key+'.png');part.save(path)
  sole_y = part.getchannel('A').getbbox()[3] - 1 if key.startswith('foot_') else None
  entry['parts'][key]={'sole_y':sole_y,'texture':'res://'+str(path.relative_to(root)),'pivot':pivot,'end':end,'polygon':poly,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
 savepart('body',s['body'],s['hip'])
 arm=arms[name]
 savepart('arm',arm['polygon'],arm['pivot'])
 body_path=folder/'body.png';body=Image.open(body_path).convert('RGBA')
 arm_mask=Image.new('L',im.size);ImageDraw.Draw(arm_mask).polygon(arm['polygon'],fill=255)
 body.putalpha(ImageChops.subtract(body.getchannel('A'),arm_mask))
 # A small, explicitly authored armor underlay is sampled from visible torso material.
 # It is restricted to the old opaque torso footprint; sword/background pixels are never filled.
 fill_mask=Image.new('L',im.size);ImageDraw.Draw(fill_mask).polygon(arm['underlay_polygon'],fill=255)
 fill_mask=ImageChops.multiply(fill_mask,im.getchannel('A').point(lambda a:255 if a>=240 else 0))
 fill_mask=ImageChops.multiply(fill_mask,arm_mask)
 patch=im.crop(tuple(arm['underlay_source']))
 sample=list(patch.getdata())
 color=tuple(int(statistics.median(p[c] for p in sample)) for c in range(3))+(255,)
 fill=Image.new('RGBA',im.size,color)
 fill.putalpha(fill_mask)
 body=Image.alpha_composite(body,fill);body.save(body_path)
 cape=capes[name]
 savepart('cape',cape['polygon'],cape['pivot'])
 cape_mask=Image.new('L',im.size);ImageDraw.Draw(cape_mask).polygon(cape['polygon'],fill=255)
 ImageDraw.Draw(cape_mask).rectangle((0,0,im.width,cape['keep_y']),fill=0)
 body.putalpha(ImageChops.subtract(body.getchannel('A'),cape_mask));body.save(body_path)
 entry['parts']['body']['subtract_cape']={'polygon':cape['polygon'],'keep_y':cape['keep_y']}
 entry['parts']['body']['sha256']=hashlib.sha256(body_path.read_bytes()).hexdigest()
 entry['parts']['body']['subtract_polygon']=arm['polygon']
 entry['parts']['body']['authored_underlay']={'polygon':arm['underlay_polygon'],'source_rect':arm['underlay_source'],'method':'flat armor underpaint using median visible torso color, restricted to original opaque footprint; new authoring, not recovered anatomy'}
 rig=rigs[name]
 savepart('upper_arm',rig['upper'],rig['shoulder'],rig['elbow'])
 savepart('forearm',rig['forearm'],rig['elbow'],rig['wrist'])
 savepart('weapon_hand',rig['weapon'],rig['weapon_pivot'],rig['weapon_tip'])
 upper_mask=Image.new('L',im.size);ImageDraw.Draw(upper_mask).polygon(rig['upper'],fill=255)
 body.putalpha(ImageChops.subtract(body.getchannel('A'),upper_mask))
 upper_fill=Image.new('L',im.size);ImageDraw.Draw(upper_fill).polygon(rig['upper_fill'],fill=255)
 upper_fill=ImageChops.multiply(upper_fill,upper_mask)
 upper_fill=ImageChops.multiply(upper_fill,im.getchannel('A').point(lambda a:255 if a>=240 else 0))
 fill=Image.new('RGBA',im.size,color);fill.putalpha(upper_fill);body=Image.alpha_composite(body,fill)
 if rig['blade_cut']:
  cut=Image.new('L',im.size);ImageDraw.Draw(cut).polygon(rig['blade_cut'],fill=255)
  body.putalpha(ImageChops.subtract(body.getchannel('A'),cut))
 far=far_arms[name]
 savepart('far_arm',far['polygon'],far['pivot'])
 # The assassin blade was rebound to the near hand. Remove its overlapping sliver here.
 if name == 'assassin':
  exclude=[(39,75),(42,69),(57,61),(59,64),(54,71),(44,77)]
  exclusion=Image.new('L',im.size);ImageDraw.Draw(exclusion).polygon(exclude,fill=255)
  far_path=folder/'far_arm.png';part=Image.open(far_path).convert('RGBA')
  part.putalpha(ImageChops.subtract(part.getchannel('A'),exclusion));part.save(far_path)
  entry['parts']['far_arm']['exclude_polygon']=exclude
  entry['parts']['far_arm']['sha256']=hashlib.sha256(far_path.read_bytes()).hexdigest()
 far_mask=Image.new('L',im.size);ImageDraw.Draw(far_mask).polygon(far['polygon'],fill=255)
 body.putalpha(ImageChops.subtract(body.getchannel('A'),far_mask))
 under=Image.new('L',im.size);ImageDraw.Draw(under).polygon(far['underlay'],fill=255)
 under=ImageChops.multiply(under,far_mask)
 under=ImageChops.multiply(under,im.getchannel('A').point(lambda a:255 if a>=240 else 0))
 fill=Image.new('RGBA',im.size,color);fill.putalpha(under);body=Image.alpha_composite(body,fill)
 entry['parts']['body']['far_arm_cut']=far['polygon']
 entry['parts']['body']['far_arm_underlay']=far['underlay']
 body.save(body_path)
 entry['parts']['body']['additional_cut']=rig['upper']
 entry['parts']['body']['additional_underlay']=rig['upper_fill']
 entry['parts']['body']['blade_cut']=rig['blade_cut']
 entry['parts']['body']['sha256']=hashlib.sha256(body_path.read_bytes()).hexdigest()
 entry['rig']={'waist':rig['waist'],'neck':rig['neck'],'weapon_hand_source':'visible attached hand and weapon; assassin blade rebound to near hand for this authored rig'}
 for key,rect,pivot in [('head',(0,0,148,rig['neck'][1]+3),rig['neck']),('torso',(0,rig['neck'][1]-2,148,rig['waist'][1]+7),rig['waist']),('pelvis',(0,rig['waist'][1]+2,148,116),s['hip'])]:
  mask=Image.new('L',im.size);ImageDraw.Draw(mask).rectangle(rect,fill=255)
  part=body.copy();part.putalpha(ImageChops.multiply(body.getchannel('A'),mask));path=folder/(key+'.png');part.save(path)
  entry['parts'][key]={'texture':'res://'+str(path.relative_to(root)),'pivot':pivot,'derived_from':'body','partition_rect':list(rect),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
 for i,l in enumerate(s['legs']):
  savepart(f'thigh_{i}',l['thigh'],l['hip'],l['knee']);savepart(f'shin_{i}',l['shin'],l['knee'],l['ankle']);savepart(f'foot_{i}',l['foot'],l['ankle'])
 manifest['skins'][name]=entry
(root/'data/animation/shared_skin_pilot.json').write_text(json.dumps(manifest,indent=2)+'\n')
