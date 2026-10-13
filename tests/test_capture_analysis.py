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
