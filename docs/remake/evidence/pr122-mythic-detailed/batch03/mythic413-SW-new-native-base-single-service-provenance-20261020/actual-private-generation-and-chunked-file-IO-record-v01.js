// Actual executed private SW generation/IO sequence; request and exact writer paths are in frozen JSON.
const t=Date.now(),r=await tools.image_gen__imagegen(load("SW_private_req")); // exactly once
store("SW_private_service_result",r);store("SW_private_elapsed_ms",Date.now()-t);
if(typeof r.image_url!=="string"||!r.image_url.startsWith("data:image/png;base64,"))throw Error("Unexpected private result format; no retry");
const payload=r.image_url.slice("data:image/png;base64,".length);store("SW_private_payload",payload);
const call=await tools.exec_command({cmd:"python /workspace/scratch/mythic413-SW-private-base-generation-continuing-20261020-v01/save-private-base64-payload-stdin-v02.py /workspace/scratch/mythic413-SW-private-base-generation-continuing-20261020-v01/service-SW-fullbody-base-native-r001.png "+payload.length,tty:true,yield_time_ms:1000,max_output_tokens:100});
if(!call.session_id||!call.output.includes("PRIVATE_STDIN_READY_ECHO_DISABLED"))throw Error("Writer not ready");
store("SW_private_writer_session",call.session_id);
for(let i=0;i<payload.length;i+=49152){
 const saved=await tools.write_stdin({session_id:call.session_id,chars:payload.slice(i,i+49152),yield_time_ms:1,max_output_tokens:160});
 if(saved.output&&!saved.output.includes('"sha256"'))throw Error("Unexpected writer output");
}
// Returned only result keys, timing, readiness, local path/hash/bytes. No image/Base64 forwarding.
