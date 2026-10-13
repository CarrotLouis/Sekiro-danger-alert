"""Run each offline test in a fresh process using the installed game's LuaJIT."""
import argparse
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mom-source', type=Path, required=True)
    args = parser.parse_args()
    dll = os.environ.get('HD2_LUA51_DLL')
    if not dll or not Path(dll).is_file():
        parser.error('Set HD2_LUA51_DLL to the installed game bin/lua51.dll')
    if not (args.mom_source / 'src/mod_options_menu.lua').is_file():
        parser.error('--mom-source must point to a ModOptionsMenu source checkout')
    (ROOT / 'build/test_logs').mkdir(parents=True, exist_ok=True)
    for test in sorted((ROOT / 'tests').glob('test_*.lua')):
        command = [sys.executable, str(ROOT / 'vendor/game_lua.py'), str(test), str(ROOT)]
        if test.name == 'test_menu.lua':
            command.append(str(args.mom_source.resolve()))
        print(test.name, flush=True)
        subprocess.run(command, check=True, cwd=ROOT)

if __name__ == '__main__':
    main()
