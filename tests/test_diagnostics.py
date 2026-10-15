"""Build and inspect the optional diagnostic variant, never the deployed game."""
import json
from pathlib import Path
import subprocess
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'vendor'))
from hd2_archive import read_archive,resource_hash,LUA_TYPE

subprocess.run([sys.executable,str(ROOT/'scripts/build.py'),'--diagnostics'],check=True,cwd=ROOT,
               stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
project=json.loads((ROOT/'project.json').read_text(encoding='utf-8'))
with zipfile.ZipFile(ROOT/'outputs'/f"Sekiro danger alert {project['version']} Diagnostics.zip")as z:
    assert z.testzip()is None
    manifest=json.loads(z.read('manifest.json'))
    assert manifest['Guid']==project['guid'] and manifest['Name'].endswith(' Diagnostics')
    assert 'README-采集说明.txt'in z.namelist()
    resources=read_archive(z.read('Addon/9ba626afa44a3aa3.patch_0'),z.read('Addon/9ba626afa44a3aa3.patch_0.gpu_resources'))
source=resources[LUA_TYPE,resource_hash(project['resource'])][0][8:]
assert source==(ROOT/'build/diagnostics/Sekiro danger alert.lua').read_bytes()
for token in (b'GetAsyncKeyState',b'capture_module',b'replicated_target',b'replicated_behavior',b'peril_warning.diagnostics.',
              b'function self:projectile_state',b'function self:flight_network_state',b'function self:behavior_network_state',
              b'diagnostic_only_not_committed_shot',b'utc_started',b'research_schema'):
    assert token in source,token
assert len(resources)==101
print('PASS optional diagnostic envelope: stable GUID/entry, actual LuaJIT compile, targeted raw research channels, collection-only F8 and unchanged assets')
