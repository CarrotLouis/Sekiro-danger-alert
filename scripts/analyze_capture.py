"""Summarize local capture evidence. Never infer an attack/lock from an F8 marker alone.

Reads JSONL only; no process access, network, memory writes or native game calls.
Output goes to the ignored outputs directory unless --output is supplied.
"""
from argparse import ArgumentParser
from collections import Counter
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def analyze(rows):
    events = Counter(r.get('event', 'unknown') for r in rows)
    start = next((r for r in rows if r.get('event') == 'capture_start'), {})
    stop = next((r for r in reversed(rows) if r.get('event') == 'capture_stop'), {})
    markers = [r['t'] for r in rows if r.get('event') == 'user_attack_mark']
    decisions = Counter()
    observations, transitions, previous, times, selected = [], [], {}, [], set()
    for r in rows:
        kind = r.get('event')
        if kind == 'targeting_sample':
            t = r.get('sample_t', r['t']); times.append(t)
            for state in r.get('states', []) or []:
                key = (state['entity'], state.get('unit'))
                selected.add(key)
                ai = state.get('ai') or {}
                observation = dict(t=t, entity=key[0], unit=key[1], class_name=state.get('class_name'),
                    distance=state.get('distance'), owned=state.get('owned'),
                    aim_target=state.get('aim_target'), aim_local=state.get('aim_target_is_local'),
                    entity_target_valid=state.get('entity_target_valid'), position_only=state.get('position_only'),
                    network_target=state.get('network_target'), network_flags=state.get('network_flags'),
                    resolved_network_target=state.get('resolved_network_target'),
                    network_target_consistent=state.get('network_target_consistent'),
                    ai_available=state.get('ai_available', bool(ai)), behavior=ai.get('behavior'),
                    stage=ai.get('stage'), pending_stage=ai.get('pending_stage'), ai_target=ai.get('target'),
                    ai_local=ai.get('target_is_local'), ai_has_target=ai.get('has_target'),
                    ai_tracks_entity=ai.get('tracks_entity'))
                observations.append(observation)
                signature = {k: v for k, v in observation.items() if k not in ('t', 'distance')}
                if previous.get(key) != signature:
                    transitions.append(observation); previous[key] = signature
        elif kind == 'detector_sample':
            t = r.get('sample_t', r['t']); times.append(t)
            for decision in r.get('decisions', []) or []:
                decisions[decision['reason']] += 1
                if decision['reason'] not in ('already_observed', 'late_sample'):
                    observations.append(dict(t=t, **decision))
    gaps = sorted(b - a for a, b in zip(times, times[1:]) if b >= a)
    return dict(mode=start.get('mode', 'legacy_crusher'), version=start.get('version'),
        duration_s=stop.get('t'), stop_reason=stop.get('reason'), event_counts=dict(events),
        marker_times=markers, observed_targeting_entities=len(selected), decision_sample_counts=dict(decisions),
        sample_gap_s=dict(max=max(gaps) if gaps else None, median=gaps[len(gaps)//2] if gaps else None),
        targeting_transitions=transitions,
        marker_windows=[dict(marker_t=t, start=t-4, end=t+1,
                             observations=[x for x in observations if t-4 <= x['t'] <= t+1]) for t in markers],
        limitations=['F8 is a delayed human marker, not a measured attack onset.',
            'AI target, replicated aim target and a committed attack are different states.',
            'No transitions does not prove no enemy: inspect heartbeat selection, queue and read errors.',
            'Decision counts are sample counts, not attack counts; legacy logs lack detector decisions.'])


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    result = analyze([json.loads(line) for line in args.capture.read_text(encoding='utf-8').splitlines() if line.strip()])
    target = args.output or ROOT / 'outputs' / (args.capture.stem + '-analysis.json')
    if target.resolve() == args.capture.resolve():
        parser.error('--output must not overwrite the capture')
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: result[k] for k in ['mode', 'version', 'duration_s', 'stop_reason',
        'event_counts', 'marker_times', 'observed_targeting_entities', 'sample_gap_s']}, ensure_ascii=False, indent=2))
    print(target)


if __name__ == '__main__':
    main()
