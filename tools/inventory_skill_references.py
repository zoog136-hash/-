"""Inventory reference ZIPs without extracting or executing them.

PC Lineage sources and assets are not evidence for Lineage M on 2025-06-17.
Only hashes, counts and inspection scope are committed; no external code/art.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--archives', type=Path, required=True)
args = parser.parse_args()
target = ROOT/'data/skills/research_inputs/external-source-inventory.json'
by_file = {row['file']:row for row in json.loads(target.read_text())}
notes = {
    '09-LineageMSimulator-master.zip':'2017 변신카드 확률 시뮬레이터. 2025 스킬 DB가 아님.',
    '10-PakViewer-main.zip':'PC 리니지 PAK/DAT 도구. README 확인; 실행·복호화·게임 에셋 추출 없음.',
    '11-a1.zip':'PC 리니지 버그 화면 이미지 중심. 파일 목록만 확인; 원작 스킬 프레임 근거로 채택하지 않음.',
    '12-a3.zip':'PC L1J Java 서버. 소환 인스턴스의 주인·타겟·추종·종료 구조만 참고; 코드·수치·에셋 이식 없음.',
    '13-a2-1-.zip':'PC 리니지 리마스터 웹·런처·위키 및 이미지 자료. README/wiki/video_info를 확인; 모바일 원작 수치·아트로 채택하지 않음.'
}
inspected = {
    '09-LineageMSimulator-master.zip':['README_KR.md','README.md'],
    '10-PakViewer-main.zip':['README.md','src/Lin.Helper.Core/README.md'],
    '11-a1.zip':[],
    '12-a3.zip':['src/l1j/server/server/model/Instance/L1SummonInstance.java','src/l1j/server/server/model/skill/action/SummonElemental.java','src/l1j/server/server/serverpackets/S_ShowSummonList.java'],
    '13-a2-1-.zip':['README.md','wiki.md','video_info.md']
}
for filename,note in notes.items():
    path=args.archives/filename
    with path.open('rb') as stream:digest=hashlib.file_digest(stream,'sha256').hexdigest()
    with zipfile.ZipFile(path) as z:
        entries=[entry for entry in z.infolist() if not entry.is_dir()]
        scope=[]
        for entry in entries:
            if any(entry.filename==name or entry.filename.endswith('/'+name) for name in inspected[filename]):
                raw=z.read(entry)
                scope.append({'path':entry.filename,'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw),'inspection':'TEXT_REFERENCE','archive_timestamp':list(entry.date_time),'historical_date_status':'UNKNOWN'})
        by_file[filename]={'file':filename,'sha256':digest,'archive_entries':len(z.infolist()),'files':len(entries),'size':path.stat().st_size,'expanded_bytes':sum(entry.file_size for entry in entries),'licenses':[entry.filename for entry in entries if Path(entry.filename).name.lower().startswith(('license','copying','readme'))],'license_status':'UNKNOWN','skill_files':[entry.filename for entry in entries if 'skill' in Path(entry.filename).name.lower() and Path(entry.filename).suffix.lower() in ('.java','.json','.rs','.go','.yaml','.sql')],'extensions':dict(Counter(Path(entry.filename).suffix.lower() for entry in entries)),'inspected_text':scope,'lineagem_cutoff_validity':'UNKNOWN','adopted_original_skill_values':0,'adopted_publisher_assets':0,'notes':note}
target.write_text(json.dumps(sorted(by_file.values(),key=lambda row:row['file']),ensure_ascii=False,indent=2)+'\n')
resolved={'a2.zip':{'status':'RESOLVED_UPLOAD','replacement':'13-a2-1-.zip','notes':'a2(1).zip 실체를 읽음. 이전 미제공 파일과 바이트 동일 여부는 UNKNOWN.'}}
(target.parent/'external-source-blocked.json').write_text(json.dumps(resolved,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'archives_inventoried':len(by_file),'a2_reupload_inspected':True,'original_numbers_imported':0}))
