"""Next-attack identities and bounded collection envelope, not live cue proof."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'vendor'))
from hd2_archive import resource_hash, read_archive, LUA_TYPE

request=json.loads((ROOT/'config/expansion_v2.json').read_text(encoding='utf-8'))
assert request['steam_build']=='25480438'
controls={c['id']:c for c in request['controls']}
assert len(controls)==11 and len(request['capture_moves'])==14
assert {c['id']for c in controls.values()if not c['default']}=={
    'nursing_putrid_regurgitation','bile_corrosive_regurgitation','rupture_corrosive_regurgitation'}
assert all(c['status']=='requires_live_mapping' for c in controls.values())
resources={r['hash']:r for r in request['resources']}
for r in resources.values():
    if r['path'] is not None:
        assert r['hash']==f"{resource_hash(r['path']):016x}"
    else:
        assert r['hash']=='0d382ae7ffea9d45' and r['name_text_id']=='4bc6d48a'
        assert r['identity_evidence']['arc_type']==5
for move in request['capture_moves']:
    assert move['resources']
    if move['id']=='hive_lord_all':
        assert move['controls']==['hive_lord_body_slam','hive_lord_bile_rain']
        assert [(x['key'],x['vk']) for x in move['manual_markers']]==[('-',0xbd),('=',0xbb),('[',0xdb),(']',0xdd)]
        assert move['capture_profile']=='hive_lord_long'
    else:assert move['control'] in controls
    assert set(move['resources'])<=resources.keys()
    assert move['status']=='pending_capture'
assert len(controls['charger_charge']['resources'])==5
assert len(controls['commander_charge']['resources'])==2
assert request['charge_rule']['default']==5 and request['charge_rule']['maximum']==15
assert request['charge_rule']['minimum']==0 and request['charge_rule']['step']==1
assert request['charge_rule']['distance_options']==[
    {'id':'charger_charge_range','control':'charger_charge','default':5},
    {'id':'commander_charge_range','control':'commander_charge','default':5}]
assert request['menu_plan']['attack_controls']==26
assert request['menu_plan']['attack_rows_with_range_and_reset']==29
assert max(request['menu_plan']['attack_rows_with_range_and_reset'],request['menu_plan']['appearance_rows'])<=32
original=json.loads((ROOT/'project.json').read_text())
catalog=json.loads((ROOT/'config/attack_catalog.json').read_text(encoding='utf-8'))
assert not ({m['id']for m in catalog['moves']}&controls.keys()),'unmapped requests must not become production warning rules'
assert all(m['status']=='enabled_from_capture'for m in catalog['moves'])
before=(ROOT/'project.json').read_bytes()
ordinary=ROOT/'outputs'/f"Sekiro danger alert {original['version']}.zip"
ordinary_hash=hashlib.sha256(ordinary.read_bytes()).hexdigest()
refused=subprocess.run([sys.executable,str(ROOT/'scripts/build.py'),'--next-attacks'],
    capture_output=True,text=True,encoding='utf-8',cwd=ROOT)
assert refused.returncode!=0 and 'requires --diagnostics' in refused.stderr
result=subprocess.run([sys.executable,str(ROOT/'scripts/build.py'),'--diagnostics','--next-attacks'],
    capture_output=True,text=True,encoding='utf-8',cwd=ROOT)
assert result.returncode==0,result.stdout+result.stderr
assert (ROOT/'project.json').read_bytes()==before
assert hashlib.sha256(ordinary.read_bytes()).hexdigest()==ordinary_hash,'collection build must not overwrite the ordinary ZIP'
target=ROOT/'outputs'/f"Sekiro danger alert {request['version']} Diagnostics.zip"
with zipfile.ZipFile(target) as archive:
    assert archive.testzip() is None
    manifest=json.loads(archive.read('manifest.json'))
    assert manifest['Guid']==original['guid']
    assert manifest['Name']==f"Sekiro danger alert {request['version']} Diagnostics"
    prefix='Addon/9ba626afa44a3aa3.patch_0'
    packed=read_archive(archive.read(prefix),archive.read(prefix+'.gpu_resources'))
    source=packed[LUA_TYPE,resource_hash(original['resource'])][0][8:]
    assert len(packed)==101
    assert source==(ROOT/'build/diagnostics/Sekiro danger alert.lua').read_bytes()
    for move in request['capture_moves']:assert move['id'].encode() in source
    for token in [b"key='bugs_new'",b'requested_control',b'requested_warning_enabled',b'pending_capture']:
        assert token in source,token
    assert archive.read('README-使用说明.txt')==(ROOT/'tools/diagnostics/README-新增招式采集.txt').read_bytes()
    assert b'WriteProcessMemory'not in source and b'VirtualProtect'not in source
    assert archive.read('README.txt').startswith(('Sekiro danger alert '+request['version']).encode())
print('PASS 11 pending controls/14 capture scopes, four Hive keys, identities, defaults, bounded menu plan and isolated same-GUID collection ZIP; new warning integration remains pending')
