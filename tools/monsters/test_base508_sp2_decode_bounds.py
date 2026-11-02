"""Malformed byte streams exercise decode limits; no image fixtures are produced."""
import unittest
import brotli
from base508_sp2_packet import source_body
class SourceDecodeBoundsTests(unittest.TestCase):
 def test_fe_bytes_are_returned_unchanged(self):
  raw=b'\xfe'+bytes(range(64));self.assertIs(source_body(raw,max_decoded_bytes=len(raw)),raw)
 def test_brotli_bytes_are_returned_unchanged(self):
  raw=b'\xfe'+bytes(range(256))*10000
  self.assertEqual(source_body(brotli.compress(raw)),raw)
 def test_brotli_output_exceeding_bound_is_rejected(self):
  with self.assertRaisesRegex(ValueError,'decoded bound'):source_body(brotli.compress(b'\xfe'+b'X'*4096),max_decoded_bytes=64)
 def test_fe_exceeding_bound_is_rejected(self):
  with self.assertRaisesRegex(ValueError,'decoded bound'):source_body(b'\xfe'+b'X'*65,max_decoded_bytes=64)
 def test_truncated_compressed_stream_is_rejected(self):
  raw=brotli.compress(b'\xfe'+bytes(range(256))*10)
  with self.assertRaises(ValueError):source_body(raw[:-1])
 def test_trailing_input_is_rejected(self):
  with self.assertRaises(ValueError):source_body(brotli.compress(b'\xfehello')+b'garbage')
 def test_empty_and_non_fe_output_are_rejected(self):
  for raw in [b'',brotli.compress(b'not SP2')]:
   with self.assertRaises(ValueError):source_body(raw)
if __name__=='__main__':unittest.main()
