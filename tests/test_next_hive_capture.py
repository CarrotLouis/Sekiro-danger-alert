"""After test_next_attacks builds its catalog, exercise and parse the real long collector."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import uuid
import unittest

ROOT=Path(__file__).resolve().parents[1]


class HiveCapture(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        result=subprocess.run([sys.executable,str(ROOT/'vendor/game_lua.py'),
            str(ROOT/'tests/fixtures/hive_capture_checks.lua'),str(ROOT)],
            cwd=ROOT,capture_output=True,text=True,encoding='utf-8')
        if result.returncode:
            raise AssertionError(result.stdout+result.stderr)
        print(result.stdout.split('HIVE_RESULT ',1)[0].strip())
        cls.paths=json.JSONDecoder().raw_decode(next(x[len('HIVE_RESULT '):]for x in result.stdout.splitlines()if x.startswith('HIVE_RESULT ')))[0]
        cls.parts=[[json.loads(line)for line in Path(p).read_text(encoding='utf-8').splitlines()]
            for p in cls.paths['long_paths']]

    def test_parts_are_valid_bounded_and_share_one_clock(self):
        self.assertEqual(len(self.parts),3)
        self.assertEqual(len({p[0]['session_id']for p in self.parts}),1)
        self.assertEqual([p[0]['part_index']for p in self.parts],[1,2,3])
        self.assertEqual([p[0]['t']for p in self.parts],[0,300,600])
        self.assertEqual([p[-1]['session_continues']for p in self.parts],[True,True,False])
        times=[r['t']for p in self.parts for r in p]
        self.assertEqual(times,sorted(times))
        for path,p in zip(self.paths['long_paths'],self.parts):
            self.assertLessEqual(Path(path).stat().st_size,8*1024*1024)
            self.assertEqual(p[0]['duration_limit_s'],3600)
            self.assertEqual(p[0]['research_schema'],3)
            self.assertEqual(p[-1]['part_marker_count'],sum(r['event']=='user_attack_mark'for r in p))
            self.assertEqual(p[-1]['part_research_samples'],sum(r['event']=='research_sample'for r in p))

    def test_keys_keep_their_variant_and_player_epoch(self):
        mapping={'-':'hive_lord_body_slam_surfaced','=':'hive_lord_body_slam_emerging',
            '[':'hive_lord_bile_rain_sweeps',']':'hive_lord_bile_rain_stream'}
        marks=[r for p in self.parts for r in p if r['event']=='user_attack_mark']
        self.assertEqual(len(marks),8)
        for r in marks:
            self.assertEqual(r['marked_move'],mapping[r['key']])
        self.assertEqual(self.parts[-1][-1]['marker_counts'],{k:2 for k in mapping})
        waiting=next(r for r in marks if r['t']==301)
        self.assertFalse(waiting['local_avatar_available'])
        self.assertNotIn('last_observation',waiting)
        resumed=next(r for r in marks if r['t']==302)
        self.assertEqual(resumed['avatar_epoch'],2)
        self.assertEqual(resumed['last_observation']['sample_t'],302)

    def test_offline_report_retains_keyed_annotations_and_continuation(self):
        spec=importlib.util.spec_from_file_location('hive_analysis',ROOT/'scripts/analyze_capture.py')
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        r=module.analyze(self.parts[1])
        self.assertEqual(r['capture_segment']['part_index'],2)
        self.assertEqual(r['capture_segment']['duration_s'],300)
        self.assertTrue(r['capture_segment']['session_continues'])
        self.assertEqual([m['key']for m in r['marker_annotations']],['=','[',']'])
        self.assertEqual(r['marked_move_counts'],{'hive_lord_body_slam_emerging':1,
            'hive_lord_bile_rain_sweeps':1,'hive_lord_bile_rain_stream':1})

    def test_byte_quota_and_open_failure_leave_readable_previous_parts(self):
        quota=[[json.loads(s)for s in Path(p).read_text(encoding='utf-8').splitlines()]for p in self.paths['quota_paths']]
        self.assertEqual(len(quota),2)
        self.assertTrue(quota[0][-1]['session_continues'])
        self.assertFalse(quota[1][-1]['session_continues'])
        self.assertEqual(quota[1][-1]['reason'],'256 MiB session limit')
        self.assertEqual(quota[1][-1]['marker_count'],1)
        failed=Path(self.paths['failed_paths'][0])
        self.assertEqual(json.loads(failed.read_text(encoding='utf-8').splitlines()[-1])['reason'],'part rotated')

    def test_rotation_io_time_cannot_make_a_record_predate_its_header(self):
        parts=[[json.loads(s)for s in Path(p).read_text(encoding='utf-8').splitlines()]
            for p in self.paths['clocked_paths']]
        self.assertEqual(len(parts),2)
        times=[r['t']for p in parts for r in p]
        self.assertEqual(times,sorted(times))

    def test_failed_write_stops_without_inventing_a_recorded_marker(self):
        rows=[json.loads(s)for s in Path(self.paths['write_failed_paths'][0]).read_text(encoding='utf-8').splitlines()]
        self.assertTrue(any(r['event']=='research_sample'for r in rows))
        self.assertFalse(any(r['event']=='user_attack_mark'for r in rows))

    def test_cli_accepts_a_genuine_marker_only_continuation_and_says_no_samples(self):
        path=self.paths['clocked_paths'][1]
        # mkdtemp's private directory ACL is not readable by the Windows
        # sandbox's child token; keep the inspectable report in ignored build/.
        output=ROOT/'build'/('hive-cli-'+uuid.uuid4().hex+'.json')
        r=subprocess.run([sys.executable,str(ROOT/'scripts/analyze_capture.py'),path,
            '--summary-only','--json','--output',str(output)],
            cwd=ROOT,capture_output=True,text=True,encoding='utf-8')
        self.assertEqual(r.returncode,0,r.stderr)
        result=json.loads(r.stdout)
        self.assertFalse(result['capture_segment']['has_sample_records'])
        self.assertEqual(result['marker_annotations'][0]['key'],'=')
        self.assertEqual(result['marked_move_counts'],{'hive_lord_body_slam_emerging':1})


if __name__=='__main__':unittest.main()
