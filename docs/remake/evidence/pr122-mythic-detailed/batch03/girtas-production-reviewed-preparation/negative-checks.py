"""Synthetic, isolated schema/path/log checks only; never a real actor approval."""
from pathlib import Path
import ast
import copy
import hashlib
import importlib.util
import json
import sys
import tempfile

sys.dont_write_bytecode = True
HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
from girtas_review_guard import input_marker, log_path, repo_path, strict_json, verify_log

count = 0
def rejects(label, callback):
    global count
    try:
        callback()
    except (ValueError, OSError):
        count += 1
    else:
        raise AssertionError('Incorrect acceptance: ' + label)

for name in ('girtas_review_guard.py', 'prepare-girtas-production-connection.py',
             'approve-girtas-production-r001.py', 'commit-girtas-production-r001.py'):
    ast.parse((HERE / name).read_text(), filename=name)

# The reviewed test adds assertions; preserve the draft's complete behavioral
# and profile checks byte-for-byte. This is static text review, never Godot.
draft_test = (HERE.parent / 'pr122-girtas-production-prep/pr122_girtas_native_default_main_connection_test.gd').read_text()
reviewed_test = (HERE / 'pr122_girtas_native_default_main_connection_test.gd').read_text()
def function_text(text, name):
    start = text.index('func '+name+'(')
    ends = [text.find(token, start+1) for token in ('\nfunc ', '\nconst ', '\nvar ')]
    end = min([offset for offset in ends if offset >= 0] or [len(text)])
    return text[start:end].rstrip()
for name in ('_same_hit_frame_maps', '_invariants', '_save_invariants', '_assert_default_connection',
             '_present', '_check_live_tracks', '_check_death'):
    assert function_text(draft_test, name) == function_text(reviewed_test, name), name
for script in ('approve-girtas-production-r001.py','commit-girtas-production-r001.py'):
    tree = ast.parse((HERE / script).read_text())
    test_pin = next(node.value.value for node in tree.body if isinstance(node, ast.Assign)
                    and any(isinstance(target, ast.Name) and target.id == 'REVIEWED_TEST_SHA' for target in node.targets))
    assert test_pin == hashlib.sha256(reviewed_test.encode()).hexdigest(), script

spec = importlib.util.spec_from_file_location('isolated_official_quality_schema',
    '/workspace/twilight/tools/pr122_native_production_approvals.py')
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)

with tempfile.TemporaryDirectory(prefix='isolated-negative-', dir=HERE) as temporary:
    root = Path(temporary)
    (root / 'safe.json').write_text('{}')
    (root / 'link.json').symlink_to(root / 'safe.json')
    rejects('repo traversal', lambda: repo_path(root, '../escape.json'))
    rejects('repo absolute path', lambda: repo_path(root, root / 'safe.json'))
    rejects('repo symlink', lambda: repo_path(root, 'link.json'))
    rejects('log symlink', lambda: log_path(root, root / 'link.json'))
    reader = gate._Reader(root)
    rejects('official stale SHA', lambda: reader.pin({'path':'safe.json', 'sha256':'0'*64}))
    rejects('official escaped path', lambda: reader.file('../safe.json'))
    rejects('official symlink', lambda: reader.file('link.json'))

rejects('duplicate JSON', lambda: strict_json('{"a":1,"a":2}'))
rejects('nonfinite JSON', lambda: strict_json('{"a":NaN}'))
engine = '4.7.2.stable.official.ed1daf0bf'
test_sha = 'a' * 64
inputs = input_marker(*['b' * 64] * 5)
marker = gate.default_main_marker('transform:267')
good_log = '\n'.join(['PR122_GIRTAS_DEFAULT_MAIN_ENGINE_PASS version='+engine,
    'PR122_GIRTAS_DEFAULT_MAIN_TEST_PIN sha256='+test_sha, inputs, marker])
def logcheck(value):
    verify_log(value, marker=marker, engine=engine, test_sha=test_sha, inputs=inputs)
logcheck(good_log)
rejects('stale runtime snapshot', lambda: logcheck(good_log.replace('register='+'b'*64, 'register='+'c'*64)))
rejects('wrong engine', lambda: logcheck(good_log.replace(engine, '4.7.1.stable.official')))
rejects('wrong reviewed test SHA', lambda: logcheck(good_log.replace(test_sha, 'd'*64)))
rejects('duplicate PASS', lambda: logcheck(good_log+'\n'+marker))
rejects('conflicting input marker', lambda: logcheck(good_log+'\n'+inputs.replace('b'*64, 'e'*64)))
rejects('candidate injection', lambda: logcheck(good_log+'\nPR122_NATIVE_MAIN_PASS'))
rejects('engine error', lambda: logcheck(good_log+'\nSCRIPT ERROR'))

expected = {'source_selection_sha256':'1'*64,
    'production_frames':{'path':'frames.tres','sha256':'2'*64},
    'production_profile':{'path':'profile.tres','sha256':'3'*64},
    'effective_profile_sha256':'4'*64}
tracks = []
for direction, role in sorted(gate.TRACK_KEYS):
    tracks.append({'direction':direction,'role':role,'source_sha256':'5'*64,
        'source_geometry_sha256':'6'*64,'geometry_sha256':'7'*64,
        'frame_rgba_sha256':['8'*64]*6})
quality = dict(expected, schema='pr122-native-independent-quality-v1', key='transform:267',
    status='PASS', independent=True, reviewer='SYNTHETIC_SCHEMA_ONLY',
    checks={key:'PASS' for key in gate.QUALITY_CHECKS},
    tracks=[dict(t,status='PASS',visual_findings=['SYNTHETIC_SCHEMA_ONLY']) for t in tracks])
class MemoryReader:
    def __init__(self, value): self.value = value
    def json_pin(self, _): return self.value
def qcheck(value): gate._quality(MemoryReader(value), {}, 'transform:267', expected, tracks)
qcheck(quality)
bad = copy.deepcopy(quality); bad['tracks'] = bad['tracks'][:37]
rejects('partial 37 tracks', lambda: qcheck(bad))
for name in gate.QUALITY_CHECKS:
    failed = copy.deepcopy(quality); failed['checks'][name] = 'HOLD'
    rejects('failed required check '+name, lambda value=failed: qcheck(value))
bad = copy.deepcopy(quality); bad['tracks'][0]['source_sha256'] = '9'*64
rejects('stale source SHA', lambda: qcheck(bad))
bad = copy.deepcopy(quality); bad['tracks'][0]['geometry_sha256'] = '9'*64
rejects('stale geometry SHA', lambda: qcheck(bad))
bad = copy.deepcopy(quality); bad['tracks'][0]['frame_rgba_sha256'][0] = '9'*64
rejects('stale pose SHA', lambda: qcheck(bad))
bad = copy.deepcopy(quality); bad['tracks'][0]['visual_findings'] = []
rejects('bare PASS', lambda: qcheck(bad))
bad = copy.deepcopy(quality); bad['independent'] = False
rejects('unreviewed quality', lambda: qcheck(bad))
bad = copy.deepcopy(quality); bad['production_profile']['sha256'] = '9'*64
rejects('stale production profile', lambda: qcheck(bad))
template = strict_json((HERE / 'final48-quality-REQUIRED-template.json').read_bytes())
rejects('HOLD template', lambda: qcheck(template))
print(json.dumps({'status':'PASS_SYNTHETIC_NEGATIVE_CHECKS_ONLY', 'rejections':count,
    'python_ast_files':4, 'real_actor_revalidated':False, 'engine_executed':False,
    'approval_issued':False, 'repository_writes':False}))
