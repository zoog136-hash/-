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
# Only the visible forearm/hand (and warrior sword) is articulated. No hidden arm is invented.
arms = {
 'warrior': {'pivot':[70,55], 'polygon':[(66,52),(72,51),(77,55),(81,57),(87,58),(90,63),(125,82),(125,93),(116,93),(79,70),(76,66),(70,63),(65,59)], 'underlay_polygon':[(65,54),(77,54),(80,58),(80,65),(72,66),(66,61)], 'underlay_source':[76,48,80,54]},
 'assassin': {'pivot':[70,69], 'polygon':[(66,66),(72,65),(74,69),(76,75),(78,80),(78,86),(72,88),(68,82),(67,76),(65,71)], 'underlay_polygon':[(67,68),(73,68),(76,75),(76,82),(71,84),(67,78)], 'underlay_source':[77,58,83,68]}
}
capes = {
 'warrior': {'pivot':[57,63], 'keep_y':67, 'polygon':[(52,61),(62,59),(61,68),(56,78),(52,84),(47,94),(42,94),(36,86),(36,73),(45,63)]},
 'assassin': {'pivot':[54,79], 'keep_y':82, 'polygon':[(48,76),(59,76),(62,79),(58,85),(51,90),(43,95),(38,99),(36,94),(39,85),(44,80)]}
}
manifest={'schema':3,'direction':'E','scope':'two humanoid skins, locomotion-only cutout pilot; joints hand-authored from visible art; hidden anatomy not reconstructed','skins':{}}
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
 for i,l in enumerate(s['legs']):
  savepart(f'thigh_{i}',l['thigh'],l['hip'],l['knee']);savepart(f'shin_{i}',l['shin'],l['knee'],l['ankle']);savepart(f'foot_{i}',l['foot'],l['ankle'])
 manifest['skins'][name]=entry
(root/'data/animation/shared_skin_pilot.json').write_text(json.dumps(manifest,indent=2)+'\n')
