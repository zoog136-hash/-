from pathlib import Path
import sys,base64,hashlib,json,termios
fd=sys.stdin.fileno();attrs=termios.tcgetattr(fd);attrs[3]&=~(termios.ECHO|termios.ICANON);attrs[6][termios.VMIN]=1;attrs[6][termios.VTIME]=0;termios.tcsetattr(fd,termios.TCSANOW,attrs)
print("PRIVATE_STDIN_READY_ECHO_DISABLED",flush=True)
p=Path(sys.argv[1]);expected=int(sys.argv[2]);data=sys.stdin.buffer.read(expected)
assert len(data)==expected
raw=base64.b64decode(data,validate=True)
with p.open('xb')as f:f.write(raw)
print(json.dumps(dict(path=str(p),sha256=hashlib.sha256(raw).hexdigest(),bytes=len(raw))),flush=True)
