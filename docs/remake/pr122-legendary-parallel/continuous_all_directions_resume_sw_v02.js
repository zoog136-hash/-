async () => {
 const resumeProof=await tools.exec_command({cmd:"python3 - <<\x27PY\x27\nfrom pathlib import Path\nimport json\np=Path(\x27/workspace/legendary_work/docs/remake/pr122-legendary-parallel/generation-receipts\x27)\nrows=list(p.glob(\x27transform_*-SW-run-v01.json\x27))\nassert len(rows)==40,\x27SW RUN resume requires all40 returned receipts before controller handoff\x27\nprint(json.dumps({\x27SW_RUN_returned\x27:len(rows)}))\nPY",max_output_tokens:100});
 if(resumeProof.exit_code!==0)throw Error(resumeProof.output);

 const prepare=eval(load("prepareContinuousPhaseCode"));
 const queue=eval(load("continuousGenerationQueueCode"));
 const remote=eval(load("waitGenerationPhaseRemoteCode"));
 const phases=[{direction:"SW",base:106},{direction:"W",base:138},{direction:"NW",base:170},{direction:"N",base:202},{direction:"NE",base:234}];
 const batches=start=>Array.from({length:8},(_,i)=>start+i);
 await queue({jobs:await prepare({direction:"SW",role:"run",batchStart:114}),concurrency:20}); // All40 receipts proved above: resume maps only, no image calls.
 const guardSelection=async direction=>{
  let attempts=0;
  while(true){
   const path="/workspace/legendary_work/docs/remake/pr122-legendary-parallel/guard-reuse-selection-"+direction+"-v01.json";
   const r=await tools.exec_command({cmd:"python3 - <<'PY'\nimport json,pathlib\np=pathlib.Path("+JSON.stringify(path)+")\nprint(p.read_text() if p.exists() else 'null')\nPY",max_output_tokens:6000});
   if(r.exit_code!==0)throw Error(r.output);
   const plan=JSON.parse(r.output);
   if(plan){
    if(plan.direction!==direction||plan.reviewed_saved_idle!==true||plan.final_approval!==false)throw Error("Invalid guard reference selection");
    return plan;
   }
   if(attempts++%4===0)notify({direction,awaiting:"saved IDLE reference review only; no final QA"});
   await new Promise(resolve=>setTimeout(resolve,15000));
  }
 };
 for(let i=0;i<phases.length;i++){
  const {direction,base}=phases[i];
  if(i>0){
   await queue({jobs:await prepare({direction,role:"idle",batchStart:base}),concurrency:20});
   await remote(batches(base),direction+" IDLE");
   await queue({jobs:await prepare({direction,role:"run",batchStart:base+8}),concurrency:20});
  }
  await remote(batches(base+8),direction+" RUN");
  const plan=await guardSelection(direction);
  await queue({jobs:await prepare({direction,role:"attack",batchStart:base+16,fallbackIds:plan.fallback_ids||[]}),concurrency:20});
  await remote(batches(base+16),direction+" ATTACK");
  await queue({jobs:await prepare({direction,role:"hit",batchStart:base+24,fallbackIds:plan.fallback_ids||[]}),concurrency:20});
  await remote(batches(base+24),direction+" HIT");
 }
 text({all_remaining_directions_remote_saved:true,final_approval:false,full_quality_verification:"NOT_RUN_BY_GENERATOR"});
}
