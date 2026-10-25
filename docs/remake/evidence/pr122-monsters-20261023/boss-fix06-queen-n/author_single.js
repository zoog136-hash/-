async function authorQueenNSingles(names) {
 const root='/workspace/twilight';
 const base=root+'/docs/remake/evidence/pr122-monsters-20261023/boss-fix06-queen-n';
 const q=s=>"'"+s.replace(/'/g,"'\\''")+"'";
 return await Promise.allSettled(names.map(async name=>{
  const read=await tools.exec_command({cmd:'cat '+q(base+'/requests/'+name+'.json'),workdir:root,max_output_tokens:5000});
  const input=JSON.parse(read.output);
  const result=await tools.image_gen__imagegen(input.request);
  const files=new Set();
  const visit=(v,k='')=>{
   if(['image_url','data','base64','b64_json'].includes(k))return;
   if(typeof v==='string'&&v.length<10000){for(const m of v.matchAll(/\/workspace\/generated_images\/exec-[0-9a-f-]+\.png/g))files.add(m[0]);}
   else if(v&&typeof v==='object')for(const[a,b]of Object.entries(v))visit(b,a);
  };visit(result);
  if(files.size!==1){store('queen-N-'+name+'-raw-tool-result',result);throw Error('Unexpected local PNG count '+files.size);}
  const generated=[...files][0],dest=base+'/raw/'+name+'.png';
  const run=await tools.exec_command({cmd:'python3 - '+q(generated)+' '+q(dest)+" <<'PY'\nimport json,sys,hashlib\nfrom pathlib import Path\nfrom PIL import Image\nsys.path.insert(0,'tools');import import_original_based_motion as c\ns,d=map(Path,sys.argv[1:]);assert not d.exists();d.write_bytes(s.read_bytes())\nmeta={'path':str(d),'sha256':hashlib.sha256(d.read_bytes()).hexdigest(),'bytes':d.stat().st_size,'image_size':list(Image.open(d).size)}\ncheck={**meta,'direction':'N','role':'run','rows':1}\ntry:\n g=c.analyze(d,1,[0],directions_axis='columns',canvas_size=2048,directions=['N']);c.require_complete_pose_regions(d,g);check.update(status='GEOMETRY_PASS_ONLY',geometry=g)\nexcept ValueError as ex:check.update(status='SOURCE_HOLD',reason=str(ex))\np=d.parent.parent/'checks'/(d.stem+'.json');assert not p.exists();p.write_text(json.dumps(check,ensure_ascii=False,indent=2)+'\\n')\nprint(json.dumps({**meta,'geometry':check['status'],'reason':check.get('reason')}))\nPY",workdir:root,max_output_tokens:500});
  const meta=JSON.parse(run.output);
  const receipt={request:base+'/requests/'+name+'.json',generated_path:generated,preserved:meta,new_approvals:0};
  await tools.apply_patch('*** Begin Patch\n*** Add File: '+base+'/requests/'+name+'-result.json\n+'+JSON.stringify(receipt,null,2).split('\n').join('\n+')+'\n*** End Patch');
  return {name,...meta};
 }));
}
