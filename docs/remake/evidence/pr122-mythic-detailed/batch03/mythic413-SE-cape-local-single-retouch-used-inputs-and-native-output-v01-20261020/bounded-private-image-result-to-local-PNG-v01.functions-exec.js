// functions.exec orchestration reference; no service call or image forwarding.
// Before use: store("private_png_bounded_save_config_v1", {
//   result_store_key: "key_used_for_private_service_result",
//   partial_path: "/workspace/scratch/NEW_FOLDER/NEW_IMAGE.png.partial"
// }); Paste this body into functions.exec. It writes the unchanged PNG only.
const cfg=load("private_png_bounded_save_config_v1");
if(!cfg || typeof cfg.result_store_key!=="string" ||
 !/^\/workspace\/scratch\/[A-Za-z0-9_./-]+\.png\.partial$/.test(cfg.partial_path) ||
 cfg.partial_path.split("/").includes(".."))throw Error("Unsafe new private destination");
const result=load(cfg.result_store_key);
if(!result || typeof result.image_url!=="string")throw Error("No stored PNG payload; stop without retry");
const match=result.image_url.match(/^data:image\/png;base64,([A-Za-z0-9+/]+={0,2})$/);
if(!match)throw Error("Unsupported PNG payload; do not print raw result");
const data=match[1];let written=0,chunks=0;
for(let start=0;start<data.length;start+=48000){
 const part=data.slice(start,start+48000);
 if(part.length%4!==0 || !/^[A-Za-z0-9+/]+={0,2}$/.test(part))throw Error("Invalid bounded chunk");
 const bytes=part.length/4*3-(part.endsWith("==")?2:part.endsWith("=")?1:0);
 const cmd="python3 -B - <<'PY'\nimport base64,os\nfrom pathlib import Path\np=Path('"+cfg.partial_path+"')\n"+
 (start===0?"assert not p.exists()\n":"assert p.is_file() and p.stat().st_size=="+written+"\n")+
 "b=base64.b64decode('"+part+"',validate=True)\nassert len(b)=="+bytes+
 "\nwith p.open('"+(start===0?"xb":"ab")+"')as f:f.write(b);f.flush();os.fsync(f.fileno())\nPY";
 const response=await tools.exec_command({cmd,max_output_tokens:80});
 if(response.exit_code!==0)throw Error("Bounded write failed at chunk "+chunks+"; preserve partial, no blind retry");
 written+=bytes;chunks++;
}
store(cfg.result_store_key+"_decoded_png_bytes",written);
text({status:"PRIVATE_RAW_PNG_SAVED_AS_PARTIAL_NO_PAYLOAD_FORWARDED",bytes:written,bounded_chunks:chunks});
