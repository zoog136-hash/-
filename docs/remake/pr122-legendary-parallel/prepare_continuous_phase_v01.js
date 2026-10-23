async ({direction,role,batchStart,fallbackIds=[]}) => {
 const work="/workspace/legendary_work", prefix="docs/remake/pr122-legendary-parallel";
 const roster=load("roster"); if(!roster?.length)throw Error("roster not loaded");
 const ids=roster.map(a=>a.id.split(":")[1]);
 const prepareResult=await tools.exec_command({cmd:"python3 - <<'PY'\nimport json,pathlib,sys\np=pathlib.Path('/workspace/legendary_work/docs/remake/pr122-legendary-parallel')\nsys.path.insert(0,str(p))\nimport prepare_mixed_draft_guard_request as guard\nD="+JSON.stringify(direction)+"\nrole="+JSON.stringify(role)+"\nids="+JSON.stringify(ids)+"\nfallback="+JSON.stringify(fallbackIds)+"\nresult=[]\nfor id in ids:\n standard=p/'requests'/f'transform_{id}-{D}-{role}-v01.json'\n supplement=p/'requests'/f'transform_{id}-{D}-{role}-guard-supplement-v01.json'\n existing=standard if standard.exists() else supplement if supplement.exists() else None\n if existing is not None:\n  result.append({'id':id,'request':str(existing.relative_to(p.parents[2]))});continue\n if id=='176' and role!='run':\n  template=p/'templates'/f'transform_176-{D}-{role}-supplement-v01.json'\n  with standard.open('xb') as h:h.write(template.read_bytes())\n  result.append({'id':id,'request':str(standard.relative_to(p.parents[2]))});continue\n if role in ('attack','hit') and id not in fallback:\n  path,q=guard.prepare('/workspace/legendary_repo',id,D,role)\n  result.append({'id':id,'request':str(path.relative_to(p.parents[2]))})\n else:result.append({'id':id,'request':None})\nprint(json.dumps(result))\nPY",max_output_tokens:4000});
 if(prepareResult.exit_code!==0)throw Error(prepareResult.output);
 const items=JSON.parse(prepareResult.output);
 const source=load("normalLaunchCode");if(!source)throw Error("normal launcher not loaded");
 const normalPrepare=eval(source.replace(" const r=await tools.image_gen__imagegen(req);"," return {id,role,direction,request:'docs/remake/pr122-legendary-parallel/requests/transform_'+id+'-'+direction+'-'+role+'-v01.json',config:q};\n const r=await tools.image_gen__imagegen(req);"));
 const jobs=[];
 for(let i=0;i<items.length;i++){
  const item=items[i],batch=batchStart+Math.floor(i/5);
  if(!item.request)item.request=(await normalPrepare(item.id,role,direction,batch)).request;
  jobs.push({...item,direction,role,batch});
 }
 return jobs;
}
