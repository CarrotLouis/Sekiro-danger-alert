"""Build the Bingus addon and its private compiled image families, without touching the game."""
from pathlib import Path
import argparse,hashlib,json,struct,sys,wave,zipfile
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'vendor'))
from hd2_archive import resource_hash,lua_resource,make_resource_archive,read_archive,LUA_TYPE
from hd2_image import icon_family,icon_masks,write_png
from PIL import Image

CONFIG=json.loads((ROOT/'project.json').read_text())
ARGS=argparse.ArgumentParser()
ARGS.add_argument('--output-dir',type=Path,default=ROOT/'outputs')
OUT=ARGS.parse_args().output_dir.resolve();OUT.mkdir(parents=True,exist_ok=True)
OWNER=CONFIG['resource']
BUILD=ROOT/'build';BUILD.mkdir(exist_ok=True)

def lua_bytes(data):
    # A single escaped string per 4 KiB chunk, not a per-byte table/constructor.
    # No literal binary NUL in the discoverable Lua source.
    return 'table.concat({\n'+',\n'.join('"'+''.join('\\%03d'%b for b in data[i:i+4096])+'"'
        for i in range(0,len(data),4096))+'\n})'

def module(path):
    return '(function()\n'+path.read_text(encoding='utf-8')+'\nend)()'

def masks():
    dest=ROOT/'assets/frames';dest.mkdir(exist_ok=True)
    frames=OUT/'Sekiro danger alert Transparent Sequence/PNG_1920x1080_5994fps'
    for n in range(48):
        target=dest/f'{n:03}.png'
        if target.exists():continue
        rgba=Image.open(frames/f'peril_{n:04}.png').convert('RGBA')
        # Recompose on black before converting RGB to the game's R/G mask convention.
        black=Image.new('RGBA',rgba.size,(0,0,0,255));black.alpha_composite(rgba)
        square=black.crop((256,-160,1664,1248)).resize((256,256),Image.Resampling.LANCZOS)
        raw=icon_masks(square.tobytes(),dark=(0,0,0),red=(255,45,45),white=(255,255,245))
        target.write_bytes(write_png(256,256,raw))

def profile():
    crusher='content/fac_illuminate/cha_bodyhorror_helmetguy/cha_bodyhorror_helmetguy'
    pins=[('exe',0x5542dc,'488b4128','animation resource'),
          ('exe',0x554310,'488b46504c8b0c03','animation active layers'),
          ('exe',0x554329,'458b440b044c03c1','animation group offsets'),
          ('exe',2873456,'488d4160c3','unit scene graph'),
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
    text="""return {
 steam_build='25480438',
 exe_sha256='F5FEE03DCFDB2E553A4752C283590950AC13316B376D8196AA556FF0400D5F06',
 game_sha256='2E2C3B7C2500646DADD5F2B4C6E0504DBB7E7896139F64CDDC0D1813C718F51E',
 avatar_resource='4d1c334d294dfa97',
 crusher_resource='%016x',
 pins={%s},
 -- Captured attack onsets; do not substitute animation hashes shared by other abilities.
 attack_states={[1411]=true,[1412]=true},
}
"""%(resource_hash(crusher),','.join(rows))
    (ROOT/'src/profile.lua').write_text(text,encoding='utf-8')

def build():
    masks();profile()
    resources={};frames=[];records=[]
    cache=BUILD/'image_cache';cache.mkdir(exist_ok=True)
    for n in range(48):
        name=OWNER+'/images/peril_%03d'%n;h=resource_hash(name)
        png=(ROOT/f'assets/frames/{n:03}.png').read_bytes();sha=hashlib.sha256(png).hexdigest()
        cache_file=cache/(sha+'-'+str(h)+'.bin')
        if cache_file.exists():
            blob=cache_file.read_bytes()
            a,b=struct.unpack_from('<II',blob,0);main,gpu=blob[8:8+a],blob[8+a:8+a+b]
            from hd2_image import TEXTURE_TYPE,MATERIAL_TYPE,icon_material
            family={TEXTURE_TYPE:(main,gpu),MATERIAL_TYPE:(icon_material(h),b'')}
        else:
            family=icon_family(png,h)
            from hd2_image import TEXTURE_TYPE
            main,gpu=family[TEXTURE_TYPE];cache_file.write_bytes(struct.pack('<II',len(main),len(gpu))+main+gpu)
        for kind,data in family.items():resources[(kind,h)]=data
        frames.append("{name='%s',hash='%016x'}"%(name,h))
        records.append({'frame':n,'name':name,'hash':'%016x'%h,'mask_png_sha256':sha})
        if (n+1)%12==0:print('Image families:',n+1,flush=True)
    with wave.open(str(ROOT/'assets/peril.wav'),'rb') as wav:
        assert wav.getsampwidth()==2 and wav.getnchannels()==2 and wav.getframerate()==48000
        pcm=wav.readframes(wav.getnframes())
    assets="return {fps=60000/1001,rate=48000,channels=2,colours={{1,1,45/255,45/255},{1,1,1,245/255},{0,0,0,0},{0,0,0,0}},frames={%s},pcm=%s}\n"%(',\n'.join(frames),lua_bytes(pcm))
    (BUILD/'assets.lua').write_text(assets,encoding='utf-8')
    chunks=['-- HD2-Addon: '+OWNER+'\n',"if rawget(_G,'SekiroDangerAlert') then return rawget(_G,'SekiroDangerAlert') end\n"]
    for name,path in [('runtime','vendor/bingus_runtime.lua'),('memory_module','vendor/bingus_memory.lua'),
                      ('profile','src/profile.lua'),('assets','build/assets.lua'),('menu_module','src/menu.lua'),
                      ('audio_module','src/audio.lua'),('native_module','src/native.lua'),('overlay_module','src/overlay.lua'),
                      ('capture_module','src/capture.lua'),('marker_module','src/marker.lua'),('detector_module','src/detector.lua')]:
        chunks.append('local '+name+'='+module(ROOT/path)+'\n')
    chunks.append((ROOT/'src/entry.lua').read_text(encoding='utf-8'))
    entry=''.join(chunks).encode('utf-8');assert b'\0' not in entry and not entry.startswith(b'\xef\xbb\xbf')
    (BUILD/'Sekiro danger alert.lua').write_bytes(entry)
    resources[(LUA_TYPE,resource_hash(OWNER))]=(lua_resource(entry),b'')
    main,gpu=make_resource_archive(resources)
    assert read_archive(main,gpu)==resources
    archive='9ba626afa44a3aa3.patch_0'
    description=('Sekiro danger alert: Crusher attack onset warning within 10 m, live avatar-head projection and independent sound volume. '
                 'Requires Bingus Shared Loader v18+ and Mod Options Menu v1.2. '
                 'Uses code / research from HD2Runtime by SkyeShade https://github.com/SkyeShade/HD2Runtime')
    manifest={'Version':1,'Guid':CONFIG['guid'],'Name':'Sekiro danger alert '+CONFIG['version'],'Description':description,
              'Options':[{'Name':'Sekiro danger alert','Description':description,'Include':['Addon']}]}
    files={'manifest.json':json.dumps(manifest,indent=2).encode(),
           'Addon/'+archive:main,'Addon/'+archive+'.gpu_resources':gpu,'Addon/'+archive+'.stream':b''}
    for name in ['README-测试说明.txt','CREDITS.txt']:
        if (ROOT/name).exists():files[name]=(ROOT/name).read_bytes()
    target=OUT/('Sekiro danger alert '+CONFIG['version']+'.zip')
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED) as z:
        for name,data in sorted(files.items()):
            info=zipfile.ZipInfo(name,date_time=(2026,10,13,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED
            z.writestr(info,data)
    record={'version':CONFIG['version'],'guid':CONFIG['guid'],'resource':OWNER,'resource_count':len(resources),
            'image_frames':len(frames),'lua_bytes':len(entry),'archive_bytes':len(main),'gpu_bytes':len(gpu),
            'package_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'images':records}
    (BUILD/'build_record.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in record.items() if k!='images'},indent=2))

if __name__=='__main__':build()
