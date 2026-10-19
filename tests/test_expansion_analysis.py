"""Regressions from October 19: cached abilities and delayed F8 are not charges."""
from pathlib import Path
import importlib.util
import json
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('capture_analysis', ROOT/'scripts/analyze_capture.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
CHARGER, RUPTURE = '1a7fcdff98c664b0', 'a381a11c07d3eb94'


def sample(t, ability=222, clock=0, active=True, unit=8, target=7, owned=True, fire=0, resource=CHARGER):
    return dict(event='research_sample', t=t, avatar_entity=7,
        states=[dict(entity=3, unit=unit, owned=owned, resource=resource, distance=10-t,
            ai=dict(has_target=True, tracks_entity=True, target=target, raw_hex='private bytes'),
            weapon_inputs=dict(local_input_bytes=[fire, 0, 0, 0, 0]))],
        abilities=[dict(entity=3, id=ability, time=clock, active=active, paused=False, slot=9)])


class ExpansionAnalysis(unittest.TestCase):
    def test_inactive_rows_do_not_extend_a_charge_and_f8_does_not_create_one(self):
        rows = [sample(0), sample(.1, clock=.1), sample(.2, active=False, clock=.1),
            sample(.3, active=False, clock=.1), dict(event='user_attack_mark', t=.35),
            sample(.4), sample(.5, ability=225)]
        r = module.expansion_summary(rows)
        self.assertEqual([p['ability'] for p in r['active_periods']], [222, 222, 225])
        self.assertEqual(r['active_periods'][0]['last_sample'], .1)
        self.assertFalse(r['markers'][0]['prior_observation']['states'][0]['active'])
        self.assertNotIn('private bytes', json.dumps(r))
        self.assertEqual(r['target_samples'], {'local': 6})

    def test_lifecycle_clock_reset_and_gap_are_explicit(self):
        rows = [sample(0, clock=1), sample(.1, clock=1.1), sample(.2, clock=0),
            sample(.3, clock=.1, unit=80), sample(1, clock=.8, unit=80)]
        p = module.expansion_summary(rows)['active_periods']
        self.assertEqual(len(p), 4)
        self.assertTrue(p[0]['initial_partial'])
        self.assertTrue(p[1]['discontinuity'])
        self.assertNotEqual(p[1]['actor'], p[2]['actor'])
        self.assertTrue(p[3]['discontinuity'])

    def test_fire_input_and_other_target_do_not_become_impact_or_local_lock(self):
        rows = [sample(0, ability=187, resource=RUPTURE),
            sample(.1, ability=187, clock=.1, resource=RUPTURE, fire=1, target=70),
            sample(.2, ability=187, clock=.2, resource=RUPTURE, fire=1, target=70),
            dict(event='user_attack_mark', t=.25)]
        r = module.expansion_summary(rows)
        p = r['active_periods'][0]
        self.assertEqual(p['target_samples'], {'local': 1, 'other': 2})
        self.assertEqual(len(p['input_onsets']), 1)
        self.assertEqual(p['input_onsets'][0]['target'], 'other')
        self.assertEqual(r['markers'][0]['prior_observation']['states'][0]['target'], 'other')
        guest = module.expansion_summary([sample(0, owned=False)])
        self.assertEqual(guest['target_samples'], {'unknown': 1})

    def test_dense_manager_slot_move_does_not_split_a_cycle_or_replay_firing(self):
        rows = [sample(0, clock=2.3, fire=1), sample(.1, clock=2.4, fire=1)]
        rows[1]['abilities'][0]['slot'] = 19
        r = module.expansion_summary(rows)
        self.assertEqual(len(r['active_periods']), 1)
        self.assertEqual(r['active_periods'][0]['slot_changes'], 1)
        self.assertEqual(len(r['active_periods'][0]['input_onsets']), 1)

    def test_empty_unknown_and_time_reversal_are_not_silently_certified(self):
        self.assertFalse(module.expansion_summary([dict(event='user_attack_mark', t=0)])['actors'])
        self.assertFalse(module.expansion_summary([sample(0, resource='unknown')])['actors'])
        r = module.expansion_summary([sample(.2, clock=.2), sample(.1, clock=.1)])
        self.assertEqual(r['time_reversals'], 1)
        self.assertTrue(r['active_periods'][1]['discontinuity'])
        with self.assertRaises(ValueError):
            module.expansion_summary([sample(float('nan'))])


if __name__ == '__main__':
    unittest.main()
