"""Reproduce native actual hip skin join retouch; no anatomy/root/alpha move."""
from pathlib import Path
from PIL import Image
import numpy as np
P=Path(__file__).parent
S=Path('/workspace/scratch/mythic413-NW-walk-contact0-author-20261020-v01/left-backswing-native-edit-v02/thunder_female-NW-walk-contact0-LEFTbackswing-bounded-v02.png')
a=np.array(Image.open(S).convert('RGBA'));o=np.array(Image.open(P/'thunder_female-NW-walk-LOAD1-rigged-v03.png').convert('RGBA'))
y,x=np.indices(o.shape[:2])
def skin(z):return(z[:,:,0]>140)&(z[:,:,1]>90)&(z[:,:,2]>55)&(z[:,:,0]>z[:,:,1]*1.08)&(z[:,:,1]>z[:,:,2]*1.05)&(z[:,:,3]>240)
m=skin(a)&skin(o)&(x>535)&(x<700)&(y>=714)&(y<734);w=np.clip((734-y)/20.,0.,1.)
for c in range(3):o[:,:,c][m]=np.rint(o[:,:,c][m]*(1-w[m])+a[:,:,c][m]*w[m]).astype(np.uint8)
f=P/'thunder_female-NW-walk-LOAD1-rigged-retouched-v04.png'
assert not f.exists(),'Never overwrite original completed production PNG'
Image.fromarray(o).save(f)
