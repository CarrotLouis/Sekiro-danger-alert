"""Summarize local capture evidence. Never infer an attack/lock from an F8 marker alone.

Reads JSONL only; no process access, network, memory writes or native game calls.
Output goes to the ignored outputs directory unless --output is supplied.
"""
from argparse import ArgumentParser
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
REPORT_KIND = 'Sekiro danger alert capture analysis'


def research_summary(rows):
    """Compact schema-2 evidence; timestamps stay local to this capture.

    Added after the 2026-10-15 paired Dragon captures: a peer's processed target
    can be stale throughout a dive. An input or post-shot timer is not a
    pre-shot commitment. Changing floating-point timers must not make every
    sample a structural transition. No raw buffers are copied into this summary.
    """
    dragon, cannon = '960b48a421a3faaa', '843d18d4b5512b63'
    actors, previous, transitions, dives, preparations = {}, {}, [], [], []
    current_dives, current_preparations, last_abilities = {}, {}, {}
    errors = Counter()
    sample_times = []
    for line, row in enumerate(rows, 1):
        if row.get('event') != 'research_sample':
            continue
        t = row.get('sample_t', row['t'])
        sample_times.append(t)
        abilities = {a['entity']: a for a in row.get('abilities', []) or []}
        for state in row.get('states', []) or []:
            errors.update((state.get('observation_errors') or {}).keys())
            resource = state.get('resource')
            if resource not in (dragon, cannon):
                continue
            key = (state['entity'], state.get('unit'), state.get('network_id'), state.get('owned'))
            actor = actors.setdefault(key, dict(entity=key[0], unit=key[1], network_id=key[2],
                owned=key[3], resource=resource, samples=0, channels={}))
            actor['samples'] += 1
            for channel in ('ai', 'aim', 'weapon_inputs', 'projectile_state',
                    'flight_network_state', 'behavior_network_state'):
                if state.get(channel):
                    actor['channels'][channel] = actor['channels'].get(channel, 0) + 1
            ai, aim = state.get('ai') or {}, state.get('aim') or {}
            behavior = ai if state.get('owned') else (state.get('replicated_behavior')
                or state.get('behavior_network_state') or {})
            stage, ability = behavior.get('stage'), abilities.get(state['entity'], {})
            target = ai.get('target') if state.get('owned') else None
            inputs, projectile = state.get('weapon_inputs') or {}, state.get('projectile_state') or {}
            mask, timer = inputs.get('replicated_input_bits'), projectile.get('fire_gate_timer')
            point = dict(t=t, line=row.get('_source_line', line), entity=key[0], network_id=key[2],
                owned=key[3], stage=stage, ability=ability.get('id'), active=ability.get('active'),
                preparation_ready=behavior.get('preparation_ready'),
                authoritative_ai_target=target, network_target=aim.get('network_target'),
                aim_flags=aim.get('network_flags'), input_mask=mask,
                projectile_state=projectile.get('state_bytes'), projectile_effect=projectile.get('effect_bytes'))
            signature = {k: v for k, v in point.items() if k not in ('t', 'line')}
            if previous.get(key) != signature:
                transitions.append(point)
                previous[key] = signature
            if resource == dragon:
                old_ability = last_abilities.get(key, {})
                active = ability.get('id') == 254 and ability.get('active') is True
                reset = ability.get('time', 0) < old_ability.get('time', 0) - .1
                if active and (not (old_ability.get('id') == 254 and old_ability.get('active')) or reset):
                    cycle = dict(entity=key[0], network_id=key[2], owned=key[3], first_sample=t,
                        first_line=point['line'], first_clock=ability.get('time'),
                        initial_partial=actor['samples'] == 1 or ability.get('time', 0) > .2,
                        stage6_targets=[], cue_samples=[], ended=False)
                    dives.append(cycle)
                    current_dives[key] = cycle
                cycle = current_dives.get(key)
                if cycle:
                    if active:
                        cycle['last_sample'] = t
                        if stage == 6 and target is not None and target not in cycle['stage6_targets']:
                            cycle['stage6_targets'].append(target)
                        if stage != 6 and 'stage6_end' not in cycle:
                            cycle['stage6_end'] = t
                        clock = ability.get('time', 0)
                        if 1 <= clock <= 1.2:
                            cycle['cue_samples'].append(dict(t=t, line=point['line'], ability_time=clock,
                                authoritative_ai_target=target, network_target=aim.get('network_target'),
                                aim_flags=aim.get('network_flags'), avatar_network=row.get('avatar_network')))
                    else:
                        cycle['ended'] = True
                        if ability.get('id') == 252 and ability.get('active') is True:
                            cycle['next_hover'] = dict(t=t, authoritative_ai_target=target)
                            del current_dives[key]
                last_abilities[key] = ability
            else:
                cycle = current_preparations.get(key)
                if stage != 3:
                    if cycle:
                        cycle.update(closed=True, end=t)
                        del current_preparations[key]
                    continue
                if cycle is None:
                    cycle = dict(entity=key[0], network_id=key[2], owned=key[3], start=t,
                        first_line=point['line'], initial_partial=actor['samples'] == 1,
                        closed=False, samples=0, projectile_samples_before_input=0,
                        first_ready=None, first_input=None, first_positive_timer=None,
                        timer_before_input=[], _projectile_variants=set())
                    preparations.append(cycle)
                    current_preparations[key] = cycle
                cycle['samples'] += 1
                cycle['last_sample'] = t
                if cycle['first_ready'] is None and behavior.get('preparation_ready') is True:
                    cycle['first_ready'] = t
                if cycle['first_input'] is None and mask is not None and (int(mask) & 7) in (1, 4):
                    cycle['first_input'] = t
                    cycle['first_input_line'] = point['line']
                if timer is not None and timer > 0 and cycle['first_positive_timer'] is None:
                    cycle['first_positive_timer'] = t
                if cycle['first_input'] is None:
                    if timer is not None:
                        cycle['timer_before_input'].append(timer)
                    if projectile.get('raw_hex'):
                        cycle['projectile_samples_before_input'] += 1
                        cycle['_projectile_variants'].add(projectile['raw_hex'])
    for cycle in preparations:
        timers, variants = cycle.pop('timer_before_input'), cycle.pop('_projectile_variants')
        cycle['timer_before_input_range'] = [min(timers), max(timers)] if timers else None
        cycle['projectile_variants_before_input'] = len(variants) if cycle['projectile_samples_before_input'] else None
        cycle['input_observed'] = cycle['first_input'] is not None
    gaps = sorted(b - a for a, b in zip(sample_times, sample_times[1:]) if b >= a)
    return dict(actors=list(actors.values()), observation_errors=dict(errors),
        sample_gap_s=dict(median=gaps[len(gaps)//2] if gaps else None, max=max(gaps) if gaps else None),
        structural_transitions=transitions, dragon_dives=dives, factory_preparations=preparations,
        limitations=['No automatic cross-PC clock alignment or entity-ID matching.',
            'Only network identity is shared; a stage/cycle correspondence still needs review.',
            'Single current AI targets do not prove an attack cannot damage multiple players.',
            'A zero timer and unchanged sampled bytes do not exclude a sub-sample state.',
            'Input observed is not an independently timed projectile or a guaranteed future shot.'])


def analyze(rows, excluded_markers=()):
    events = Counter(r.get('event', 'unknown') for r in rows)
    start = next((r for r in rows if r.get('event') == 'capture_start'), {})
    stop = next((r for r in reversed(rows) if r.get('event') == 'capture_stop'), {})
    all_markers = [r['t'] for r in rows if r.get('event') == 'user_attack_mark']
    excluded = set(excluded_markers)
    if any(i < 1 or i > len(all_markers) for i in excluded):
        raise ValueError('--exclude-marker must name an existing one-based marker')
    markers = [t for i, t in enumerate(all_markers, 1) if i not in excluded]
    decisions = Counter()
    observations, transitions, previous, times, selected = [], [], {}, [], set()
    runs, active_runs = [], {}
    for r in rows:
        kind = r.get('event')
        if kind in ('targeting_sample', 'research_sample'):
            t = r.get('sample_t', r['t']); times.append(t)
            for state in r.get('states', []) or []:
                key = (state['entity'], state.get('unit'))
                selected.add(key)
                ai = state.get('ai') or {}
                aim = state.get('aim') or state
                observation = dict(t=t, entity=key[0], unit=key[1], class_name=state.get('class_name'),
                    distance=state.get('distance'), owned=state.get('owned'),
                    resource=state.get('resource'), weapon_inputs=state.get('weapon_inputs'),
                    aim_target=aim.get('aim_target'), aim_local=aim.get('aim_target_is_local'),
                    entity_target_valid=aim.get('entity_target_valid'), position_only=aim.get('position_only'),
                    network_target=aim.get('network_target'), network_flags=aim.get('network_flags'),
                    resolved_network_target=aim.get('resolved_network_target'),
                    network_target_consistent=aim.get('network_target_consistent'),
                    ai_available=state.get('ai_available', bool(ai)), behavior=ai.get('behavior'),
                    stage=ai.get('stage'), pending_stage=ai.get('pending_stage'), ai_target=ai.get('target'),
                    ai_local=ai.get('target_is_local'), ai_has_target=ai.get('has_target'),
                    ai_tracks_entity=ai.get('tracks_entity'))
                observations.append(observation)
                signature = {k: v for k, v in observation.items() if k not in ('t', 'distance')}
                if previous.get(key) != signature:
                    transitions.append(observation); previous[key] = signature
            current_runs = {}
            states = {s['entity']: s for s in r.get('states', []) or []}
            for ability in r.get('abilities', []) or []:
                state = states.get(ability['entity'], {})
                key = (ability['entity'], state.get('unit'), ability['slot'])
                run = active_runs.get(key)
                if not run or run['ability'] != ability['id'] or ability['time'] < run['last_clock'] - .1:
                    speed = ability.get('speed', 0)
                    run = dict(entity=key[0], unit=key[1], slot=key[2], ability=ability['id'],
                        first_sample=t, first_clock=ability['time'],
                        estimated_start=t-ability['time']/speed if speed > 0 else None,
                        class_name=state.get('class_name'), owned=state.get('owned'),
                        initial_ai=state.get('ai'), samples=0)
                    runs.append(run)
                run.update(last_sample=t, last_clock=ability['time'], samples=run['samples']+1)
                current_runs[key] = run
            active_runs = current_runs
        elif kind == 'detector_sample':
            t = r.get('sample_t', r['t'])
            if start.get('mode') not in ('targeting', 'combat'): times.append(t)
            for decision in r.get('decisions', []) or []:
                decisions[decision['reason']] += 1
                if decision['reason'] not in ('already_observed', 'late_sample'):
                    observations.append(dict(t=t, **decision))
        elif kind == 'animation_change':
            observations.append(dict(t=r['t'], source='animation', entity=r.get('entity'),
                unit=r.get('unit'), resource=r.get('resource'), animation_states=r.get('states')))
    gaps = sorted(b - a for a, b in zip(times, times[1:]) if b >= a)
    return dict(report_kind=REPORT_KIND, mode=start.get('mode', 'legacy_crusher'), version=start.get('version'),
        research_schema=start.get('research_schema'), capture_stopped=bool(stop),
        requested_move=start.get('requested_move'), capture_context=start.get('capture_context'),
        duration_s=stop.get('t'), stop_reason=stop.get('reason'), event_counts=dict(events),
        marker_times=markers, observed_targeting_entities=len(selected), decision_sample_counts=dict(decisions),
        excluded_markers=[dict(index=i, t=all_markers[i-1]) for i in sorted(excluded)],
        research=research_summary(rows),
        sample_gap_s=dict(max=max(gaps) if gaps else None, median=gaps[len(gaps)//2] if gaps else None),
        targeting_transitions=transitions, ability_runs=runs,
        marker_ability_context=[dict(marker_t=t, candidates=[dict(entity=x['entity'], ability=x['ability'],
            first_sample=x['first_sample'], estimated_start=x['estimated_start'],
            marker_after_estimated_start=t-x['estimated_start'] if x['estimated_start'] is not None else None)
            for x in runs if x['first_sample'] <= t <= x['last_sample']+2]) for t in markers],
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
    parser.add_argument('--json', action='store_true', help='Print a machine-readable compact report')
    parser.add_argument('--summary-only', action='store_true', help='Omit raw observations and marker windows from output')
    parser.add_argument('--exclude-marker', type=int, action='append', default=[], help='One-based known mistaken F8; repeatable')
    parser.add_argument('--replace-output', action='store_true', help='Allow replacing an analysis report, never a capture')
    args = parser.parse_args()
    def finite_float(value):
        number = float(value)
        if not math.isfinite(number):
            raise ValueError('non-finite JSON number')
        return number
    def invalid_constant(value):
        raise ValueError('non-finite JSON number: ' + value)
    target = args.output or ROOT / 'outputs' / (args.capture.stem + '-analysis.json')
    try:
        if target.resolve() == args.capture.resolve() or target.suffix.lower() != '.json':
            raise ValueError('--output must be an analysis report, never a capture')
        if target.exists() and args.capture.exists() and target.samefile(args.capture):
            raise ValueError('--output aliases the capture')
        if target.exists() and args.replace_output:
            with target.open('rb') as stream:
                old = stream.read(64 * 1024 * 1024 + 1)
            if len(old) > 64 * 1024 * 1024 or json.loads(old).get('report_kind') != REPORT_KIND:
                raise ValueError('--replace-output refuses an unrecognized file; choose a new report path')
        with args.capture.open('rb') as stream:
            raw = stream.read(64 * 1024 * 1024 + 1)
        if len(raw) > 64 * 1024 * 1024:
            raise ValueError('capture exceeds 64 MiB analysis limit')
        rows = []
        for line, text in enumerate(raw.decode('utf-8-sig').splitlines(), 1):
            if text.strip():
                try:
                    row = json.loads(text, parse_constant=invalid_constant, parse_float=finite_float)
                    if not isinstance(row, dict) or 'event' not in row:
                        raise ValueError('expected event object')
                    rows.append(dict(row, _source_line=line))
                except ValueError as exc:
                    raise ValueError(f'line {line}: {exc}') from exc
        if not rows or rows[0].get('event') != 'capture_start' or not any(
                r.get('event') in ('research_sample', 'targeting_sample', 'detector_sample') for r in rows):
            raise ValueError('no usable capture/sample records')
        result = analyze(rows, args.exclude_marker)
        summary = {k: result[k] for k in ['report_kind', 'mode', 'version', 'research_schema', 'capture_stopped', 'duration_s', 'stop_reason',
            'event_counts', 'marker_times', 'excluded_markers', 'observed_targeting_entities', 'sample_gap_s', 'research']}
        payload = summary if args.summary_only else result
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open('w' if args.replace_output else 'x', encoding='utf-8', newline='\n') as stream:
            stream.write(json.dumps(payload, ensure_ascii=False, indent=2) + '\n')
        summary.update(ok=True, input=dict(path=str(args.capture.resolve()), bytes=len(raw),
            sha256=hashlib.sha256(raw).hexdigest()), output=str(target.resolve()))
        print(json.dumps(summary, ensure_ascii=args.json, indent=None if args.json else 2))
        return 0
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as exc:
        message = f'{args.capture}: {exc}'
        print('FAIL capture analysis: ' + message, file=sys.stderr)
        if args.json:
            print(json.dumps(dict(ok=False, error=message)))
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
