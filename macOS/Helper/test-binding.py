#!/usr/bin/env python3
"""Pure binding regression tests. No live AX/AppleEvents sessions are queried."""
import json, subprocess, pathlib
root=pathlib.Path(__file__).resolve().parent.parent
bundled=root / 'AIMicro Host.app/Contents/Resources/Helper/MicroRemoteAX'
binary=bundled if bundled.exists() else pathlib.Path(__file__).with_name('MicroRemoteAX')
result=subprocess.run([str(binary),'--self-test'],text=True,capture_output=True,check=True)
assert result.stdout.startswith('PASS:')
invalid=subprocess.run([str(binary)],input='not JSON\n',text=True,capture_output=True,check=True)
assert json.loads(invalid.stdout)['error']=='invalidJSON'
print(result.stdout.strip())
print('PASS: malformed protocol input rejected')
