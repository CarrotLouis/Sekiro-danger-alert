"""Compare 0.8.2 and current factory discovery with real reads of owned buffers.

Requires Windows and HD2_LUA51_DLL. No game process is opened or started.
Only ignored build/ and outputs/ reports are written. This is a microbenchmark,
not an in-game frame-time or FPS measurement. --help performs no writes.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]
BASELINE='9a157976fb29d3be312a053395ba86579b752e16'


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--json',action='store_true')
    args=parser.parse_args()
    try:
        dll=Path(os.environ.get('HD2_LUA51_DLL',''))
        if os.name!='nt' or not dll.is_file():
            raise ValueError('Set HD2_LUA51_DLL to the installed game Lua DLL on Windows')
        command=['git','-c','safe.directory='+ROOT.as_posix()]
        sha=subprocess.check_output(command+['rev-parse',BASELINE],cwd=ROOT).decode().strip()
        native=subprocess.check_output(command+['show',sha+':src/native.lua'],cwd=ROOT)
        baseline=ROOT/'build/performance-baseline';baseline.mkdir(parents=True,exist_ok=True)
        (baseline/'native.lua').write_bytes(native)
        result=subprocess.run([sys.executable,'-X','utf8',str(ROOT/'vendor/game_lua.py'),
            str(ROOT/'scripts/benchmark_release.lua'),str(ROOT),str(baseline)],cwd=ROOT,
            capture_output=True,text=True,encoding='utf-8')
        if result.returncode:
            raise ValueError(result.stderr or result.stdout)
        cases=[]
        for line in result.stdout.splitlines():
            if line.startswith('RESULT '):
                _,count,old,new,reads,size=line.split()[:6]
                old,new=float(old),float(new)
                cases.append(dict(actors=int(count),baseline_ms=old,current_ms=new,reads_per_poll=float(reads),
                    bytes_per_poll=float(size),cpu_reduction_percent=(1-new/old)*100,
                    current_ms_per_second_at_20hz=new*20))
        if len(cases)!=4 or 'PASS baseline-equivalent'not in result.stdout:
            raise ValueError('missing benchmark cases or equivalence checks')
        report=dict(ok=True,baseline_commit=sha,baseline_native_sha256=hashlib.sha256(native).hexdigest(),
            current_native_sha256=hashlib.sha256((ROOT/'src/native.lua').read_bytes()).hexdigest(),
            scope='factory discovery; real ReadProcessMemory on synthetic owned buffers; seven-trial median',
            live_game_measured=False,cases=cases,
            limits='Excludes full AI/ability processing, game contention, rendering and GPU/driver costs; not an FPS result.')
        output=ROOT/'outputs/Sekiro danger alert 1.0.0 Performance.json'
        output.parent.mkdir(parents=True,exist_ok=True)
        output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
        report['report_path']=str(output)
        print(json.dumps(report,indent=None if args.json else 2))
        return 0
    except (OSError,ValueError,subprocess.CalledProcessError) as exc:
        print('FAIL performance comparison: '+str(exc),file=sys.stderr)
        if args.json:print(json.dumps(dict(ok=False,error=str(exc))))
        return 2


if __name__=='__main__':
    raise SystemExit(main())
