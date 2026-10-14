"""Capture identities must resolve to verified resource hashes, never guessed attacks."""
import json
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'vendor'))
from hd2_archive import resource_hash
catalog=json.loads((ROOT/'config/attack_catalog.json').read_text(encoding='utf-8'))
assert catalog['build']=='25480438'
resources={r['hash']:r for r in catalog['resources']}
assert len(resources)==len(catalog['resources'])
for h,r in resources.items():
    assert h==f"{resource_hash(r['path']):016x}"
    assert r['health_component'] and isinstance(r['behavior'],int)
moves=catalog['moves']
assert len(moves)==16 and len({m['id'] for m in moves})==16
for m in moves:
    assert m['default'] is True and m['status']=='capture_required'
    assert m['resources'] and set(m['resources'])<=resources.keys()
by_id={m['id']:m for m in moves}
assert by_id['titan_caustic_surge']['id']!=by_id['titan_cataclysmic_slam']['id']
assert by_id['barrager_direct_mlrs']['capture_note'].endswith('distance.')
assert set(by_id['tentacle_slam']['resources'])=={'dcf8e74212fbee3b','672f7da17f3ba34a'}
assert '8fb47dd28b398cf7' in by_id['annihilator_fusion_cannon']['resources']
print('PASS 16 distinct requested moves, default-on settings, verified resource hashes, child scopes and pending status')
