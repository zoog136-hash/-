from pathlib import Path
import datetime
import hashlib
import json
import shutil
import subprocess
import urllib.parse

repo=Path('/workspace/twilight'); runtime=Path('/workspace/runtime')
base=Path('docs/remake/evidence/pr122-remaining106/batch17')
stop=base/'authoring-stop-20261019'; output=repo/stop/'transfer'
transfer=json.loads((runtime/'batch17-stop-transfer.json').read_text())
verified=json.loads((runtime/'batch17-stop-remote-verification.json').read_text())
assert len(transfer['pushes'])==4
assert verified['archive_parts_redownload_SHA256_verified']==162
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip()
assert head==transfer['pushes'][-1]['head']==verified['verified_remote_head']
assert not subprocess.check_output(['git','status','--porcelain=v1'],cwd=repo).strip()
output.mkdir(parents=True,exist_ok=True)
(output/'.gitattributes').write_text('*.log -text -diff\n*.log.old -text -diff\n')
for p in sorted(runtime.iterdir()):
    if p.is_file() and (p.name.startswith(('batch17-stop-','save_batch17_stop_','verify_batch17_stop_','finalize_batch17_stop')) or p.name in {'xorg.conf','xorg.log','xorg.log.old','preflight-resource.log'}):
        assert p.stat().st_size<32*1024*1024,p
        shutil.copy2(p,output/p.name)

checkpoint=repo/base/'checkpoint.json'; value=json.loads(checkpoint.read_text())
value.update({'complete_evidence_commit':head,'all_162_archive_parts_remote_redownload_SHA256_verified':True,'remote_archive_bytes':verified['archive_bytes'],'remote_preservation_receipt':str(stop/'transfer/batch17-stop-remote-verification.json'),'current_stop_save_commit_resolution':'git log -1 --format=%H -- docs/remake/TWILIGHT_PR122_STOP_20261019.md'})
checkpoint.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')

checkpoint=repo/'docs/remake/TWILIGHT_REMAINING106_CHECKPOINT.json'; value=json.loads(checkpoint.read_text())
value['historical_latest_source_status_before_this_stop']=value['latest_source_status']
value['latest_source_status']={'approved_total':405,'new_approved_this_batch':0,'raw_new_PNGs':67,'HOLD':17,'IN_PROGRESS':1,'NOT_AUTHORED':75,'runtime_connected_unapproved':0,'current_detail':str(base/'checkpoint.json'),'private_backup':'NOT_DELIVERED','old_reaper':'UNRECOVERED'}
value.update({'observed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'last_safe_commit':head,'complete_evidence_commit':head,'stop_delivery_receipt':str(stop/'transfer/batch17-stop-remote-verification.json'),'current_safe_commit_resolution':'git log -1 --format=%H -- docs/remake/TWILIGHT_PR122_STOP_20261019.md'})
value['stop_save'].update({'all_archive_parts_remote_SHA256_verified':162,'complete_evidence_commit':head,'full_CI':'NOT_VERIFIED; user stopped work; save commits use skip ci'})
checkpoint.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')

p=repo/'docs/remake/TWILIGHT_PR122_STOP_20261019.md'
p.write_text(p.read_text()+'\n## 원격 저장 완료 확인\n\n전체162개 분할본을 포함하는 커밋은 `'+head+'`다. 4,751,840,049바이트 전부를 원격에서 다시 내려받아 각 조각 SHA-256을 확인했고, 새/변경 blob의 Git SHA와 크기도 일치한다. [원격 전달 영수증](evidence/pr122-remaining106/batch17/authoring-stop-20261019/transfer/batch17-stop-remote-verification.json), [정상 push 기록](evidence/pr122-remaining106/batch17/authoring-stop-20261019/transfer/batch17-stop-transfer.json), 설정·드라이버·로그도 함께 보존했다. 이 영수증을 추가한 최신 저장 SHA는 이 문서의 `git log -1 --format=%H`로 확인한다. 저장 커밋은 `[skip ci]`이며 신규 제작·테스트·수동 CI를 재개하지 않았다.\n')

files={}
for p in sorted(output.iterdir()):
    if p.is_file(): files[p.name]={'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
(output/'durable-files-SHA256.json').write_text(json.dumps({'files':files,'private_backup':'NOT_DELIVERED','old_reaper':'UNRECOVERED'},ensure_ascii=False,indent=2)+'\n')

log=runtime/'batch17-stop-final-push.log'
def run(args):
    with log.open('ab') as stream:subprocess.run(args,cwd=repo,stdout=stream,stderr=subprocess.STDOUT,check=True)
run(['git','add','--sparse','--',str(stop),str(base/'checkpoint.json'),'docs/remake/TWILIGHT_REMAINING106_CHECKPOINT.json','docs/remake/TWILIGHT_PR122_STOP_20261019.md'])
run(['git','diff','--cached','--check'])
run(['git','commit','-m','[skip ci] Record complete stopped-session delivery and resume point'])
run(['git','push','origin','HEAD:feature/twilight-remaining106-20261016'])
final=subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip()
remote=subprocess.check_output(['git','ls-remote','origin','refs/heads/feature/twilight-remaining106-20261016'],cwd=repo,text=True).split()[0]
assert remote==final
for rel in [stop/'transfer/batch17-stop-remote-verification.json',Path('docs/remake/TWILIGHT_PR122_STOP_20261019.md')]:
    url='https://raw.githubusercontent.com/zoog136-hash/-/'+final+'/'+urllib.parse.quote(rel.as_posix())
    data=subprocess.check_output(['curl','-fsSL','--max-time','90',url])
    assert hashlib.sha256(data).digest()==hashlib.sha256((repo/rel).read_bytes()).digest()
assert not subprocess.check_output(['git','status','--porcelain=v1'],cwd=repo).strip()
print(json.dumps({'saved_HEAD':final,'remote_HEAD_verified':True,'worktree':'CLEAN','archive_parts_remote_full_body_SHA256_verified':162,'new_approvals':0,'full_CI':'NOT_VERIFIED','private_backup':'NOT_DELIVERED','old_reaper':'UNRECOVERED'}),flush=True)
