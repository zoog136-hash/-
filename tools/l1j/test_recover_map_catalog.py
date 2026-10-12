"""Strict source-grid conversion and nested-map inventory behavior."""
import io
import struct
import unittest
import zipfile

from convert_maps import read_cache
from recover_map_catalog import kind_of, read_text, zip_entries


class RecoveryTests(unittest.TestCase):
    def test_cache_column_major_becomes_row_major(self):
        header=struct.pack('>5i',42,32704,32640,2,3)
        meta, grid=read_cache(header+bytes([11,12,13,21,22,23]),42)
        self.assertEqual(meta['source_origin'],[32704,32640])
        self.assertEqual(grid.tolist(),[[11,21],[12,22],[13,23]])

    def test_cache_rejects_wrong_id_and_trailing_payload(self):
        header=struct.pack('>5i',42,0,0,2,2)
        for expected, blob in [(43,header+bytes(4)),(42,header+bytes(5)),(42,header+bytes(3))]:
            with self.assertRaises(ValueError): read_cache(blob,expected)

    def test_text_is_already_row_major_and_has_no_invented_origin(self):
        meta, grid=read_text(b'11,21,\r\n12,22,\r\n13,23,\r\n')
        self.assertEqual(meta,{'dimensions':[2,3],'source_origin':None})
        self.assertEqual(grid.tolist(),[[11,21],[12,22],[13,23]])

    def test_malformed_text_is_never_clamped_or_partially_accepted(self):
        for blob in [b'1,2\n3\n',b'1,256\n',b'1,-1\n',b'1,,2\n',b'1.5,2\n',b'\n',b'hello']:
            with self.subTest(blob=blob), self.assertRaises(ValueError): read_text(blob)

    def test_flat_members_in_map_archive_keep_their_context(self):
        output=io.BytesIO()
        with zipfile.ZipFile(output,'w') as archive:
            archive.writestr('42.txt','1,2\n3,4\n')
            archive.writestr('program.exe','must not execute')
        with zipfile.ZipFile(io.BytesIO(output.getvalue())) as archive:
            entries=list(zip_entries(archive,'sources!maps/352_maps.zip'))
        self.assertEqual(entries[0][2],b'1,2\n3,4\n')
        self.assertIsNone(entries[1][2])
        self.assertEqual(kind_of('42.txt','sources!maps/352_maps.zip'),'TEXT')
        self.assertEqual(kind_of('42.txt','unrelated.zip'),'')


if __name__=='__main__': unittest.main()
