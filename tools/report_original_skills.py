"""Publish reviewable coverage, legacy disposition, comparison and continuation lists."""
import csv
import json
from pathlib import Path
import argparse
from collections import Counter

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--cache',type=Path,default=ROOT/'data/skills/research_inputs');args=parser.parse_args()
data=ROOT/'data/skills';dest=ROOT/'docs/skills';dest.mkdir(parents=True,exist_ok=True)
def read(file):return json.loads((data/file).read_text())
master=read('master.json');records=master['records'];inventory=read('research_inventory.json')['records'];balance=read('balance.json')['skills'];sources=read('sources.json');relations=read('relations.json')
by_id={r['id']:r for r in records};old=json.loads((ROOT/'data/game_db_v17.json').read_text())['스킬'];old_names={r['name'] for r in old}
with (dest/'original-vs-twilight.csv').open('w',encoding='utf-8-sig',newline='') as f:
    writer=csv.writer(f,lineterminator='\n');writer.writerow(['ID','직업','스킬명','과거_이름_존재','20250617_완전검증','실행_연결','구현_상태','기존_동명','등급','효과','최소레벨','선행조건_검증','강화대상','밸런스','출처','보류사유'])
    for row in inventory:
        r=by_id.get(row.get('runtime_id',''),{});rel=relations.get(r.get('id',''),{})
        writer.writerow([row['id'],row['class'],row['name'],row.get('historical_presence','UNKNOWN'),'UNKNOWN',r.get('runtime_effect','NONE'),row['implementation'],'예' if row['name'] in old_names else '아니오',r.get('grade','UNKNOWN'),r.get('desc','UNKNOWN'),r.get('minimum_level','UNKNOWN'),rel.get('requires_status','UNKNOWN'),by_id.get(rel.get('upgrades_from'),{}).get('name','UNKNOWN'),'CUSTOM_BALANCE' if r else 'UNKNOWN',' | '.join(x.get('source_url','') for x in row['observations']),row.get('blocked_reason','원작 전 효과 및 VFX 비교 완료 전 PARTIAL')])
workbook=json.loads((args.cache/'audit-workbook.json').read_text());candidates=next(s['rows'][1:] for s in workbook if s['name']=='TWILIGHT_원작후보41');names={r[0] for r in candidates}
with (dest/'legacy-disposition.csv').open('w',encoding='utf-8-sig',newline='') as f:
    writer=csv.writer(f,lineterminator='\n');writer.writerow(['기존스킬명','기존직업','분류','활성_동명','저장정책'])
    for r in old:writer.writerow([r['name'],r['class'],'원작 이름 후보 · 세부검증 필요' if r['name'] in names else '자체 제작 · 활성 도감 제외','예' if any(x['name']==r['name'] for x in records) else '아니오','game_db_v17 원본 유지 / 슬롯·버프·쿨타임 이전 참조 아카이브'])
lines=['# TWILIGHT 원작 스킬 이행 도감 — 검증 중','','기준일: 2025-06-17. 기준일의 전체 원작 목록과 전 효과를 확정한 도감이 아닙니다. 현재 DB 후보는 과거 목록으로 간주하지 않습니다.','','- 현재 Inven 13직업: 662 직업 배정, 486 고유 ID의 상세 메타데이터 확보.','- 조사 인벤토리: %d 직업·이름 레코드. 날짜가 확인되는 과거 기록과 현재 후보를 구분합니다.'%len(inventory),'- 실행 연결: %d개, 모두 PARTIAL. 실제 전투 경로를 연결했지만 원작 전체 효과의 일치 검증은 남아 있습니다.'%len(records),'- 기존 257개 DB 보존: 원작 이름 후보 41개 / 자체 제작 분류 %d개.'%(len(old)-len(names)),'- 원작 미확인 수치는 balance.json의 CUSTOM_BALANCE. 내부 lm_ ID는 NC의 공식 ID가 아닙니다.','','## 직업별 실행 연결','','| 직업 | 이름 | 등급 | 동작 | 레벨 | 선행 조건 | 강화 대상 | 출처 |','|---|---|---|---|---:|---|---|---|']
for job in master['classes']+['공용']:
    for r in records:
        if r['class']!=job:continue
        rel=relations[r['id']];base=by_id.get(rel.get('upgrades_from'),{}).get('name','—');source=sources[r['source_ids'][0]]
        lines.append('| %s | %s | %s | %s | %s | UNKNOWN | %s | [%s](%s) |'%(job,r['name'],r['grade'],r['mode'],r['minimum_level'],base,source['effective'],source['url']))
lines+=['','## 보류와 다음 단계','','research_inventory.json과 original-vs-twilight.csv에 보류 항목을 모두 남겼습니다. 다음 단계는 보류 항목의 2025 직전 설명·등급·PvE 대상 확인, 전후 리부트 계보 확정, 그 결과를 사용한 고유 효과 추가입니다. 그랜드 마스터: 카운터, 리포스트, 카운터 리벤지, 타이탄, 콤보·돌진·소환·마법 복사·버프 제거를 일반 피해나 공통 버프로 대체하지 않습니다.','','원작 영상별 업로드 날짜·타임스탬프·프레임 대조는 아직 UNKNOWN입니다. vfx.json은 자체 제작 프리셋이며 원작 시각 일치 완료를 뜻하지 않습니다. Windows·Android 실기기 성능은 별도 검증이 필요합니다.','','## 파일','','- data/skills/master.json: 실행 스킬 필수 필드와 상태','- research_inventory.json: 역사·현재 후보 및 보류 상태','- curation.json / source_seed.json: 재생성 가능한 수작업 검증 기록','- balance.json / relations.json / status_rules.json: 수치·계승·상태 규칙','- equipment_links.json: 기존 아이템·변신·인형·성물 설명의 발동 옵션 연결 및 BLOCKED 옵션','- vfx.json / assets/skills: ID별 자체 벡터 아이콘·효과 프리셋·합성 WAV','- original-vs-twilight.csv / legacy-disposition.csv: 비교·기존 데이터 처리']
(dest/'CATALOG.md').write_text('\n'.join(lines)+'\n')
fetch=json.loads((args.cache/'fetch-summary.json').read_text()) if (args.cache/'fetch-summary.json').exists() else {'unique_details_cached':len(list((args.cache/'details').glob('*.json'))),'historical_completeness':'UNKNOWN'}
(dest/'research-fetch-summary.json').write_text(json.dumps(fetch,ensure_ascii=False,indent=2)+'\n')
(dest/'external-source-inventory.json').write_text((args.cache/'external-source-inventory.json').read_text())
print(json.dumps({'runtime':len(records),'candidate_records':len(inventory),'legacy_original_name_candidates':len(names),'legacy_custom':len(old)-len(names),'status':dict(Counter(x['implementation'] for x in inventory))},ensure_ascii=False))
