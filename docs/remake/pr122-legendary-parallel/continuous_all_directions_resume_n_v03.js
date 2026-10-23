async () => {
 const prepare=eval(load("prepareContinuousPhaseCode"));
 const queue=eval(load("continuousGenerationQueueV03Code"));
 const remote=eval(load("waitGenerationPhaseRemoteCode"));
 const phases=[{direction:"N",base:202},{direction:"NE",base:234}];
 const batches=start=>Array.from({length:8},(_,i)=>start+i);
 const resumeProof=await tools.exec_command({cmd:"python3 - <<\x27PY\x27\nfrom pathlib import Path\nimport json\np=Path(\x27/workspace/legendary_work/docs/remake/pr122-legendary-parallel/generation-receipts\x27)\nrows=list(p.glob(\x27transform_*-NW-hit-v01.json\x27))\nassert len(rows)==40,\x27Controller handoff requires all40 NW HIT image receipts\x27\nprint(json.dumps({\x27NW_HIT_returned\x27:len(rows)}))\nPY",max_output_tokens:100});
 if(resumeProof.exit_code!==0)throw Error(resumeProof.output);
 await queue({jobs:await prepare({direction:"NW",role:"hit",batchStart:194}),concurrency:20}); // Proved all40 receipts above: resume metadata only, no image calls.
 await remote(batches(194),"NW HIT");
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
  {
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
