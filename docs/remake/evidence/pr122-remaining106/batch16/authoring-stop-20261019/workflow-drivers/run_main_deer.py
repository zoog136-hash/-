from pathlib import Path
import json
import os
import subprocess
import time

root = Path('/workspace/runtime/batch16')
project = root / 'Main-project'
out = root / 'Deer-Main-QA-v01'
out.mkdir(exist_ok=False)
env = dict(os.environ)
for name in ['data', 'config', 'cache']:
    (out / name).mkdir()
env.update(DISPLAY=':107', LIBGL_ALWAYS_SOFTWARE='1',
    XDG_DATA_HOME=str(out/'data'), XDG_CONFIG_HOME=str(out/'config'), XDG_CACHE_HOME=str(out/'cache'))
engine = '/workspace/tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'
commands = [('import', [engine, '--headless', '--path', str(project), '--editor', '--import'])]
commands.append(('gameplay', [engine, '--path', str(project), '--rendering-driver', 'opengl3',
    '--audio-driver', 'Dummy', '--script', 'res://tests/pr122_family_reuse_main_review.gd']))
for kind, command in commands:
    if kind == 'gameplay':
        env.update(TWILIGHT_PR100_BATCH_ISOLATED='1',
            TWILIGHT_PR100_BATCH_CONFIG='res://tests/fixtures/pr122_batch16_deer.json',
            TWILIGHT_PR100_BATCH_REPORT=str(out/'gameplay.json'),
            TWILIGHT_PR100_BATCH_CAPTURE_DIR=str(out/'captures'))
    start = time.monotonic()
    with (out/(kind+'.log')).open('w') as log:
        result = subprocess.run(command, cwd=project, env=env, stdout=log,
            stderr=subprocess.STDOUT, timeout=1200)
    print(kind, result.returncode, round(time.monotonic()-start, 2), flush=True)
    if result.returncode:
        print((out/(kind+'.log')).read_text(errors='replace')[-6500:], flush=True)
        raise SystemExit(result.returncode)
report = json.loads((out/'gameplay.json').read_text())
print('BATCH16_ACTUAL_MAIN_RESULT',json.dumps({k:v for k,v in report.items() if k!='cases'},ensure_ascii=False),flush=True)
assert not report['failures']
