from pathlib import Path
import json,shutil,sys
sys.path.insert(0,'/workspace/twilight/tools');import import_original_based_motion as core
root=Path('/workspace/runtime/batch16')
for index in sys.argv[1:]:
    for item in json.loads(Path(index).read_text()):
        dest=root/('monk-'+item['key']+'.png')
        if dest.exists():assert core.sha(dest)==core.sha(Path(item['image']))
        else:shutil.copyfile(item['image'],dest)
        (root/('monk-'+item['key']+'-request.json')).write_text(json.dumps(item,ensure_ascii=False,indent=2)+'\n')
        try:
            direction=item['key'].split('_')[0]
            g=core.analyze(dest,16,[0,1],directions_axis='phase_grid4',directions=[direction],canvas_size=768)
            core.require_complete_pose_regions(dest,g)
            print('MONK16_GEOMETRY_PASS',item['key'],len(g['frames']),g['neutral_height'],flush=True)
        except (ValueError,AssertionError) as error:print('MONK16_SOURCE_HOLD',item['key'],str(error),flush=True)
