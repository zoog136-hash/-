"""Run the actual unique-form Main regression with isolated caches and saves.

Uses current source declarations for a small QA class cache, source-byte textures,
real Main map/colliders, and Xvfb rendering. Does not modify or import source assets.
This is not a substitute for native import/export, CI, or anatomical art review.
"""
import argparse,json,os,re,subprocess,time
from pathlib import Path

def run(root,out,godot,script,xvfb):
    out.mkdir(parents=True,exist_ok=False)
    project=out/'project';project.mkdir()
    (project/'project.godot').write_bytes((root/'project.godot').read_bytes())
    for name in ['scripts','data','assets','scenes','docs','tests','addons','Main.tscn']:
        p=root/name
        if p.exists():(project/name).symlink_to(p,target_is_directory=p.is_dir())
    pack_source=root/'external_map_packs'
    assert pack_source.is_dir(), 'Current Main map pack source required; never substitute an older layout'
    (project/'external_map_packs').symlink_to(pack_source,target_is_directory=True)
    def base(f):
        m=re.search(r'^extends\s+(\w+|"[^"]+")',f.read_text(),re.M)
        if not m:return 'RefCounted'
        if not m[1].startswith('"'):return m[1]
        p=root/m[1].strip('"').removeprefix('res://')
        c=re.search(r'^class_name\s+(\w+)',p.read_text(),re.M)
        return c[1] if c else base(p)
    classes=[]
    for directory in ['scripts','addons']:
        for p in (root/directory).rglob('*.gd'):
            c=re.search(r'^class_name\s+(\w+)',p.read_text(),re.M)
            if c:classes.append(dict(base=base(p),**{'class':c[1]},icon='',is_abstract=False,is_tool=False,language='GDScript',path='res://'+p.relative_to(root).as_posix()))
    (project/'.godot').mkdir()
    (project/'.godot/global_script_class_cache.cfg').write_text('list='+json.dumps(classes,ensure_ascii=False,indent=2)+'\n')
    env=os.environ.copy()
    for kind in ['DATA','CACHE','CONFIG']:
        p=out/kind.lower();p.mkdir();env['XDG_'+kind+'_HOME']=str(p)
    env.update(BOSS_DEFAULT_MAIN_OUTPUT=str(out),LIBGL_ALWAYS_SOFTWARE='1')
    cmd=[str(godot),'--path',str(project),'--audio-driver','Dummy','--script',str(script)]
    display=None;xlog=None
    assert xvfb and xvfb.is_file(),'Provide --xvfb for visible Main verification'
    xlog=(out/'xvfb.log').open('w')
    # Ask Xvfb to allocate a free display; never terminate another task's display.
    read_fd,write_fd=os.pipe()
    display=subprocess.Popen([str(xvfb),'-displayfd',str(write_fd),'-screen','0','1280x720x24','-nolisten','tcp','-ac'],pass_fds=(write_fd,),stdout=xlog,stderr=subprocess.STDOUT)
    os.close(write_fd)
    import select
    assert select.select([read_fd],[],[],15)[0],'Xvfb did not allocate a display'
    number=os.read(read_fd,64).decode().strip();os.close(read_fd)
    assert number.isdigit(),'Invalid Xvfb display'
    env['DISPLAY']=':'+number
    cmd+=['--display-driver','x11','--rendering-method','gl_compatibility','--rendering-driver','opengl3']
    (out/'command.json').write_text(json.dumps(cmd,indent=2)+'\n')
    started=time.monotonic()
    try:
        with (out/'godot.log').open('w') as log:
            result=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=420)
        lines=(out/'godot.log').read_text().splitlines()
        errors=[line for line in lines if any(s in line for s in ['SCRIPT ERROR','Parse Error','ERROR:'])]
        report=dict(mode="actual_main_unique_precision",returncode=result.returncode,elapsed_seconds=round(time.monotonic()-started,2),engine=subprocess.check_output([str(godot),'--version'],text=True).strip(),errors=errors,source_head=subprocess.check_output(['git','--no-lazy-fetch','rev-parse','HEAD'],cwd=root,text=True).strip(),isolated_user_data=True,native_import_test=False,new_art_approvals=0)
        (out/'process.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
        print(json.dumps({k:v for k,v in report.items() if k!='errors'},ensure_ascii=False));print('engine_errors',len(errors))
        return 1 if errors or result.returncode else 0
    finally:
        if display:display.terminate();display.wait(timeout=5)
        if xlog:xlog.close()

if __name__=='__main__':
    parser=argparse.ArgumentParser(description='Actual default unique2 Main phase, marker, physics and map-readiness regression. Source-byte textures; not native import/export or formal art approval.')
    parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--godot',type=Path,required=True)
    parser.add_argument('--xvfb',type=Path,required=True)
    parser.add_argument('--script',type=Path,help='Optional Main precision SceneTree script; default is tests/transform_unique_precision_main.gd under root')
    args=parser.parse_args()
    task_root=args.root.resolve()
    task_script=(args.script or task_root/'tests/transform_unique_precision_main.gd').resolve()
    if not task_script.is_file():parser.error('Precision script is missing: '+str(task_script))
    raise SystemExit(run(task_root,args.output.resolve(),args.godot.resolve(),task_script,args.xvfb.resolve()))
