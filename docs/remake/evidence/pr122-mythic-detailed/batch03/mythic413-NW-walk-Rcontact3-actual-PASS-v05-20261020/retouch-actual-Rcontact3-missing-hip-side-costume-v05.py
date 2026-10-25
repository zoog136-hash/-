"""Fill only missing original hip-side material under unchanged skirt."""
from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np
P=Path(__file__).parent
S=Path('/workspace/scratch/mythic413-NW-walk-contact0-author-20261020-v01/thunder_female-NW-walk-contact0-v01-service.png')
a=np.array(Image.open(S).convert('RGBA'));o=np.array(Image.open(P/'thunder_female-NW-walk-Rcontact3-finished-local-rig-v03.png').convert('RGBA'))
m=Image.new('L',(1254,1254));ImageDraw.Draw(m).polygon([(535,714),(595,714),(594,740),(608,762),(586,792),(550,784),(533,741)],fill=255)
q=(np.asarray(m)>0)&(a[:,:,3]>40)&(o[:,:,3]<40);o[q]=a[q]
f=P/'thunder_female-NW-walk-Rcontact3-finished-hip-join-v05.png';assert not f.exists(),'Never overwrite actual completed source';Image.fromarray(o).save(f)
