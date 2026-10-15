"""Check the actual release payload excludes all development collection code."""
import json
from pathlib import Path
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'vendor'))
from hd2_archive import read_archive,resource_hash,LUA_TYPE

project=json.loads((ROOT/'project.json').read_text(encoding='utf-8'))
package=ROOT/'outputs'/f"Sekiro danger alert {project['version']}.zip"
with zipfile.ZipFile(package) as z:
    assert len(z.namelist())==6
    assert 'README-使用说明.txt' in z.namelist()
    assert not any('test' in n.lower() or 'spawner' in n.lower() for n in z.namelist())
    resources=read_archive(z.read('Addon/9ba626afa44a3aa3.patch_0'),
                           z.read('Addon/9ba626afa44a3aa3.patch_0.gpu_resources'))
source=resources[LUA_TYPE,resource_hash(project['resource'])][0][8:].decode('utf-8')
assert source==(ROOT/'build/Sekiro danger alert.lua').read_text(encoding='utf-8')
for name in ('capture_module','marker_module','tracking_module','GetAsyncKeyState','research_capture',
             'target_capture','automatic_trigger','raw_hex','capture_note',
             'function self:weapon_inputs','function self:targeting_header','function self:animation'):
    assert name not in source,name
assert "id='crusher_melee'" in source and "mod_id='peril_warning.crusher'" in source
assert 'peril_warning.crusher.moves' not in source
assert not any((ROOT/'src'/name).exists() for name in ('capture.lua','tracking.lua','marker.lua'))
print('PASS packaged release contains only production modules, one settings category and the unified Crusher control')
