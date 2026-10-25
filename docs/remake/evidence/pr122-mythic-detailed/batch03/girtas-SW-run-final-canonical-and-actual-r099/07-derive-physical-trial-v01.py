from pathlib import Path
import json,sys
p=Path(__file__).parent;sys.path.insert(0,'/workspace/twilight/tools');from pr122_reviewed_runtime_layout import apply_reviewed_layout
q=json.loads((p/'reviewed_runtime_layout.trial-v01.json').read_text());b=json.loads((p/'geometry-source-reviewed-six.json').read_text());r=json.loads((p/'source-region-review.v03.json').read_text());g,proof=apply_reviewed_layout(p/'girtas-SW-run-v03six.png',b,q,source_region_review=r)
for name,value in [('runtime-geometry.trial-v01.json',g),('runtime-layout.trial-v01-proof.json',proof)]:
 f=p/name;assert not f.exists();f.write_text(json.dumps(value,indent=2)+'\n')
print(json.dumps({'Cs':q['authored_pose_canvas_sizes'],'anchors':q['source_anchors'],'source_pixels_unchanged':proof.get('source_pixels_unchanged')}))
