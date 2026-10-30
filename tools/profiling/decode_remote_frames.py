import json,sys
rows=[json.loads(x)['message'] for x in open(sys.argv[1])]; sig={}; frames=[];active=False;visual={}
for name,thread,d in rows:
 if name=='servers:function_signature':sig[d[1]]=d[0]
 if name=='visual:profile_frame':visual[d[0]]=d[2:]
 if name=='output':
  if 'ENTRY_COST_ACTIVE_BEGIN' in str(d):active=True
  if 'ENTRY_COST_ACTIVE_END' in str(d):active=False
 if name=='servers:profile_frame':
  p=7; servers={}
  for i in range(d[6]):
   n,c=d[p:p+2];servers[n]=d[p+2:p+2+c];p+=2+c
  count=d[p];p+=1;func=[]
  for i in range(p,p+count,5):
   id,c,s,t,internal=d[i:i+5];func.append(dict(name=sig.get(id,str(id)),calls=c,self_ms=s*1000,total_ms=t*1000,internal_ms=internal*1000))
  frames.append(dict(frame=d[0],active=active,frame_ms=d[1]*1000,process_ms=d[2]*1000,physics_ms=d[3]*1000,physics_frame_ms=d[4]*1000,script_ms=d[5]*1000,servers=servers,functions=func))
a=[f for f in frames if f['active']]
json.dump(dict(active_frames=a,visual_frames=visual,all_frame_count=len(frames)),open(sys.argv[2],'w'),indent=2)
