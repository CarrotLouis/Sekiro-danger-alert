"""Preview timing, alpha and smooth-glow checks without game or private font data."""
import importlib.util
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('preview_effect', ROOT/'scripts/preview_effect.py')
preview = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preview)

states = [preview.timing(i) for i in range(preview.COUNT)]
assert all(states[i]['main_scale'] < states[i+1]['main_scale'] for i in range(preview.PEAK))
assert all(s['main_scale'] == 1 for s in states[preview.PEAK:]), 'no growth during fade'
assert all(states[i]['main_opacity'] > states[i+1]['main_opacity'] for i in range(preview.PEAK, preview.END))
assert states[preview.PEAK]['main_opacity'] == 1
assert states[preview.END]['main_opacity'] == 0
assert states[6]['echo_scale']/states[6]['main_scale'] > 1.8
assert states[4]['echo_opacity'] > .2
assert all(s['echo_opacity'] == 0 for s in states[24:]), 'echo must disappear before main'
assert abs(sum(preview.gif_durations())-preview.COUNT/preview.FPS*1000) < 5
assert preview.COUNT/preview.FPS < .835

# A synthetic glyph makes these checks independent of the non-redistributable font.
glyph = Image.new('L', (90, 100))
draw = ImageDraw.Draw(glyph)
draw.rectangle((10, 10, 80, 25), fill=255)
draw.rectangle((35, 25, 55, 90), fill=255)
renderer = preview.Renderer(glyph, size=128, supersample=2)
peak = np.asarray(renderer.frame(preview.PEAK))
assert not peak[0, :, 3].any() and not peak[-1, :, 3].any()
assert not peak[:, 0, 3].any() and not peak[:, -1, 3].any()
assert len(np.unique(peak[:, :, 3])) > 150, 'halo needs a continuous range of alpha levels'
assert ((peak[:, :, 3] > 0) & (peak[:, :, 3] < 40)).sum() > 1000
energies = []
for frame in (24, 32, 40, 46, 49):
    rgba = np.asarray(renderer.frame(frame), dtype=float)/255
    rgb = rgba[:, :, :3]*rgba[:, :, 3:]
    energies.append(rgb.sum())
    assert np.isfinite(rgba).all()
assert all(a > b for a, b in zip(energies, energies[1:])), 'rendered tail must keep fading'
assert energies[-2]/energies[0] < .035
assert energies[-1] == 0
assert not np.asarray(renderer.frame(49)).any()

# Straight alpha must reconstruct the emitted light on black without dark fringes.
source = np.array([[[.23, .08, .09], [0., 0., 0.]]], dtype=np.float32)
rgba = np.asarray(preview.rgba_from_light(source), dtype=float)/255
assert np.max(np.abs(rgba[:, :, :3]*rgba[:, :, 3:]-source)) < 2/255
assert not rgba[0, 1].any()
print('PASS preview-only two-layer timing, frozen fade geometry, smooth alpha and 50-frame duration')
