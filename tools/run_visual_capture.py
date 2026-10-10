#!/usr/bin/env python3
"""Run actual Godot GL capture with a private, unpacked Xvfb when needed.

Xvfb and Godot share one process/network namespace. Ordinary desktop users can
omit --xvfb and use their existing DISPLAY. No privileged package install needed.
"""
import argparse, os, pathlib, socket, subprocess, tempfile, time

p=argparse.ArgumentParser()
p.add_argument('--godot',required=True)
p.add_argument('--root',type=pathlib.Path,required=True)
p.add_argument('--script',default='res://tests/capture_resource_integration.gd')
p.add_argument('--data',type=pathlib.Path,required=True)
p.add_argument('--log',type=pathlib.Path,required=True)
p.add_argument('--xvfb',type=pathlib.Path)
p.add_argument('--xlib',type=pathlib.Path)
p.add_argument('--fonts',type=pathlib.Path)
p.add_argument('--timeout',type=int,default=240)
a=p.parse_args();a.data.mkdir(parents=True,exist_ok=True);a.log.parent.mkdir(parents=True,exist_ok=True)
env=os.environ.copy();env['XDG_DATA_HOME']=str(a.data.resolve());env['LIBGL_ALWAYS_SOFTWARE']='1'
server=None;log=None
try:
    if a.xvfb:
        display=130+os.getpid()%1000
        env['DISPLAY']=f'127.0.0.1:{display}'
        if a.xlib:env['LD_LIBRARY_PATH']=str(a.xlib.resolve())
        log=open(a.log.with_suffix('.xvfb.log'),'w')
        command=[str(a.xvfb),f':{display}','-screen','0','1280x720x24','-ac',
                 '-nolisten','unix','-nolisten','local','-listen','tcp']
        if a.fonts:command+=['-fp',str(a.fonts.resolve())]
        server=subprocess.Popen(command,stdout=log,stderr=log,env=env)
        connected=False
        for _ in range(50):
            if server.poll() is not None:raise RuntimeError('Xvfb failed; inspect '+str(a.log.with_suffix('.xvfb.log')))
            try:
                connection=socket.create_connection(('127.0.0.1',6000+display),.1);connection.close();connected=True;break
            except OSError:time.sleep(.1)
        if not connected:raise RuntimeError('Xvfb display unavailable')
    with open(a.log,'w') as output:
        result=subprocess.run([a.godot,'--path',str(a.root.resolve()),'--audio-driver','Dummy',
                               '--script',a.script],stdout=output,stderr=subprocess.STDOUT,env=env,timeout=a.timeout)
    print('GODOT_GL_EXIT',result.returncode,'log',a.log,flush=True)
    raise SystemExit(result.returncode)
finally:
    if server is not None and server.poll() is None:server.terminate();server.wait(timeout=5)
    if log:log.close()
