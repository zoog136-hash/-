"""CRC/SHA audit of originals and nested ZIPs; an empty source directory is a failure."""
import argparse, collections, hashlib, io, json, pathlib, time, zipfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--sources', type=pathlib.Path, required=True)
parser.add_argument('--output', type=pathlib.Path, required=True)
parser.add_argument('--expected', type=int, default=13)
args = parser.parse_args()
report = {"archives": [], "errors": []}

def inspect(z, label, depth=0):
    entries = z.infolist()
    result = {"path": label, "entries": len(entries), "expanded_bytes": sum(i.file_size for i in entries), "crc_checked": 0, "nested": [], "errors": []}
    names = collections.Counter(i.filename for i in entries)
    result["duplicate_paths"] = [n for n, c in names.items() if c > 1]
    for info in entries:
        if info.is_dir():
            continue
        try:
            data = z.read(info)
            result["crc_checked"] += 1
            if info.filename.lower().endswith(".zip"):
                if depth >= 8:
                    raise ValueError("nested archive depth exceeds audit bound")
                with zipfile.ZipFile(io.BytesIO(data)) as child:
                    result["nested"].append(inspect(child, label + "!" + info.filename, depth + 1))
        except Exception as exc:
            result["errors"].append({"entry": info.filename, "error": str(exc)})
    return result

sources = sorted(args.sources.glob('*.zip'))
if len(sources) != args.expected:
    raise SystemExit(f'Expected {args.expected} source ZIPs, found {len(sources)}')
for p in sources:
    started = time.monotonic()
    sha = hashlib.sha256()
    with p.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            sha.update(block)
    try:
        with zipfile.ZipFile(p) as z:
            item = inspect(z, p.name)
        item["sha256"] = sha.hexdigest()
        item["bytes"] = p.stat().st_size
        report["archives"].append(item)
        print(p.name, item["crc_checked"], "entries", len(item["errors"]), "errors", round(time.monotonic() - started, 2), flush=True)
    except Exception as exc:
        report["errors"].append({"file": p.name, "error": str(exc)})
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')

def failed(item):
    return bool(item['errors'] or item['duplicate_paths'] or any(failed(n) for n in item['nested']))

raise SystemExit(bool(report['errors'] or any(failed(a) for a in report['archives'])))
