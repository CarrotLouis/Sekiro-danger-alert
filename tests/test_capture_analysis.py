"""A selected target must remain distinct from a committed shot in the report."""
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('capture_analysis', ROOT / 'scripts/analyze_capture.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
rows = [{'event': 'capture_start', 't': 0, 'mode': 'targeting', 'version': 'test'}]
for t, target, valid, stage in [(0, 7, True, 2), (.1, 7, True, 2), (.2, 7, False, 2), (.3, 8, True, 3)]:
    rows.append(dict(event='targeting_sample', t=t, states=[dict(entity=1, unit=2, aim_target=target,
        aim_target_is_local=target == 7, entity_target_valid=valid, position_only=not valid,
        ai={'stage': stage}, distance=100)]))
rows += [dict(event='user_attack_mark', t=1.2), dict(event='capture_stop', t=2, reason='test')]
result = module.analyze(rows)
assert len(result['targeting_transitions']) == 3
assert len(result['marker_windows'][0]['observations']) == 4
assert result['targeting_transitions'][1]['aim_local'] and not result['targeting_transitions'][1]['entity_target_valid']
assert result['observed_targeting_entities'] == 1 and not result['decision_sample_counts']
print('PASS targeting analysis preserves delayed markers, position-only targets and raw stage transitions')

# Ability onsets are a separate timeline: a constant AI stage must not hide them.
samples = [dict(event='capture_start', mode='targeting', t=0)]
for t, clock in [(1, 0), (2.05, 1.05), (3.4, 2.4), (12, 0), (13.1, 1.1)]:
    samples.append(dict(event='targeting_sample', t=t,
        states=[dict(entity=1, unit=2, owned=True, ai={'stage': 1, 'target_is_local': True})],
        abilities=[dict(entity=1, id=1037, time=clock, speed=1, slot=55)]))
samples += [dict(event='user_attack_mark', t=13.6), dict(event='capture_stop', t=14)]
result = module.analyze(samples)
assert len(result['targeting_transitions']) == 1 and len(result['ability_runs']) == 2
assert result['ability_runs'][0]['samples'] == 3
assert abs(result['marker_ability_context'][0]['candidates'][0]['marker_after_estimated_start']-1.6) < 1e-9
print('PASS ability cycles and delayed marker context remain distinct from unchanged AI stages')
