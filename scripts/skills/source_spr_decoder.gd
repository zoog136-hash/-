extends RefCounted
## Native, on-demand port of the pinned read-only RGB555 SPR decoder.
## Unknown header/t/attr/blend semantics remain opaque; no guessed color key.
const MAX_INPUT := 64 * 1024 * 1024
const MAX_PIXELS := 16 * 1024 * 1024
class Reader extends RefCounted:
 var bytes:PackedByteArray
 var pos:int=0
 var end:int=0
 var bad:bool=false
 func _init(value:PackedByteArray,start:int=0,limit:int=-1):
  bytes=value;pos=start;end=value.size() if limit<0 else limit
 func number(count:int,signed:bool=false)->int:
  if pos<0 or count>end-pos:bad=true;return 0
  var value:int=0
  for i:int in range(count):value|=int(bytes[pos+i])<<(i*8)
  pos+=count
  if signed and value&(1<<(count*8-1)):value-=1<<(count*8)
  return value

static func decode(data:PackedByteArray,index:int)->Dictionary:
 if data.is_empty() or data.size()>MAX_INPUT or index<0:return {}
 var start:int=0
 if data.size()>=4 and data.slice(0,4).get_string_from_ascii()=="SPR_":
  if data.size()<5 or data[4]!=48:return {}
  start=5
 var r:=Reader.new(data,start)
 var count:int=r.number(1)
 var palette:Array[int]=[]
 if count==255:
  var colors:int=r.number(1)
  if colors==0:colors=256
  for i:int in range(colors):palette.append(r.number(2))
  count=r.number(1)
 if index>=count:return {}
 var references:Array=[]
 for frame:int in range(count):
  for i:int in range(6):r.number(2)
  var n:int=r.number(2)
  if r.bad or n>(r.end-r.pos)/5:return {}
  for i:int in range(n):
   var x:int=r.number(1,true);var y:int=r.number(1,true)
   var opaque:int=r.number(1);var block:int=r.number(2)
   if frame==index:
    var half:int=floori(float(x)/2.0)
    references.append({"x":24*(y+x-half),"y":12*(y-half),"block":block,"opaque":opaque})
 var blocks:int=r.number(4)
 if r.bad or blocks>1000000 or blocks>(r.end-r.pos-4)/4:return {}
 var offsets:Array[int]=[]
 for i:int in range(blocks):offsets.append(r.number(4))
 r.number(4)
 if r.bad:return {}
 var block_start:int=r.pos
 var sorted:Array[int]=offsets.duplicate();sorted.sort()
 var ends:Dictionary={}
 for i:int in range(sorted.size()):
  if i+1==sorted.size() or sorted[i+1]!=sorted[i]:ends[sorted[i]]=sorted[i+1] if i+1<sorted.size() else data.size()-block_start
 var bounds:=Rect2i(0,0,1,1)
 var first:bool=true
 for ref:Dictionary in references:
  if int(ref.block)>=blocks:return {}
  var tile:=Rect2i(int(ref.x),int(ref.y),24,24)
  bounds=tile if first else bounds.merge(tile);first=false
 if bounds.size.x<=0 or bounds.size.y<=0 or bounds.size.x*bounds.size.y>MAX_PIXELS:return {}
 var image:=Image.create_empty(bounds.size.x,bounds.size.y,false,Image.FORMAT_RGBA8)
 var decoded:Dictionary={}
 for ref:Dictionary in references:
  var offset:int=offsets[int(ref.block)]
  if not decoded.has(offset):
   if decoded.size()>=58254:return {} # 128 MiB maximum decoded 24x24 tile storage.
   var limit:int=block_start+int(ends[offset])
   if block_start+offset<block_start or limit>data.size() or limit<block_start+offset:return {}
   var tile_reader:=Reader.new(data,block_start+offset,limit)
   var x0:int=tile_reader.number(1);var y0:int=tile_reader.number(1)
   tile_reader.number(1)
   var lines:int=tile_reader.number(1)
   if tile_reader.bad or x0>24 or y0+lines>24:return {}
   var rgba:=PackedByteArray();rgba.resize(24*24*4)
   for row:int in range(lines):
    var x:int=x0
    var runs:int=tile_reader.number(1)
    for run:int in range(runs):
     x+=tile_reader.number(1)/2
     var pixels:int=tile_reader.number(1)
     if x+pixels>24:return {}
     for pixel:int in range(pixels):
      var color:int=tile_reader.number(2 if palette.is_empty() else 1)
      if not palette.is_empty():
       if color>=palette.size():return {}
       color=palette[color]
      var at:int=((y0+row)*24+x)*4
      rgba[at]=((color>>10)&31)*255/31
      rgba[at+1]=((color>>5)&31)*255/31
      rgba[at+2]=(color&31)*255/31
      rgba[at+3]=255;x+=1
   if tile_reader.bad:return {}
   decoded[offset]=Image.create_from_data(24,24,false,Image.FORMAT_RGBA8,rgba)
  image.blend_rect(decoded[offset],Rect2i(0,0,24,24),Vector2i(int(ref.x),int(ref.y))-bounds.position)
 return {"image":image,"bounds":bounds,"frame_count":count,"anchor_is_foot":false,"coordinate_policy":"original-grid; opaque t/header fields not interpreted"}
