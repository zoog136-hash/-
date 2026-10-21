"""Verify and install the private PNG pack from bounded transfer parts.

No network or Drive access is performed. Download the private parts yourself;
the public receipt contains hashes and names, never private storage identifiers.
"""
import argparse
import json
import shutil
import stat
import tempfile
import zipfile
from pathlib import Path

from build_native_png_maps import ROOT, digest
from verify_native_png_pack import verify


def install(parts, destination, receipt_path, plan_path, pack_receipt=None):
    destination = destination.resolve()
    if destination.is_relative_to(ROOT) or destination.exists():
        raise ValueError('Choose a NEW private destination outside the public checkout')
    receipt = json.loads(receipt_path.read_text())
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.twilight-native-', dir=destination.parent) as temporary:
        temporary = Path(temporary)
        archive = temporary/'pack.zip'
        seen = set()
        with archive.open('wb') as output:
            for row in receipt['parts']:
                name = row['file']
                if Path(name).name != name or name in seen:
                    raise ValueError('Unsafe or duplicate part name')
                seen.add(name)
                path = parts/name
                if path.stat().st_size != row['bytes'] or digest(path) != row['sha256']:
                    raise ValueError('Part byte identity mismatch: '+name)
                with path.open('rb') as stream:
                    shutil.copyfileobj(stream, output)
        if archive.stat().st_size != receipt['bytes'] or digest(archive) != receipt['sha256']:
            raise ValueError('Reassembled ZIP identity mismatch')
        unpacked = temporary/'unpacked'
        unpacked.mkdir()
        with zipfile.ZipFile(archive) as bundle:
            if sum(row.file_size for row in bundle.infolist()) > receipt['bytes']*2+16*1024*1024:
                raise ValueError('Unexpected expansion size')
            for row in bundle.infolist():
                path = (unpacked/row.filename).resolve()
                if not path.is_relative_to(unpacked) or stat.S_ISLNK(row.external_attr >> 16):
                    raise ValueError('Unsafe archive member')
            if bundle.testzip() is not None:
                raise ValueError('ZIP CRC mismatch')
            bundle.extractall(unpacked)
        pinned = json.loads((pack_receipt or ROOT/'data/maps/native_png_pack.json').read_text())
        if digest(unpacked/'index.json') != pinned['index_sha256']:
            raise ValueError('Archive does not match the checked-in private pack receipt')
        report = verify(unpacked, plan_path)
        unpacked.rename(destination)
    return dict(report, installed=str(destination), archive_sha256=receipt['sha256'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--parts-dir', type=Path, required=True)
    parser.add_argument('--destination', type=Path, required=True)
    parser.add_argument('--receipt', type=Path, default=ROOT/'data/maps/native_png_archive.json')
    parser.add_argument('--plan', type=Path, default=ROOT/'data/maps/native_png_plan.json')
    parser.add_argument("--pack-receipt", type=Path, default=ROOT/"data/maps/native_png_pack.json")
    args = parser.parse_args()
    print(json.dumps(install(args.parts_dir, args.destination, args.receipt, args.plan, args.pack_receipt)))
