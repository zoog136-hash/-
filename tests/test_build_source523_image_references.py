#!/usr/bin/env python3
"""Structural metadata fixtures only: no source artwork or real source records."""
import gzip
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / 'tools/images/build_source523_image_references.py'


def dump(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value), encoding='utf-8')


def dump_lines(path, values):
    path.parent.mkdir(parents=True, exist_ok=True)
    with gzip.open(path, 'wt') as stream:
        for value in values: stream.write(json.dumps(value)+'\n')


def read_lines(path):
    with gzip.open(path,'rt') as stream: return [json.loads(line) for line in stream]


class ImageReferenceStructuralFixtures(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='image-reference-structural-fixtures-')
        self.root=pathlib.Path(self.temp.name)
        self.tables=self.root/'tables'
        self.inventory=self.root/'inventory'
        self.output=self.root/'private-output'
        self.types=[{'ID':1,'Name':'fixture_non_image_type','Path':'icon/'},
                    {'ID':9,'Name':'fixture_emoticon_type','Path':'Image/Emoticon/'},
                    {'ID':11,'Name':'fixture_mission_type','Path':'Image/Mission/'}]
        self.assets=[{'AssetId':0,'AssetTypeId':1,'FilePath':''},
                     {'AssetId':11,'AssetTypeId':11,'FilePath':'fixture_exact.png'},
                     {'AssetId':12,'AssetTypeId':11,'FilePath':'fixture_replaced.png'},
                     {'AssetId':13,'AssetTypeId':11,'FilePath':'fixture_absent.png'},
                     {'AssetId':21,'AssetTypeId':9,'FilePath':'fixture_filename_02.png'},
                     {'AssetId':22,'AssetTypeId':9,'FilePath':'fixture_filename_01.png'},
                     {'AssetId':31,'AssetTypeId':1,'FilePath':'fixture_icon.png'}]
        paths={r['ID']:r['Path'] for r in self.types}
        self.bindings=[{'asset_id':r['AssetId'],'row':r,
                        'path':paths[r['AssetTypeId']]+r['FilePath'],
                        'status':('zero_or_empty' if r['AssetId']==0 else 'exact_catalog_path' if r['AssetId']==11
                                  else 'current_replaced_image_member_unverified' if r['AssetId']==12 else 'not_in_available_member_catalog')}
                       for r in self.assets]
        self.retained=[{'container':'fixture_retained.dat','path':'Image/Mission/fixture_exact.png',
                        'category':'Image/Mission','encrypted_bytes':128,'plain_bytes':123,
                        'sha256':'fixture-metadata-only-not-pixel-proof','historical_card_pack_lineage':False},
                       {'container':'fixture_retained.dat','path':'Image/Mission/fixture_unreferenced.png',
                        'category':'Image/Mission','encrypted_bytes':64,'plain_bytes':61,
                        'sha256':'fixture-metadata-only-not-pixel-proof','historical_card_pack_lineage':False}]
        dump(self.tables/'AssetType.json',{'rows':self.types})
        dump(self.tables/'AssetView.json',{'rows':self.assets})
        # Source labels, unknown integers and filename strings are deliberate
        # decoys. Only the curated MiniAssetID image role may create a join.
        dump(self.tables/'Challenge.json',{'rows':[
            {'ID':1,'MiniAssetID':11,'FullAssetID':31,'CutSceneAssetID':0,
             'ArbitraryInteger':12,'Name':'Image/Mission/fixture_absent.png','Filename':'fixture_replaced.png'},
            {'ID':2,'MiniAssetID':12,'FullAssetID':0,'CutSceneAssetID':0,'ArbitraryInteger':11},
            {'ID':3,'MiniAssetID':13,'FullAssetID':0,'CutSceneAssetID':0,'ArbitraryInteger':11},
            {'ID':4,'MiniAssetID':999,'FullAssetID':0,'CutSceneAssetID':0,'ArbitraryInteger':11},
            {'ID':5,'MiniAssetID':11,'FullAssetID':0,'CutSceneAssetID':0,'ArbitraryInteger':11},
        ]})
        dump(self.tables/'UnknownFixtureTable.json',{'rows':[{'ID':1,'AssetID':11,'ImageID':11,'Name':'fixture_exact.png'}]})
        dump(self.tables/'SpriteAnimation.json',{'rows':[{'ID':71,'Delay':17}]})
        dump(self.tables/'SpriteAnimationAsset.json',{'rows':[
            {'ID':201,'SpriteAnimationID':71,'AssetID':21,'Order':2},
            {'ID':202,'SpriteAnimationID':71,'AssetID':22,'Order':1},
        ]})
        self.bindings_path=self.inventory/'source-bindings/all42968_asset_bindings523.jsonl.gz'
        dump_lines(self.bindings_path,self.bindings)
        dump_lines(self.inventory/'audit/current523_retained_images_lineage_diff.jsonl.gz',self.retained)

    def tearDown(self): self.temp.cleanup()

    def run_compiler(self, check=True, optimized=False, script=SCRIPT):
        result=subprocess.run([sys.executable]+(['-O'] if optimized else [])+[str(script),'--tables',str(self.tables),
                               '--inventory',str(self.inventory),'--output',str(self.output)],
                              capture_output=True,text=True)
        if check: self.assertEqual(result.returncode,0,result.stderr)
        return result

    def test_curated_typed_keys_and_deduplicated_metadata_only(self):
        self.run_compiler()
        refs=read_lines(self.output/'image_source_references.jsonl.gz')
        # Emoticon frame references are gone with the cut Emoticon tables.
        self.assertEqual(len(refs),4)
        self.assertEqual({r['table'] for r in refs},{'Challenge'})
        self.assertTrue(all(r['current_pixels_verified_by_this_audit'] is False for r in refs))
        self.assertEqual({r['pixel_evidence'] for r in refs if r['asset_id'] in {12,13}}, {'unresolved_current_member'})
        report=json.loads((self.output/'image_source_join_audit.json').read_text())
        self.assertEqual(report['coverage']['scope14964']['files'],2)
        self.assertEqual(report['coverage']['audited_static_references_in_scope14964'],
                         {'files':1,'stored_encrypted_member_bytes':128,'decoded_file_bytes_metadata':123})
        self.assertEqual(report['missing_AssetView_key_fields'][0]['missing_AssetView_ids'],[999])
        outside_scope=next(r for r in report['all_curated_field_audits']
                           if r['table']=='Challenge' and r['field']=='FullAssetID')
        self.assertEqual(outside_scope['row_status_counts']['outside_audited_image_type_scope'],1)
        self.assertNotIn('non_image_AssetType',outside_scope['row_status_counts'])
        missing=[r for r in read_lines(self.output/'unresolved_image_source_references.jsonl.gz')
                 if r['binding_status']=='missing_AssetView_key']
        self.assertEqual(len(missing),1)
        self.assertEqual((missing[0]['table'],missing[0]['row_index_zero'],missing[0]['field']),
                         ('Challenge',3,'MiniAssetID'))
        self.assertEqual(missing[0]['source_raw']['ID'],4)
        self.assertEqual(refs[0]['AssetView']['row_index_zero'],1)
        self.assertEqual(refs[0]['AssetType']['row_index_zero'],2)
        self.assertEqual(refs[0]['source_table_sha256'],hashlib.sha256((self.tables/'Challenge.json').read_bytes()).hexdigest())

    def test_cut_emoticon_tables_are_not_read(self):
        self.run_compiler()
        chains=json.loads((self.output/'emoticon_ordered_image_chains.json').read_text())
        self.assertEqual(chains,[])

    def test_byte_reproducible_private_outputs(self):
        self.run_compiler()
        before={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in self.output.iterdir()}
        self.run_compiler()
        after={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in self.output.iterdir()}
        self.assertEqual(before,after)

    def test_typed_path_mismatch_is_rejected_without_filename_fallback(self):
        self.bindings[1]['path']='Image/Mission/renamed_fixture_exact.png'
        dump_lines(self.bindings_path,self.bindings)
        result=self.run_compiler(check=False)
        self.assertNotEqual(result.returncode,0)
        self.assertFalse((self.output/'image_source_references.jsonl.gz').exists())

    def test_replaced_status_cannot_become_retained_current_evidence(self):
        stale=dict(self.retained[0],path='Image/Mission/fixture_replaced.png')
        dump_lines(self.inventory/'audit/current523_retained_images_lineage_diff.jsonl.gz',self.retained+[stale])
        result=self.run_compiler(check=False)
        self.assertNotEqual(result.returncode,0)
        self.assertFalse((self.output/'image_source_references.jsonl.gz').exists())

    def test_optimized_python_still_rejects_changed_binding(self):
        self.bindings[1]['path']='Image/Mission/renamed_fixture_exact.png'
        dump_lines(self.bindings_path,self.bindings)
        result=self.run_compiler(check=False,optimized=True)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('Binding typed path differs',result.stderr)
        self.assertFalse((self.output/'image_source_references.jsonl.gz').exists())

    def test_optimized_python_still_rejects_stale_current_evidence(self):
        stale=dict(self.retained[0],path='Image/Mission/fixture_replaced.png')
        dump_lines(self.inventory/'audit/current523_retained_images_lineage_diff.jsonl.gz',self.retained+[stale])
        result=self.run_compiler(check=False,optimized=True)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('Retained inventory conflicts with binding status',result.stderr)
        self.assertFalse((self.output/'image_source_references.jsonl.gz').exists())

    def test_output_inside_inventory_is_rejected_before_writing(self):
        self.output=self.inventory/'generated-fixture-output'
        result=self.run_compiler(check=False)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('outside the inventory handoff',result.stderr)
        self.assertFalse(self.output.exists())

    def test_output_inside_public_project_containing_tool_is_rejected(self):
        public_project=self.root/'public-fixture-project'
        public_project.mkdir()
        (public_project/'project.godot').write_text('; Structural fixture project marker only\n')
        copied_script=public_project/'tools/images/build_source523_image_references.py'
        copied_script.parent.mkdir(parents=True)
        shutil.copyfile(SCRIPT,copied_script)
        self.output=public_project/'source_data'
        result=self.run_compiler(check=False,script=copied_script)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('outside the public project containing this tool',result.stderr)
        self.assertFalse(self.output.exists())


if __name__=='__main__': unittest.main()
