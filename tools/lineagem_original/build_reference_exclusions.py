"""Build exact playback-only guards from the preserved source lookup, not a new search."""
import sys,json,hashlib,pathlib,collections,argparse
parser=argparse.ArgumentParser()
parser.add_argument('--audit',type=pathlib.Path,required=True)
parser.add_argument('--pack',type=pathlib.Path,required=True)
parser.add_argument('--catalog',type=pathlib.Path,default=pathlib.Path('data/lineagem_base508/cards.json'))
parser.add_argument('--output',type=pathlib.Path,default=pathlib.Path('data/lineagem_base508/unlocated_effect_exclusions.json'))
args=parser.parse_args()
root=args.pack;audit=json.loads(args.audit.read_text())
def sha(s):return hashlib.sha256(s.encode()).hexdigest()
def ref_text(actor):return '\n'.join(str(d['body']) for d in actor.get('source_all_declarations',{}).get('directives',[]) if d['code']==105)
cache={}
def actor(sid):
 if sid not in cache:cache[sid]=json.load(open(root/'actors'/f'{sid}.json'))
 return cache[sid]
rules=[];events=[];cards={}
for req in audit['attachment_requests']:
 if req['availability_classification']!='entire_prefix_not_located':continue
 for use in req['usages']:
  a=actor(use['actor_sprite_id']);t=a['tracks'][use['role']];layer=int(req['source_layer_id']);info=next(i for i in t['source_effect_layers'] if int(i['sprite_id'])==layer)
  rule={'actor_sprite_id':int(a['source_sprite_id']),'body_id':int(a['body_id']),'role':use['role'],'source_sprite_id':int(t['source_sprite_id']),'source_action_id':int(t['source_action_id']),'source_raw_body_sha256':sha(t['source_raw_body']),'source_clothes_body_sha256':sha(ref_text(a)),'layer_id':layer,'physical_layer_id':int(info['physical_sprite_id']),'source_relation':str(info['relation']),'source_attributes':[str(x) for x in info['source_attributes']],'chunk':int(req['address_split']['chunk']),'file':req['file'],'reason':'user_approved_unlocated_reference_excluded_not_original_M_equivalence'}
  rules.append(rule)
  for card in use['registered_source_card_references']:cards[card['source_id']]=card
for req in audit['missing_event_requests']:
 for use in req['usages']:
  a=actor(use['actor_sprite_id']);t=a['tracks'][use['role']]
  rule={'actor_sprite_id':int(a['source_sprite_id']),'body_id':int(a['body_id']),'role':use['role'],'source_sprite_id':int(t['source_sprite_id']),'source_action_id':int(t['source_action_id']),'source_raw_body_sha256':sha(t['source_raw_body']),'annotation_sha256':sha(use['annotation']['raw']),'token_index':int(use['annotation']['token_index']),'event_sprite_id':int(req['sprite_id']),'file':req['required_files'][0]['file'],'reason':'user_approved_unlocated_reference_excluded_not_original_M_equivalence'}
  events.append(rule)
  for card in use['registered_source_card_references']:cards[card['source_id']]=card
result={'schema':1,'policy_id':'user_approved_base508_unlocated_effect_exclusion_v1','source_snapshot':'base508','default_enabled':True,'M_equivalence_verified':False,'source_audit_sha256':hashlib.sha256(args.audit.read_bytes()).hexdigest(),'limits':'Playback copies only; preserve raw definitions/pixels/body/ticks/sparse12/available effects/awakening. Exact guards fail closed to ordinary source behavior; never suppress a compiled pixel layer or available overlay.','layer_rules':rules,'event_rules':events,'affected_source_cards':sorted(cards.values(),key=lambda x:x['source_id'])}
db=json.loads(args.catalog.read_text());by={r['sourceId']:(c,r) for c,rs in db['catalog'].items() for r in rs}
for entry in result['affected_source_cards']:
 c,r=by[entry['source_id']];g=int(r['source_grade_id']);entry.update({'source_grade_id':g,'source_grade_label':r['grade'],'runtime_policy':'exclude_unlocated_references' if g in [0,1,2,3,4] else 'classification_only_no_automatic_exclusion'})
result['active_source_grade_ids']=[0,1,2,3,4];result['higher_grade_policy']='Grades5/32/52 classification only; grade71 event separate; no resumed search.'
p=args.output;p.write_text(json.dumps(result,ensure_ascii=False,separators=(',',':'))+'\n')
print('layer_rules',len(rules),'addresses',len({r['file'] for r in rules}),'event_rules',len(events),'targets',len({r['event_sprite_id'] for r in events}),'cards',len(cards))
