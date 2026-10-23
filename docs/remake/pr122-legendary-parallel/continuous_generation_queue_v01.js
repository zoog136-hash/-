async ({jobs,concurrency=20})=>{
 const prefix="/workspace/legendary_work/docs/remake/pr122-legendary-parallel";
 const batches=[...new Set(jobs.map(j=>j.batch))];
 const raw=await tools.exec_command({cmd:"python3 - <<'PY'\nimport json,pathlib\njobs="+JSON.stringify(jobs)+"\np=pathlib.Path('/workspace/legendary_work')\nout=[]\nfor j in jobs:\n receipt=p/'docs/remake/pr122-legendary-parallel/generation-receipts'/f\"transform_{j['id']}-{j['direction']}-{j['role']}-v01.json\"\n claim=p/'docs/remake/pr122-legendary-parallel/generation-claims'/f\"transform_{j['id']}-{j['direction']}-{j['role']}-v01.json\"\n j['receipt']=json.loads(receipt.read_text()) if receipt.exists() else None\n j['claim_exists']=claim.exists()\n j['config']=json.loads((p/j['request']).read_text())\n out.append(j)\nprint(json.dumps(out,ensure_ascii=False))\nPY",max_output_tokens:65000});
 if(raw.exit_code!==0)throw Error(raw.output);
 const parsed=JSON.parse(raw.output), rows=new Map(), saved=new Set();
 let next=0,active=0,ready=parsed.filter(j=>j.receipt).length,blocked=0;
 const writeMaps=async()=>{
  for(const batch of batches){
   if(saved.has(batch))continue;
   const members=jobs.filter(j=>j.batch===batch);
   if(!members.every(j=>rows.has(j.id)))continue;
   const result=members.map(j=>rows.get(j.id));
   const path="/workspace/legendary_work/generation-batch"+batch+"-map.json";
   const ex=await tools.exec_command({cmd:"test -f "+path,max_output_tokens:50});
   if(ex.exit_code!==0)await tools.apply_patch("*** Begin Patch\n*** Add File: "+path+"\n"+JSON.stringify(result,null,2).split("\n").map(s=>"+"+s).join("\n")+"\n*** End Patch");
   saved.add(batch);notify({batch,map_ready:true});
  }
 };
 for(const j of parsed)if(j.receipt)rows.set(j.id,j.receipt);
 await writeMaps();
 const pending=parsed.filter(j=>!j.receipt);
 const uncertain=pending.filter(j=>j.claim_exists);
 if(uncertain.length)throw Error("Unresolved generation claims: "+uncertain.map(j=>j.id).join(",")+"; no duplicate image calls made");
 const save=eval(load("saveGeneratedReceiptCode"));
 let mapLock=Promise.resolve();
 const worker=async()=>{
  while(next<pending.length){
   const j=pending[next++];active++;
   const claim=prefix+"/generation-claims/transform_"+j.id+"-"+j.direction+"-"+j.role+"-v01.json";
   const claimed={id:j.id,direction:j.direction,role:j.role,batch:j.batch,request:j.request,status:"IMAGE_TOOL_CALLED_ONCE_NO_RETRY"};
   await tools.apply_patch("*** Begin Patch\n*** Add File: "+claim+"\n"+JSON.stringify(claimed,null,2).split("\n").map(s=>"+"+s).join("\n")+"\n*** End Patch");
   let row;
   try{
    const result=await tools.image_gen__imagegen(j.config.generation_request);
    const generated=result?.output_hint?.match(new RegExp("as (/workspace/generated_images/\\S+\\.png)"))?.[1];
    row=generated?{id:j.id,role:j.role,direction:j.direction,request:j.request,generated}:{id:j.id,role:j.role,direction:j.direction,request:j.request,blocked:true,error:result?.error||result?.output_hint||"Image tool returned no PNG"};
   }catch(e){row={id:j.id,role:j.role,direction:j.direction,request:j.request,blocked:true,error:String(e)};}
   await save(row);rows.set(j.id,row);active--;ready++;blocked+=row.blocked?1:0;
   notify({id:j.id,direction:j.direction,role:j.role,batch:j.batch,status:row.blocked?"BLOCKED":"PNG_READY",ready,total:jobs.length,active});
   mapLock=mapLock.then(writeMaps);await mapLock;
  }
 };
 text({phase:jobs[0]?.direction+" "+jobs[0]?.role,started:pending.length,resumed:ready,concurrency});
 const workers=Array.from({length:Math.min(concurrency,pending.length)},worker);
 await yield_control();await Promise.all(workers);await mapLock;await writeMaps();
 text({phase:jobs[0]?.direction+" "+jobs[0]?.role,source_complete:ready,blocked,maps:saved.size});
 return {ready,blocked,maps:saved.size};
}
