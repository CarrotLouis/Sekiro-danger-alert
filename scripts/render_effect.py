"""Render a font-based peril animation with evolving fractal texture and layered red glow.

The supplied font stays outside the repository. AE plugin pixels are not reproduced;
this is an independent procedural implementation of the supplied visual recipe.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SIZE = 512
FPS = 60000 / 1001
COUNT = 48
COLOURS = np.array([[1, .07, .03], [1, .80, .73]], dtype=np.float32)


def noise(seed):
    rng = np.random.default_rng(seed)
    total = np.zeros((SIZE, SIZE), np.float32)
    for octave in range(4):
        # Height 223% stretches the fractal vertically, as in the reference.
        w = 9 * 2 ** octave
        h = max(3, round(w / 2.23))
        grid = Image.fromarray(np.uint8(rng.random((h, w)) * 255))
        total += np.asarray(grid.resize((SIZE, SIZE), Image.Resampling.BICUBIC)) / 255 / 2 ** octave
    return total / 1.875


def smooth(a, b, x):
    t = np.clip((x-a)/(b-a), 0, 1)
    return t*t*(3-2*t)


def resize_center(mask, scale):
    n = max(1, round(SIZE*scale))
    scaled = mask.resize((n, n), Image.Resampling.LANCZOS)
    result = Image.new('L', (SIZE, SIZE))
    result.paste(scaled, ((SIZE-n)//2, (SIZE-n)//2))
    return result


def composite(mask):
    coefficients = np.asarray(mask, dtype=np.float32)[:, :, :2] / 255
    rgb = coefficients @ COLOURS
    alpha = np.clip(coefficients.sum(axis=2), 0, 1)
    straight = np.clip(rgb/np.maximum(alpha[:, :, None], 1/255), 0, 1)
    straight[alpha == 0] = 0
    return Image.fromarray(np.uint8(np.dstack([straight, alpha])*255+.5))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--font', type=Path, required=True)
    args = parser.parse_args()
    font = ImageFont.truetype(str(args.font), 720)
    bbox = font.getbbox('危')
    glyph = Image.new('L', (bbox[2]-bbox[0]+16, bbox[3]-bbox[1]+16))
    ImageDraw.Draw(glyph).text((8-bbox[0], 8-bbox[1]), '危', font=font, fill=255)
    glyph = glyph.crop(glyph.getbbox())
    glyph.thumbnail((300, 300), Image.Resampling.LANCZOS)
    base = Image.new('L', (SIZE, SIZE))
    base.paste(glyph, ((SIZE-glyph.width)//2, (SIZE-glyph.height)//2))
    a, b = noise(9203), noise(1731)
    edge = np.minimum(np.arange(SIZE), np.arange(SIZE)[::-1])
    taper = smooth(2, 24, edge).astype(np.float32)
    boundary = taper[:, None]*taper[None, :]
    directory = ROOT/'assets/frames'
    directory.mkdir(parents=True, exist_ok=True)
    output = ROOT/'outputs/Sekiro danger alert Font Animation'
    output.mkdir(parents=True, exist_ok=True)
    frames = []
    for index in range(COUNT):
        t = index/FPS
        opacity = float(smooth(0, .045, t)*(1-smooth(.39, .78, t)))
        scale = .78 + .22*float(smooth(0, .10, t)) + .22*float(smooth(.4, .8, t))
        shape = resize_center(base, scale)
        alpha = np.asarray(shape, dtype=np.float32)/255
        phase = -2*np.pi/3 + t*3.8
        moving = np.roll(a, (round(t*35), round(t*125)), (0, 1))
        field = (moving*(.5+.5*np.cos(phase)) + b*(.5-.5*np.cos(phase)))
        # Inverted 150% contrast, with dark valleys and preserved luminous ridges.
        field = np.clip((1-field-.5)*1.5+.5-.10, 0, 1)
        light = np.clip((field-.28)*2.4, 0, 1)**1.25
        body = alpha * (.18+.82*light)
        glow = np.zeros_like(alpha)
        for radius, strength in [(3, .34), (12, .26), (32, .17), (68, .11)]:
            glow += np.asarray(shape.filter(ImageFilter.GaussianBlur(radius)), dtype=np.float32)/255*strength
        echo = np.asarray(resize_center(base, scale*1.16).filter(ImageFilter.GaussianBlur(2)), dtype=np.float32)/255
        glow += echo*.12*(1-float(smooth(.10, .45, t)))
        r = np.clip((body*(1-light*.62)+glow*1.5*(1-alpha*.55))*opacity*boundary, 0, 1)
        g = np.clip(body*light*.72*opacity*boundary, 0, 1)
        mask = Image.fromarray(np.uint8(np.dstack([r, g, np.zeros_like(r), np.ones_like(r)])*255+.5))
        mask.save(directory/f'{index:03}.png')
        rgba = composite(mask)
        rgba.save(output/f'{index:03}.png')
        frames.append(rgba)
    # Preview represents the same R/G shader colours as the shipped material.
    backgrounds = []
    for frame in frames:
        back = Image.new('RGBA', (SIZE, SIZE), (22, 25, 32, 255))
        back.alpha_composite(frame)
        backgrounds.append(back.convert('RGB'))
    durations = [round((i+1)*100/FPS)*10-round(i*100/FPS)*10 for i in range(COUNT)]
    backgrounds[0].save(output/'Sekiro danger alert Preview.gif', save_all=True,
                        append_images=backgrounds[1:], duration=durations, loop=0)
    sheet = Image.new('RGB', (SIZE*3, SIZE*2), (22, 25, 32))
    for cell, index in enumerate([5, 10, 16, 24, 33, 42]):
        sheet.paste(backgrounds[index], ((cell%3)*SIZE, (cell//3)*SIZE))
    sheet.save(output/'Sekiro danger alert Contact.png')
    metadata = {
        'renderer': 'procedural-font-fractal-v1', 'font_family': font.getname()[0],
        'font_sha256': hashlib.sha256(args.font.read_bytes()).hexdigest(),
        'font_bundled': False, 'texture_size': SIZE, 'frames': COUNT,
        'fps_numerator': 60000, 'fps_denominator': 1001,
        'quad_ratio_to_v020': .38, 'colours': [[1, 1, .07, .03], [1, 1, .80, .73]],
        'reference': {'complexity': 4, 'contrast': 150, 'stretch_y_percent': 223,
                      'evolution_degrees': -120, 'glow_exposure': 1.5},
        'note': 'Independent approximation; no AE plugins or font binary distributed.',
    }
    (ROOT/'assets/effect.json').write_text(json.dumps(metadata, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(metadata, indent=2))


if __name__ == '__main__':
    main()
