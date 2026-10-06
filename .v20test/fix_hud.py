from pathlib import Path
import sys

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
text = "\n".join(line for line in text.splitlines() if "icon_max_width" not in line) + "\n"
p.write_text(text, encoding="utf-8")
