"""Promote the approved R2 straight-alpha PNG sequence to native icon masks."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SIZE = 512
# (alpha, red, green, blue). Put the broad red glow in BC1's 6-bit G channel.
COLOURS = [[1, 1, 1, 1], [1, 1, 0, 0], [1, 1, 1, 0]]


def premultiplied(rgba):
    a = np.asarray(rgba, dtype=np.float32)/255
    return a[:, :, :3]*a[:, :, 3:]


def encode(rgb):
    r, g, b = np.clip(rgb, 0, 1).transpose(2, 0, 1)
    if np.max(g-r) > .005 or np.max(b-g) > .005:
        raise ValueError('R2 colour basis requires red >= green >= blue')
    return Image.fromarray(np.uint8(np.clip(np.dstack((b, r-g, g-b, np.ones_like(r)))*255+.5, 0, 255)))


def decode(mask):
    weights = np.asarray(mask, dtype=np.float32)[:, :, :3]/255
    return np.clip(weights @ np.asarray(COLOURS, np.float32)[:, 1:], 0, 1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sequence', type=Path, required=True, help='Approved R2 directory containing PNG/ and preview.json')
    args = parser.parse_args()
    source = json.loads((args.sequence/'preview.json').read_text(encoding='utf-8'))
    assert source['preview_revision'] == 'R2' and source['frames'] == 50 and source['fps'] == '60000/1001'
    records = []
    # Read and validate every input before changing the production assets.
    masks = []
    for index in range(50):
        file = args.sequence/f'PNG/{index:03}.png'
        with Image.open(file) as image:
            assert image.mode == 'RGBA' and image.size == (768, 768)
            rgb = premultiplied(image)
        small = np.stack([np.asarray(Image.fromarray(rgb[:, :, c]).resize(
            (SIZE, SIZE), Image.Resampling.LANCZOS)) for c in range(3)], axis=2)
        mask = encode(small)
        masks.append(mask)
        records.append({'frame': index, 'approved_png_sha256': hashlib.sha256(file.read_bytes()).hexdigest()})
    assert not decode(masks[-1]).any()
    directory = ROOT/'assets/frames'
    directory.mkdir(exist_ok=True)
    for index, mask in enumerate(masks):
        mask.save(directory/f'{index:03}.png')
    metadata = {
        'renderer': 'procedural-font-fractal-r2', 'approved_revision': 'R2',
        'font_family': source['font_family'], 'font_sha256': source['font_sha256'], 'font_bundled': False,
        'texture_size': SIZE, 'frames': 50, 'fps_numerator': 60000, 'fps_denominator': 1001,
        'quad_ratio_to_v020': .38*(300/512)/.35,
        'colours': COLOURS, 'mask_encoding': 'R=blue, G=red-green, B=green-blue, A=255',
        'note': 'Approved R2 frames; premultiplied resampling, exact RGB basis before BC1 compression.',
        'source_frames': records,
    }
    (ROOT/'assets/effect.json').write_text(json.dumps(metadata, indent=2)+'\n', encoding='utf-8')
    print('Imported 50 approved R2 frames; preserved baseline glyph size with a wider glow quad.')


if __name__ == '__main__':
    main()
