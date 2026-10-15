"""Counterexamples from paired-capture research, with synthetic identities/buffers.

These test the offline report, not game targeting or a proposed warning fix.
"""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts/analyze_capture.py'
spec = importlib.util.spec_from_file_location('research_analysis', SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
DRAGON, CANNON = '960b48a421a3faaa', '843d18d4b5512b63'


def dragon_sample(t, stage, ability, active, clock, target, owned=True):
    return dict(event='research_sample', t=t, sample_t=t, avatar_network=20,
        states=[dict(entity=1, unit=2, network_id=3, resource=DRAGON, owned=owned,
            ai=dict(stage=stage if owned else 1, target=target if owned else 0),
            replicated_behavior=dict(stage=stage),
            aim=dict(network_target=21, network_flags=4))],
        abilities=[dict(entity=1, slot=5, id=ability, active=active, time=clock, speed=1)])


rows = [dict(event='capture_start', mode='combat', t=0)]
rows += [dragon_sample(*s) for s in [(0, 9, 252, False, 4, 7),
    (1, 6, 254, True, 0, 7), (2.05, 6, 254, True, 1.05, 7),
    (4, 7, 254, True, 3, 7), (5.4, 7, 254, False, 4.3, 8),
    (7, 7, 252, True, 0, 8)]]
rows += [dict(event='user_attack_mark', t=2.5), dict(event='user_attack_mark', t=4.5),
    dict(event='capture_stop', t=8, reason='test')]
result = module.analyze(rows, [2])
dives = result['research']['dragon_dives']
assert len(dives) == 1 and dives[0]['stage6_targets'] == [7]
assert dives[0]['next_hover']['authoritative_ai_target'] == 8
assert dives[0]['cue_samples'][0]['network_target'] == 21
assert dives[0]['cue_samples'][0]['aim_flags'] == 4
assert result['marker_times'] == [2.5] and result['excluded_markers'] == [dict(index=2, t=4.5)]
peer = module.research_summary([dragon_sample(1, 6, 254, True, 1.05, 7, owned=False)])
assert peer['dragon_dives'][0]['stage6_targets'] == []
assert peer['dragon_dives'][0]['cue_samples'][0]['authoritative_ai_target'] is None
assert peer['dragon_dives'][0]['initial_partial']
print('PASS dive and later hover targets, frozen peer aim, partial onset and excluded F8 remain distinct')


def factory_sample(t, stage, mask, timer, raw='0000'):
    projectile = dict(fire_gate_timer=timer, state_bytes=[int(timer > 0), 0, 0], effect_bytes=[0, 0, 0])
    if raw is not None:
        projectile['raw_hex'] = raw
    return dict(event='research_sample', t=t, sample_t=t, abilities=[],
        states=[dict(entity=9, unit=10, network_id=11, resource=CANNON, owned=True,
            ai=dict(stage=stage, target=7), weapon_inputs=dict(replicated_input_bits=mask),
            projectile_state=projectile)])


# Two flash/preparation intervals, one with input and a post-input timer, one without.
rows = [factory_sample(*s) for s in [(0, 2, 0, 0), (1, 3, 0, 0),
    (1.5, 3, 0, 0), (2, 3, 4684, .99), (2.1, 3, 4684, .89),
    (3, 2, 0, 0), (8, 3, 0, 0), (8.5, 3, 0, 0), (11, 2, 0, 0),
    (16, 3, 0, 0)]]
research = module.research_summary(rows)
first, second, tail = research['factory_preparations']
assert first['first_input'] == first['first_positive_timer'] == 2
assert first['timer_before_input_range'] == [0, 0] and first['projectile_variants_before_input'] == 1
assert second['closed'] and not second['input_observed']
assert not tail['closed'] and not tail['input_observed']
# A changing timer is sampled evidence, not a new structural event every frame.
assert not any(x['t'] == 2.1 for x in research['structural_transitions'])
missing = module.research_summary([factory_sample(0, 3, 0, 0, None)])
assert missing['factory_preparations'][0]['projectile_variants_before_input'] is None
assert missing['factory_preparations'][0]['initial_partial']
assert 'raw_hex' not in json.dumps(research)
print('PASS first input versus cooldown, closed no-input cycle, open tail and unavailable raw evidence')


temporary_root = (ROOT / 'build/test_logs').resolve()
temporary_root.mkdir(parents=True, exist_ok=True)
def check_cli():
    # Keep small test artifacts in the existing ignored test-log tree. Python's
    # mode-0700 TemporaryDirectory is unreadable in some Windows sandbox ACLs.
    folder = temporary_root / ('capture-analysis-' + uuid.uuid4().hex)
    folder.mkdir()
    assert folder.resolve().parent == temporary_root
    capture, output = folder / 'capture-\u91c7\u96c6.jsonl', folder / 'report.json'
    capture.write_text('\n'.join(json.dumps(x) for x in [dict(event='capture_start', mode='combat', t=0),
        factory_sample(0, 2, 0, 0), factory_sample(1, 3, 0, 0)]) + '\n', encoding='utf-8')
    before = capture.read_bytes()

    def cli(*args):
        return subprocess.run([sys.executable, '-X', 'utf8', str(SCRIPT), *map(str, args)],
            capture_output=True, text=True, encoding='utf-8', cwd=folder)

    assert cli('--help').returncode == 0 and list(folder.iterdir()) == [capture]
    run = cli(capture, '--output', output, '--json', '--summary-only')
    report = json.loads(run.stdout)
    assert run.returncode == 0 and report['ok'] and len(report['input']['sha256']) == 64
    assert 'marker_windows' not in json.loads(output.read_text(encoding='utf-8'))
    saved = output.read_bytes()
    assert cli(capture, '--output', output, '--json').returncode == 2
    assert output.read_bytes() == saved
    assert cli(capture, '--output', output, '--replace-output', '--summary-only', '--json').returncode == 0
    assert output.read_bytes() == saved
    assert cli(capture, '--output', capture, '--replace-output', '--json').returncode == 2
    assert capture.read_bytes() == before
    assert cli(capture, '--output', output, '--replace-output', '--exclude-marker', '1').returncode == 2
    assert output.read_bytes() == saved
    foreign = folder / 'unrelated.json'
    foreign.write_text('{"keep": true}', encoding='utf-8')
    assert cli(capture, '--output', foreign, '--replace-output', '--json').returncode == 2
    assert foreign.read_text(encoding='utf-8') == '{"keep": true}'
    bad = folder / 'bad.jsonl'
    bad.write_text('{broken JSON}\n', encoding='utf-8')
    run = cli(bad, '--output', folder / 'bad-report.json', '--json')
    assert run.returncode == 2 and not json.loads(run.stdout)['ok'] and 'line 1' in run.stderr
    assert not (folder / 'bad-report.json').exists()
    bad.write_text('{"event": "capture_start", "t": 1e999}\n', encoding='utf-8')
    assert cli(bad, '--output', folder / 'bad-report.json', '--json').returncode == 2
    run = cli(folder / 'absent.jsonl', '--output', output, '--json')
    assert run.returncode == 2 and not json.loads(run.stdout)['ok']


check_cli()
print('PASS CLI JSON/hash, side-effect-free help, invalid/missing input and capture/output preservation')
