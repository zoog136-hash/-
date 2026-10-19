// Evaluate this async function inside functions.exec; it is not a Node CLI.
// Production image payloads stay private; local receipts permit safe resumption.
async function authorOne(options = {}) {
 const root='/workspace/twilight', engine='/workspace/scratch/godot472/Godot_v4.7.2-stable_linux.x86_64';
 const q=s=>"'"+s.replace(/'/g,"'\\''")+"'";
 const run=async a=>{let r=await tools.exec_command(a),out=r.output;while(r.session_id){r=await tools.write_stdin({session_id:r.session_id,chars:'',yield_time_ms:1000,max_output_tokens:600});out+=r.output;}if(r.exit_code!==0)throw Error(out.slice(-1000));return out;};
 let finished=false,timer,info;
 try {
  const command=options.requestPath
   ? "python3 - "+q(options.requestPath)+" <<'PY'\nimport json,re,sys\nfrom pathlib import Path\np=Path(sys.argv[1]);r=json.loads(p.read_text());a=json.load(open('data/pr122_native_locomotion_staging.json'))['actors'].get(r['key'],{});n=int(re.search(r'/r(\\d+)/',a.get('frames','/r000/')).group(1))+1;print(json.dumps(dict(path=str(p),request=r,revision=f'r{n:03d}'),ensure_ascii=False))\nPY"
   : "python3 - <<'PY'\nimport json,re,sys,subprocess\nfrom pathlib import Path\nsys.path.insert(0,'tools')\nregister=json.load(open('data/pr122_native_locomotion_staging.json'));target=register.get('next_locomotion_source')\nif target:\n out=subprocess.check_output([sys.executable,'tools/prepare_pr122_native_movement.py','--key',target['key'],'--direction',target['direction'],'--role',target['role'],'--version','v01'],text=True);prepared=json.loads(out);p,r=prepared['path'],prepared['request']\nelse:\n from prepare_pr122_native_action import prepare\n p,r=prepare(Path.cwd())\na=register['actors'].get(r['key'],{});n=int(re.search(r'/r(\\d+)/',a.get('frames','/r000/')).group(1))+1;print(json.dumps(dict(path=p,request=r,revision=f'r{n:03d}'),ensure_ascii=False))\nPY";
  info=JSON.parse(await run({cmd:command,workdir:root,max_output_tokens:3500}));
  const req=info.request; if(req.status!=='REQUESTED_NOT_APPROVED')throw Error('Do not repeat processed authoring');
  text({authoring:[req.key,req.direction,req.role],request:info.path});
  for(const path of req.references){const view=await tools.view_image({path});if(!view.image_url)throw Error('Reference unavailable');}
  const pulse=async()=>{if(finished)return;text(req.name+' '+req.direction+' '+req.role+' 제작 중 — 이미지 미첨부');await yield_control();if(!finished)timer=setTimeout(pulse,30000);};timer=setTimeout(pulse,30000);
  const result=await tools.image_gen__imagegen({prompt:req.prompt,referenced_image_paths:req.references,transparent_background:true});
  const files=new Set();
  const visit=(v,k='')=>{if(['image_url','data','base64','b64_json'].includes(k))return;if(typeof v==='string'&&v.length<5000){for(const m of v.matchAll(/\/workspace\/generated_images\/exec-[0-9a-f-]+\.png/g))files.add(m[0]);}else if(v&&typeof v==='object')for(const [a,b]of Object.entries(v))visit(b,a);};visit(result);
  if(files.size!==1)throw Error('Unexpected output paths; preserve request without assigning');
  const generated=[...files][0],receipt='/workspace/scratch/twilight-receipts/'+info.path.split('/').pop();
  await tools.apply_patch('*** Begin Patch\n*** Add File: '+receipt+'\n+'+JSON.stringify({request:info.path,generated,revision:info.revision})+'\n*** End Patch');
  const connect=async(next,png)=>{
   const log='/tmp/twilight-native-'+req.key.replace(':','-')+'-'+next.revision;
   text(await run({cmd:'python3 tools/advance_pr122_native_locomotion.py --request '+q(next.path)+' --generated '+q(png)+' --revision '+q(next.revision)+' --godot '+q(engine)+' > '+q(log+'-unit.log')+' 2>&1; result=$?; tail -c 1050 '+q(log+'-unit.log')+'; exit "$result"',workdir:root,max_output_tokens:500,yield_time_ms:1000}));
   text(await run({cmd:'python3 tools/checkpoint_pr122_native_clip.py --request '+q(next.path)+' > '+q(log+'-save.log')+' 2>&1; result=$?; tail -c 1000 '+q(log+'-save.log')+'; exit "$result"',workdir:root,max_output_tokens:500,yield_time_ms:1000,sandbox_permissions:'with_additional_permissions',additional_permissions:{network:{enabled:true}}}));
  };
  await connect(info,generated);
  const state=await run({cmd:'python3 -c '+q('import json,sys;print(json.load(open(sys.argv[1]))["status"])')+' '+q(info.path),workdir:root,max_output_tokens:100});
  if(state.includes('GENERATED_HOLD')){
   const recovery=JSON.parse(await run({cmd:'python3 tools/recover_pr122_disjoint_action.py --request '+q(info.path)+' > /tmp/twilight-latest-recovery.json 2> /tmp/twilight-latest-recovery.log; result=$?; if [ "$result" = 0 ]; then cat /tmp/twilight-latest-recovery.json; else tail -c 900 /tmp/twilight-latest-recovery.log; fi; exit "$result"',workdir:root,max_output_tokens:500,yield_time_ms:1000}));
   await connect(recovery,recovery.generated);
  }
  return {status:'SAVED',request:info.path};
 } catch(e){text({status:'PRESERVE_FILES_REVIEW_STEP',request:info?.path,error:String(e).slice(-1000)});return {status:'STOP'};}
 finally {finished=true;if(timer)clearTimeout(timer);}
}
