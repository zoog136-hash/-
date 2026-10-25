from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json,hashlib
D=Path(__file__).resolve().parent;Q=D/'original915-complete-near-leg-native-v01';Q.mkdir();p=Path('/workspace/scratch/mythic413-NW-run-author-20261020-r001/thunder_female-NW-run-contact0-v01-service.png');I=Image.open(p).convert('RGBA');h=lambda f:hashlib.sha256(f.read_bytes()).hexdigest();assert h(p)=='915b1a2dfbaf90529bd63601a25cece5ece5dfbda5520489a38f3bdb0c1f5007'
poly=[(580,672),(600,659),(619,657),(639,662),(660,671),(680,678),(691,690),(695,710),(695,737),(698,754),(698,790),(699,819),(706,846),(720,866),(731,891),(739,914),(747,943),(748,974),(752,1007),(759,1033),(777,1058),(790,1085),(797,1113),(784,1140),(783,1193),(762,1194),(757,1175),(720,1180),(699,1177),(681,1163),(681,1135),(710,1123),(710,1073),(713,1043),(699,1007),(686,975),(670,942),(654,912),(643,884),(632,861),(622,836),(616,812),(605,786),(587,774),(577,752),(566,722),(561,693)]
foot=[(714,1051),(723,1041),(739,1039),(752,1046),(767,1058),(782,1074),(793,1092),(797,1111),(787,1124),(784,1155),(784,1194),(761,1194),(758,1177),(731,1181),(706,1179),(689,1171),(679,1159),(681,1140),(696,1132),(706,1122),(712,1094)]
def mask(poly):
 m=Image.new('L',(1254*3,1254*3));ImageDraw.Draw(m).polygon([(3*x,3*y)for x,y in poly],fill=255);return m.resize((1254,1254),Image.Resampling.LANCZOS)
LM=mask(poly);FM=mask(foot)
for name,m in [('actual-whole-upperthigh-and-boot-semantic-matte.png',LM),('actual-whole-shoe-semantic-matte.png',FM)]:m.save(Q/name)
a=np.asarray(I.getchannel('A')).astype(float)
for name,m in [('actual-complete-original-upperthigh-and-boot-shaft-native.png',np.asarray(LM).astype(float)/255*(1-np.asarray(FM).astype(float)/255)),('actual-original-complete-stiletto-native.png',np.asarray(FM).astype(float)/255)]:
 z=I.copy();z.putalpha(Image.fromarray(np.rint(a*m).astype('uint8')));z.save(Q/name)
rows=[dict(path=str(f),sha256=h(f),bytes=f.stat().st_size)for f in Q.iterdir()if f.is_file()];proof=dict(source=dict(path=str(p),sha256=h(p)),native_C=2560,density_factor=2.5,source_resampled=False,RGB_untouched_inside_semantic_mattes=True,source_anatomical_bind_proposal=dict(hip=[631,690],knee=[653,865],tarsal=[749,1068],uncertainty_native=8),purpose='actual same-actor fully visible skin upperthigh and boot material for newly revealed flight joints, not redoing existing approved clip',files=rows,approval_added=0);j=Q/'actual-complete-original-thigh-and-boot-source-contract.json';j.write_text(json.dumps(proof,indent=2)+'\n');print(json.dumps(dict(path=str(j),sha256=h(j),files=len(rows))))
