from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import subprocess
import time
import urllib.parse

repo=Path('/workspace/twilight'); runtime=Path('/workspace/runtime')
base=Path('docs/remake/evidence/pr122-remaining106/batch17/authoring-stop-20261019')
manifest=json.loads((repo/base/'preservation-manifest.json').read_text())
def check(item):
    part,source_head=item
    path=(base/part['path']).as_posix()
    url='https://raw.githubusercontent.com/zoog136-hash/-/'+source_head+'/'+urllib.parse.quote(path)
    expected=part['sha256'];digest=hashlib.sha256();size=0
    with subprocess.Popen(['curl','-fsSL','--retry','3','--retry-all-errors','--max-time','180',url],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL) as process:
        for data in iter(lambda:process.stdout.read(1024*1024),b''):
            digest.update(data);size+=len(data)
        assert process.wait()==0,path
    assert size==part['bytes'] and digest.hexdigest()==expected,path
    return {**part,'verified_source_head':source_head,'redownload_SHA256_verified':True}

verified=[]
for index in range(4):
    deadline=time.monotonic()+1800
    while True:
        p=runtime/'batch17-stop-transfer.json'
        try:state=json.loads(p.read_text())
        except (FileNotFoundError,json.JSONDecodeError):state={'pushes':[]}
        if len(state['pushes'])>index:break
        assert time.monotonic()<deadline,'save transfer timeout'
        time.sleep(2)
    source_head=state['pushes'][index]['head']
    with ThreadPoolExecutor(max_workers=4) as pool:
        for result in pool.map(check,[(part,source_head) for part in manifest['parts'][index*41:(index+1)*41]]):
            verified.append(result)
            if len(verified)%20==0:print('ARCHIVE_PARTS_VERIFIED',len(verified),flush=True)
    (runtime/'batch17-stop-verified-parts.json').write_text(json.dumps(verified,indent=2)+'\n')
head=state['pushes'][-1]['head']
remote_head=subprocess.check_output(['git','ls-remote','origin','refs/heads/feature/twilight-remaining106-20261016'],cwd=repo,text=True).split()[0]
assert remote_head==head
tree_path=runtime/'batch17-stop-remote-tree.json'
with tree_path.open('wb') as output:
    subprocess.run(['gh','api',f'repos/zoog136-hash/-/git/trees/{head}?recursive=1'],cwd=repo,stdout=output,check=True)
tree=json.loads(tree_path.read_text());assert not tree.get('truncated')
remote={x['path']:x for x in tree['tree'] if x['type']=='blob'}
local={}
for row in subprocess.check_output(['git','ls-tree','-r','-z',head],cwd=repo).decode().split('\0'):
    if row:
        meta,path=row.split('\t',1);local[path]=meta.split()[2]
changes=[x for x in subprocess.check_output(['git','diff','--name-only','-z','c3115b7a82bab5e2faf579ad218abe47eee07cf4',head],cwd=repo).decode().split('\0') if x]
for path in changes:
    assert remote[path]['sha']==local[path],path
    assert remote[path]['size']==(repo/path).stat().st_size,path
for part in verified:part['remote_blob']=remote[(base/part['path']).as_posix()]['sha']
receipt={'verified_remote_head':head,'remote_changed_blobs_and_sizes_verified':len(changes),'archive_parts_redownload_SHA256_verified':len(verified),'archive_bytes':sum(x['bytes'] for x in verified),'archive_SHA256':manifest['archive_sha256'],'archive_member_count':manifest['file_count'],'PNG_count':manifest['PNG_count'],'all_archive_members_local_restore_SHA256_verified':True,'new_approvals':0,'final_full_CI':'NOT_VERIFIED; stopped by user','private_backup':'NOT_DELIVERED','old_reaper':'UNRECOVERED','parts':verified}
(runtime/'batch17-stop-remote-verification.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
print('STOP_SAVE_REMOTE_DELIVERY_PASS',len(changes),'blobs;',len(verified),'full part bodies;',receipt['archive_bytes'],'bytes',flush=True)
