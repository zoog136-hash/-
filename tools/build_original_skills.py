"""Build the dated skill catalogue. Never import current DB values as 2025 facts.

Inputs are public metadata cached by research_original_skills.py and the supplied
historical audit workbook (JSON extraction). No NC artwork or third-party code.
The manifest is an audit inventory, not a claim of historical completeness.
"""
import argparse
import hashlib
import json
import re
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLASSES = ['군주','기사','요정','마법사','다크엘프','총사','투사','암흑기사','신성검사','광전사','사신','뇌신','마검사']
STATUS = ['VERIFIED','INFERRED','CUSTOM_BALANCE','UNKNOWN','NOT_APPLICABLE']
SOURCES=json.loads((ROOT/'data/skills/source_seed.json').read_text())
SPECS=[]
def curate():
    SPECS.clear()
    SPECS.extend(json.loads((ROOT/'data/skills/curation.json').read_text()))

def normalized(s):return re.sub(r'[\s:：()（）·]', '', s).replace('Lv','').lower()
def ident(job,name):return 'lm_'+hashlib.sha256((job+':'+normalized(name)).encode()).hexdigest()[:16]
def field(value=None,status='UNKNOWN',source=None,note=None):
    d={'value':value,'status':status}
    if source:d['sources']=[source]
    if note:d['note']=note
    return d

BASIC=['original_name','original_skill_id','class','school','stage','grade','activation','category']
LEARN=['minimum_level','book_name','book_grade','book_acquisition','requires_skill','requires_skill_level','additional_materials','adena_cost','other_cost','upgrades_from','replaces_skill','inherits_effects','unlock_conditions']
COMBAT=['target','shape','range','attack_type','element','base_damage','damage_multiplier','hit_rule','critical','defense_rule','mr_rule','status','status_chance','duration','cooldown','cast_time','mp_cost','hp_cost','item_cost','weapons','equipment','proc_chance','proc_count','stacking','dispel_conditions','immunity_conditions']
VISUAL=['original_icon','cast_motion','cast_vfx','projectile','projectile_movement','impact_vfx','area_vfx','status_vfx','persistent_vfx','end_vfx','sound','hit_frame','total_duration','reference_video','upload_date','timestamp']
PASSIVE=['stats','upgrade','proc','mark','amplify','stack_defense','stack_attack','recovery']

def build(cache):
    curate()
    out=ROOT/'data/skills';out.mkdir(parents=True,exist_ok=True)
    registry={}
    saved_metadata=json.loads((ROOT/'data/skills/research_inputs/evidence-metadata.json').read_text()) if (ROOT/'data/skills/research_inputs/evidence-metadata.json').exists() else {}
    for k,(date,url,kind,filename) in SOURCES.items():
        f=cache/'evidence'/f'{filename}.txt'
        registry[k]={'url':url,'published':date,'effective':date,'effective_status':'VERIFIED' if kind=='OFFICIAL' else 'UNKNOWN','observed_at':date,'type':kind,'scope':'historical observation, continuity to cutoff not assumed','sha256':hashlib.sha256(f.read_bytes()).hexdigest() if f.exists() else None}
        for field_name in ['published','effective','effective_status','page_modified','sha256','hash_scope','api_response_sha256','reference_video','retrieved_at']:
            if field_name in saved_metadata.get(k, {}):registry[k][field_name]=saved_metadata[k][field_name]
        html_file=cache/'evidence'/f'{filename}.html'
        if html_file.exists():
            h=html_file.read_text()
            for kind_date,field_name in [('Published','published'),('Modified','page_modified')]:
                match=re.search(r'"date'+kind_date+r'":"([^"]+)"',h)
                if match:registry[k][field_name]=match.group(1)
            if registry[k].get('page_modified','')[:10] > '2025-06-17':raise ValueError('Post-cutoff revised secondary source '+k)
    roster=json.loads((cache/'current-skill-roster.json').read_text())
    # Listing versions from the future are audit candidates only.
    inventory={};by_name={}
    for group in roster:
        job=group['job']
        if isinstance(group,dict):
            for s in group.get('skills',[]):
                name=s['name'];sid=ident(job,name)
                inventory[sid]={'id':sid,'name':name,'class':job,'inven_id':s['code'],'observations':[{'source_url':group['url'],'effective':None,'status':'UNKNOWN','scope':'current page; no historical overwrite'}],'historical_presence':'UNKNOWN','implementation':'BLOCKED','pve':'UNKNOWN','blocked_reason':'기준일 직전 설명·PvE 대상 검증 필요'}
                by_name[job,normalized(name)]=sid
    workbook=json.loads((cache/'audit-workbook.json').read_text())
    for sheet in workbook:
        if sheet['name']!='원작근거_직업별':continue
        for row in sheet['rows'][1:]:
            if len(row)<6:continue
            job,name,date,scope,url=row[:5];sid=by_name.get((job,normalized(name)),ident(job,name))
            if sid not in inventory:inventory[sid]={'id':sid,'name':name,'class':job,'inven_id':None,'observations':[],'historical_presence':'UNKNOWN','implementation':'BLOCKED','pve':'UNKNOWN','blocked_reason':'역사적 명칭의 개편·유지 여부 검증 필요'}
            inventory[sid]['observations'].append({'source_url':url,'effective':date,'status':'VERIFIED','scope':scope})
            inventory[sid]['historical_presence']='VERIFIED'
    records=[];balance={};relations={};vfx={}
    spec_ids={(s['job'],normalized(s['name'])):ident(s['job'],s['name']) for s in SPECS}
    old=json.loads((ROOT/'data/game_db_v17.json').read_text())['스킬']
    old_names={normalized(s['name']):s for s in old}
    for s in SPECS:
        job,name,source,mode=s['job'],s['name'],s['source'],s['mode'];sid=ident(job,name)
        values={'power':40,'mp':10,'hp':0,'range':240,'duration':5,'cooldown':8 if mode=='status' else 2,'cast_time':.42,'global_cooldown':.3,'shape':'single','targets':6,'radius':128,'attack_type':'none','element':'none','proc_chance':1,'status_chance':.6,'stats':{},'items':{},'weapons':[],'counter_chance':{'일반':.1,'고급':.1,'희귀':.1,'영웅':.15,'전설':.2,'신화':.25,'유일':.3}[s['grade']],'counter_multiplier':1}
        excluded={'job','name','grade','source','mode','description','upgrades','requires','proof','classes','stage','school','level','motif','additional_sources','mechanism_proofs'}
        values.update({k:v for k,v in s.items() if k not in excluded})
        values['minimum_level']=s.get('level',1 if job=='공용' and s.get('stage',1)==1 else 10 if job=='공용' else {'일반':30,'영웅':60,'전설':80,'신화':80}[s['grade']])
        passive_mode=mode in PASSIVE
        if passive_mode:values['mp']=0;values['hp']=0;values['items']={}
        proof=s.get('proof',{}).copy()
        if 'level' in s and source in ['thunder22','classes24']:proof['minimum_level']=source
        # Even values shown on current DB are not accepted as dated numerical proof.
        balance[sid]={k:field(v,'VERIFIED' if k in proof else 'CUSTOM_BALANCE',proof.get(k),None if k in proof else 'TWILIGHT offline fallback; original number unconfirmed') for k,v in values.items()}
        rec={'id':sid,'name':name,'class':job,'classes':s.get('classes',CLASSES if job=='공용' else [job]),'grade':s['grade'],'activation':'passive' if passive_mode else 'active','mode':mode,'effect':'original','origin':'LINEAGEM_20250617','desc':s['description'],'source_ids':[source],'historical_effective':registry[source]['effective'],'pve':'INFERRED','implementation':'PARTIAL','runtime_effect':'CONNECTED','historical_continuity':'UNKNOWN','stage':s.get('stage',1),'school':s.get('school','rune' if job=='마검사' else 'class' if job!='공용' else 'general_magic'),'minimum_level':values['minimum_level'],'icon':f'res://assets/skills/icons/{sid}.svg','fields':{g:{k:field() for k in keys} for g,keys in [('basic',BASIC),('learning',LEARN),('combat',COMBAT),('visual',VISUAL)]}}
        for k,val in [('original_name',name),('class',job),('grade',s['grade']),('activation',rec['activation'])]:rec['fields']['basic'][k]=field(val,'VERIFIED',source)
        rec['fields']['basic']['school']=field(rec['school'],'INFERRED',source)
        rec['fields']['basic']['stage']=field(rec['stage'],'VERIFIED' if source=='thunder22' else 'INFERRED',source)
        rec['fields']['basic']['category']=field(mode,'INFERRED',source)
        rec['fields']['learning']['minimum_level']=balance[sid]['minimum_level']
        rel={'requires_skill':[],'requires_skill_level':{},'upgrades_from':None,'replaces_skill':None,'inherits_effects':[],'unlock_conditions':[],'requires_status':'UNKNOWN','relationship_status':'NOT_APPLICABLE' if mode!='upgrade' else 'VERIFIED'}
        if s.get('upgrades'):
            base=spec_ids.get((job,normalized(s['upgrades'])))
            if not base:raise ValueError('Missing upgrade base '+s['upgrades'])
            rel.update(upgrades_from=base,inherits_effects=[base],patch=s['patch'])
            rec['fields']['learning']['upgrades_from']=field(base,'VERIFIED',source)
            rec['fields']['learning']['inherits_effects']=field([base],'VERIFIED',source)
        # UNKNOWN is explicitly different from verified absence of prerequisites.
        relations[sid]=rel
        bk={'군주':'마법서','기사':'기술서','요정':'정령의 수정','마법사':'마법서','다크엘프':'흑정령의 수정','총사':'기술 교본','투사':'용기사의 서판','암흑기사':'흑기사의 기술서','신성검사':'성서','광전사':'전사의 인장','사신':'사신의 서','뇌신':'뇌신의 서판','마검사':'룬 마법서','공용':'마법서'}[job]
        rec['book_name']=f'{bk} ({name})'
        rec['fields']['learning']['book_name']=field(rec['book_name'],'INFERRED',source)
        rec['fields']['learning']['book_grade']=field(s['grade'],'INFERRED',source)
        if 'book_cost' not in values:balance[sid]['book_cost']=field({'일반':3000,'영웅':100000,'전설':400000,'신화':1000000}[s['grade']],'CUSTOM_BALANCE',note='Offline book shop fallback; historical acquisition remains UNKNOWN')
        rec['fields']['learning']['adena_cost']=balance[sid]['book_cost']
        cm={'power':'base_damage','mp':'mp_cost','hp':'hp_cost','items':'item_cost','weapons':'weapons','shape':'shape','range':'range','attack_type':'attack_type','element':'element','status':'status','status_chance':'status_chance','duration':'duration','cooldown':'cooldown','cast_time':'cast_time','proc_chance':'proc_chance','hits':'proc_count','multiplier':'damage_multiplier'}
        for key,dst in cm.items():
            if key in balance[sid]:rec['fields']['combat'][dst]=balance[sid][key]
        rec['fields']['combat']['target']=field('self' if mode in ['buff','heal','stealth','counter','convert','cleanse','teleport','summon'] else 'NPC','INFERRED',source)
        # A unique preset is authored for each ID; resemblance is NOT claimed
        # before dated video frames have been inspected.
        motif=s.get('motif',mode);h=int(sid[-6:],16)
        vfx[sid]={'cast_vfx':sid+':cast','projectile_vfx':sid+':projectile','impact_vfx':sid+':impact','persistent_vfx':sid+':persistent','end_vfx':sid+':end','status_vfx':sid+':status','audio_profile':sid+':audio','motif':motif,'hue':(h%360)/360,'seed':h,'animation_timeline':{'cast':0,'release':'player_motion_event','impact':'collision_or_attack_marker','end':.7},'visual_verification':'UNKNOWN','references':[{'source':source,'url':registry[source]['url'],'upload_date':None,'timestamp':None,'status':'UNKNOWN','note':'mechanics reference; dated VFX/video comparison pending'}]}
        rec['comparison']=['기존 구현 수정' if normalized(name) in old_names else '신규 구현','원작 미확인 수치에 자체 밸런스 적용']
        rec['source_ids']=list(dict.fromkeys([source]+s.get('additional_sources',[])))
        if s.get('mechanism_proofs'):
            rec['mechanisms']={key:field(True,'VERIFIED',evidence) for key,evidence in s['mechanism_proofs'].items()}
        records.append(rec)
        entry=inventory.get(by_name.get((job,normalized(name)),''))
        if entry is not None:entry.update(implementation='PARTIAL',runtime_id=sid,pve='INFERRED')
        else:inventory[sid]={'id':sid,'name':name,'class':job,'observations':[{'source_url':registry[source]['url'],'effective':registry[source]['effective'],'status':'VERIFIED','scope':'dated mechanism reference'}],'historical_presence':'VERIFIED','implementation':'PARTIAL','runtime_id':sid,'pve':'INFERRED'}
    # Explicit NPC/PC scope in the 2022 launch table; never guess from name.
    for job,name,source,reason in [('뇌신','템페스트','thunder22','공식 출시 설명의 대상이 적 PC로 한정'),('총사','컴뱃 업','guns25','2025-03 설명의 효과가 PvP 대미지 리덕션뿐임')]:
        sid=by_name.get((job,normalized(name)),ident(job,name))
        inventory.setdefault(sid,{'id':sid,'name':name,'class':job,'observations':[],'historical_presence':'VERIFIED'})
        inventory[sid].update(implementation='PVP_EXCLUDED',pve='NOT_APPLICABLE',exclusion_source=source,blocked_reason=reason)
        inventory[sid]['observations'].append({'source_url':registry[source]['url'],'effective':registry[source]['effective'],'status':'VERIFIED','scope':'PvP-only effect; historical continuity otherwise unknown'})
    for e in inventory.values():
        if e['class']=='뇌신' and normalized(e['name'])==normalized('템페스트'):
            e.update(implementation='PVP_EXCLUDED',pve='NOT_APPLICABLE',blocked_reason='공식 2022-08-24 설명의 대상이 적 PC로 한정',exclusion_source='thunder22')
    # Every candidate has the same required field schema. Undated current
    # metadata is retained under current_candidate, never inside VERIFIED facts.
    for entry in inventory.values():
        if 'runtime_id' in entry:
            runtime=next(r for r in records if r['id']==entry['runtime_id'])
            entry['fields']=runtime['fields']
        else:
            entry['fields']={g:{k:field() for k in keys} for g,keys in [('basic',BASIC),('learning',LEARN),('combat',COMBAT),('visual',VISUAL)]}
        entry['historical_continuity']='UNKNOWN'
    data={'schema_version':1,'cutoff':'2025-06-17','classes':CLASSES,'completeness':'UNKNOWN','records':records}
    outputs={'master.json':data,'balance.json':{'schema_version':1,'counter_fallback':{'일반':.1,'고급':.1,'희귀':.1,'영웅':.15,'전설':.2,'신화':.25,'유일':.3},'skills':balance},'relations.json':relations,'vfx.json':vfx,'sources.json':registry,'research_inventory.json':{'cutoff':'2025-06-17','completeness':'UNKNOWN','warning':'Current pages are candidates, dated observations are not a complete cutoff snapshot. Unresolved mechanisms stay BLOCKED.','records':list(inventory.values())},'status_rules.json':{'boss_duration_factor':.35,'boss_chance_factor':.35,'refresh':'max_remaining','immunities':['stun','hold','fear','silence','poison','bleed','slow'],'numerical_status':'CUSTOM_BALANCE'}}
    for file,d in outputs.items():(out/file).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
    links=[];equipment_balance={}
    runtime_names={normalized(r['name']):r['id'] for r in records}
    for category,items in json.loads((ROOT/'data/catalog_v19.json').read_text()).items():
        if category not in ['아이템','변신','마법인형','성물'] or not isinstance(items,list):continue
        for item in items:
            mapped=[]
            for fragment in str(item.get('desc','')).split('·'):
                match=re.match(r'\s*발동:\s*(.*?)(?:\s+(\d+(?:\.\d+)?)%)?\s*$',fragment)
                if not match:continue
                name=match.group(1);id=runtime_names.get(normalized(name));key=hashlib.sha256((category+':'+item['name']+':'+name).encode()).hexdigest()[:16]
                if id:
                    mapped.append({'key':key,'skill_id':id,'trigger':'on_hit','status':'INFERRED','history':'UNKNOWN','note':'Existing catalog association; original item effect date not yet verified'})
                    equipment_balance[key]=field(float(match.group(2))/100 if match.group(2) else .05,'CUSTOM_BALANCE',note='Current option probability is not accepted as a historical fact; local conservative fallback')
                else:mapped.append({'key':key,'name':name,'status':'BLOCKED','history':'UNKNOWN','note':'No verified runtime mechanism; never converted to generic damage'})
            if mapped:links.append({'category':category,'name':item['name'],'links':mapped})
    (out/'equipment_links.json').write_text(json.dumps({'records':links},ensure_ascii=False,indent=2)+'\n')
    balances=outputs['balance.json'];balances['equipment']=equipment_balance;balances['runtime_defaults']={k:field(v,'CUSTOM_BALANCE') for k,v in {'equipment_level_damage_percent':2,'sp_base':1,'sp_int_baseline':12,'sp_int_divisor':3}.items()}
    (out/'balance.json').write_text(json.dumps(balances,ensure_ascii=False,indent=2)+'\n')
    make_icons(records,vfx)
    make_audio(records,vfx)
    print(json.dumps({'runtime_records':len(records),'audit_assignments':len(inventory),'classes':len(CLASSES),'historical_completeness':'UNKNOWN'},ensure_ascii=False))

def make_icons(records,vfx):
    dest=ROOT/'assets/skills/icons';dest.mkdir(parents=True,exist_ok=True)
    for r in records:
        p=vfx[r['id']];seed=p['seed'];hue=int(p['hue']*360)
        # Independent vector art. Distinct glyph, color, rune positions, and
        # silhouette per skill ID; no reused bitmap or publisher artwork.
        paths=['M34 8L23 32h11l-5 24 21-31H38z','M14 14L49 49m-8-3 9-8M20 15l-5 5','M32 9L51 18v15Q48 48 32 56Q16 48 13 33V18z','M10 37Q31 5 54 37Q32 65 10 37z','M16 50Q10 28 31 11Q30 26 45 31Q57 46 32 55z','M9 32h45M43 21l11 11-11 11','M32 9L52 32 32 55 12 32z','M14 44L32 14l18 30z']
        glyph='M22 51V35L16 29V20L25 16V8h14v8l9 4v9l-6 6v16M22 35h20M25 16h14M28 8v8M36 8v8M30 36v17M36 36v17M8 32h9v15l-5 6-5-6V32' if r['mode']=='summon' else paths[seed%len(paths)]
        marks=''.join(f'<circle cx="{12+(seed//(i+1))%40}" cy="{9+(seed//(i+3))%45}" r="{1+i%2}" fill="hsl({(hue+80)%360},80%,75%)"/>' for i in range(4))
        svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><defs><radialGradient id="g"><stop stop-color="hsl({hue},55%,32%)"/><stop offset="1" stop-color="#080e1b"/></radialGradient></defs><rect x="1" y="1" width="62" height="62" rx="9" fill="url(#g)" stroke="hsl({hue},70%,70%)" stroke-width="2"/><path d="{glyph}" fill="none" stroke="hsl({hue},85%,76%)" stroke-width="4" stroke-linejoin="round"/>{marks}<path d="M7 58h{15+seed%33}" stroke="hsl({hue},80%,55%)" stroke-width="2"/></svg>'
        (dest/(r['id']+'.svg')).write_text(svg)

def make_audio(records,presets):
    """Original short synth timbres, not extracted or imitated audio samples."""
    dest=ROOT/'assets/skills/audio';dest.mkdir(parents=True,exist_ok=True)
    for record in records:
        sid=record['id'];seed=presets[sid]['seed'];noise=random.Random(seed);samples=[]
        rate=16000;frequency=180+seed%650
        for i in range(2400):
            t=i/rate;envelope=(1-i/2400)**2*min(1,i/80)
            tone=math.sin(math.tau*frequency*t)+.3*math.sin(math.tau*frequency*2.01*t)
            if 'thunder' in presets[sid]['motif'] or 'lightning' in presets[sid]['motif']:tone=.55*tone+.5*noise.uniform(-1,1)
            samples.append(struct.pack('<h',int(max(-1,min(1,tone*.18*envelope))*32767)))
        with wave.open(str(dest/(sid+'.wav')),'wb') as wav:
            wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(rate);wav.writeframes(b''.join(samples))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--cache',type=Path,default=ROOT/'data/skills/research_inputs');args=parser.parse_args();build(args.cache)
