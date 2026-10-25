from pathlib import Path
import hashlib
b=Path(__file__).parent
s=(b/'author-N-run-six-actual-native-v05.py').read_text().replace('v05','v06')
s=s.replace('thigh=ypart(right,640,793)\ncalf=ypart(right,780,896)', '''# Source endpoints stop at the actual knee. The rounded native leather joint
# is a separate real material cap, not extrapolated endpoint UV.
thigh=ypart(right,640,788)
calf=ypart(right,787,896)
km=Image.new('L',right.size);ImageDraw.Draw(km).ellipse((651,765,707,809),fill=255)
ka=np.array(right);ka[:,:,3]=np.minimum(ka[:,:,3],np.array(km));ka[ka[:,:,3]==0,:3]=0
knee_cap=native(Image.fromarray(ka))''')
s=s.replace("forearm=native(sources['complete-original-native-LEFT-forearm-hand-bracer-ornament-material.png'])",'''# Complete native cuff/brace shell belongs to the moving free arm. The former
# handoff omitted the curved white/gold cuff x535..578, y520..574. Its genuine
# source contour is moved, and the straight blue/gold coat edge is untouched.
forearm=native(selected(src,[(532,500),(565,507),(578,523),(576,540),(564,564),(550,579),(524,588),(504,610),(501,633),(486,655),(467,650),(464,628),(478,599),(490,576),(505,552),(516,524)]))
forearm.save(D/'native-complete-freeLEFT-forearm-cuff-hand-material.png')
Image.fromarray(np.array(forearm)[:,:,3]).save(D/'native-complete-freeLEFT-forearm-cuff-hand-semantic-matte.png')''')
s=s.replace("('native-calf-material',calf)","('native-calf-material',calf),('native-rounded-knee-leather-material',knee_cap)")
s=s.replace("leg.alpha_composite(affine_bone(calf,[679,787],[678,895],kne,ankle,-1 if side=='L' else 1))",'''# The narrow front-facing tarsal leather fits under its complete source
  # shoe armor. This is the paired material's fixed transverse projection.
  leather_parity=(-1 if side=='L' else 1)/(0.8 if x['shoe']=='front' else 1.)
  leg.alpha_composite(affine_bone(calf,[679,787],[678,895],kne,ankle,leather_parity))
  kaxis=np.array(ankle)-np.array(kne);kaxis=kaxis/np.linalg.norm(kaxis)
  leg.alpha_composite(affine_bone(knee_cap,[679,787],[679,809],kne,(np.array(kne)+22*kaxis).tolist(),-1 if side=='L' else 1))''')
s=s.replace("UV='No t-clamp; inverse map samples alpha-bounded semantic real material, each bone region preclipped with <=7px joint overlap.","UV='No t-clamp; inverse map samples alpha-bounded semantic real material, each bone region preclipped at its actual knee endpoint with native rounded leather joint surface.")
s=s.replace("actor_approvals_added=0,game_clips_adopted=0)","actual_joint_finish='Complete original LEFT cuff/bracer/hand native contour moves with arm; old arm shell removed by its semantic matte. Rounded knee uses actual native black/gold leather, source endpoints stop at knee. Front tarsal leather transverse projection 0.8 under complete original shoe.',actor_approvals_added=0,game_clips_adopted=0)")
p=b/'author-N-run-six-actual-native-v06.py';assert not p.exists();p.write_text(s)
print(hashlib.sha256(p.read_bytes()).hexdigest())
