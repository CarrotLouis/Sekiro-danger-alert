"""Build the independent test addon; no deployment or live game calls.

Required: Python 3 and HD2_LUA51_DLL pointing at the installed game's LuaJIT DLL.
Source gates and offline checks run before creating a ZIP. --validate-only creates no ZIP.
"""
from pathlib import Path
import argparse,hashlib,json,os,re,subprocess,sys,uuid,zipfile
ROOT=Path(__file__).resolve().parents[2]
MOD=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'vendor'))
from hd2_archive import LUA_TYPE,make_archive,lua_resource,read_archive,resource_hash

def lua(value):
    if isinstance(value,str):return json.dumps(value,ensure_ascii=False)
    if isinstance(value,bool):return 'true'if value else'false'
    if isinstance(value,dict):return '{'+','.join('['+lua(k)+']='+lua(v)for k,v in value.items())+'}'
    if isinstance(value,list):return '{'+','.join(lua(v)for v in value)+'}'
    if value is None:return 'nil'
    return str(int(value))if isinstance(value,float)and value.is_integer()else str(value)

def module(path):return '(function()\n'+path.read_text(encoding='utf-8')+'\nend)()'

def encode_profile(native):
    # Config contains only build-relative facts, never live pointers or game files.
    native=dict(native)
    # Binary code pins need decimal byte escapes (UTF-8 would corrupt bytes above 127).
    pins=native.pop('pins')
    encoded=lua(native)
    encoded=encoded[:-1]+',["pins"]={'+','.join('{module='+lua(p['module'])+',rva='+str(p['rva'])+
        ',label='+lua(p['label'])+',bytes="'+''.join('\\%03d'%b for b in bytes.fromhex(p['hex']))+'"}'
        for p in pins)+'}}'
    return encoded

def assemble(project,catalog,native,peer):
    files=[('runtime',ROOT/'vendor/bingus_runtime.lua'),('memory_module',ROOT/'vendor/bingus_memory.lua'),
        ('profile',ROOT/'src/profile.lua'),('core_module',ROOT/'src/native.lua'),
        ('menu_module',MOD/'src/menu.lua'),('native_module',MOD/'src/native.lua'),
        ('controller_module',MOD/'src/controller.lua'),('channel_module',MOD/'src/channel.lua'),
        ('remote_module',MOD/'src/remote.lua')]
    chunks=['-- HD2-Addon: '+project['resource']+'\n',
        "if rawget(_G,'SekiroDangerAlertEnemySpawner') then return rawget(_G,'SekiroDangerAlertEnemySpawner') end\n",
        'local project='+lua(project)+'\n','local catalog='+lua(catalog)+'\n','local spawn_profile='+encode_profile(native)+'\n',
        'local peer_profile='+encode_profile(peer)+'\n']
    for name,path in files:chunks.append('local '+name+'='+module(path)+'\n')
    chunks.append((MOD/'src/entry.lua').read_text(encoding='utf-8'))
    pre=''.join(chunks);build_id=hashlib.sha256(pre.encode()).hexdigest()[:12]
    chunks.insert(2,'local build_id='+lua(build_id)+'\n')
    return ''.join(chunks).encode('utf-8'),build_id

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--validate-only',action='store_true')
    parser.add_argument('--mom-source',type=Path,default=ROOT/'work/ModOptionsMenu')
    parser.add_argument('--output-dir',type=Path,default=ROOT/'outputs')
    args=parser.parse_args()
    dll=os.environ.get('HD2_LUA51_DLL')
    if not dll or not Path(dll).is_file():parser.error('Set HD2_LUA51_DLL to the installed game bin/lua51.dll')
    if not(args.mom_source/'src/mod_options_menu.lua').is_file():parser.error('--mom-source must be a ModOptionsMenu checkout')
    project=json.loads((MOD/'project.json').read_text(encoding='utf-8'))
    uuid.UUID(project['guid'])
    owner=json.loads((ROOT/'project.json').read_text(encoding='utf-8'))
    assert project['guid']!=owner['guid']and project['resource']!=owner['resource'],'companion identity collision'
    assert re.fullmatch(r'mods/[A-Za-z0-9_]+/[A-Za-z0-9_/]+',project['resource'])
    catalog=json.loads((MOD/'config/enemies.json').read_text(encoding='utf-8'))
    native=json.loads((MOD/'config/native.json').read_text(encoding='utf-8'))
    peer=json.loads((MOD/'config/peer_channel.json').read_text(encoding='utf-8'))
    entry,build_id=assemble(project,catalog,native,peer)
    assert not entry.startswith(b'\xef\xbb\xbf')and b'\0'not in entry,'source encoding refused'
    assert not re.search(rb'WriteProcessMemory|VirtualProtect|CreateRemoteThread',entry),'memory writing is refused'
    guide=re.search(r'local GUIDE=\[===\[(.*?)\]===\]',entry.decode('utf-8'),re.S)
    assert guide,'missing embedded guide'
    build=ROOT/'build/enemy_spawner';build.mkdir(parents=True,exist_ok=True)
    source=build/'Sekiro danger alert - Enemy Spawner.lua';source.write_bytes(entry)
    compile_script=build/'compile.lua'
    compile_script.write_text("local f=assert(io.open(arg[1],'rb'));local s=f:read('*a');f:close();assert(loadstring(s));print('PASS packaged LuaJIT compile')",encoding='utf-8')
    subprocess.run([sys.executable,str(ROOT/'vendor/game_lua.py'),str(compile_script),str(source)],check=True,cwd=ROOT)
    subprocess.run([sys.executable,str(ROOT/'tests/test_spawner_catalog.py')],check=True,cwd=ROOT)
    subprocess.run([sys.executable,str(ROOT/'vendor/game_lua.py'),str(ROOT/'tests/test_spawner.lua'),str(ROOT)],check=True,cwd=ROOT)
    subprocess.run([sys.executable,str(ROOT/'vendor/game_lua.py'),str(ROOT/'tests/test_spawner_remote.lua'),str(ROOT)],check=True,cwd=ROOT)
    subprocess.run([sys.executable,str(ROOT/'vendor/game_lua.py'),str(ROOT/'tests/test_spawner_channel.lua'),str(ROOT)],check=True,cwd=ROOT)
    subprocess.run([sys.executable,str(ROOT/'vendor/game_lua.py'),str(ROOT/'tests/test_spawner_entry.lua'),str(ROOT)],check=True,cwd=ROOT)
    subprocess.run([sys.executable,str(ROOT/'vendor/game_lua.py'),str(ROOT/'tests/test_spawner_menu.lua'),str(ROOT),str(args.mom_source.resolve())],check=True,cwd=ROOT)
    if args.validate_only:print('PASS Enemy Spawner source gates and offline checks');return
    archive=make_archive({resource_hash(project['resource']):lua_resource(entry)})
    assert read_archive(archive)=={(LUA_TYPE,resource_hash(project['resource'])):(lua_resource(entry),b'')}
    description=('Independent host/client-request enemy test spawner for Sekiro danger alert; 24 entries, '
        'including two experimental solo-only Gazer weapon cores. '
        'host-authoritative creation, both peers need this version; native package loading and one-shot menu action. Impaler requires difficulty 5–10 and eligible tentacles. '
        'Requires Bingus Shared Loader v18+ and ModOptionsMenu v1.2. '
        'Uses code / research from HD2Runtime by SkyeShade https://github.com/SkyeShade/HD2Runtime')
    manifest={'Version':1,'Guid':project['guid'],'Name':project['name']+' '+project['version'],
        'Description':description,'Options':[{'Name':project['name'],'Description':description,'Include':['Addon']}]}
    prefix='Addon/9ba626afa44a3aa3.patch_0'
    files={'manifest.json':json.dumps(manifest,ensure_ascii=False,indent=2).encode('utf-8'),prefix:archive,
        prefix+'.stream':b'',prefix+'.gpu_resources':b'','README.txt':guide.group(1).strip().replace('\n','\r\n').encode('utf-8'),
        'CREDITS.txt':(ROOT/'CREDITS.txt').read_bytes(),
        'HD2Runtime-LICENSE.txt':(ROOT/'vendor/HD2Runtime-LICENSE.txt').read_bytes(),
        'Bingus-LICENSE.txt':(ROOT/'vendor/Bingus-LICENSE.txt').read_bytes()}
    assert not any(Path(n).suffix.lower()in{'.bat','.cmd','.ps1','.dll','.exe','.js','.vbs'}for n in files)
    args.output_dir.mkdir(parents=True,exist_ok=True)
    target=args.output_dir/(project['name']+' '+project['version']+'.zip')
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED)as z:
        for name,data in sorted(files.items()):
            info=zipfile.ZipInfo(name,date_time=(2026,10,14,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;z.writestr(info,data)
    with zipfile.ZipFile(target)as z:
        assert z.read(prefix)==archive and json.loads(z.read('manifest.json'))==manifest
        assert z.read('README.txt')and z.read(prefix+'.stream')==b''and z.read(prefix+'.gpu_resources')==b''
    report={'version':project['version'],'build':build_id,'guid':project['guid'],'resource':project['resource'],
        'enemy_count':len(catalog['enemies']),'package':str(target.resolve()),'size':target.stat().st_size,
        'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'live_verified':False}
    (build/'build-report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False))

if __name__=='__main__':main()
