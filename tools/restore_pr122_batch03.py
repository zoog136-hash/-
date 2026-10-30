import hashlib
import json
import pathlib
import subprocess
import sys
import tarfile


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


source = pathlib.Path(sys.argv[1]).resolve()
destination = pathlib.Path(sys.argv[2]).resolve()
manifest = json.loads((source / 'manifest.json').read_text())
if destination.exists():
    raise SystemExit('Refusing existing destination: ' + str(destination))
archive = destination.parent / (destination.name + '.tar.zst')
if archive.exists():
    raise SystemExit('Refusing existing archive: ' + str(archive))
parts = []
for item in manifest['parts']:
    path = source / item['path']
    assert path.stat().st_size == item['bytes'], str(path)
    assert digest(path) == item['sha256'], str(path)
    parts.append(path)
with archive.open('xb') as out:
    for path in parts:
        with path.open('rb') as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b''):
                out.write(chunk)
assert archive.stat().st_size == manifest['archive_bytes']
assert digest(archive) == manifest['archive_sha256']
subprocess.run(['zstd', '-t', str(archive)], check=True)
expected = {x['path']: x for x in manifest['members']}
seen = set()
destination.mkdir(parents=True)
process = subprocess.Popen(['zstd', '-dc', str(archive)], stdout=subprocess.PIPE)
with tarfile.open(fileobj=process.stdout, mode='r|') as tar:
    for member in tar:
        path = pathlib.PurePosixPath(member.name)
        assert not path.is_absolute() and '..' not in path.parts, member.name
        if member.isdir():
            (destination / path).mkdir(parents=True, exist_ok=True)
            continue
        assert member.isfile() and not member.issym() and not member.islnk(), member.name
        assert member.name in expected and member.name not in seen, member.name
        entry = expected[member.name]
        assert member.size == entry['bytes'], member.name
        output = destination / path
        output.parent.mkdir(parents=True, exist_ok=True)
        h = hashlib.sha256()
        with tar.extractfile(member) as f, output.open('xb') as out:
            for chunk in iter(lambda: f.read(1024 * 1024), b''):
                h.update(chunk)
                out.write(chunk)
        assert h.hexdigest() == entry['sha256'], member.name
        seen.add(member.name)
assert process.wait() == 0
assert seen == set(expected), sorted(set(expected) - seen)
proof = {'parts': len(parts), 'members': len(seen), 'archive_sha256': digest(archive),
         'destination': str(destination), 'all_part_and_member_sha256_match': True,
         'new_completion': 0, 'production_written': False}
(destination.parent / (destination.name + '-restore-proof.json')).write_text(
    json.dumps(proof, indent=2) + '\n')
print(json.dumps(proof))
