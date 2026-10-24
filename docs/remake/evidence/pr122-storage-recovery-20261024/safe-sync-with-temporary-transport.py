import os,json,subprocess,sys
from pathlib import Path
r=Path('/workspace/twilight');branch='feature/twilight-remaining106-20261016'
s=Path(sys.argv[1]);s.mkdir(parents=True,exist_ok=True)
env=os.environ.copy()
# Network fetch transport stays outside the capacity-limited workspace. The
# local production commit remains in the real repository throughout the save.
if not env.get('GIT_OBJECT_DIRECTORY'):
    transport=Path('/tmp/pr122-metadata-sync-cache/objects')
    transport.mkdir(parents=True,exist_ok=True)
    env.update(GIT_OBJECT_DIRECTORY=str(transport),GIT_ALTERNATE_OBJECT_DIRECTORIES=str(r/'.git/objects'))
env.update(GIT_INDEX_FILE=str(s/'merge-index'),GIT_NO_LAZY_FETCH='1',GIT_OPTIONAL_LOCKS='0',GIT_TERMINAL_PROMPT='0')
def git(*args,input=None):
    p=subprocess.run(['git','-c','gc.auto=0','-c','maintenance.auto=false',*args],cwd=r,env=env,input=input,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    if p.returncode:
        (s/'last-error.log').write_bytes(p.stderr);raise RuntimeError('Git '+args[0]+' stopped; bounded log saved')
    return p.stdout
assert git('branch','--show-current').decode().strip()==branch
checkout=git('rev-parse','HEAD').decode().strip()
local=os.environ.get('PR122_PRESERVED_MERGE',checkout)
assert git('merge-base','--is-ancestor',checkout,local)==b''
checkenv=dict(env);checkenv.pop('GIT_INDEX_FILE')
assert not subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=r,env=checkenv).strip(),'Preserve tracked uncommitted edits before checkpoint'
assert '[skip ci]' in git('show','-s','--format=%s',local).decode().lower()
remote=git('ls-remote','--heads','origin',branch).split()[0].decode()
git('fetch','--filter=blob:none','--no-tags','--no-write-fetch-head','--no-auto-maintenance','--refmap=','origin',remote)
base=git('merge-base',local,remote).decode().strip()
def changes(rev):
    rows=git('diff-tree','-r','--no-commit-id','--raw','--no-abbrev','--no-renames','-z',base,rev).split(b'\0');d={};i=0
    while i<len(rows) and rows[i]:
        oldmode,mode,oldoid,oid,status=rows[i][1:].decode().split();d[rows[i+1].decode()]=(mode,oid,status);i+=2
    return d
ours,theirs=changes(local),changes(remote);resume='docs/remake/TWILIGHT_PR122_RESUME_20261019.md'
overlap={p for p in set(ours)&set(theirs) if ours[p]!=theirs[p]}
assert overlap<={resume},'Production conflict preserved; do not guess ownership'
git('read-tree',local)
updates=[f'{mode} {oid}\t{path}'.encode()+b'\0' for path,(mode,oid,status) in theirs.items() if path not in overlap]
if updates:git('update-index','-z','--index-info',input=b''.join(updates))
if resume in overlap:
    texts=[git('show',rev+':'+resume) for rev in [local,base,remote]]
    for name,t in zip(['local','base','remote'],texts):(s/(name+'-resume.md')).write_bytes(t)
    p=subprocess.run(['git','merge-file','--union','-p',str(s/'local-resume.md'),str(s/'base-resume.md'),str(s/'remote-resume.md')],capture_output=True)
    assert p.returncode==0 and b'<<<<<<<' not in p.stdout
    for text in [texts[0],texts[2]]:assert set(text.splitlines())-set(texts[1].splitlines())<=set(p.stdout.splitlines())
    oid=git('hash-object','-w','--stdin',input=p.stdout).decode().strip();git('update-index','--add','--cacheinfo','100644',oid,resume)
tree=git('write-tree','--missing-ok').decode().strip()
def entries(rev):
    result={}
    for row in git('ls-tree','-r','-z',rev).split(b'\0'):
        if row:
            meta,path=row.split(b'\t',1);result[path.decode()]=tuple(meta.decode().split())
    return result
lt,rt,mt=entries(local),entries(remote),entries(tree)
for path in ours:
    if path not in overlap:assert mt.get(path)==lt.get(path),path
for path in theirs:
    if path not in overlap:assert mt.get(path)==rt.get(path),path
assert {p for p in set(lt)|set(mt) if lt.get(p)!=mt.get(p)}<=set(theirs)
msg='[skip ci] Preserve mythic animation repairs and concurrent PR122 work\n\nBoth parent histories and exact changed-path Git object IDs are preserved. Existing tracked and untracked local files are untouched.\n'
head=git('commit-tree',tree,'-p',local,'-p',remote,input=msg.encode()).decode().strip()
proof=dict(local=local,remote_parent=remote,merge=head,local_changed_paths=len(ours),remote_changed_paths=len(theirs),both_parent_changed_path_objects_preserved=True,local_checkout_unchanged=checkout)
(s/'preservation.json').write_text(json.dumps(proof,indent=2)+'\n')
# A normal push performs the atomic remote-ref check. If another writer wins,
# retain this merge as the next synchronization parent; never force-push.
p=subprocess.run(['git','-c','gc.auto=0','-c','maintenance.auto=false','-c','push.negotiate=false','push','origin',head+':refs/heads/'+branch],cwd=r,env=env,capture_output=True)
(s/'push.log').write_bytes(p.stdout+p.stderr);assert p.returncode==0,'Normal push stopped; merge preserved'
assert git('ls-remote','--heads','origin',branch).split()[0].decode()==head
proof['push_verified']=True;(s/'preservation.json').write_text(json.dumps(proof,indent=2)+'\n')
Path('/workspace/scratch/pr122-last-verified-remote-sha.txt').write_text(head+'\n')
print(json.dumps(dict(status='PUSH_VERIFIED',remote=head,local=local,local_paths_preserved=len(ours),remote_paths_preserved=len(theirs))))
