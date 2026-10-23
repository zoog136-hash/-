async () => {
 const prefix="/workspace/legendary_work/docs/remake/pr122-legendary-parallel";
 const preparation=await tools.exec_command({cmd:"python3 - <<'PY'\nfrom pathlib import Path\nimport json,hashlib,datetime\np=Path('/workspace/legendary_work/docs/remake/pr122-legendary-parallel')\nsource_rows=[]\nfor n in range(250,266):\n f=Path(f'/workspace/legendary_delivery_logs/batch{n}-delivery.json')\n assert f.exists() and json.loads(f.read_text()).get('status')=='REMOTE_SAVED',f'NE ATTACK/HIT source batch{n} must be preserved remotely before recovery'\n source_map=Path(f'/workspace/legendary_work/generation-batch{n}-map.json')\n members=json.loads(source_map.read_text());assert len(members)==5,f'Expected canonical five rows in source batch{n}'\n for row in members:\n  assert row['direction']=='NE' and row['role'] in ['attack','hit']\n  if row.get('blocked'):assert row.get('error'),f'Blocked row must retain its exact error: {row}'\n  else:assert row.get('generated') and Path(row['generated']).is_file(),f'Normal source PNG absent: {row}'\n source_rows.extend(members)\ngate={'source_batches_remote_saved':16,'source_attempts':len(source_rows),'successful_source_rows':sum(not r.get('blocked') for r in source_rows),'blocked_source_rows':sum(bool(r.get('blocked')) for r in source_rows),'blocked_source_members':[{'id':r['id'],'direction':r['direction'],'role':r['role'],'request':r['request'],'error':r['error']} for r in source_rows if r.get('blocked')],'success_count_requirement':'No hardcoded success count; preserved normal or individually blocked source rows both pass the delivery gate.'}\nassert len(source_rows)==80,'Expected80 source attempts; success and blocked counts remain distinct'\nrows=[]\nsha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()\nfor i,role in [('113','idle'),('282','idle'),('338','hit')]:\n oldr=p/f'generation-receipts/transform_{i}-NE-{role}-v01.json'\n blocked=json.loads(oldr.read_text());assert blocked.get('blocked') is True\n assert i!='274','Moderation-blocked274 is outside this recovery scope'\n oldq=Path('/workspace/legendary_work')/blocked['request']\n newq=p/f'requests/transform_{i}-NE-{role}-recovery-v02.json';newr=p/f'generation-receipts/transform_{i}-NE-{role}-recovery-v02.json';claim=p/f'generation-claims/transform_{i}-NE-{role}-recovery-v02.json'\n if newr.exists():\n  rows.append({'id':i,'role':role,'receipt':json.loads(newr.read_text())});continue\n assert not claim.exists(),f'Unresolved recovery claim{i}/{role}: no duplicate image call permitted'\n target=Path('/workspace/legendary_repo/assets/actors/eight_direction/legendary_parallel')/f'transform_{i}/draft001'\n assert not list(target.glob(f'NE-{role}-*')),f'Existing normal target artifacts{i}/{role} must not be regenerated'\n if not newq.exists():\n  q=json.loads(oldq.read_text());assert q['key']==f'transform:{i}' and q['direction']=='NE' and q['role']==role\n  assert 'reasoning' not in q['generation_request']\n  if i=='338':assert q.get('draft_guard_reuse'),'Native saved NE IDLE guards0/5 must remain unchanged; only four missing HIT poses may be authored'\n  q['recovery']={'original_request':str(oldq.relative_to(p.parent.parent.parent)),'original_request_sha256':sha(oldq),'original_failed_receipt':str(oldr.relative_to(p.parent.parent.parent)),'original_failed_receipt_sha256':sha(oldr),'original_error':blocked['error'],'cause':'referenced-image exec-server transport closed' if i=='113' else 'unknown no-PNG tool result; other raw fields not captured','recovery_attempt_limit':1,'recovery_attempt_index':1,'normal_clips_regenerated':0,'authorized_scope':'First successful missing NE clip only; preserve old blocked request/receipt and existing original guard pixels','connection_recovery_evidence':'Same original catalog reference later produced a normal NE RUN PNG','recovery_batch':266,'expected_newly_authored_poses':4 if i=='338' else 6,'expected_reused_prior_draft_poses':2 if i=='338' else 0,'preceding_ne_attack_hit_delivery':gate,'created_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}\n  with newq.open('x') as f:f.write(json.dumps(q,ensure_ascii=False,indent=2)+'\\n')\n q=json.loads(newq.read_text());assert q['recovery']['recovery_attempt_limit']==1\n rows.append({'id':i,'role':role,'request':'docs/remake/pr122-legendary-parallel/requests/'+newq.name,'request_sha256':sha(newq),'generation_request':q['generation_request'],'recovery':q['recovery'],'receipt_path':str(newr),'claim_path':str(claim)})\nprint(json.dumps(rows,ensure_ascii=False))\nPY",max_output_tokens:16000});
 if(preparation.exit_code!==0)throw Error(preparation.output);
 const jobs=JSON.parse(preparation.output);
 const sanitize=(value,key="",seen=new WeakSet())=>{
  if(value===undefined)return {undefined:true};
  if(value===null||typeof value==="number"||typeof value==="boolean")return value;
  if(typeof value==="string"){
   if(/^data:[^;]*;base64,/i.test(value)||(/^(data|base64|b64_json|image_base64|audio_base64)$/i.test(key)&&value.length>128)||value.length>512&&/^[A-Za-z0-9+/=\r\n]+$/.test(value))return {omitted:"Base64/binary payload",characters:value.length};
   return value;
  }
  if(typeof value!=="object")return String(value);
  if(seen.has(value))return {circular_reference:true};seen.add(value);
  if(Array.isArray(value))return value.map(item=>sanitize(item,"",seen));
  const out={};for(const k of Object.getOwnPropertyNames(value))out[k]=sanitize(value[k],k,seen);
  return out;
 };
 const write=async(path,value)=>{
  const probe=await tools.exec_command({cmd:"test -e "+path,max_output_tokens:30});
  if(probe.exit_code===0)throw Error("Refusing to overwrite recovery evidence: "+path);
  await tools.apply_patch("*** Begin Patch\n*** Add File: "+path+"\n"+JSON.stringify(value,null,2).split("\n").map(s=>"+"+s).join("\n")+"\n*** End Patch");
 };
 const settled=await Promise.allSettled(jobs.map(async j=>{
  if(j.receipt){notify({id:j.id,recovery:"resumed existing receipt; image calls0"});return j.receipt;}
  await write(j.claim_path,{id:j.id,direction:"NE",role:j.role,request:j.request,request_sha256:j.request_sha256,status:"IMAGE_TOOL_RECOVERY_CALLED_ONCE_NO_RETRY",recovery_attempt_limit:1,recovery_attempt_index:1,original_error:j.recovery.original_error});
  let result,thrown;
  try{result=await tools.image_gen__imagegen(j.generation_request);}catch(e){thrown=e;}
  const generated=result?.output_hint?.match(new RegExp("as (/workspace/generated_images/\\S+\\.png)"))?.[1];
  const error=thrown?String(thrown):(result?.error||result?.output_hint||"Image tool returned no PNG");
  const resultPath=prefix+"/generation-tool-results/transform_"+j.id+"-NE-"+j.role+"-recovery-v02-result.json";
  await write(resultPath,{id:j.id,direction:"NE",role:j.role,request:j.request,request_sha256:j.request_sha256,recovery_attempt_limit:1,recovery_attempt_index:1,generated:generated||null,blocked:!generated,tool_return_type:typeof result,tool_result_without_base64:sanitize(result),thrown_error_without_base64:thrown?sanitize(thrown):null,original_failure:j.recovery,normal_clips_regenerated:0,final_approval:false});
  const row={id:j.id,role:j.role,direction:"NE",request:j.request,...(generated?{generated}:{blocked:true,error})};
  await write(j.receipt_path,row);notify({id:j.id,direction:"NE",role:j.role,batch:266,status:generated?"RECOVERY_PNG_READY":"RECOVERY_BLOCKED",recovery_attempt:1});return row;
 }));
 const failures=settled.filter(r=>r.status==="rejected");
 if(failures.length)throw Error("Recovery metadata failure after both image workers settled: "+failures.map(r=>String(r.reason)).join(" | "));
 const outputs=settled.map(r=>r.value);
 const map="/workspace/legendary_work/generation-batch266-map.json";
 const probe=await tools.exec_command({cmd:"test -e "+map,max_output_tokens:30});
 if(probe.exit_code!==0)await write(map,outputs);
 text({batch:266,map_ready:true,rows:outputs.map(r=>({id:r.id,blocked:!!r.blocked})),normal_clips_regenerated:0,final_approval:false});
}
