async ({plan_path,candidate,root_authorized_image_calls=false})=>{
 if(root_authorized_image_calls!==true)return {row:{status:"WAIT",reason:"WAIT_ROOT_IMAGE_CALL_AUTHORIZATION",candidate},settlement:Promise.resolve()};
 const quote=s=>"'"+String(s).replace(/'/g,"'\\''")+"'";
 const helper="/workspace/legendary_work/docs/remake/pr122-legendary-parallel/prepare_quota_recovery_v08.py";
 const check=await tools.exec_command({cmd:"python "+quote(helper)+" --claim "+quote(candidate)+" --plan "+quote(plan_path)+" --root-authorized-image-call",max_output_tokens:12000});
 if(check.exit_code!==0)throw Error(check.output);
 const gate=JSON.parse(check.output);
 if(gate.status!=="CLAIMED_ONCE")return {row:gate,settlement:Promise.resolve()};
 const j=gate.job;
 store("quality-quota-recovery-active",(load("quality-quota-recovery-active")||0)+1);
 let result,row;
 try{
  result=await tools.image_gen__imagegen(gate.generation_request);
  const hint=typeof result?.output_hint==="string"?result.output_hint:"";
  const generated=hint.match(/as (\/workspace\/generated_images\/\S+\.png)/)?.[1];
  row={id:j.id,direction:j.direction,role:j.role,request:j.request,request_sha256:j.request_sha256,
   correction_candidate_id:j.correction_candidate_id,previous_source_sha256:j.previous_source_sha256,
   representation:j.representation,batch:j.batch,
   ...(generated?{generated}:{blocked:true,error:result?.error||hint||"Image tool returned no PNG"})};
 }catch(e){
  result={thrown_error:String(e)};
  row={id:j.id,direction:j.direction,role:j.role,request:j.request,request_sha256:j.request_sha256,
   correction_candidate_id:j.correction_candidate_id,previous_source_sha256:j.previous_source_sha256,
   representation:j.representation,batch:j.batch,blocked:true,error:String(e)};
 }finally{store("quality-quota-recovery-active",Math.max(0,(load("quality-quota-recovery-active")||1)-1));}
 const strip=v=>{
  if(typeof v==="string"&&(v.startsWith("data:")||(v.length>20000&&/^[A-Za-z0-9+/=\r\n]+$/.test(v))))return "[binary/base64 omitted]";
  if(Array.isArray(v))return v.map(strip);
  if(v&&typeof v==="object"){const o={};for(const[k,value]of Object.entries(v))o[k]=/^(data|b64_json|image_url)$/i.test(k)?"[binary/base64 omitted]":strip(value);return o;}
  return v;
 };
 const returned=new Date().toISOString();
 const settlement=(async()=>{
  const meta={candidate:j.correction_candidate_id,returned_utc:returned,result_without_base64:strip(result),
   request:j.request,request_sha256:j.request_sha256,maximum_generation_calls:1,generation_retries:0,original_client_attempts:1,recovery_attempt_number:1,total_client_attempt_number:2,maximum_successful_generated_PNGs:1};
  for(const[path,value]of [[gate.tool_result,meta],[gate.receipt,{...row,returned_utc:returned}]]){
   await tools.apply_patch("*** Begin Patch\n*** Add File: "+path+"\n"+JSON.stringify(value,null,2).split("\n").map(x=>"+"+x).join("\n")+"\n*** End Patch");
  }
  store("quality-quota-recovery-result-"+j.correction_candidate_id,row);
 })();
 notify({candidate:j.correction_candidate_id,id:j.id,direction:j.direction,role:j.role,
  status:row.blocked?"BLOCKED":"PNG_READY",active:load("quality-quota-recovery-active")});
 return {row,settlement};
}
