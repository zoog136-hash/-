"""Validate available original TI2 once and prime the common derived cache."""
import argparse,json,sys,zlib
from pathlib import Path
from base508_tile_cache import TileCache

def warm(requirements,cache_path,out):
 members=requirements['all_member_locations'];specs=[s for s in members.values() if s['member'].endswith('.ti2') and s['local']['state']=='LOCAL_CRC_VERIFIED'];cache=TileCache(cache_path);failures=[];passed=0
 try:
  for i,spec in enumerate(specs,1):
   path=Path(spec['local']['valid_paths'][0]);data=path.read_bytes()
   try:
    if len(data)!=spec['bytes'] or f'{zlib.crc32(data):08x}'!=spec['crc32']:raise ValueError('Original TI2 changed after input verification')
    _,tile=cache.read(data);passed+=1
   except (ValueError,RuntimeError) as error:failures.append({'member':spec['member'],'reason':str(error)})
   if i%100==0:print(json.dumps({'ti2_processed':i,'total':len(specs),'strict_codec_pass':passed,'failures':len(failures)}),file=sys.stderr,flush=True)
  result={'original_ti2_available':len(specs),'strict_ti2_codec_pass':passed,'new_cached_source_decodes':cache.decodes,'derived_cache_hits':cache.hits,'memoized_source_codec_failures':cache.memoized_failures,'failed_original_members':failures,'actual_original_maps_rendered_added':0,'raw_source_modified':False}
  out.write_text(json.dumps(result,indent=2)+'\n');return result
 finally:cache.close()
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 for key in ['requirements','cache','out']:p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();print(json.dumps(warm(json.loads(a.requirements.read_text()),a.cache,a.out)))
