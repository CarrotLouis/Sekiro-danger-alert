"""Build the Bingus addon and its private compiled image families, without touching the game."""
from pathlib import Path
import argparse,hashlib,json,os,re,struct,subprocess,sys,wave,zipfile
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'vendor'))
from hd2_archive import resource_hash,lua_resource,make_resource_archive,read_archive,LUA_TYPE
from hd2_image import texture_main,bc1_mips,icon_material,TEXTURE_TYPE,MATERIAL_TYPE,read_png
from PIL import Image
from release_source import load_locales,without_comments

CONFIG=json.loads((ROOT/'project.json').read_text())
EFFECT=json.loads((ROOT/'assets/effect.json').read_text())
ARGS=argparse.ArgumentParser()
ARGS.add_argument('--output-dir',type=Path,default=ROOT/'outputs')
ARGS.add_argument('--diagnostics',action='store_true',help='Alternative package with bounded collection; same GUID, replace the normal package')
ARGS.add_argument('--next-attacks',action='store_true',help='Development-only collection catalog for the next attack expansion')
OPTIONS=ARGS.parse_args()
NEXT=None
if OPTIONS.next_attacks:
    if not OPTIONS.diagnostics:ARGS.error('--next-attacks requires --diagnostics; it never changes the ordinary release')
    NEXT=json.loads((ROOT/'config/expansion_v2.json').read_text(encoding='utf-8'))
    if not re.fullmatch(r'\d+\.\d+\.\d+-dev\.\d+',NEXT.get('version','')):
        ARGS.error('The next-attack catalog must name an explicit development version')
    if NEXT.get('steam_build')!='25480438':ARGS.error('The next-attack catalog is not for the reviewed game build')
    CONFIG={**CONFIG,'version':NEXT['version']}
if OPTIONS.diagnostics and int(CONFIG['version'].split('.')[0])>=1 and not OPTIONS.next_attacks:
    ARGS.error('The development variant is unavailable for release versions')
OUT=OPTIONS.output_dir.resolve();OUT.mkdir(parents=True,exist_ok=True)
OWNER=CONFIG['resource']
BUILD=ROOT/'build';BUILD.mkdir(exist_ok=True)

def lua_bytes(data):
    # A single escaped string per 4 KiB chunk, not a per-byte table/constructor.
    # No literal binary NUL in the discoverable Lua source.
    return 'table.concat({\n'+',\n'.join('"'+''.join('\\%03d'%b for b in data[i:i+4096])+'"'
        for i in range(0,len(data),4096))+'\n})'

def module(path):
    return '(function()\n'+path.read_text(encoding='utf-8')+'\nend)()'

def lua(value):
    if isinstance(value,str):return json.dumps(value,ensure_ascii=False)
    if isinstance(value,bool):return 'true' if value else 'false'
    if value is None:return 'nil'
    if isinstance(value,list):return '{'+','.join(lua(x) for x in value)+'}'
    if isinstance(value,dict):return '{'+','.join('['+lua(k)+']='+lua(v) for k,v in value.items())+'}'
    return str(value)

def masks():
    for n in range(EFFECT['frames']):
        target=ROOT/f'assets/frames/{n:03}.png'
        if not target.is_file():raise FileNotFoundError('Restore assets/frames or import the approved R2 sequence')

def profile():
    crusher='content/fac_illuminate/cha_bodyhorror_helmetguy/cha_bodyhorror_helmetguy'
    pins=[('exe',2873456,'488d4160c3','unit scene graph'),
          ('exe',6235350,'488b2c02','resource slot'),
          ('exe',1475261,'c70133832ad9','material object'),
          ('exe',0x1fe5ff,'448b4210','scene graph node count'),
          ('exe',0x1fe608,'488b5240','scene graph node names'),
          ('exe',0x30d980,'f30f104134c3','camera field of view'),
          ('game',0x12f55c3,'4c8b0d967f1702','camera manager global'),
          ('game',0x127a18c,'0f11430c','camera cached right'),
          ('game',0x127a194,'0f114b1c','camera cached forward'),
          ('game',0x127a19c,'0f11432c','camera cached up'),
          ('game',0x127a1ab,'0f114b3c','camera cached position')]
    rows=["{module='%s',rva=%d,bytes=%s,label='%s'}"%(m,r,lua_bytes(bytes.fromhex(b)),label) for m,r,b,label in pins]
    targeting=json.loads((ROOT/'config/targeting_probe.json').read_text())
    target_rows=["{rva=%d,bytes=%s,label='%s'}"%(p['rva'],lua_bytes(bytes.fromhex(p['hex'])),p['label'])
                 for p in targeting['pins']]
    target_resources=["['%s']='%s'"%(r['hash'],r['name']) for r in targeting['resources']]
    attacks=json.loads((ROOT/'config/attack_probe.json').read_text())
    attack_rows=["{rva=%d,bytes=%s,label='%s'}"%(p['rva'],lua_bytes(bytes.fromhex(p['hex'])),p['label'])
                 for p in attacks['pins']]
    peer=json.loads((ROOT/'config/peer_sync.json').read_text(encoding='utf-8'))
    peer_rows=["{rva=%d,bytes=%s,label='%s'}"%(p['rva'],lua_bytes(bytes.fromhex(p['hex'])),p['label'])
               for p in peer['pins']]
    cannon='{'+','.join(k+'='+ ("'%s'"%v if isinstance(v,str) else str(v)) for k,v in attacks['cannon'].items())+'}'
    combat=json.loads((ROOT/'config/combat_probe.json').read_text())
    combat_rows=["{rva=%d,bytes=%s,label='%s'}"%(p['rva'],lua_bytes(bytes.fromhex(p['hex'])),p['label']) for p in combat['pins']]
    expanded=json.loads((ROOT/'config/expanded_attacks.json').read_text(encoding='utf-8'))
    expanded.pop('source');expanded.pop('build')
    expanded_pins=expanded.pop('pins');expanded['ids']={}
    for rules in expanded['resources'].values():
        for key in ('abilities','excluded'):
            rules[key]={int(k):v for k,v in rules[key].items()}
            for id in rules[key]:expanded['ids'][id]=True
    encoded=lua(expanded)[:-1]+', ["pins"]={'+','.join(
        "{rva=%d,bytes=%s,label=%s}"%(p['rva'],lua_bytes(bytes.fromhex(p['hex'])),lua(p['label'])) for p in expanded_pins)+'}}'
    catalog=json.loads((ROOT/'config/attack_catalog.json').read_text(encoding='utf-8'))
    automatic_hashes=set(expanded['resources'])|{expanded['factory']['resource']}
    health_resources=lua({r['hash']:{'class_name':r['class_name']} for r in catalog['resources']if r['hash']in automatic_hashes})
    text="""return {
 steam_build='25480438',
 exe_sha256='F5FEE03DCFDB2E553A4752C283590950AC13316B376D8196AA556FF0400D5F06',
 game_sha256='2E2C3B7C2500646DADD5F2B4C6E0504DBB7E7896139F64CDDC0D1813C718F51E',
 avatar_resource='4d1c334d294dfa97',
 crusher_resource='%016x',
 pins={%s},
 targeting_pins={%s},
 targeting_resources={%s},
 attack_pins={%s},
 peer_pins={%s},
 cannon=%s,
 combat_pins={%s},
 expanded=%s,
 health_resources=%s,
 -- 1411/1412 have live capture support. Other branches are statically reviewed;
 -- exact move names / live coverage still need confirmation. Never use shared animation hashes alone.
 attack_states={[1411]=true,[1412]=true,[1413]=true,[1414]=true,[1415]=true,[1416]=true,
                [1417]=true,[1418]=true,[1419]=true,[1420]=true,[1421]=true,[1422]=true,[1424]=true},
 ignored_stomps={[1409]=true,[1410]=true,[1423]=true},
}
"""%(resource_hash(crusher),','.join(rows),','.join(target_rows),','.join(target_resources),','.join(attack_rows),','.join(peer_rows),cannon,','.join(combat_rows),encoded,health_resources)
    (ROOT/'src/profile.lua').write_text(text,encoding='utf-8')
    (ROOT/'src/catalog.lua').write_text('-- Generated from config/attack_catalog.json; edit the JSON source.\nreturn '+lua(catalog)+'\n',encoding='utf-8')

def build():
    masks();profile()
    resources={};frames=[];records=[]
    cache=BUILD/'image_cache';cache.mkdir(exist_ok=True)
    for n in range(EFFECT['frames']):
        name=OWNER+'/images/peril_%03d'%n;h=resource_hash(name)
        png=(ROOT/f'assets/frames/{n:03}.png').read_bytes();sha=hashlib.sha256(png).hexdigest()
        cache_file=cache/(sha+'-'+str(h)+'.bin')
        if cache_file.exists():
            blob=cache_file.read_bytes()
            a,b=struct.unpack_from('<II',blob,0);main,gpu=blob[8:8+a],blob[8+a:8+a+b]
            family={TEXTURE_TYPE:(main,gpu),MATERIAL_TYPE:(icon_material(h),b'')}
        else:
            w,height,rgba=read_png(png)
            assert w==height==EFFECT['texture_size'] and w&(w-1)==0
            main,gpu=texture_main(w,height,w.bit_length()),bc1_mips(w,height,rgba)
            family={TEXTURE_TYPE:(main,gpu),MATERIAL_TYPE:(icon_material(h),b'')}
            cache_file.write_bytes(struct.pack('<II',len(main),len(gpu))+main+gpu)
        for kind,data in family.items():resources[(kind,h)]=data
        frames.append("{name='%s',hash='%016x'}"%(name,h))
        records.append({'frame':n,'name':name,'hash':'%016x'%h,'mask_png_sha256':sha})
        if (n+1)%12==0:print('Image families:',n+1,flush=True)
    with wave.open(str(ROOT/'assets/peril.wav'),'rb') as wav:
        assert wav.getsampwidth()==2 and wav.getnchannels()==2 and wav.getframerate()==48000
        pcm=wav.readframes(wav.getnframes())
    palette=EFFECT['colours']
    assert 1<=len(palette)<=4 and all(len(c)==4 for c in palette)
    palette=palette+[[0,0,0,0]]*(4-len(palette))
    colours='{'+','.join('{'+','.join(str(x) for x in c)+'}' for c in palette)+'}'
    assets="return {fps=%s/%s,rate=48000,channels=2,quad_ratio=%s,colours=%s,frames={%s},pcm=%s}\n"%(EFFECT['fps_numerator'],EFFECT['fps_denominator'],EFFECT['quad_ratio_to_v020'],colours,',\n'.join(frames),lua_bytes(pcm))
    (BUILD/'assets.lua').write_text(assets,encoding='utf-8')
    chunks=['-- HD2-Addon: '+OWNER+'\n',"if rawget(_G,'SekiroDangerAlert') then return rawget(_G,'SekiroDangerAlert') end\n"]
    chunks.append('local project='+lua(CONFIG)+'\n')
    locales=load_locales(ROOT)
    (BUILD/'locales.lua').write_text('return '+lua(locales)+'\n',encoding='utf-8')
    chunks.append('local locales='+lua(locales)+'\n')
    catalog=json.loads((ROOT/'config/attack_catalog.json').read_text(encoding='utf-8'))
    release_catalog={'moves':[{k:move[k] for k in ('id','faction')}for move in catalog['moves']]}
    chunks.append('local catalog='+lua(release_catalog)+'\n')
    for name,path in [('runtime','vendor/bingus_runtime.lua'),('memory_module','vendor/bingus_memory.lua'),
                      ('profile','src/profile.lua'),('assets','build/assets.lua'),('localization_module','src/localization.lua'),('menu_module','src/menu.lua'),
                      ('audio_module','src/audio.lua'),('native_module','src/native.lua'),('overlay_module','src/overlay.lua'),
                      ('detector_module','src/detector.lua')]:
        chunks.append('local '+name+'='+module(ROOT/path)+'\n')
    if OPTIONS.diagnostics:
        vehicle=json.loads((ROOT/'config/vehicle_probe.json').read_text(encoding='utf-8'))
        assert vehicle['build']==CONFIG.get('steam_build','25480438')
        chunks.append('profile.vehicle_probe='+lua(vehicle)+'\n')
        folder=BUILD/'diagnostics';folder.mkdir(exist_ok=True)
        (folder/'vehicle_profile.lua').write_text('return '+lua(vehicle)+'\n',encoding='utf-8')
        if NEXT:
            existing={r['hash']for r in catalog['resources']}
            catalog['resources']+= [r for r in NEXT['resources']if r['hash']not in existing]
            catalog['moves']+=NEXT['capture_moves']
            folder=BUILD/'diagnostics';folder.mkdir(exist_ok=True)
            (folder/'catalog.lua').write_text('return '+lua(catalog)+'\n',encoding='utf-8')
        chunks.append('local diagnostic_catalog='+lua(catalog)+'\n')
        for name,path in [('vehicle_probe_module','tools/diagnostics/src/vehicle.lua'),
                          ('research_native','tools/diagnostics/src/native.lua'),
                          ('capture_module','tools/diagnostics/src/capture.lua'),
                          ('tracking_module','tools/diagnostics/src/tracking.lua'),
                          ('marker_module','tools/diagnostics/src/marker.lua'),
                          ('instrument_module','tools/diagnostics/src/instrument.lua')]:
            chunks.append('local '+name+'='+module(ROOT/path)+'\n')
        chunks.append('research_native.vehicle=vehicle_probe_module\n')
        chunks.append('local instrumentation=instrument_module.new(research_native,capture_module,tracking_module,marker_module,diagnostic_catalog,profile,project.version)\n')
    chunks.append((ROOT/('tools/diagnostics/src/entry.lua' if OPTIONS.diagnostics else 'src/entry.lua')).read_text(encoding='utf-8'))
    if not OPTIONS.diagnostics:
        chunks=['-- HD2-Addon: '+OWNER+'\n',without_comments(''.join(chunks[1:]))]
    build_id=hashlib.sha256(''.join(chunks).encode('utf-8')).hexdigest()[:12]
    chunks.insert(1,"local build_id='"+build_id+"'\n")
    entry=''.join(chunks).encode('utf-8');assert b'\0' not in entry and not entry.startswith(b'\xef\xbb\xbf')
    source_dir=BUILD/'diagnostics'if OPTIONS.diagnostics else BUILD
    source_dir.mkdir(exist_ok=True)
    (source_dir/'Sekiro danger alert.lua').write_bytes(entry)
    dll=os.environ.get('HD2_LUA51_DLL')
    assert dll and Path(dll).is_file(),'Set HD2_LUA51_DLL to the installed game Lua DLL before building'
    subprocess.run([sys.executable,str(ROOT/'vendor/game_lua.py'),str(ROOT/'tests/test_compile.lua'),
                    str(ROOT),str(source_dir/'Sekiro danger alert.lua')],check=True,cwd=ROOT)
    resources[(LUA_TYPE,resource_hash(OWNER))]=(lua_resource(entry),b'')
    main,gpu=make_resource_archive(resources)
    assert read_archive(main,gpu)==resources
    archive='9ba626afa44a3aa3.patch_0'
    description=('Sekiro danger alert: targeted enemy attack warnings with Sekiro-style animation and sound. '
                 '20 attack switches grouped by faction and appearance, volume, preview and reset controls on one settings page. '
                 'Alchemical Pyrosis during diving runs and Heavy MLRS (HE) in direct-fire mode only. '
                 'Requires Bingus Shared Loader v18+ and Mod Options Menu v1.2. '
                 'Uses code / research from HD2Runtime by SkyeShade https://github.com/SkyeShade/HD2Runtime')
    suffix=' Diagnostics'if OPTIONS.diagnostics else''
    if OPTIONS.diagnostics:description+=' Includes optional F8 collection, vehicle comparison contexts and a segmented 60-minute Hive Lord session on a separate diagnostic page; automatic targeting is unchanged; replaces the normal package.'
    if NEXT:description+=' Next-attack collection catalog only; new warning rules are not enabled without live mapping.'
    manifest={'Version':1,'Guid':CONFIG['guid'],'Name':'Sekiro danger alert '+CONFIG['version']+suffix,'Description':description,
              'Options':[{'Name':'Sekiro danger alert','Description':description,'Include':['Addon']}]}
    files={'manifest.json':json.dumps(manifest,indent=2).encode(),
           'Addon/'+archive:main,'Addon/'+archive+'.gpu_resources':gpu,'Addon/'+archive+'.stream':b''}
    for name in ['README.txt','README-使用说明.txt','CREDITS.txt']:
        files[name]=(ROOT/name).read_bytes()
    for source,target in [('Bingus-LICENSE.txt','LICENSES/Bingus-0BSD.txt'),('HD2Runtime-LICENSE.txt','LICENSES/HD2Runtime-MIT.txt')]:
        files[target]=(ROOT/'vendor'/source).read_bytes()
    if OPTIONS.diagnostics:
        files['README-采集说明.txt']=(ROOT/'tools/diagnostics/README-采集说明.txt').read_bytes()
        files['README-载具测试.txt']=(ROOT/'tools/diagnostics/README-载具测试.txt').read_bytes()
    if NEXT:
        guide=(ROOT/'tools/diagnostics/README-新增招式采集.txt').read_bytes()
        files['README-使用说明.txt']=guide
        files['README-采集说明.txt']=guide
        files['README.txt']=(ROOT/'tools/diagnostics/README-next-attacks.txt').read_bytes()
    target=OUT/('Sekiro danger alert '+CONFIG['version']+suffix+'.zip')
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED) as z:
        for name,data in sorted(files.items()):
            info=zipfile.ZipInfo(name,date_time=(2026,10,13,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED
            z.writestr(info,data)
    record={'version':CONFIG['version'],'build':build_id,'variant':'diagnostics'if OPTIONS.diagnostics else'standard',
            'guid':CONFIG['guid'],'resource':OWNER,'resource_count':len(resources),
            'image_frames':len(frames),'lua_bytes':len(entry),'archive_bytes':len(main),'gpu_bytes':len(gpu),
            'package_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'images':records}
    (source_dir/'build_record.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in record.items() if k!='images'},indent=2))

if __name__=='__main__':build()
