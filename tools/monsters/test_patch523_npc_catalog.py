"""Compiler checks use tiny synthetic rows, never source content in Git."""
import hashlib, importlib.util, json, tempfile, unittest, zipfile
from pathlib import Path
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('compiler',Path(__file__).with_name('build_patch523_npc_catalog.py'))
compiler=importlib.util.module_from_spec(spec);spec.loader.exec_module(compiler)

class CompilerTests(unittest.TestCase):
    def make(self, root, *, bad_row=False,bad_hash=False):
        rows={'NpcClass':[{'ID':7,'Sprite':22}], 'StatusEffectAttr':[{'StatusEffectID':31,'AttrType':8,'Value':99}]}
        source=root/'source.zip'; evidence={'source_rows':{},'source_table_provenance':{}}
        with zipfile.ZipFile(source,'w') as z:
            for name, content in rows.items():
                raw=('\ufeff'+json.dumps({'rows':content})).encode()
                z.writestr('content/'+name+'.json',raw)
                evidence['source_rows'][name]=[{'source_row_1based':1,'row':content[0].copy()}]
                evidence['source_table_provenance'][name]={'path':'content/'+name+'.json','actual':{'sha256':compiler.sha(raw),'bytes':len(raw),'row_count':1,'crc32':format(compiler.zlib.crc32(raw)&0xffffffff,'08x')}}
        if bad_row: evidence['source_rows']['NpcClass'][0]['row']['Sprite']=23
        if bad_hash: evidence['source_table_provenance']['NpcClass']['actual']['sha256']='0'*64
        report=root/'report.zip'
        with zipfile.ZipFile(report,'w') as z: z.writestr(compiler.BOSS_REPORT,json.dumps(evidence))
        return source,report

    def test_retains_composite_rows_and_source_positions(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);source,report=self.make(root)
            with patch.object(compiler,'SOURCE_SHA',compiler.sha(source.read_bytes())):
                result=compiler.compile_catalog(source,report,None)
                self.assertEqual(result['tables']['StatusEffectAttr']['@1']['row']['StatusEffectID'],31)
                self.assertEqual(result['boss_npc_ids'],[7])
                self.assertEqual(result['tables']['NpcClass']['7']['source_row_1based'],1)
                a=compiler.write_pack(result,root/'a');b=compiler.write_pack(result,root/'b')
                self.assertEqual(a,b)
                self.assertEqual(a['catalog_sha256'],compiler.sha((root/'a/npc_spells.json').read_bytes()))

    def test_rejects_changed_source_archive(self):
        with tempfile.TemporaryDirectory() as d:
            source,report=self.make(Path(d))
            with self.assertRaisesRegex(ValueError,'ZIP SHA'): compiler.compile_catalog(source,report,None)

    def test_rejects_report_row_that_differs_from_original(self):
        with tempfile.TemporaryDirectory() as d:
            source,report=self.make(Path(d),bad_row=True)
            with patch.object(compiler,'SOURCE_SHA',compiler.sha(source.read_bytes())):
                with self.assertRaisesRegex(ValueError,'differs from source'): compiler.compile_catalog(source,report,None)

    def test_rejects_stale_table_provenance(self):
        with tempfile.TemporaryDirectory() as d:
            source,report=self.make(Path(d),bad_hash=True)
            with patch.object(compiler,'SOURCE_SHA',compiler.sha(source.read_bytes())):
                with self.assertRaisesRegex(ValueError,'provenance mismatch'): compiler.compile_catalog(source,report,None)

if __name__=='__main__': unittest.main()
