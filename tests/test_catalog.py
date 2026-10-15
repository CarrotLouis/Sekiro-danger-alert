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
assert len(moves)==18 and len({m['id'] for m in moves})==18
for m in moves:
    assert m['default'] is True and m['status']in {'enabled_from_capture','enabled_from_native_pending_capture'}
    assert m['faction']in {2,8,4}
    assert m['resources'] and set(m['resources'])<=resources.keys()
by_id={m['id']:m for m in moves}
assert by_id['titan_caustic_surge']['id']!=by_id['titan_cataclysmic_slam']['id']
assert by_id['barrager_direct_mlrs']['capture_note'].endswith('distance.')
assert set(by_id['tentacle_slam']['resources'])=={'dcf8e74212fbee3b','672f7da17f3ba34a'}
assert '8fb47dd28b398cf7' in by_id['annihilator_fusion_cannon']['resources']
rules=json.loads((ROOT/'config/expanded_attacks.json').read_text(encoding='utf-8'))
mapped={r['move']for e in rules['resources'].values()for r in e['abilities'].values()}|{rules['factory']['move']}
assert mapped==set(by_id),'each requested move must have an automatic path'
assert set(rules['resources'])|{rules['factory']['resource']}<=resources.keys()
for hash,e in rules['resources'].items():
    assert resources[hash]['behavior']==e['behavior']
    assert not(set(e['abilities'])&set(e['excluded']))
    for id,r in e['abilities'].items():
        assert hash in by_id[r['move']]['resources'] and int(id)>0
        assert r['cues'] and all(0<=c['time']<c['last']for c in r['cues'])
        assert all(c['last']<c['fire']for c in r['cues']if'fire'in c)
assert set(rules['resources']['960b48a421a3faaa']['abilities'])=={'254'}
assert rules['resources']['960b48a421a3faaa']['excluded']['252']=='hover_breath'
assert 'diving breath only'in by_id['dragon_alchemical_pyrosis']['attack_name']
assert set(rules['resources']['5d142c3a73ebc634']['abilities'])=={'1018'}
assert rules['resources']['5d142c3a73ebc634']['excluded']['1019']=='artillery'
assert len(rules['resources']['5d142c3a73ebc634']['abilities']['1018']['cues'])==3
assert rules['factory']['resource']=='843d18d4b5512b63' and rules['factory']['stage_start_offset']==0x188
assert rules['factory']['earliest_fire_time']==1 and rules['factory']['last_warning_time']<=.8
assert len(rules['pins'])>=60
assert all(m['status']=='enabled_from_capture' for m in moves)
assert resources['965eae5a51acdd4a']['behavior']==280
assert set(rules['resources']['965eae5a51acdd4a']['abilities'])=={'1956','1957','1961','1962'}
harvester=json.loads((ROOT/'config/harvester.json').read_text(encoding='utf-8'))
assert harvester['entity']=='965eae5a51acdd4a'and harvester['behavior']==280
assert [(m['mount_index'],m['weapon_slot'])for m in harvester['mounts']]==[(0,0),(1,3),(2,1),(3,2)]
assert harvester['mounts'][2]['component']=='ArcWeaponComponentData'
assert harvester['moves']['harvester_tesla_ripper']['abilities']==[1961,1962]
assert harvester['moves']['harvester_disintegration_beamer']['abilities']==[1956,1957]
assert rules['resources'][harvester['entity']]['excluded'][str(1963)]=='tripod_cannon'
assert any(p['rva']==harvester['slot_binding_rva']for p in rules['pins'])
project=json.loads((ROOT/'project.json').read_text(encoding='utf-8'))
assert project['guid']=='1dc82965-3c84-4eec-bb72-88e8121ac0dc'
assert 'version=project.version'in(ROOT/'src/entry.lua').read_text(encoding='utf-8')
assert harvester['captured_abilities']==[1956,1957,1961]
print('PASS 18 enabled distinct moves, captured Harvester IDs with native-only 1962 recorded, resource identities and existing exclusions')
