"""Check curated spawn facts and ABI pins without the game or original tables."""
from pathlib import Path
import json,struct,sys,unittest,uuid
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'vendor'))
from hd2_archive import resource_hash
MOD=ROOT/'tools/enemy_spawner'
class SpawnerCatalog(unittest.TestCase):
    def test_identities_and_packages(self):
        c=json.loads((MOD/'config/enemies.json').read_text(encoding='utf-8'))
        self.assertEqual(len(c['enemies']),14)
        self.assertEqual(len({e['id']for e in c['enemies']}),14)
        self.assertEqual(len({e['hash']for e in c['enemies']}),14)
        for e in c['enemies']:
            self.assertEqual(f'{resource_hash(e["path"]):016x}',e['hash'])
            raw=bytes.fromhex(e['package_record']);self.assertEqual(len(raw),32)
            self.assertEqual(e['packages'],[f'{struct.unpack_from("<Q",raw,o)[0]:016x}'for o in (8,16)if struct.unpack_from('<Q',raw,o)[0]])
            self.assertGreater(len(e['required_units']),0)
            self.assertLessEqual(len(e['required_units']),32)
            self.assertEqual(e['required_units'][0]['entity'],e['hash'])
        self.assertEqual(sum(e['faction']==2 for e in c['enemies']),8)
        self.assertEqual(sum(e['faction']==8 for e in c['enemies']),6)
        rows={e['id']:e for e in c['enemies']}
        self.assertEqual(rows['walker_scout_tier2']['hash'],'9076eeed17fcee35')
        self.assertEqual(rows['walker_scout_tier2']['behavior'],96)
        self.assertEqual(rows['lieutenant_assault_jumppack']['hash'],'e44ec9f9b3fe1d2a')
        self.assertEqual(rows['lieutenant_assault_jumppack']['behavior'],57)
        self.assertIn('b940c889d77f8219',{d['entity']for d in rows['lieutenant_assault_jumppack']['required_units']})
        self.assertEqual(rows['impaler']['min_difficulty'],5)
        self.assertEqual(rows['impaler']['summons'],[{'entity':'672f7da17f3ba34a','group':'aff5b26b','row':29}])
        self.assertIn({'entity':'672f7da17f3ba34a','unit':'672f7da17f3ba34a'},rows['impaler']['required_units'])
        self.assertIn('50c4a70c3174bc79',rows['impaler']['packages'])
        self.assertEqual([e['id']for e in c['enemies']if e.get('summons')],['impaler'])
        self.assertEqual(c['tables']['EnemyPackageComponentData'],{'index':77,'slots':316,'records':158,'offset':5056,'stride':32})
    def test_companion_does_not_replace_warning(self):
        p=json.loads((MOD/'project.json').read_text(encoding='utf-8'))
        original=json.loads((ROOT/'project.json').read_text(encoding='utf-8'))
        uuid.UUID(p['guid']);self.assertNotEqual(p['guid'],original['guid'])
        self.assertNotEqual(p['resource'],original['resource'])
        self.assertTrue(p['name'].startswith('Sekiro danger alert'))
        source=(MOD/'src/native.lua').read_text(encoding='utf-8')
        for forbidden in ['WriteProcessMemory','VirtualProtect','CreateRemoteThread']:
            self.assertNotIn(forbidden,source)
        self.assertEqual(source.count("ffi.cast('void (*)(void *, const uint64_t *, uint32_t)'"),1)
        self.assertEqual(source.count("ffi.cast('uint32_t *(*)(uint32_t *, uint64_t, void *)'"),1)
        self.assertNotIn('calls=',(MOD/'src/entry.lua').read_text(encoding='utf-8'))
    def test_capture_scope_matches_spawned_variants(self):
        c=json.loads((ROOT/'config/attack_catalog.json').read_text(encoding='utf-8'))
        moves={m['id']:m for m in c['moves']}
        self.assertEqual(moves['reinforced_heavy_rockets']['resources'],['9076eeed17fcee35'])
        self.assertEqual(moves['jet_hulk_rotary_saw']['resources'],['e44ec9f9b3fe1d2a'])
        self.assertEqual(moves['reinforced_heavy_rockets']['status'],'enabled_from_capture')
        self.assertEqual(moves['jet_hulk_rotary_saw']['status'],'enabled_from_capture')
    def test_pin_extent_and_abi(self):
        p=json.loads((MOD/'config/native.json').read_text(encoding='utf-8'))
        pins={i['label']:i for i in p['pins']}
        self.assertEqual(p['spawn_rva'],0xfd9710)
        self.assertEqual(len(bytes.fromhex(pins['complete spawn request ABI']['hex'])),0xb8)
        self.assertEqual(len(bytes.fromhex(pins['component creation and default context']['hex'])),0x1c9)
        self.assertEqual(p['context_size'],0x8a0)
        self.assertEqual(p['invalid_entity'],0x348456c)
        self.assertEqual(p['loader']['requestRva'],19915600)
        self.assertEqual(p['summon_gate'],{'difficulty':0x518c4,'roster':0x660,'descriptor':0x21cbd60,
            'rows':0x32b6ba0,'count':45,'stride':128,'weights':48,'tags':88,'tag_bytes':32})
        self.assertEqual(len(bytes.fromhex(pins['complete native enemy picker']['hex'])),0x253)
        self.assertEqual(pins['native spawn limit dereferences picked entry']['rva'],0x952ff0)
        self.assertEqual(pins['summon resolves native roster entry']['rva'],0x11c8c90)
        for i in p['pins']:
            self.assertIn(i['module'],{'game','exe'});self.assertGreater(i['rva'],4096)
            self.assertGreaterEqual(len(bytes.fromhex(i['hex'])),5)
if __name__=='__main__':unittest.main()
