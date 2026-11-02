"""Shared content-addressed derived TI2/RGBA cache; never executes serialized code."""
import base64,hashlib,json,sqlite3,zlib
from collections import OrderedDict
from pathlib import Path
from PIL import Image
from base508_ti2 import read_ti2,render

class TileCache:
 def __init__(self,path):
  path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
  self.db=sqlite3.connect(path);self.revision=hashlib.sha256(Path(__file__).with_name('base508_ti2.py').read_bytes()).hexdigest();self.memory=OrderedDict();self.hits=0;self.decodes=0
  self.db.execute('CREATE TABLE IF NOT EXISTS derived (revision TEXT, source TEXT, kind TEXT, payload BLOB, sha TEXT, PRIMARY KEY(revision,source,kind))')
 def _get(self,source,kind):
  row=self.db.execute('SELECT payload,sha FROM derived WHERE revision=? AND source=? AND kind=?',(self.revision,source,kind)).fetchone()
  if not row:return None
  payload,sha=row
  if hashlib.sha256(payload).hexdigest()!=sha:raise ValueError('Corrupt derived tile cache; original inputs unchanged')
  self.hits+=1;return zlib.decompress(payload)
 def _put(self,source,kind,data):
  payload=zlib.compress(data);self.db.execute('INSERT OR REPLACE INTO derived VALUES (?,?,?,?,?)',(self.revision,source,kind,payload,hashlib.sha256(payload).hexdigest()))
 def read(self,payload):
  key=hashlib.sha256(payload).hexdigest()
  if key in self.memory:self.memory.move_to_end(key);return key,self.memory[key]
  cached=self._get(key,'parsed')
  if cached is None:
   tile=read_ti2(payload);serial=dict(tile,blocks=[dict(b,pixels=base64.b64encode(b['pixels']).decode('ascii')) for b in tile['blocks']]);self._put(key,'parsed',json.dumps(serial,separators=(',',':')).encode());self.decodes+=1
  else:
   tile=json.loads(cached)
   for block in tile['blocks']:block['pixels']=base64.b64decode(block['pixels'],validate=True)
  self.memory[key]=tile
  while len(self.memory)>32:self.memory.popitem(last=False)
  return key,tile
 def frame(self,key,tile,index):
  if not 0<=index<len(tile['blocks']):raise ValueError('Original TI2 subimage absent')
  data=self._get(key,'rgba:'+str(index))
  if data is not None:
   if len(data)!=2304:raise ValueError('Invalid cached frame extent')
   return Image.frombytes('RGBA',(24,24),data)
  image=render(tile['blocks'][index],tile['palette'],display_alpha=True);self._put(key,'rgba:'+str(index),image.tobytes());return image
 def close(self):self.db.commit();self.db.close()
