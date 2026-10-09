"""Launch Xvfb and Godot in one execution environment and retain real GL evidence."""
import argparse
import os
from pathlib import Path
import re
import socket
import subprocess
import time

p = argparse.ArgumentParser()
p.add_argument('--godot', required=True)
p.add_argument('--xvfb', default='/usr/bin/Xvfb')
p.add_argument('--output', default='ui-review')
args = p.parse_args()
root = Path(__file__).resolve().parents[1]
out = Path(args.output).resolve()
out.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
env.update({'DISPLAY':'127.0.0.1:96','LIBGL_ALWAYS_SOFTWARE':'1','XDG_DATA_HOME':str(out/'data')})
env['LD_LIBRARY_PATH'] = str(Path(args.xvfb).resolve().parents[1]/'lib/x86_64-linux-gnu')+':'+env.get('LD_LIBRARY_PATH','')
with (out/'xvfb.log').open('w') as display_log:
    display = subprocess.Popen([args.xvfb,':96','-screen','0','2560x1440x24','-ac','-nolisten','unix','-nolisten','local','-listen','tcp','-nolock'],env=env,stdout=display_log,stderr=display_log)
    try:
        for attempt in range(50):
            if display.poll() is not None:
                raise RuntimeError('Xvfb failed; see xvfb.log')
            try:
                with socket.create_connection(('127.0.0.1',6096),timeout=.1):
                    break
            except OSError:
                time.sleep(.1)
        else:
            raise RuntimeError('Xvfb not ready')
        command = [args.godot,'--audio-driver','Dummy','--path',str(root),'--script','res://tests/capture_ui_renewal.gd']
        result = subprocess.run(command,capture_output=True,text=True,env=env,timeout=240)
        output = result.stdout+result.stderr
        (out/'render.log').write_text(output)
        print(output[-14000:])
        ok = result.returncode == 0 and 'UI_RENEWAL_CAPTURE_OK' in output and not re.search(r'SCRIPT ERROR:|ERROR:',output)
        raise SystemExit(0 if ok else 1)
    finally:
        display.terminate()
        display.wait(timeout=5)
