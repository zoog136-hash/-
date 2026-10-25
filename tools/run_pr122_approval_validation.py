"""Run a bounded audit against real resources with isolated caches and saves.

The class cache is derived from current source declarations, as in the existing
boss Main harness. This is not a substitute for native import/export CI.
"""
import argparse,json,os,re,subprocess,time
from pathlib import Path

def run(root,out,godot,mode,plan,xvfb):
    out.mkdir(parents=True,exist_ok=False)
    project=out/'project';project.mkdir()
    (project/'project.godot').write_bytes((root/'project.godot').read_bytes())
    for name in ['scripts','data','assets','scenes','docs','tests','addons','Main.tscn']:
        p=root/name
        if p.exists():(project/name).symlink_to(p,target_is_directory=p.is_dir())
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
    env.update(PR122_APPROVAL_PLAN=str(plan or ''),PR122_APPROVAL_REPORT=str(out/'resource-report.json'),BOSS_DEFAULT_MAIN_OUTPUT=str(out),LIBGL_ALWAYS_SOFTWARE='1')
    script='pr122_approval_resource_audit.gd' if mode=='resources' else 'pr122_published_boss_approval_main.gd'
    cmd=[str(godot),'--path',str(project),'--audio-driver','Dummy','--script','res://tests/'+script]
    display=None;xlog=None
    if mode=='resources':cmd+=['--headless']
    else:
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
            result=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=900 if mode=='resources' else 240)
        lines=(out/'godot.log').read_text().splitlines()
        errors=[line for line in lines if any(s in line for s in ['SCRIPT ERROR','Parse Error','ERROR:'])]
        report=dict(mode=mode,returncode=result.returncode,elapsed_seconds=round(time.monotonic()-started,2),engine=subprocess.check_output([str(godot),'--version'],text=True).strip(),errors=errors,source_head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),isolated_user_data=True,native_import_test=False,new_art_approvals=0)
        (out/'process.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
        print(json.dumps({k:v for k,v in report.items() if k!='errors'},ensure_ascii=False));print('engine_errors',len(errors))
        return 1 if errors or result.returncode else 0
    finally:
        if display:display.terminate();display.wait(timeout=5)
        if xlog:xlog.close()

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]);p.add_argument('--output',type=Path,required=True);p.add_argument('--godot',type=Path,required=True);p.add_argument('--mode',choices=['resources','main'],required=True);p.add_argument('--plan',type=Path);p.add_argument('--xvfb',type=Path);a=p.parse_args()
    raise SystemExit(run(a.root.resolve(),a.output.resolve(),a.godot.resolve(),a.mode,a.plan.resolve() if a.plan else None,a.xvfb.resolve() if a.xvfb else None))
