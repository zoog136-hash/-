"""One-shot, hash-pinned map transport; never touches gameplay code or main."""
import hashlib, json, os, pathlib, shutil, stat, tempfile, urllib.request, urllib.parse, zipfile
P = pathlib.Path
ROOT = P.cwd()
NATIVE_HASH = '2bc0a2463ef7448a8b16b890911175d3da03f2d992dcbcaa18cfd7563c310122'
INDEX_HASH = '009b980a2dffb695d578086dd1acb63b27093ab67968f402e0d9cf0422cb3711'
OMAN_HASH = '9123660429fc06a9e88a3f7719f2121401f53dc57d71e1da543b085caa399708'
PARTS = [(94371840,'2dc2460e84612e93a0da746a817ccaf3f908059a0ae520631dafeda68605cd49'), (94371840,'539b50073c708f2108b7fc638fd627eb0344041fdbcd25442cedc1709cdcda16'), (85428423,'9738cef4fb6963d7e9f25f7cfa6455a31989af13b60e0f0fcf75e639078a5983')]
def require(ok, message):
    if not ok: raise ValueError(message)
def digest(p):
    with P(p).open('rb') as f: return hashlib.file_digest(f,'sha256').hexdigest()
def extract(archive, target, expected_hash, count, maximum):
    require(digest(archive)==expected_hash,'Archive SHA-256 mismatch')
    with zipfile.ZipFile(archive) as z:
        entries=z.infolist()
        require(len(entries)==count,'Unexpected file count')
        require(sum(x.file_size for x in entries)<=maximum,'Unexpected expanded length')
        seen=set()
        for entry in entries:
            rel=P(entry.filename)
            require(not rel.is_absolute() and '..' not in rel.parts and '\\' not in entry.filename,'Unsafe archive path')
            require(not stat.S_ISLNK(entry.external_attr >> 16),'Archive symlink rejected')
            require(entry.filename not in seen and not entry.is_dir(),'Duplicate/directory entry')
            require(entry.file_size < 25*1024*1024,'Member exceeds 25 MiB')
            require(rel.suffix in ('.json','.png','.bin'),'Unexpected file type')
            seen.add(entry.filename)
        require(z.testzip() is None,'ZIP CRC failed')
        z.extractall(target)
def validate_native(root):
    require(digest(root/'index.json')==INDEX_HASH,'Pack index mismatch')
    index=json.loads((root/'index.json').read_text())
    require(set(index['maps'])=={'albino_01','albino_02','albino_03','escaros_world','yahee_temple','balrog_temple'},'Map set mismatch')
    background=foreground=0
    for mid,row in index['maps'].items():
        require(row['manifest']==mid+'/manifest.json','Manifest path mismatch')
        manifest=root/row['manifest']; require(digest(manifest)==row['sha256'],'Manifest mismatch')
        m=json.loads(manifest.read_text())
        require(m['map_id']==mid and m['plan_sha256']==index['plan_sha256'],'Manifest identity mismatch')
        background += len(m['chunks']); foreground += len(m.get('foreground',[]))
        for chunk in m['chunks']+m.get('foreground',[]):
            require(P(chunk['file']).name==chunk['file'],'Unsafe chunk path')
            p=root/mid/chunk['file']; require(digest(p)==chunk['sha256'],'Chunk mismatch')
            with p.open('rb') as f: require(f.read(8)==b'\x89PNG\r\n\x1a\n','Invalid PNG signature')
        if 'split' in row:
            split=row['split']; require(P(split['file']).name==split['file'],'Unsafe split path')
            require(digest(root/split['file'])==split['sha256'],'Split PNG mismatch')
    require(background==193 and foreground==1,'Unexpected chunk totals')
    return {'maps':6,'background_chunks':background,'foreground_chunks':foreground,'png_files':len(list(root.rglob('*.png'))),'source_files':len([p for p in root.rglob('*') if p.is_file()])}
def install_tree(source,destination):
    for p in source.rglob('*'):
        if not p.is_file(): continue
        target=destination/p.relative_to(source)
        if target.exists(): require(digest(target)==digest(p),'Refusing to replace different existing asset')
        else:
            target.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(p,target)
def main():
    with tempfile.TemporaryDirectory() as t:
        temp=P(t); archive=temp/'native.zip'
        if os.environ.get('LOCAL_NATIVE_ZIP'):
            shutil.copyfile(os.environ['LOCAL_NATIVE_ZIP'],archive)
        else:
            cid=os.environ['TRANSFER_COMMENT_ID']; require(cid.isdecimal(),'Invalid transfer comment')
            req=urllib.request.Request('https://api.github.com/repos/zoog136-hash/-/issues/comments/'+cid,headers={'Accept':'application/vnd.github+json','User-Agent':'TWILIGHT-map-transfer'})
            with urllib.request.urlopen(req,timeout=45) as r: comment=json.load(r)
            require(comment['user']['login']=='zoog136-hash','Unexpected transfer author')
            body=comment['body']; require(body.startswith('TWILIGHT_MAP_TRANSFER_V5\n'),'Missing transfer marker')
            urls=json.loads(body.split('```json\n',1)[1].split('\n```',1)[0])['urls']; require(len(urls)==3,'Expected three sources')
            with archive.open('wb') as output:
                for i,(url,(size,sha)) in enumerate(zip(urls,PARTS),1):
                    parsed=urllib.parse.urlsplit(url)
                    require(parsed.scheme=='https' and (parsed.hostname or '').endswith('.oaiusercontent.com'),'Unexpected transfer host')
                    h=hashlib.sha256(); n=0
                    with urllib.request.urlopen(url,timeout=90) as stream:
                        while True:
                            b=stream.read(1024*1024)
                            if not b: break
                            n+=len(b); require(n<=size,'Source exceeds pinned length'); h.update(b); output.write(b)
                    require(n==size and h.hexdigest()==sha,'Source part mismatch')
                    print('Verified source part',i,flush=True)
        native=temp/'native'; oman=temp/'oman'
        extract(archive,native,NATIVE_HASH,210,280000000)
        extract(ROOT/'external_map_packs/TWILIGHT-map-remake-private-20261015-v2.zip',oman,OMAN_HASH,15,40000000)
        report=validate_native(native)
        destination=ROOT/'external_map_packs'
        install_tree(native,destination/'native_png_v5'); install_tree(oman,destination/'oman_v2')
        (destination/'.gdignore').write_text('# Raw PNG archives: prevent automatic editor imports; no gameplay auto-enable.\n')
        (destination/'.gitattributes').write_text('native_png_v5/** -text\noman_v2/** -text\n')
        entries=[]
        for prefix in ['native_png_v5','oman_v2']:
            for p in sorted((destination/prefix).rglob('*')):
                if p.is_file(): entries.append({'path':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size,'sha256':digest(p)})
        report.update({'schema':1,'native_archive_sha256':NATIVE_HASH,'oman_archive_sha256':OMAN_HASH,'native_index_sha256':INDEX_HASH,'uploaded_source_files':len(entries),'source_bytes':sum(x['bytes'] for x in entries),'runtime_auto_activation':False,'android_test':'NOT_RUN','files':entries})
        (destination/'MAP_ASSET_DELIVERY.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
        print(json.dumps({k:v for k,v in report.items() if k!='files'}),flush=True)
if __name__=='__main__':
    try: main()
    except Exception as e:
        print('Map asset transfer failed:',type(e).__name__,flush=True)
        raise SystemExit(1)
