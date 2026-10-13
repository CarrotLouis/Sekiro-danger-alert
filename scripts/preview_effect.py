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
MAIN_STOP = 34
END = 49
OUTPUT = ROOT / 'outputs/Sekiro danger alert Animation R2'


def smooth(x):
    x = np.clip(x, 0, 1)
    return x*x*(3-2*x)


def timing(frame):
    """Two independent growth curves, changing colour, erosion and bloom envelopes."""
    f = np.clip(frame, 0, END)
    growth = (1-np.exp(-min(f, MAIN_STOP)/9))/(1-np.exp(-MAIN_STOP/9))
    echo_growth = (1-np.exp(-min(f, 19)/3.5))/(1-np.exp(-19/3.5))
    return {
        'main_scale': float(.70+.30*growth),
        'main_opacity': float((1-smooth((f-29)/20))**.65),
        'main_brightness': float(np.interp(f, [0, 11, 19, 33, 41, 49], [1.18, 1.16, 1.14, 1.10, .85, .3])),
        'whiteness': float(np.interp(f, [0, 11, 19, 25, 33, 41, 49], [1, .87, .66, .40, .12, .025, 0])),
        'echo_scale': float(.82+1.03*echo_growth),
        'echo_opacity': float(.27*smooth(f/3)*(1-smooth((f-11)/13))),
        'erosion': float(.88*smooth((f-23)/26)),
        'glow': float(np.interp(f, [0, 6, 11, 19, 25, 33, 41, 49], [.30, 1, .86, .45, .20, .06, .008, 0])),
    }


def erosion_mask(core, field, progress):
    # Thin strokes / stroke boundaries have lower core values and disappear first.
    # A continuous noise field varies the advancing dissolve across the glyph.
    resistance = .30+.44*np.clip(core, 0, 1)+.26*np.clip(field, 0, 1)
    return smooth((resistance-progress)/.24+.5)


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
        self.filters = [np.exp(-2*np.pi**2*(r*self.n/SIZE)**2*f) for r in (3, 14, 48, 115)]
        edge = np.minimum(np.arange(self.n), np.arange(self.n)[::-1])
        taper = smooth(edge/(self.n*.05)).astype(np.float32)
        self.boundary = taper[:, None]*taper[None, :]
        y, x = np.mgrid[:self.n, :self.n]
        self.radius2 = ((x-self.n/2)**2+(y-self.n/2)**2)/(self.n/SIZE)**2
        self.boundary *= 1-smooth((np.sqrt(self.radius2)-SIZE*.35)/(SIZE*.15))

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
        phase = index/END
        field = self.a*(1-phase*.45)+self.b*phase*.45
        texture = np.clip((1-field-.38)*4, 0, 1)**1.1
        white = state['whiteness']*(.70+.30*texture)
        colour = np.stack((np.ones_like(white), .025+.975*white, .015+.91*white), axis=2)
        main = self.layer(state['main_scale'], softness=3.0)
        echo = self.layer(state['echo_scale'], softness=2.1)
        core = np.maximum(np.fft.irfft2(np.fft.rfft2(main)*self.filters[0], s=(self.n, self.n)), 0)
        dissolve = erosion_mask(core, field, state['erosion'])
        main_light = main*(1-(1-state['whiteness'])*.70*(1-texture))*dissolve*state['main_brightness']
        echo_colour = np.stack((np.ones_like(white), .06+.54*texture, .04+.48*texture), axis=2)
        rgb = echo[:, :, None]*echo_colour*(.50+.50*texture[:, :, None])*state['echo_opacity']
        rgb += main_light[:, :, None]*colour*state['main_opacity']
        # Bloom expands and recedes on its own envelope instead of simply sharing
        # the main layer's alpha. The broad skirt supplies the reference's red haze.
        spectrum = np.fft.rfft2(main*(.75+.25*texture)*dissolve + echo*state['echo_opacity']*.08)
        for filt, strength, tint in zip(self.filters, (.65, 1.4, 1.6, 1.0),
                                       ((1, .08, .065), (1, .06, .045), (1, .035, .02), (1, .02, .01))):
            blurred = np.maximum(np.fft.irfft2(spectrum*filt, s=(self.n, self.n)), 0).astype(np.float32)
            rgb += blurred[:, :, None]*strength*state['glow']*np.array(tint, np.float32)
        sigma = 205+55*state['glow']
        skirt = .26*state['glow']*np.exp(-self.radius2/(2*sigma**2))
        rgb += skirt[:, :, None]*np.array([1, .018, .012], np.float32)
        rgb *= self.boundary[:, :, None]
        # Downsample premultiplied light before constructing straight-alpha PNGs.
        small = np.stack([np.asarray(Image.fromarray(rgb[:, :, c]).resize(
            (self.size, self.size), Image.Resampling.LANCZOS)) for c in range(3)], axis=2)
        return rgba_from_light(small)


def on_background(rgba, colour=(0, 0, 0)):
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


def compare_reference(ffmpeg, video, frames):
    """Fixed crop/scale for every source frame: no per-frame resizing or retiming."""
    result = subprocess.run([str(ffmpeg), '-v', 'error', '-i', str(video), '-frames:v', str(COUNT),
                             '-vf', f'crop=540:540:640:250,scale={SIZE}:{SIZE}',
                             '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'], capture_output=True, check=True)
    source = np.frombuffer(result.stdout, np.uint8).reshape(COUNT, SIZE, SIZE, 3)
    pairs = []
    for i, frame in enumerate(frames):
        pair = Image.new('RGB', (SIZE*2, SIZE+32))
        pair.paste(Image.fromarray(source[i]))
        pair.paste(frame, (SIZE, 0))
        draw = ImageDraw.Draw(pair)
        draw.text((16, SIZE+8), f'Original | Frame {i:02d} | {i/FPS:.3f} s', fill='white')
        draw.text((SIZE+16, SIZE+8), f'Sekiro danger alert R2 | Frame {i:02d}', fill='white')
        pairs.append(pair)
    encode_video(ffmpeg, pairs, OUTPUT/'Sekiro danger alert R2 Comparison.mp4')
    for label, indices in [('Early', (0, 6, 11, 19)), ('Late', (25, 33, 41, 46))]:
        sheet = Image.new('RGB', (SIZE*2, (SIZE+32)))
        for cell, i in enumerate(indices):
            small = pairs[i].resize((SIZE, (SIZE+32)//2), Image.Resampling.LANCZOS)
            sheet.paste(small, (cell%2*SIZE, cell//2*((SIZE+32)//2)))
        sheet.save(OUTPUT/f'Sekiro danger alert R2 Compare {label}.png')
    return {'source_sha256': hashlib.sha256(video.read_bytes()).hexdigest(),
            'source_crop': [640, 250, 540, 540], 'uniform_scale': [SIZE, SIZE],
            'frame_alignment': 'same zero-based frame at 60000/1001 fps; no retiming',
            'keyframes': [0, 6, 11, 19, 25, 33, 41, 46]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--font', type=Path, required=True)
    parser.add_argument('--ffmpeg', type=Path, required=True)
    parser.add_argument('--reference-video', type=Path)
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
    encode_video(args.ffmpeg, frames, OUTPUT/'Sekiro danger alert R2 59.94fps.mp4')
    # Separate repeat video makes the short effect easier to inspect in a player.
    pause = [Image.new('RGB', (SIZE, SIZE), (0, 0, 0))]*60
    encode_video(args.ffmpeg, (frames+pause)*3, OUTPUT/'Sekiro danger alert R2 Preview.mp4')
    # One global palette plus dithering avoids changing bands between GIF frames.
    atlas = Image.new('RGB', (SIZE*5, SIZE*2))
    for cell, index in enumerate(range(0, COUNT, 5)):
        atlas.paste(frames[index], (cell%5*SIZE, cell//5*SIZE))
    palette = atlas.quantize(colors=256)
    gif = [f.quantize(palette=palette, dither=Image.Dither.FLOYDSTEINBERG) for f in frames]
    # Hold the already-black final frame. Avoid a duplicate disposal-2 terminal
    # frame, which can produce an invalid final descriptor with Pillow's encoder.
    durations = gif_durations()
    durations[-1] += 1000
    gif[0].save(OUTPUT/'Sekiro danger alert R2 Preview.gif', save_all=True,
                append_images=gif[1:], duration=durations, loop=0, optimize=False, disposal=1)
    sheet = Image.new('RGB', (SIZE*3, (SIZE+32)*2), (0, 0, 0))
    for cell, index in enumerate((0, 11, 19, 25, 33, 41)):
        x, y = cell%3*SIZE, cell//3*(SIZE+32)
        sheet.paste(frames[index], (x, y))
        ImageDraw.Draw(sheet).text((x+16, y+SIZE+8), f'Frame {index:02d} / {index/FPS:.3f} s', fill='white')
    sheet.save(OUTPUT/'Sekiro danger alert R2 Contact.png')
    frames[10].save(OUTPUT/'Sekiro danger alert R2 Still.png')
    comparison = compare_reference(args.ffmpeg, args.reference_video, frames) if args.reference_video else None
    metadata = {
        'public_name': 'Sekiro danger alert', 'preview_revision': 'R2', 'approved': False,
        'font_family': family, 'font_sha256': hashlib.sha256(args.font.read_bytes()).hexdigest(),
        'font_bundled': False, 'size': SIZE, 'frames': COUNT, 'fps': '60000/1001',
        'main_growth_stop_frame': MAIN_STOP, 'echo_invisible_frame': 24, 'fully_transparent_frame': END,
        'gif_pause_ms': 1000, 'echo_growth_stop_frame': 19, 'echo_fade_start_frame': 11,
        'colour_darkening_and_spatial_erosion': True,
        'production_assets_changed': False, 'game_package_created': False,
        'reference_comparison': comparison,
        'frames_timing': [timing(i) for i in range(COUNT)],
    }
    (OUTPUT/'preview.json').write_text(json.dumps(metadata, indent=2)+'\n', encoding='utf-8')
    print(f'Preview only: {OUTPUT}')


if __name__ == '__main__':
    main()
