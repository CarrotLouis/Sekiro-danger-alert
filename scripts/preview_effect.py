"""Preview-only two-layer peril animation. Never changes shipped assets or packages.

Read the owner's font externally; render only to the ignored outputs directory.
Frame numbers are zero-based. The MP4 is authoritative for 60000/1001 timing;
the GIF uses a global palette and includes a separate one-second viewing pause.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
FPS = 60000 / 1001
COUNT = 50
SIZE = 768
PEAK = 14
END = 49
OUTPUT = ROOT / 'outputs/Sekiro danger alert Animation R1'


def smooth(x):
    x = np.clip(x, 0, 1)
    return x*x*(3-2*x)


def timing(frame):
    """Freeze main geometry at its brightness peak; echo has its own envelope."""
    growth = float(smooth(frame / PEAK))
    fade = float(1-smooth((frame-PEAK)/(END-PEAK)))
    return {
        'main_scale': .74 + .26*growth,
        'main_opacity': (.72 + .28*growth)*fade,
        'echo_scale': .88 + 1.04*float(1-(1-np.clip(frame/13, 0, 1))**2),
        'echo_opacity': .28*float(smooth(frame/3)) * float(1-smooth((frame-4)/20)),
    }


def make_glyph(font_path, size):
    font = ImageFont.truetype(str(font_path), size)
    box = font.getbbox('危')
    glyph = Image.new('L', (box[2]-box[0]+16, box[3]-box[1]+16))
    ImageDraw.Draw(glyph).text((8-box[0], 8-box[1]), '危', font=font, fill=255)
    return glyph.crop(glyph.getbbox()), font.getname()[0]


def fractal(size, seed):
    rng = np.random.default_rng(seed)
    field = np.zeros((size, size), np.float32)
    for octave in range(4):
        width = 14*2**octave
        grid = Image.fromarray(rng.random((max(3, round(width/2.23)), width)).astype(np.float32))
        field += np.asarray(grid.resize((size, size), Image.Resampling.BICUBIC)) / 2**octave
    return field / 1.875


def rgba_from_light(rgb):
    """Encode emitted light as straight alpha, retaining smooth faint fringes."""
    rgb = np.clip(rgb, 0, 1)
    alpha = rgb.max(axis=2)
    straight = np.divide(rgb, alpha[:, :, None], out=np.zeros_like(rgb), where=alpha[:, :, None] > 0)
    rgba = np.uint8(np.clip(np.dstack((straight, alpha))*255+.5, 0, 255))
    rgba[rgba[:, :, 3] == 0] = 0
    return Image.fromarray(rgba)


class Renderer:
    def __init__(self, glyph, size=SIZE, supersample=2):
        self.size = size
        self.n = size*supersample
        self.glyph = glyph
        self.a = fractal(self.n, 9203)
        self.b = fractal(self.n, 1731)
        f = np.fft.fftfreq(self.n)[:, None]**2 + np.fft.rfftfreq(self.n)[None, :]**2
        # Floating-point Gaussian convolution avoids an 8-bit staircase in the halo.
        self.filters = [np.exp(-2*np.pi**2*(r*self.n/SIZE)**2*f) for r in (2, 8, 25, 64)]
        edge = np.minimum(np.arange(self.n), np.arange(self.n)[::-1])
        taper = smooth(edge/(self.n*.05)).astype(np.float32)
        self.boundary = taper[:, None]*taper[None, :]

    def layer(self, scale, softness=.65):
        height = round(self.n*.35*scale)
        width = round(height*self.glyph.width/self.glyph.height)
        glyph = self.glyph.resize((width, height), Image.Resampling.LANCZOS)
        canvas = Image.new('L', (self.n, self.n))
        canvas.paste(glyph, ((self.n-width)//2, (self.n-height)//2))
        canvas = canvas.filter(ImageFilter.GaussianBlur(softness*self.n/SIZE))
        return np.asarray(canvas, dtype=np.float32)/255

    def frame(self, index):
        state = timing(index)
        if index >= END:
            return Image.new('RGBA', (self.size, self.size))
        # Slow texture evolution is also frozen at the peak: fade cannot introduce
        # new bright patches or make a static glyph appear to keep growing.
        phase = min(index, PEAK)/PEAK
        field = self.a*(1-phase*.35)+self.b*phase*.35
        light = .45 + .55*np.clip((1-field-.38)*4, 0, 1)**1.1
        colour = (np.array([1, .12, .16], np.float32)[None, None, :]
                  + light[:, :, None]*np.array([0, .70, .66], np.float32))
        main = self.layer(state['main_scale'])
        echo = self.layer(state['echo_scale'], softness=2.1)
        main_light = main*(.45+.55*light)
        # An actual second glyph, not a blur of the main glyph.
        rgb = echo[:, :, None]*colour*(.50+.50*light[:, :, None])*state['echo_opacity']
        rgb += main_light[:, :, None]*colour*state['main_opacity']
        spectrum = np.fft.rfft2(main_light*state['main_opacity'] + echo*state['echo_opacity']*.7)
        for filt, strength, tint in zip(self.filters, (.25, .43, .60, .55),
                                       ((1, .20, .22), (1, .15, .16), (1, .09, .10), (1, .06, .065))):
            blurred = np.maximum(np.fft.irfft2(spectrum*filt, s=(self.n, self.n)), 0).astype(np.float32)
            rgb += blurred[:, :, None]*strength*np.array(tint, np.float32)
        rgb *= self.boundary[:, :, None]
        # Downsample premultiplied light before constructing straight-alpha PNGs.
        small = np.stack([np.asarray(Image.fromarray(rgb[:, :, c]).resize(
            (self.size, self.size), Image.Resampling.LANCZOS)) for c in range(3)], axis=2)
        return rgba_from_light(small)


def on_background(rgba, colour=(5, 3, 4)):
    image = Image.new('RGBA', rgba.size, (*colour, 255))
    image.alpha_composite(rgba)
    return image.convert('RGB')


def gif_durations():
    return [round((i+1)*100/FPS)*10-round(i*100/FPS)*10 for i in range(COUNT)]


def encode_video(ffmpeg, frames, path):
    command = [str(ffmpeg), '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24',
               '-s', f'{frames[0].width}x{frames[0].height}', '-r', '60000/1001', '-i', '-',
               '-an', '-c:v', 'libx264', '-crf', '16', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(path)]
    subprocess.run(command, input=b''.join(im.tobytes() for im in frames), check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--font', type=Path, required=True)
    parser.add_argument('--ffmpeg', type=Path, required=True)
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    sequence = OUTPUT/'PNG'
    sequence.mkdir(exist_ok=True)
    glyph, family = make_glyph(args.font, SIZE*2)
    renderer = Renderer(glyph)
    frames = []
    for i in range(COUNT):
        rgba = renderer.frame(i)
        rgba.save(sequence/f'{i:03d}.png')
        frames.append(on_background(rgba))
    encode_video(args.ffmpeg, frames, OUTPUT/'Sekiro danger alert R1 59.94fps.mp4')
    # Separate repeat video makes the short effect easier to inspect in a player.
    pause = [Image.new('RGB', (SIZE, SIZE), (5, 3, 4))]*60
    encode_video(args.ffmpeg, (frames+pause)*3, OUTPUT/'Sekiro danger alert R1 Preview.mp4')
    # One global palette plus dithering avoids changing bands between GIF frames.
    atlas = Image.new('RGB', (SIZE*5, SIZE*2))
    for cell, index in enumerate(range(0, COUNT, 5)):
        atlas.paste(frames[index], (cell%5*SIZE, cell//5*SIZE))
    palette = atlas.quantize(colors=256)
    gif = [f.quantize(palette=palette, dither=Image.Dither.FLOYDSTEINBERG) for f in frames]
    gif.append(pause[0].quantize(palette=palette))
    gif[0].save(OUTPUT/'Sekiro danger alert R1 Preview.gif', save_all=True,
                append_images=gif[1:], duration=gif_durations()+[1000], loop=0, optimize=False, disposal=2)
    sheet = Image.new('RGB', (SIZE*3, (SIZE+32)*2), (5, 3, 4))
    for cell, index in enumerate((4, 10, 14, 24, 36, 46)):
        x, y = cell%3*SIZE, cell//3*(SIZE+32)
        sheet.paste(frames[index], (x, y))
        ImageDraw.Draw(sheet).text((x+16, y+SIZE+8), f'Frame {index:02d} / {index/FPS:.3f} s', fill='white')
    sheet.save(OUTPUT/'Sekiro danger alert R1 Contact.png')
    frames[10].save(OUTPUT/'Sekiro danger alert R1 Still.png')
    metadata = {
        'public_name': 'Sekiro danger alert', 'preview_revision': 'R1', 'approved': False,
        'font_family': family, 'font_sha256': hashlib.sha256(args.font.read_bytes()).hexdigest(),
        'font_bundled': False, 'size': SIZE, 'frames': COUNT, 'fps': '60000/1001',
        'main_peak_frame': PEAK, 'echo_invisible_frame': 24, 'fully_transparent_frame': END,
        'gif_pause_ms': 1000, 'main_scale_frozen_during_fade': True,
        'production_assets_changed': False, 'game_package_created': False,
        'frames_timing': [timing(i) for i in range(COUNT)],
    }
    (OUTPUT/'preview.json').write_text(json.dumps(metadata, indent=2)+'\n', encoding='utf-8')
    print(f'Preview only: {OUTPUT}')


if __name__ == '__main__':
    main()
