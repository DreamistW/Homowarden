"""Repack @huozhiniao/argon2 1.0.1 with OpenHarmony SDK metadata.

Usage: python scripts/patch-argon2-openharmony.py upstream.har output.har
The input may also be an extracted package directory. Native binaries are unchanged.
"""
import argparse
import gzip
import io
import json
from pathlib import Path
import tarfile


def patch(source: Path, destination: Path) -> None:
    files = {}
    if source.is_dir():
        for path in source.rglob('*'):
            if path.is_file():
                files[path.relative_to(source).as_posix()] = path.read_bytes()
    else:
        with tarfile.open(source, 'r:*') as archive:
            for item in archive.getmembers():
                if item.isfile():
                    name = item.name.removeprefix('./').removeprefix('package/')
                    files[name] = archive.extractfile(item).read()
    files = {name: data for name, data in files.items()
             if 'oh_modules' not in Path(name).parts and not name.endswith('oh-package-lock.json5')}
    manifest = json.loads(files['oh-package.json5'])
    if manifest['name'] != '@huozhiniao/argon2' or manifest['version'] != '1.0.1':
        raise ValueError('Expected @huozhiniao/argon2 1.0.1')
    manifest['compatibleSdkType'] = 'OpenHarmony'
    for component in manifest.get('nativeComponents', []):
        component['compatibleSdkType'] = 'OpenHarmony'
    files['oh-package.json5'] = (json.dumps(manifest, ensure_ascii=False, indent=2) + '\n').encode()
    module = json.loads(files['src/main/module.json'])
    module['app']['compileSdkType'] = 'OpenHarmony'
    files['src/main/module.json'] = (json.dumps(module, ensure_ascii=False, indent=2) + '\n').encode()
    with destination.open('wb') as output:
        with gzip.GzipFile(filename='', mode='wb', fileobj=output, mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode='w') as archive:
                for name, content in sorted(files.items()):
                    item = tarfile.TarInfo('package/' + name)
                    item.size = len(content)
                    item.mode = 0o644
                    archive.addfile(item, io.BytesIO(content))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('destination', type=Path)
    args = parser.parse_args()
    patch(args.source, args.destination)
