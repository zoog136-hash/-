"""Synthetic prefix/actual-byte frame-adapter regressions; no game art."""
from __future__ import annotations
import contextlib,copy,hashlib,io,json
from pathlib import Path
import sys,tempfile,unittest
from unittest import mock
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools/lineagem_original'))
sys.path.insert(1,str(Path(__file__).resolve().parent))
import build_reference_sp2_bank as bank

def fixture():
    layers=[{'kind':kind,'member':f'Sprite/{100+i}-0.sp2','group_bit':0,'frame_index':0}for i,kind in enumerate(['body','shadow','clothes','clothes','clothes'])]
    actor={'roles':{'selected':{'directions':[[{'layers':layers}]]}}}
    parsed={layer['member']:{'groups':{0:{'frames':[{'samples':1}]}}}for layer in layers}
    return actor,parsed

class SourceClothesPrefixTest(unittest.TestCase):
    def test_successful_prefix_survives_and_later_files_are_not_read(self):
        actor,parsed=fixture();before=copy.deepcopy(actor)
        parsed['Sprite/103-0.sp2']['groups'].clear();parsed.pop('Sprite/104-0.sp2')
        result=bank.apply_client_frame_rules(actor,{},parsed)
        layers=result['roles']['selected']['directions'][0][0]['layers']
        self.assertNotIn('client_null',layers[2]);self.assertEqual(layers[3]['client_null'],'direction_absent')
        self.assertEqual(layers[4]['client_null'],'clothes_prefix_stopped');self.assertEqual(layers[4]['clothes_prefix_stop_layer_index'],3)
        self.assertNotIn('Sprite/104-0.sp2',parsed);self.assertEqual(actor,before)

    def test_body_and_shadow_null_do_not_stop_clothes(self):
        actor,parsed=fixture()
        for member in ['Sprite/100-0.sp2','Sprite/101-0.sp2']:parsed[member]['groups'].clear()
        layers=bank.apply_client_frame_rules(actor,{},parsed)['roles']['selected']['directions'][0][0]['layers']
        self.assertTrue(all(layer['client_null']=='direction_absent'for layer in layers[:2]))
        self.assertTrue(all('client_null'not in layer for layer in layers[2:]))

    def test_empty_frame_vector_is_not_a_null_asset_and_clothes_continue(self):
        actor,parsed=fixture();parsed['Sprite/103-0.sp2']['groups'][0]['frames']=[]
        layers=bank.apply_client_frame_rules(actor,{},parsed)['roles']['selected']['directions'][0][0]['layers']
        self.assertEqual(layers[3]['client_null'],'empty_frame_set');self.assertNotIn('client_null',layers[4])

    def test_each_asset_clamps_to_its_own_frame_count(self):
        actor,parsed=fixture()
        for layer in actor['roles']['selected']['directions'][0][0]['layers']:layer['frame_index']=4
        parsed['Sprite/102-0.sp2']['groups'][0]['frames']=[{'samples':1}for _ in range(3)]
        layers=bank.apply_client_frame_rules(actor,{},parsed)['roles']['selected']['directions'][0][0]['layers']
        self.assertEqual([layer['frame_index']for layer in layers],[0,0,2,0,0]);self.assertTrue(all(layer['clamped_from_frame_index']==4 for layer in layers))

    def test_prefix_stop_resets_per_frame_and_direction(self):
        actor,parsed=fixture();first=actor['roles']['selected']['directions'][0][0]
        first['layers'][3]['group_bit']=1
        good=copy.deepcopy(first);good['layers'][3]['group_bit']=0
        actor['roles']['selected']['directions']=[[first,copy.deepcopy(good)],[copy.deepcopy(good)]]
        directions=bank.apply_client_frame_rules(actor,{},parsed)['roles']['selected']['directions']
        self.assertEqual(directions[0][0]['layers'][4]['client_null'],'clothes_prefix_stopped')
        self.assertTrue(all('client_null'not in layer for layer in directions[0][1]['layers']))
        self.assertTrue(all('client_null'not in layer for layer in directions[1][0]['layers']))

    def compile_frame_case(self,adapter,missing_direction=False):
        from test_reference_sp2_bank import fixture as source_fixture
        metadata,request,text,raw=source_fixture();source=metadata['actions'][request['action_key']]
        if missing_direction:
            text=text.replace('3.Breath(0 1,','3.Breath(1 1,');source['declared_flag']=1;source['raw_body']='1 1,0.0:2'
        else:
            text=text.replace('0.0:2','0.4:2');source['raw_body']='0 1,0.4:2';source['source_tokens_selector_frame_ticks']=[[0,4,2]]
        digest=hashlib.sha256(text.encode('cp949')).hexdigest();source['source_file_sha256']=digest
        metadata['sources']['list_fixture.spr']['sha256']=digest;metadata['declarations'][0]['source_file_sha256']=digest
        with tempfile.TemporaryDirectory(prefix='source-frame-adapter-')as directory:
            root=Path(directory);requests=root/'requests.jsonl';requests.write_text(json.dumps(request)+'\n')
            original=root/'original'/request['target_members'][0];original.parent.mkdir(parents=True);original.write_bytes(raw)
            spr=root/'spr';spr.mkdir();(spr/'list_fixture.spr').write_bytes(text.encode('cp949'))
            args=bank.argparse.Namespace(metadata=root,requests=requests,output=root/'output',plan_only=False,original_root=root/'original',spr_root=spr,dependency_index=None,client_frame_rules=adapter)
            with mock.patch.object(bank,'load_metadata',return_value=metadata),contextlib.redirect_stdout(io.StringIO()):summary=bank.build(args)
            result=list(bank.records(args.output/'action-outcomes.jsonl.gz'))[0];path=args.output/'actors/100/action-3.json'
            record=json.loads(path.read_text())if path.exists()else None
            self.assertEqual(original.read_bytes(),raw);self.assertEqual((spr/'list_fixture.spr').read_bytes(),text.encode('cp949'))
            return summary,result,record

    def test_default_strict_gate_preserves_saved_range_rejection(self):
        summary,result,record=self.compile_frame_case(False)
        self.assertEqual(summary['counts']['compiled_actions'],0);self.assertEqual(result['status'],'blocked_saved_direction_or_frame');self.assertIsNone(record)

    def test_explicit_adapter_reaches_actual_clamp_and_retains_saved_diagnostic(self):
        summary,result,record=self.compile_frame_case(True)
        self.assertEqual(summary['counts']['compiled_actions'],1,result);self.assertTrue(result['saved_address_issues'])
        layer=record['actor']['roles']['source_action:3']['directions'][0][0]['layers'][0]
        self.assertEqual((layer['frame_index'],layer['clamped_from_frame_index']),(0,4))
        self.assertEqual(record['consumer_contract']['clothes_collection_policy'],bank.CLOTHES_PREFIX_POLICY)

    def test_explicit_adapter_keeps_missing_direction_null_without_mirroring(self):
        summary,result,record=self.compile_frame_case(True,missing_direction=True)
        self.assertEqual(summary['counts']['compiled_actions'],1,result);self.assertEqual(len(result['saved_address_issues']),7)
        directions=record['actor']['roles']['source_action:3']['directions'];self.assertNotIn('client_null',directions[0][0]['layers'][0])
        self.assertTrue(all(directions[bit][0]['layers'][0]['client_null']=='direction_absent'for bit in range(1,8)))

if __name__=='__main__':unittest.main()
