from pathlib import Path
import argparse,json,os,subprocess,time

parser=argparse.ArgumentParser()
parser.add_argument('--fixture',required=True)
parser.add_argument('--out',required=True)
parser.add_argument('--project',default='/workspace/runtime/batch17/Main-project')
parser.add_argument('--mode',choices=['import','gameplay','temporal','transform','all'],default='all')
args=parser.parse_args()
project=Path(args.project);out=Path(args.out);out.mkdir(parents=True,exist_ok=False)
engine='/workspace/runtime/bin/Godot_v4.7.2-stable_linux.x86_64'
phases=['import','gameplay','temporal'] if args.mode=='all' else [args.mode]
for mode in phases:
    env=dict(os.environ);base=out/mode;base.mkdir()
    for directory in ['data','config','cache']:(base/directory).mkdir()
    env.update(DISPLAY=':107',LIBGL_ALWAYS_SOFTWARE='1',XDG_DATA_HOME=str(base/'data'),
               XDG_CONFIG_HOME=str(base/'config'),XDG_CACHE_HOME=str(base/'cache'))
    if mode=='import':command=[engine,'--headless','--path',str(project),'--editor','--import']
    else:
        prefix='TWILIGHT_PR100_TEMPORAL' if mode=='temporal' else 'TWILIGHT_PR100_BATCH'
        env.update({prefix+'_ISOLATED':'1',prefix+'_CONFIG':args.fixture,
                    prefix+'_REPORT':str(base/'report.json'),prefix+'_CAPTURE_DIR':str(base/'captures')})
        script={'gameplay':'pr122_family_reuse_main_review.gd','temporal':'original_based_temporal_main_test.gd',
                'transform':'pr122_tomb269_baseline_visual_review.gd'}[mode]
        command=[engine,'--path',str(project),'--rendering-driver','opengl3','--audio-driver','Dummy','--script','res://tests/'+script]
    (base/'command.json').write_text(json.dumps(command,indent=2)+'\n')
    started=time.monotonic()
    with (base/'run.log').open('w') as log:
        try:r=subprocess.run(command,cwd=project,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=1800)
        except subprocess.TimeoutExpired:
            (base/'process.json').write_text(json.dumps({'status':'TIMEOUT','seconds':1800})+'\n');raise
    log=(base/'run.log').read_text(errors='replace')
    result={'returncode':r.returncode,'seconds':round(time.monotonic()-started,3),
            'engine':'4.7.2.stable.official.ed1daf0bf','real_OpenGL':mode!='import'}
    (base/'process.json').write_text(json.dumps(result,indent=2)+'\n')
    print(mode,json.dumps(result),flush=True)
    if r.returncode or any(word in log for word in ['SCRIPT ERROR:','Parse Error:','ERROR:']):
        print(log[-2200:],flush=True);raise SystemExit(r.returncode or 1)
    if mode!='import':
        report=json.loads((base/'report.json').read_text());summary={k:v for k,v in report.items() if k not in ['cases','samples']}
        print(mode,json.dumps(summary,ensure_ascii=False),flush=True)
        assert report['failures']==[] and report['checks']>0
