"""Generate codec cross-checks from supplied real SP2 inputs, without visual review."""
import argparse,sys,pathlib,json,hashlib
sys.path[:0]=[str(pathlib.Path(__file__).resolve().parents[1]/'lineagem_original')]
import base508_sp2_packet as codec,original_sp2
parser=argparse.ArgumentParser();parser.add_argument('--inputs',type=pathlib.Path,required=True);parser.add_argument('--output',type=pathlib.Path,required=True);args=parser.parse_args()
root=args.output.resolve();root.mkdir(parents=True,exist_ok=True)
samples=[]
for name in ['1110-0.sp2','1111-0.sp2','145-16.sp2','128-16.sp2','31-0.sp2','31-8.sp2','18465-0.sp2','18465-56.sp2','18466-0.sp2','18467-0.sp2','18468-0.sp2']:
 raw=(args.inputs/'Sprite'/name).read_bytes();encoded,parsed=codec.normalize(raw);target=root/(name+'.bin');target.write_bytes(encoded)
 bits=[i for i in range(8) if parsed[1]&(1<<i)]
 for bit in [bits[0],bits[-1]]:
  fs,blocks=parsed[2][bits.index(bit)]
  for frame in sorted({0,len(fs)-1}):
   image,offset=original_sp2.render(parsed[0],fs,blocks,frame);geometry=codec.geometry(parsed,bit,frame);assert list(offset)==geometry['offset'] and list(image.size)==geometry['pixel_size']
   samples.append({'path':str(target),'sha256':hashlib.sha256(encoded).hexdigest(),'bit':bit,'frame':frame,'width':image.width,'height':image.height,'offset':list(offset),'rgba_sha256':hashlib.sha256(image.tobytes()).hexdigest()})
(root/'samples.json').write_text(json.dumps(samples));print('CODEC_SAMPLES',len(samples))
