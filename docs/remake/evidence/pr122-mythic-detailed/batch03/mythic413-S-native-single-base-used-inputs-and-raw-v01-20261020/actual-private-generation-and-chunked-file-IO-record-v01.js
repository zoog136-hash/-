// Actual private S generation and IO sequence, recorded after successful execution.
const req = load("S_private_req");
const r = await tools.image_gen__imagegen(req); // exactly once, no retry
store("S_private_service_result", r); // never print/forward image_url
const payload = r.image_url.slice("data:image/png;base64,".length);
const writer = await tools.exec_command({cmd: "python <frozen-writer> <native-raw-output> " + payload.length, tty:true, yield_time_ms:1000, max_output_tokens:100});
if (!writer.output.includes("PRIVATE_STDIN_READY_ECHO_DISABLED")) throw Error("writer not ready");
for (let i=0; i<payload.length; i+=49152) {
  const saved = await tools.write_stdin({session_id:writer.session_id, chars:payload.slice(i,i+49152), yield_time_ms:1, max_output_tokens:160});
  if (saved.output && !saved.output.includes('"sha256"')) throw Error("unexpected writer output");
}
// Only readiness and local path/hash/byte metadata were returned.
