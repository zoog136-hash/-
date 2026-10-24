from pathlib import Path
import hashlib
b=Path(__file__).parent;s=(b/'author-N-run-six-actual-native-v07.py').read_text().replace('v07','v08')
old="forearm=native(selected(src,[(532,500),(565,507),(578,523),(576,540),(564,564),(550,579),(524,588),(504,610),(501,633),(486,655),(467,650),(464,628),(478,599),(490,576),(505,552),(516,524)]))"
new="""forearm_base=selected(src,[(532,500),(565,507),(578,523),(576,540),(564,564),(550,579),(524,588),(504,610),(501,633),(486,655),(467,650),(464,628),(478,599),(490,576),(505,552),(516,524)])
# Independent source QC identified the genuine western bracer filigree, not
# cloth: x503..518,y521..553 and x484..491,y575..586. Preserve this real
# ornament on the moving arm; no actual coat pixels occur in this west contour.
forearm_west=selected(src,[(458,505),(530,505),(535,565),(516,610),(502,637),(485,658),(455,658),(451,606)])
fa=np.array(forearm_base);fw=np.array(forearm_west);take=fw[:,:,3]>fa[:,:,3];fa[take]=fw[take]
forearm=native(Image.fromarray(fa))
Image.fromarray(fw).save(D/'native-original-west-bracer-filigree-semantic-material.png')"""
assert old in s;s=s.replace(old,new)
s=s.replace("actor_approvals_added=0,game_clips_adopted=0)","independent_oldarm_source_hold_closed='Complete western native bracer filigree added to moving actual LEFT forearm alpha; corresponding original fixed-body pixels removed by the same source alpha matte; genuine adjacent coat unchanged.',actor_approvals_added=0,game_clips_adopted=0)")
p=b/'author-N-run-six-actual-native-v08.py';assert not p.exists();p.write_text(s);print(hashlib.sha256(p.read_bytes()).hexdigest())
