// Run only inside functions.exec. Never return image payloads or mutate a catalog.
async function authorQueenPair(directions, version) {
 const root='/workspace/twilight';
 const base=root+'/docs/remake/evidence/pr122-monsters-20261023/boss-fix01-queen';
 const q=s=>"'"+s.replace(/'/g,"'\\''")+"'";
 return await Promise.allSettled(directions.map(async direction=>{
  const name='queen-'+direction+'-run6-'+version;
  const requestPath=base+'/requests/'+name+'.json';
  const read=await tools.exec_command({cmd:'cat '+q(requestPath),workdir:root,max_output_tokens:8000});
  const info=JSON.parse(read.output);
  const result=await tools.image_gen__imagegen(info.request);
  const paths=new Set();
  const visit=(v,k='')=>{
   if(['image_url','data','base64','b64_json'].includes(k))return;
   if(typeof v==='string'&&v.length<10000){for(const m of v.matchAll(/\/workspace\/generated_images\/exec-[0-9a-f-]+\.png/g))paths.add(m[0]);}
   else if(v&&typeof v==='object'){for(const [a,b]of Object.entries(v))visit(b,a);}
  };visit(result);
  if(paths.size!==1){store('queen-repair-'+name+'-result',result);throw Error('Unexpected local image path count '+paths.size);}
  const generated=[...paths][0],dest=base+'/raw/'+name+'.png';
  const preserve=await tools.exec_command({cmd:'python3 - '+q(generated)+' '+q(dest)+' '+q(direction)+' '+q(name)+" <<'PY'\nimport sys,hashlib,json\nfrom pathlib import Path\nroot=Path.cwd();sys.path.insert(0,'tools');import import_original_based_motion as c\ns,d=map(Path,sys.argv[1:3]);direction,name=sys.argv[3:5];assert not d.exists();d.write_bytes(s.read_bytes())\nmeta={'path':str(d),'sha256':hashlib.sha256(d.read_bytes()).hexdigest(),'bytes':d.stat().st_size}\ncheck={'direction':direction,'source':str(d.relative_to(root)),**meta}\ntry:\n g=c.analyze(d,6,[0,1],directions_axis='phase_grid2',canvas_size=2048,directions=[direction]);c.require_complete_pose_regions(d,g);check.update(status='GEOMETRY_PASS_ONLY',geometry=g)\nexcept ValueError as ex:check.update(status='SOURCE_HOLD',reason=str(ex))\np=d.parent.parent/'checks'/(name+'.json');assert not p.exists();p.write_text(json.dumps(check,ensure_ascii=False,indent=2)+'\\n')\nprint(json.dumps({**meta,'geometry':check['status'],'reason':check.get('reason')}))\nPY",workdir:root,max_output_tokens:500});
  const meta=JSON.parse(preserve.output);
  const receipt={direction,request:requestPath,generated_path:generated,preserved:meta,visual_approval:'HOLD'};
  await tools.apply_patch('*** Begin Patch\n*** Add File: '+base+'/requests/'+name+'-result.json\n+'+JSON.stringify(receipt,null,2).split('\n').join('\n+')+'\n*** End Patch');
  return {direction,...meta};
 }));
}
