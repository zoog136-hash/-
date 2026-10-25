// Run in functions.exec, not a shell. Requests and terminal receipts live on disk.
// Three workers, one attempt per absent sheet. A provider quota pauses new claims.
const root='/workspace/twilight';
const control='docs/remake/evidence/pr122-monsters-20261023/boss-draft-first/corrections-v01/control.py';
const quote=s=>"'"+String(s).replaceAll("'","'\\''")+"'";
async function cmd(args){
  const r=await tools.exec_command({cmd:'python3 '+quote(control)+' '+args.map(quote).join(' '),workdir:root,max_output_tokens:7000,yield_time_ms:1000});
  if(r.exit_code!==0)throw new Error('Durable queue operation failed: '+r.output.slice(-1200));
  return JSON.parse(r.output);
}
let completed=0,failed=0,stop=false;
async function worker(number){
  while(!stop){
    const claim=await cmd(['claim']);
    if(claim.done)return claim.summary;
    const {slug,clip}=claim.job;
    try{
      const result=await tools.image_gen__imagegen(claim.request);
      const hint=typeof result==='object'&&result?result.output_hint:'';
      const paths=String(hint).match(/\/workspace\/generated_images\/[^\s`"<>]+\.png/g);
      if(!paths?.length)throw new Error('Image provider returned no durable PNG path: '+String(hint).slice(0,900));
      const saved=await cmd(['save','--slug',slug,'--clip',clip,'--image',paths[paths.length-1]]);
      completed++;
      notify({worker:number,slug,clip,status:saved.status,summary:saved.summary});
    }catch(error){
      const reason=String(error).slice(0,2400);
      const quota=/429|quota|rate.?limit|daily.limit|too.many.requests/i.test(reason);
      const hold=await cmd(['error','--slug',slug,'--clip',clip,'--reason',reason,...(quota?['--global-pause']:[])]);
      failed++;if(quota)stop=true;
      notify({worker:number,slug,clip,status:hold.status,reason,summary:hold.summary});
      if(failed>=3){stop=true;notify({status:'BOUNDED_FAILURE_STOP',failed});}
    }
  }
}
await yield_control();
const results=await Promise.allSettled([worker(1),worker(2),worker(3)]);
text({status:'GENERATION_WORKERS_FINISHED',completed,failed,workers:results});
