#!/usr/bin/env python3
"""Run only the final changed-boss Main integration, with isolated save data."""
import argparse,json,os,re,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[5]
def base(f):
    m=re.search(r'^extends\s+(\w+|"[^"]+")',f.read_text(),re.M)
    if not m:return 'RefCounted'
    s=m[1]
    if not s.startswith('"'):return s
    q=ROOT/s.strip('"').removeprefix('res://');c=re.search(r'^class_name\s+(\w+)',q.read_text(),re.M)
    return c[1] if c else base(q)
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--out',required=True,type=Path);a=ap.parse_args();out=a.out.resolve();out.mkdir(exist_ok=False)
    project=out/'project';project.mkdir();(project/'project.godot').write_text((ROOT/'project.godot').read_text())
    for name in ['scripts','data','assets','scenes','docs','tests','addons','Main.tscn']:(project/name).symlink_to(ROOT/name,target_is_directory=(ROOT/name).is_dir())
    classes=[]
    for directory in ['scripts','addons']:
        for f in (ROOT/directory).rglob('*.gd'):
            c=re.search(r'^class_name\s+(\w+)',f.read_text(),re.M)
            if c:classes.append(dict(base=base(f),**{'class':c[1]},icon='',is_abstract=False,is_tool=False,language='GDScript',path='res://'+f.relative_to(ROOT).as_posix()))
    (project/'.godot').mkdir();(project/'.godot/global_script_class_cache.cfg').write_text('list='+json.dumps(classes,ensure_ascii=False,indent=2)+'\n')
    env=os.environ.copy();env.update(DISPLAY=':291',LIBGL_ALWAYS_SOFTWARE='1',BOSS_DEFAULT_MAIN_OUTPUT=str(out))
    for n in ['DATA','CACHE','CONFIG']:
        q=out/('twilight-test-'+n.lower());q.mkdir();env['XDG_'+n+'_HOME']=str(q)
    cmd=['/workspace/runtime/bin/Godot_v4.7.2-stable_linux.x86_64','--path',str(project),'--audio-driver','Dummy','--display-driver','x11','--rendering-method','gl_compatibility','--rendering-driver','opengl3','--script','res://docs/remake/evidence/pr122-monsters-20261023/boss-draft-first/whole-review-v01/default-connection/main.gd']
    (out/'command.json').write_text(json.dumps(cmd,indent=2)+'\n')
    with (out/'xvfb.txt').open('w') as xlog:
        x=subprocess.Popen(['/workspace/runtime/boss-qa-xvfb/unpacked/usr/bin/Xvfb',':291','-screen','0','1280x720x24','-nolisten','tcp','-ac'],stdout=xlog,stderr=subprocess.STDOUT)
        try:
            for _ in range(50):
                if Path('/tmp/.X11-unix/X291').exists():break
                time.sleep(.1)
            with (out/'godot.txt').open('w') as log:r=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=120)
            s=(out/'godot.txt').read_text();errors=[line for line in s.splitlines() if any(a in line for a in ['SCRIPT ERROR','Parse Error','ERROR:'])]
            result=dict(returncode=r.returncode,script_errors=errors,actual_Main=True,isolated_user_data=True,source_image_loader='Real PNG/WebP bytes only; no raster fixtures; no profile/candidate injection')
            (out/'process.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(dict(returncode=r.returncode,script_error_count=len(errors),first_errors=errors[:6],actual_Main=True)))
        finally:x.terminate();x.wait(timeout=5)
if __name__=='__main__':main()
