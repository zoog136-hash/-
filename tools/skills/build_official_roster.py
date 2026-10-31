#!/usr/bin/env python3
"""Build a bounded, class-aware registry from observed official guide tables.
Unpublished combat values stay null and never acquire runtime defaults.
"""
import argparse, collections, hashlib, json, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def norm(value): return re.sub(r'\s+', '', value).replace('디스인티그레이트','디스인트그레이트').replace('셋팅업','세팅업')
SHARED_REVIEW = {(cls,name) for cls,names in {
    "요정":["블레스드 아머","턴 언데드","프로즌 클라우드","파이어 볼","콘 오브 콜드","그레이터 힐","콜 라이트닝","선 버스트"],
    "신성검사":["블레스드 아머","턴 언데드","프로즌 클라우드"]}.items() for name in names}
# Explicit semantic review of the observed official descriptions. This grants
# preview art only; no numeric, targeting, proc, or skill ownership inheritance.
PREVIEW_REVIEW = {
    '프라임 소드':('엑스칼리버','projected sword'),
    '임페리얼 아머':('실드','self protection'),
    '임페리얼 배리어':('앱솔루트 배리어','temporary protection'),
    '블레이드 스턴':('쇼크 스턴','stun impact'),
    '엘리멘탈 큐어':('힐','self recovery'),
    '엘리멘탈 실드':('실드','damage protection'),
    '엘리멘탈 스턴':('쇼크 스턴','stun impact'),
    '버닝 웨폰':('파이어스톰','fire motif only; not the original weapon animation'),
    '플레임 소드':('파이어스톰','fire motif only; not the original sword animation'),
    '네이쳐스 블레싱':('힐','health recovery'),
    '어스 실드':('아이언 스킨','self protection'),
    '리무브 커스':('큐어 포이즌','cleansing motif; not identical debuff rules'),
    '힐 올':('힐','health recovery; not a party-target implementation'),
    '캔슬레이션':('큐어 포이즌','status removal motif only'),
    '다크스타':('미티어 스트라이크','falling meteor motif; not the original dark-star art'),
    '쉐도우 스턴':('다크 스턴','stun impact; movement not implemented'),
    '이머전시 케어':('힐','self recovery'),
    '브레스 스턴':('쇼크 스턴','stun impact; chain combo not implemented'),
    '다크 미러':('카운터 배리어','reflection/protection motif'),
    '매직 미러':('카운터 배리어','reflection/protection motif'),
    '세인트 그레이스':('힐','self recovery'),
    '파워 블러드':('블러드 러스트','blood motif only; life steal not implemented'),
    '골든 플레이트':('실드','temporary armor motif; charge not implemented'),
    '데스 스턴':('다크 스턴','stun impact; death-heal not implemented'),
    '룬 스트라이크':('룬 스턴','rune stun motif'),
    '샌드 스톰':('이럽션','ground burst motif only; not original sand art'),
    '라이트닝 블로우':('썬더 볼트','lightning motif only'),
    '썬더 플릭':('썬더 볼트','lightning motif only'),
}

def build(source):
    guides=json.loads(source.read_text())['guides']
    master=json.loads((ROOT/'data/skills/master.json').read_text())['records']
    supplement=json.loads((ROOT/'data/skills/current_official_specs.json').read_text())['records']
    existing={norm(r['name']):r for r in master+supplement}
    grouped={}; aliases={}; observations=[]
    for guide in guides:
        for table in guide['tables']:
            for row in table:
                if len(row)!=8 or '습득' in row[2]['text']: continue
                name=re.sub(r'\s+',' ',row[1]['text']).strip()
                if name in ['마법 이름','기술 이름'] or not name:continue
                key=norm(name)
                facts={'class':guide['class'],'name':name,'source_url':guide['url'],'updated_date':guide['document_updated'],
                    'level_display':row[2]['text'].strip(),'mp_display':row[3]['text'].strip(),'hp_display':row[4]['text'].strip(),
                    'material_display':row[5]['text'].strip(),'duration_display':row[6]['text'].strip()}
                prior=existing.get(key)
                if prior:
                    facts.update(status='existing_alias' if re.sub(r'\s+','',name)!=re.sub(r'\s+','',prior['name']) else 'existing_name',runtime_name=prior['name'])
                    if facts['status']=='existing_alias':aliases[name]=prior['name']
                    if guide['class'] not in prior.get('classes',[prior['class']]):
                        facts['status']='existing_shared_class' if (guide['class'],prior['name']) in SHARED_REVIEW else 'existing_class_unreviewed'
                        if facts['status']=='existing_shared_class':
                            assert facts['level_display'].isdigit() and facts['mp_display'].isdigit()
                            facts['semantic_review']='Same named self-defense, undead-only, elemental attack or self-heal spell; reuse existing TWILIGHT mechanics, not unpublished original coefficients.'
                elif key=='콜클랜':facts['status']='excluded_clan_only'
                else:
                    facts['status']='missing_enhancement' if re.search(r'\([^)]*\)|Lv\d|그랜드 마스터',name) else 'missing_base'
                    grouped.setdefault(key,[]).append(facts)
                observations.append(facts)
    references=[]
    for key,rows in grouped.items():
        row=rows[0];name=row['name'];classes=list(dict.fromkeys(r['class'] for r in rows))
        level=int(row['level_display']) if row['level_display'].isdigit() else None
        passive='패시브' in row['mp_display']
        official={'source_url':row['source_url'],'updated_date':row['updated_date'],'accessed_date':'2026-10-30',
            'observed_via':'official guide table; class-specific observations retained in official_roster.json',
            'current_name':name,'learning_level':level,'mp_cost':int(row['mp_display']) if row['mp_display'].isdigit() else None,
            'hp_cost':int(row['hp_display']) if row['hp_display'].isdigit() else None,'duration':None,'cooldown_seconds':None,
            'material':None if row['material_display']=='-' else row['material_display'],'grade':None,
            'activation':'passive' if passive else 'active','mode':'passive' if passive else 'active',
            'effect_summary':'공식 가이드에서 확인한 스킬입니다. 실행에 필요한 계수·조건·재사용 시간은 미확인입니다.',
            'numeric_status':'Unknown is null, never zero. Registration is not implementation.'}
        base_key=norm(re.split(r'\(|Lv\d', name)[0])
        base=existing.get(base_key) if base_key!=key else None
        references.append({'visual_reference_id':base.get('id','lmref_'+hashlib.sha256((base['class']+':'+base['name']).encode()).hexdigest()[:16]) if base else '', 'visual_reference_name':base['name'] if base else '', 'name':name,'class':classes[0],'classes':classes,'historical_aliases':[],'class_observations':rows,
            'current_official':official,'historical':{'source_url':row['source_url'],'existence_verified':True},
            'classification':row['status'],'implementation_gate':'Reference only; do not synthesize combat effects or values.',
            'missing_runtime_fields':['피해·회복·확률·강화 계수와 발동 조건','공개되지 않은 재사용·습득 규칙']})
    for reference in references:
        review=PREVIEW_REVIEW.get(reference['name'])
        if not review:continue
        base=existing[norm(review[0])]
        reference['visual_reference_id']=base['id']
        reference['visual_reference_name']=base['name']
        reference['visual_matching_basis']='Official description semantic review: '+review[1]+'. TWILIGHT similar preview only; original animation/behavior unverified.'
        reference['visual_review_source']=reference['current_official']['source_url']
    by_name={norm(row['name']):row for row in references}
    for reference in references:
        if reference['visual_reference_id'] or reference['classification']!='missing_enhancement':continue
        base_key=norm(re.split(r'\(|Lv\d',reference['name'])[0])
        base=by_name.get(base_key)
        if base and base is not reference and base['visual_reference_id']:
            reference['visual_reference_id']='lmref_'+hashlib.sha256((base['class']+':'+base['name']).encode()).hexdigest()[:16]
            reference['visual_reference_name']=base['name']
            reference['visual_matching_basis']='Reviewed base-skill preview only; enhancement art and behavior unverified.'
    output={'schema':1,'scope':'Observed official guide pages, not a claim of a complete live-service roster.',
        'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'class_count':len(guides),
        'observations':observations,'aliases':aliases,'references':references,'counts':dict(collections.Counter(r['status'] for r in observations))}
    (ROOT/'data/skills/official_roster.json').write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'classes':len(guides),'observations':len(observations),'unique_observed_names':len({norm(r['name']) for r in observations}),'new_reference_records':len(references),'classifications':output['counts'],'aliases':aliases},ensure_ascii=False))
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--input',type=Path,required=True);build(p.parse_args().input)
