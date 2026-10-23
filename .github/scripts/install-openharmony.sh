#!/usr/bin/env bash
set -euo pipefail

tools_root="${1:?Pass the toolchain cache directory}"
clt_home="$tools_root/command-line-tools"
sdk_home="$tools_root/sdk"
clt_url='https://repo.huaweicloud.com/harmonyos/ohpm/5.1.0/commandline-tools-linux-x64-5.1.0.840.zip'
clt_sha='1dcefa4741dc289277560b2802040e0c45b433898d8db453d711d5376e0478f1'
sdk_url='https://repo.huaweicloud.com/openharmony/os/6.1-LTS/ohos-sdk-windows_linux-public.tar.gz'
sdk_sha='e5a47f04e466b6072225ce9c04bad8b2b98d5222b0a1672bb98ca22984b304dc'

mkdir -p "$tools_root"
if [[ ! -f "$tools_root/.installed" ]]; then
  scratch="$(mktemp -d)"
  trap 'rm -rf -- "$scratch"' EXIT

  curl --fail --location --retry 4 --retry-delay 5 --connect-timeout 30 \
    --output "$scratch/clt.zip" "$clt_url"
  printf '%s  %s\n' "$clt_sha" "$scratch/clt.zip" | sha256sum --check --strict
  # Exclude the bundled HarmonyOS SDK: this project builds against the public
  # OpenHarmony SDK below. Retain executable modes from the official archives.
  unzip -q "$scratch/clt.zip" \
    'command-line-tools/bin/*' 'command-line-tools/hvigor/*' \
    'command-line-tools/ohpm/*' 'command-line-tools/tool/node/*' \
    -d "$tools_root"
  rm -- "$scratch/clt.zip"

  curl --fail --location --retry 4 --retry-delay 5 --connect-timeout 30 \
    --output "$scratch/sdk.tar.gz" "$sdk_url"
  printf '%s  %s\n' "$sdk_sha" "$scratch/sdk.tar.gz" | sha256sum --check --strict
  mkdir -p "$sdk_home/23"
  python3 - "$scratch/sdk.tar.gz" "$sdk_home/23" "$scratch" <<'PY'
import pathlib, shutil, subprocess, sys, tarfile

archive, destination, scratch = map(pathlib.Path, sys.argv[1:])
required = {'ets', 'js', 'native', 'toolchains', 'previewer'}
installed = set()
with tarfile.open(archive, 'r:gz') as source:
    for member in source:
        name = pathlib.PurePosixPath(member.name).name
        component = name.split('-linux-', 1)[0]
        if not member.isfile() or '-linux-' not in name or not name.endswith('.zip') or component not in required:
            continue
        package = scratch / name
        with source.extractfile(member) as incoming, package.open('wb') as output:
            shutil.copyfileobj(incoming, output)
        subprocess.run(['unzip', '-q', str(package), '-d', str(destination)], check=True)
        package.unlink()
        installed.add(component)
if installed != required:
    raise SystemExit('Missing Linux SDK packages: ' + ', '.join(sorted(required - installed)))
PY
  rm -- "$scratch/sdk.tar.gz"
  python3 - "$sdk_home/23" <<'PY'
import json, pathlib, sys

sdk = pathlib.Path(sys.argv[1])
for component in ['ets', 'js', 'native', 'toolchains', 'previewer']:
    metadata = json.loads((sdk / component / 'oh-uni-package.json').read_text(encoding='utf-8'))
    if str(metadata['apiVersion']) != '23':
        raise SystemExit('Expected API 23 SDK: ' + component)
    print(component + ': ' + metadata['version'])
PY
  test -x "$clt_home/bin/hvigorw"
  test -x "$clt_home/bin/ohpm"
  touch "$tools_root/.installed"
fi

printf 'OHOS_CLT_HOME=%s\nOHOS_BASE_SDK_HOME=%s\nOHOS_SDK_HOME=%s\n' \
  "$clt_home" "$sdk_home" "$sdk_home" >> "$GITHUB_ENV"
printf '%s\n%s\n' "$clt_home/bin" "$clt_home/tool/node/bin" >> "$GITHUB_PATH"
