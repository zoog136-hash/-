"""Bind only exact observed current523 collection CSB nodes; no prefab text as game values."""
import argparse,gzip,hashlib,json,pathlib,zipfile
SCENE='UI/Change/Change_CollectionView.csb'
KEYS=['BUFFCARD_COLLECTION_SEARCH_TEXT','BUFFCARD_COLLECTION_SEARCH_RESET_BUTTON','BUFFCARD_COLLECTION_FILTER_TARGET_BUTTON','BUFFCARD_COLLECTION_BONUS_FILTER_TARGET_BUTTON','BUFFCARD_COLLECTION_GRADE_TAB_LISTVIEW','BUFFCARD_COLLECTION_LISTVIEW','BUFFCARD_COLLECTION_EFFECT_NODE','BUFFCARD_COLLECTION_EFFECT_LISTVIEW','BUFFCARD_COLLECTION_EFFECT_BTN','BUFFCARD_COLLECTION_CONDITION_NODE','BUFFCARD_COLLECTION_CONDITION_BTN']
STATUS=['Nd_Info_Set.Nd_Info_Condition.Panel_Condition.Nd_Item_Register.Graph_Register','Nd_Info_Set.Nd_Info_Condition.Panel_Condition.Nd_Item_Register.Text_Num','Nd_Info_Set.Nd_Info_Condition.Panel_Condition.Nd_Item_Complete.Graph_Complete','Nd_Info_Set.Nd_Info_Condition.Panel_Condition.Nd_Item_Complete.Text_Num_0']
def build(root):
    b=root/'combined_results';summary=json.loads((b/'summary.json').read_text());integrity=json.loads((b/'source_member_integrity.json').read_text())
    for src in summary['sources']:
        raw=(root/'originals'/src['path']).read_bytes()
        assert len(raw)==src['bytes'] and hashlib.sha1(raw).hexdigest()==src['manifest523_sha1'] and hashlib.sha256(raw).hexdigest()==src['sha256']
    tree=json.load(gzip.open(b/'all551_csb_trees.json.gz','rt'))[SCENE]
    for item in integrity:
        if item['member']==SCENE:
            with zipfile.ZipFile(root/'originals'/item['container']) as z:raw=z.read(SCENE)
            assert hashlib.sha256(raw).hexdigest()==item['sha256'] and len(raw)==item['bytes']
            source=item;break
    else:raise ValueError('scene integrity reference missing')
    bypath={}
    for n in tree['nodes']:
        names=[n['name']];parent=n['parent_index']
        while parent is not None and parent!=0:
            node=tree['nodes'][parent];names.insert(0,node['name']);parent=node['parent_index']
        path='.'.join(names)
        if path in bypath:raise ValueError('ambiguous node path '+path)
        bypath[path]=n
    strings={x['key']:x['value'] for x in json.loads((b/'string_binding_dictionary.json').read_text())}
    bindings={}
    for key in KEYS:
        path=strings[key];assert path in bypath,(key,path)
        bindings[key]=dict(scene=SCENE,path=path,node=bypath[path])
    for path in STATUS:assert path in bypath
    return dict(schema=1,source_snapshot='patch523',scene_source=source,bindings=bindings,status_nodes={path:bypath[path] for path in STATUS},limits=['Native key/path/state/resource bindings, adapted Godot layout.','Original frame indices and CSB designer text are not timing, cost or balance values.','External atlas pixels are separately installed; missing referenced pages remain missing.'])
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--evidence-root',type=pathlib.Path,required=True);p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args();data=build(a.evidence_root);a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n');print('verified UI bindings',len(data['bindings']))
