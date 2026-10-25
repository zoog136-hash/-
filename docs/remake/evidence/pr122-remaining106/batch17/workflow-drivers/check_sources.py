from pathlib import Path
import json,re,sys

root=Path('/workspace/runtime/batch17');repo=Path('/workspace/twilight')
sys.path.insert(0,str(repo/'tools'));import import_original_based_motion as core
report=root/'source-checks.json'; prior=json.loads(report.read_text()) if report.exists() else []
cache={x['name']:x for x in prior};results=[]
for file in sorted((root/'requests').glob('*.json')):
    item=json.loads(file.read_text());name=item['name'];path=Path(item['image_path']);digest=core.sha(path)
    if name in cache and cache[name]['sha256']==digest and cache[name].get('schema')==2:
        results.append(cache[name]);continue
    direction=name.split('-')[1];axis='phase_grid4';count=16
    if 'attack3' in name or 'death3' in name:axis='rows';count=3
    elif 'idlehit4' in name:axis='phase_grid2';count=4
    elif 'hit2' in name:axis='rows';count=2
    elif 'idle2' in name:axis='phase_grid2';count=2
    elif 'walk6' in name:axis='phase_grid3' if name.startswith('monk') else 'phase_grid2';count=6
    elif 'combat8' in name:axis='phase_grid4' if name.startswith('monk') else 'phase_grid2';count=8
    elif 'locomotion' in name:axis='phase_grid2';count=8
    elif name.startswith('monk-SW-complete'):axis='phase_grid2'
    if 'source_layout' in item:
        count=item['source_layout']['rows'];axis=item['source_layout']['directions_axis']
    row={'schema':2,'name':name,'path':str(path),'sha256':digest,'bytes':path.stat().st_size,
         'rows':count,'axis':axis,'direction':direction,'production_approved':False,
         'visual_review':'PENDING; geometry is not visual/gait approval'}
    try:
        geometry=core.analyze(path,count,[0,1],directions_axis=axis,directions=[direction],canvas_size=2048)
        core.require_complete_pose_regions(path,geometry)
        row.update(status='GEOMETRY_PASS_ONLY',geometry=geometry)
    except (ValueError,AssertionError) as error:row.update(status='SOURCE_HOLD',reason=str(error))
    results.append(row)
report.write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
print('Sources',len(results),'geometry pass',sum(x['status']=='GEOMETRY_PASS_ONLY' for x in results),
      'HOLD',[(x['name'],x.get('reason')) for x in results if x['status']=='SOURCE_HOLD'])
