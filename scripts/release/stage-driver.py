#!/usr/bin/env python3
"""Fetch the exact upstream binary archive; never install a global daemon."""
import hashlib, io, json, pathlib, tarfile, urllib.request
root = pathlib.Path(__file__).resolve().parents[2]
lock = json.loads((root / 'apps/macos/vendor/cua-driver.lock.json').read_text())
archive = urllib.request.urlopen(lock['url'], timeout=120).read()
if hashlib.sha256(archive).hexdigest() != lock['sha256']:
    raise SystemExit('Driver archive checksum mismatch')
out = root / 'apps/macos/vendor/staged'
out.mkdir(parents=True, exist_ok=True)
# The CLI is standalone (system dylibs only); its cursor theme is a companion executable.
with tarfile.open(fileobj=io.BytesIO(archive), mode='r:gz') as tar:
    for name in ('cua-driver', 'cua-cursor-theme'):
        member = tar.getmember(name)
        if not member.isfile(): raise SystemExit('Unexpected archive member')
        data = tar.extractfile(member).read()
        target = out / name
        target.write_bytes(data)
        target.chmod(0o755)
        print(f'{name}: {hashlib.sha256(data).hexdigest()}')
(out / 'archive.sha256').write_text(lock['sha256'] + '\n')
