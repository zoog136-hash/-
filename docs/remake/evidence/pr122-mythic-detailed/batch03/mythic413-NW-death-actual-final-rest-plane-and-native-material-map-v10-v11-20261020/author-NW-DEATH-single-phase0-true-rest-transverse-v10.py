from pathlib import Path
import hashlib,json,numpy as np
P=Path(__file__).parent
source=P/'author-NW-DEATH-full-six-original-white-fold-restore-v08.py'
s=source.read_text()
s=s.replace("D=P/'actual-NW-DEATH6-original-white-fold-raw-v08'","D=P/'actual-NW-DEATH-single-phase0-rest-transverse-raw-v10'")
s=s.replace('for phase,st in enumerate(states):','for phase,st in [(0,states[0])]:')
old='av=te-ts;cross=np.array([-av[1],av[0],0.]);cross/=np.linalg.norm(cross)'
new='''av=te-ts;axis=av/np.linalg.norm(av)
 # True native rest-plane transverse, transported with the torso. The old
 # horizontal ground-plane cross discarded native sleeve twist and projected
 # the genuine upper cloth almost edge-on at STAGGER0.
 rest_cross=Ut*n[0]+Vt*n[1]
 cross=rest_cross-axis*np.dot(rest_cross,axis);cross/=np.linalg.norm(cross)'''
assert s.count(old)==1
s=s.replace(old,new)
s=s.replace("'raw-native-v08.png'","'raw-native-v10.png'")
s=s.replace('raw-native-v08.png','raw-native-v10.png')
s=s.replace('NW-DEATH-six-actual-native-source-common-root-and-floor-raw-contract-v08.json','NW-DEATH-single-phase0-rest-transverse-source-root-and-floor-contract-v10.json')
s=s.replace("'ACTUAL_FULL_SIX_ORIGINAL_WHITE_FOLD_RESTORED_BEFORE_VALIDATED_VOLUME_OPERATOR'","'ACTUAL_SINGLE_PHASE0_NATIVE_UPPER_REST_TWIST_CORRECTION_PENDING_QC'")
exec(compile(s,str(source),'exec'),globals())
