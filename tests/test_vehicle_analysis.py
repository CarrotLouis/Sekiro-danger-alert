"""Synthetic vehicle/variant evidence stays distinct from a verified warning fix."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import uuid

ROOT=Path(__file__).resolve().parents[1]
SCRIPT=ROOT/'scripts/analyze_capture.py'
spec=importlib.util.spec_from_file_location('vehicle_analysis',SCRIPT)
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
rows=[dict(event='capture_start',t=0,mode='combat',vehicle_scenario='bastion_gunner'),
    dict(event='research_sample',t=1,sample_t=1,states=[],abilities=[],
        vehicle=dict(status='seat_record',seat=dict(node=1),vehicle=dict(resource='hull',entity=30)),
        target_descriptions=[dict(entity=30,relation='current_seat_collection')],
        presentation_geometry=dict(head_projectable=False,reason='head behind camera')),
    dict(event='warning_output',t=1.1,source='manual_preview',visual_started=True,audio_request_succeeded=True),
    dict(event='presentation_state',t=1.2,playing=True,bitmap_present=False,anchor_status='head behind camera'),
    dict(event='vehicle_local_state',t=2,avatar_available=False,local_control=dict(player_avatar_handle=30)),
    dict(event='capture_stop',t=3,reason='fixture complete')]
report=module.analyze(rows)
assert report['vehicle']['seat_counts']=={'hull:1':1}
assert report['vehicle']['target_relation_counts']=={'current_seat_collection':1}
assert report['vehicle']['head_projection_counts']=={'False':1}
assert report['vehicle']['warning_outputs'][0]['source']=='manual_preview'
assert report['vehicle']['status_counts']['local_avatar_unavailable']==1
assert not report['vehicle']['presentation_transitions'][0]['bitmap_present']
assert module.analyze([dict(event='capture_start',t=0)])['vehicle']is None
markers=[dict(event='user_attack_mark',t=1,key='[',marked_move='hive_lord_bile_rain_sweeps',marked_control='hive_lord_bile_rain'),
    dict(event='user_attack_mark',t=2,key=']',marked_move='hive_lord_bile_rain_stream',marked_control='hive_lord_bile_rain')]
assert module.analyze(markers)['marked_control_counts']=={'hive_lord_bile_rain':2}
folder=ROOT/'build/test_logs';folder.mkdir(exist_ok=True)
stem='vehicle-analysis-'+uuid.uuid4().hex
path=folder/(stem+'.jsonl');output=folder/(stem+'.json')
# Even if the production avatar gate rejects a vehicle phase, the independent
# local-player slot observation is useful evidence and must remain inspectable.
path.write_text('\n'.join(json.dumps(r)for r in [rows[0],rows[4],rows[-1]])+'\n',encoding='utf-8')
r=subprocess.run([sys.executable,str(SCRIPT),str(path),'--output',str(output),'--summary-only','--json'],
    cwd=ROOT,capture_output=True,text=True,encoding='utf-8')
assert r.returncode==0,r.stdout+r.stderr
summary=json.loads(r.stdout)
assert summary['vehicle']['sample_count']==0 and not summary['capture_segment']['has_sample_records']
assert summary['vehicle']['status_counts']=={'local_avatar_unavailable':1}
print('PASS vehicle report separates user labels, observed seat/target, local-avatar failure, preview/output and projection; Bile Rain variants group by final control')
