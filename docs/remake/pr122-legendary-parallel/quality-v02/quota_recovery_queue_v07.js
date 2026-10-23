async ({plan_path,candidates=null,concurrency=5,root_authorized_image_calls=false})=>{
 if(root_authorized_image_calls!==true){text({status:"WAIT_ROOT_IMAGE_CALL_AUTHORIZATION",image_calls:0,claims_reserved:0});return;}
 if(!Number.isInteger(concurrency)||concurrency<1||concurrency>20)throw Error("Image concurrency must be1..20");
 const quote=s=>"'"+String(s).replace(/'/g,"'\\''")+"'";
 const helper="/workspace/legendary_work/docs/remake/pr122-legendary-parallel/prepare_quota_recovery_v08.py";
 const read=await tools.exec_command({cmd:"python -c "+quote("import pathlib; print(pathlib.Path("+JSON.stringify(plan_path)+").read_text())"),max_output_tokens:30000});
 if(read.exit_code!==0)throw Error(read.output);
 const plan=JSON.parse(read.output),selected=candidates?new Set(candidates):null;
 if(Date.now()<Date.parse(plan.quota_not_before_utc)){text({status:"WAIT_QUOTA_RESET",not_before_utc:plan.quota_not_before_utc,image_calls:0,claims_reserved:0});return;}
 const jobs=plan.jobs.filter(j=>j.state==="READY"&&(!selected||selected.has(j.correction_candidate_id)));
 const waits=plan.jobs.filter(j=>j.state!=="READY"&&(!selected||selected.has(j.correction_candidate_id)));
 const generate=eval(load("qualityQuotaRecoveryOnceV05"));
 let next=0,completed=0,skipped=0,quotaStop=false,mapLock=Promise.resolve();
 const settlements=[],errors=[],announcedMaps=new Set();
 const writeMaps=async()=>{
  const output=await tools.exec_command({cmd:"python "+quote(helper)+" --write-maps --plan "+quote(plan_path),max_output_tokens:5000});
  if(output.exit_code!==0)throw Error(output.output);
  const maps=JSON.parse(output.output),fresh=maps.filter(m=>!announcedMaps.has(m.batch));
  for(const map of fresh)announcedMaps.add(map.batch);
  if(fresh.length)notify({quality_resume_maps:fresh});
 };
 const worker=async()=>{
  while(next<jobs.length&&!quotaStop){
   const j=jobs[next++];
   try{
    const generated=await generate({plan_path,candidate:j.correction_candidate_id,root_authorized_image_calls:true});
    const row=generated.row;
    if(row.status==="WAIT")skipped++;else completed++;
    const errorText=typeof row.error==="string"?row.error:JSON.stringify(row.error||"");
    if(row.blocked&&/429|usage_limit_reached|quota|rate.?limit/i.test(errorText))quotaStop=true;
    const settled=generated.settlement.then(()=>{
     mapLock=mapLock.then(async()=>{try{await writeMaps();}catch(e){errors.push(String(e));}});
    }).catch(e=>{errors.push("Metadata "+j.correction_candidate_id+": "+String(e));});
    settlements.push(settled);
   }catch(e){errors.push("Candidate "+j.correction_candidate_id+": "+String(e));}
  }
 };
 text({quality_resume_started:jobs.length,waiting:waits.length,concurrency,wait_details_plan:plan_path});
 await yield_control();
 await Promise.all(Array.from({length:Math.min(concurrency,jobs.length)},worker));
 await Promise.all(settlements);await mapLock;await writeMaps();
 text({quality_resume_complete:completed,skipped_existing_or_wait:skipped,waiting:waits.length,
  quota_stopped_without_new_calls:quotaStop,ready_not_called_this_run:jobs.length-next,metadata_errors:errors});
 if(errors.length)throw Error(errors.join(" | "));
}
