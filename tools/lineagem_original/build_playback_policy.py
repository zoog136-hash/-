"""Build an explicit compatibility policy without changing original timing/attribute records."""
import argparse,json,pathlib
import original_spr

def build(inputs,pack,output):
 ds=original_spr.read((inputs/'lineagem-category-source-metadata/original-spr').glob('*.spr'));rows=json.loads((inputs/'base508_all_content_validated/content/ListSprAction.json').read_text(encoding='utf-8-sig'))['rows'];candidates={}
 for p in (pack/'actors').glob('*.json'):
  actor=json.loads(p.read_text())
  for role,t in actor['tracks'].items():
   if t['fps'] is not None:continue
   sid=t['source_sprite_id'];d=ds[sid][0]
   if d.alias_target is not None:
    _,base=original_spr.resolve(ds,d.alias_target);action=base.get(t['source_action_id'])
    if action and action['fps']:
     candidates[f'{sid}:{role}']={'fps':action['fps'],'base_sprite_id':d.alias_target,'source_file':action['source_file'],'source_line':action['source_line'],'confidence':'source_value_exact_inheritance_application_unverified_for_M'}
 policy={'schema':1,'default_mode':'compatible','status':'UNVERIFIED_COMPATIBILITY_NOT_ORIGINAL_CLIENT_EQUIVALENCE','pc_default_ticks_per_second':24,'attr128_compat_alpha':0.5,'m_player_actions':{str(r['ID']):r for r in rows},'alias_base_rate_candidates':candidates,'source_clock_corrections':'res://data/lineagem_base508/source_timing_corrections.json','sources':[{'kind':'M_base508_exact_data','path':'content/ListSprAction.json','scope':'PlayerFrameRate only; fallback application is compatibility, PlayerDelay not used to rewrite native ticks'},{'kind':'PC_3_81_author_test_not_M','url':'https://morosedog.gitlab.io/private-lineage-20220524-private-lineage-119/','supports':'PC default24 and sequential110 sections'},{'kind':'PC_3_81_author_test_not_M','url':'https://morosedog.gitlab.io/private-lineage-20220520-private-lineage-115/','supports':'attr8 glowing;attr128 black-edge translucency; no exact blend equation'},{'kind':'public_SPR_parser_documentation_not_M_engine','url':'https://github.com/tony1223/PakViewer/blob/main/docs/LIST_SPR_FORMAT.md','supports':'zero duration native tokens and raw annotation symbols'},{'kind':'Godot_compositor_API_not_Lineage_equivalence','url':'https://docs.godotengine.org/en/stable/classes/class_canvasitemmaterial.html','supports':'standard additive and alpha-mix operations'}],'limits':['No source frames, ticks, FPS, attributes or offsets are overwritten.','Strict mode disables compatibility fallback and unresolved blending.','attr8 additive and attr128 alpha0.5 are declared host approximations, not recovered M equations.','No root/limb/frame interpolation or new effect artwork.']}
 output.write_text(json.dumps(policy,ensure_ascii=False,indent=2)+'\n');print('Compatibility alias-base candidates:',len(candidates))
if __name__=='__main__':
 p=argparse.ArgumentParser()
 for n in ['inputs','pack','output']:p.add_argument('--'+n,type=pathlib.Path,required=True)
 a=p.parse_args();build(a.inputs,a.pack,a.output)
