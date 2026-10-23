"""Validate a release-mode, unsigned HAP and prepare public release assets."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    hap = Path('entry/build/default/outputs/default/entry-default-unsigned.hap')
    with zipfile.ZipFile(hap) as archive:
        if archive.testzip() is not None:
            raise SystemExit('HAP ZIP checksum validation failed')
        app = json.loads(archive.read('module.json'))['app']
        if app.get('debug') is not False:
            raise SystemExit('Expected a release HAP with debug=false')
        if app.get('bundleName') != 'com.dreamist.homowarden_oh':
            raise SystemExit('Expected the OpenHarmony application bundle')
        version = app['versionName']
        if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+(?:[-+][A-Za-z0-9.-]+)?', version):
            raise SystemExit('Unsupported versionName')
        if os.environ.get('GITHUB_REF', '').startswith('refs/tags/'):
            if os.environ['GITHUB_REF_NAME'] != 'oh-v' + version:
                raise SystemExit('Release tag does not match the packaged version')

        # HAP signing adds a block immediately before the ZIP central directory.
        last = max(archive.infolist(), key=lambda member: member.header_offset)
        with hap.open('rb') as source:
            source.seek(last.header_offset)
            header = source.read(30)
            end = last.header_offset + 30 + struct.unpack_from('<H', header, 26)[0] + struct.unpack_from('<H', header, 28)[0] + last.compress_size
            if last.flag_bits & 8:
                source.seek(end)
                has_marker = source.read(4) == b'PK\x07\x08'
                end += (4 if has_marker else 0) + (20 if max(last.file_size, last.compress_size) >= 2**32 else 12)
        if end != archive.start_dir:
            raise SystemExit('Unexpected signing block or data before the ZIP central directory')

    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
    name = f'Homowarden-OpenHarmony-{version}-{commit[:7]}-release-unsigned.hap'
    args.output.mkdir(parents=True, exist_ok=True)
    target = args.output / name
    shutil.copyfile(hap, target)
    checksum = hashlib.sha256(target.read_bytes()).hexdigest()
    target.with_suffix('.hap.sha256').write_text(checksum + '  ' + name + '\n', encoding='ascii')
    print(json.dumps({'version': version, 'file': name, 'sha256': checksum, 'bytes': target.stat().st_size}))
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as output:
            output.write('version=' + version + '\n')
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as summary:
            summary.write(f'OpenHarmony {version}: release, unsigned, `{commit}`.\n\nSHA256: `{checksum}`\n')


if __name__ == '__main__':
    main()
