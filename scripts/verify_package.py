"""Inspect the finished ZIP and decode its actual BC1 images for offline visual QA."""
import hashlib
import io
import json
from pathlib import Path
import struct
import sys
import uuid
import zipfile

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'vendor'))
from hd2_archive import read_archive, resource_hash, LUA_TYPE
from hd2_image import TEXTURE_TYPE, MATERIAL_TYPE, icon_material
from import_effect import decode


def main():
    config = json.loads((ROOT/'project.json').read_text())
    effect = json.loads((ROOT/'assets/effect.json').read_text())
    package = ROOT/'outputs'/f"Sekiro danger alert {config['version']}.zip"
    archive = 'Addon/9ba626afa44a3aa3.patch_0'
    with zipfile.ZipFile(package) as z:
        assert z.testzip() is None
        assert set(z.namelist()) == {'manifest.json', 'README-测试说明.txt', 'CREDITS.txt',
                                    archive, archive+'.gpu_resources', archive+'.stream'}
        manifest = json.loads(z.read('manifest.json'))
        assert manifest['Guid'] == config['guid'] and str(uuid.UUID(manifest['Guid'])) == config['guid']
        assert manifest['Name'] == f"Sekiro danger alert {config['version']}" and manifest['Version'] == 1
        assert manifest['Options'][0]['Include'] == ['Addon']
        assert z.read(archive+'.stream') == b''
        resources = read_archive(z.read(archive), z.read(archive+'.gpu_resources'))
    assert len(resources) == effect['frames']*2+1
    body, gpu = resources[LUA_TYPE, resource_hash(config['resource'])]
    length, version = struct.unpack_from('<II', body)
    assert length == len(body)-8 and version == 2 and not gpu
    source = body[8:]
    assert source == (ROOT/'build/Sekiro danger alert.lua').read_bytes()
    assert source.startswith(('-- HD2-Addon: '+config['resource']).encode())
    assert not source.startswith(b'\xef\xbb\xbf') and b'\0' not in source
    assert ("version='"+config['version']+"'").encode() in source
    errors = []
    sheet = Image.new('RGB', (1024, 6*280))
    keys = [0, 6, 11, 19, 33, 41]
    for index in range(effect['frames']):
        h = resource_hash(config['resource']+f'/images/peril_{index:03}')
        main, gpu = resources[TEXTURE_TYPE, h]
        assert resources[MATERIAL_TYPE, h] == (icon_material(h), b'')
        assert len(gpu) == sum(max(1, (512 >> m)//4)**2*8 for m in range(10))
        assert struct.unpack_from('<I', main, 192+128)[0] == 71  # BC1_UNORM
        with Image.open(io.BytesIO(main[192:]+gpu)) as image:
            assert image.size == (512, 512)
            rgb = decode(image.convert('RGBA'))
        original = decode(Image.open(ROOT/f'assets/frames/{index:03}.png'))
        error = np.abs(rgb-original)
        errors.append({'frame': index, 'mean_rgb_error': float(error.mean()),
                       'p99_rgb_error': float(np.quantile(error, .99))})
        assert error.mean() < .01 and np.quantile(error, .99) < .065
        assert not rgb[:2].any() and not rgb[-2:].any()
        if index == 49:
            assert not rgb.any()
        if index in keys:
            row = keys.index(index)
            for col, pixels in enumerate((original, rgb)):
                # Show both at the same display scale for a fair visual comparison.
                img = Image.fromarray(np.uint8(np.clip(pixels*255+.5, 0, 255)))
                img.thumbnail((260, 260), Image.Resampling.LANCZOS)
                sheet.paste(img, (col*512+126, row*280))
            ImageDraw.Draw(sheet).text((16, row*280+262),
                f'Frame {index:02d} | left: source masks | right: decoded packaged BC1', fill='white')
    sheet.save(ROOT/'outputs'/f"Sekiro danger alert {config['version']} Packed Comparison.png")
    report = {'version': config['version'], 'guid': config['guid'], 'resources': len(resources),
              'frames': effect['frames'], 'approved_effect': effect['approved_revision'],
              'duration_seconds': effect['frames']*effect['fps_denominator']/effect['fps_numerator'],
              'package_sha256': hashlib.sha256(package.read_bytes()).hexdigest(),
              'package_bytes': package.stat().st_size, 'offline_archive_check': 'passed',
              'bc1_checks': errors, 'live_game_validated': False}
    (ROOT/'outputs'/f"Sekiro danger alert {config['version']} Validation.json").write_text(
        json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k!='bc1_checks'}, indent=2))


if __name__ == '__main__':
    main()
