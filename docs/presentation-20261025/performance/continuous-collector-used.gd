extends SceneTree
var server:=TCPServer.new()
var stream:StreamPeerTCP
var peer:=PacketPeerStream.new()
var rows:Array=[]
var start:int
var connected:bool=false
func _initialize():
 start=Time.get_ticks_msec()
 peer.input_buffer_max_size=16777216
 var err=server.listen(6017,"127.0.0.1")
 if err!=OK:printerr(err);quit(1)
 print("COLLECTOR_READY")
func _process(_delta):
 if stream==null and server.is_connection_available():
  stream=server.take_connection();peer.stream_peer=stream;connected=true
  peer.put_var(["profiler:servers",1,[true,[1024,true]]])
  peer.put_var(["profiler:visual",1,[true,[]]])
 if stream!=null:
  stream.poll()
  while peer.get_available_packet_count()>0:
   var msg=peer.get_var()
   rows.append({"received_us":Time.get_ticks_usec(),"message":msg})
  if stream.get_status()==StreamPeerTCP.STATUS_NONE or stream.get_status()==StreamPeerTCP.STATUS_ERROR:finish()
 if Time.get_ticks_msec()-start>180000:finish()
 return false
func finish():
 var file=FileAccess.open(OS.get_environment("PROFILE_CAPTURE"),FileAccess.WRITE)
 for row in rows:file.store_line(JSON.stringify(row))
 print("COLLECTOR_SAVED ",rows.size())
 quit(0 if connected else 1)
