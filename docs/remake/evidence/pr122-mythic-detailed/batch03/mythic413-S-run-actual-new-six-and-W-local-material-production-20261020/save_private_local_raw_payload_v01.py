import sys,termios,base64,hashlib,json
from pathlib import Path
n=int(sys.argv[1]);target=Path(sys.argv[2]);attrs=termios.tcgetattr(0);attrs[3]&=~(termios.ECHO|termios.ICANON);attrs[6][termios.VMIN]=1;attrs[6][termios.VTIME]=0;termios.tcsetattr(0,termios.TCSANOW,attrs)
print('PRIVATE_RAW_RECEIVER_READY',flush=True)
buf=bytearray()
while len(buf)<n:
 chunk=sys.stdin.buffer.read(min(65536,n-len(buf)))
 if not chunk:raise RuntimeError('unexpected input closure')
 buf.extend(chunk)
raw=base64.b64decode(buf,validate=True);target.write_bytes(raw)
print(json.dumps(dict(path=str(target),bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest())),flush=True)
