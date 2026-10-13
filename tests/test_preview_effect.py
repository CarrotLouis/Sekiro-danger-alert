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
assert all(states[i]['main_scale'] < states[i+1]['main_scale'] for i in range(preview.MAIN_STOP))
assert all(s['main_scale'] == 1 for s in states[preview.MAIN_STOP:])
early = states[19]['main_scale']-states[0]['main_scale']
late = states[34]['main_scale']-states[19]['main_scale']
assert early > late*5 and late > 0, 'fast initial growth must continue as a slow tail'
steps = np.diff([s['main_scale'] for s in states[:35]])
assert all(steps[i] > steps[i+1] for i in range(len(steps)-1)), 'growth must decelerate'
assert all(states[i]['whiteness'] > states[i+1]['whiteness'] for i in range(49))
assert all(states[i]['main_brightness'] >= states[i+1]['main_brightness'] for i in range(49))
assert states[0]['main_opacity'] == 1 and states[49]['main_opacity'] == 0
assert all(states[i]['echo_scale'] < states[i+1]['echo_scale'] for i in range(19))
assert all(states[i]['echo_opacity'] > states[i+1]['echo_opacity'] for i in range(11,24))
assert all(s['echo_scale'] == states[19]['echo_scale'] for s in states[19:])
assert all(s['echo_opacity'] == 0 for s in states[24:])
assert states[6]['glow'] > states[0]['glow'] > states[33]['glow'] > states[49]['glow']
edge_and_core = preview.erosion_mask(np.array([.45, 1., 1.]), np.array([.5, .2, .8]), .8)
assert edge_and_core[0] < edge_and_core[1] < edge_and_core[2], 'edge-first and spatially varied erosion'
assert abs(sum(preview.gif_durations())-preview.COUNT/preview.FPS*1000) < 5
assert preview.COUNT/preview.FPS < .835

# A synthetic glyph makes these checks independent of the non-redistributable font.
glyph = Image.new('L', (90, 100))
draw = ImageDraw.Draw(glyph)
draw.rectangle((10, 10, 80, 25), fill=255)
draw.rectangle((35, 25, 55, 90), fill=255)
renderer = preview.Renderer(glyph, size=128, supersample=2)
peak = np.asarray(renderer.frame(6))
assert not peak[0, :, 3].any() and not peak[-1, :, 3].any()
assert not peak[:, 0, 3].any() and not peak[:, -1, 3].any()
assert len(np.unique(peak[:, :, 3])) > 150, 'halo needs a continuous range of alpha levels'
assert ((peak[:, :, 3] > 0) & (peak[:, :, 3] < 40)).sum() > 1000
energies = []
for frame in (29, 35, 41, 46, 49):
    rgba = np.asarray(renderer.frame(frame), dtype=float)/255
    rgb = rgba[:, :, :3]*rgba[:, :, 3:]
    energies.append(rgb.sum())
    assert np.isfinite(rgba).all()
assert all(a > b for a, b in zip(energies, energies[1:])), 'rendered tail must keep fading'
assert 0 < energies[-2]/energies[0] < .07, 'retain a faint eroded trace until the late tail'
assert energies[-1] == 0
assert not np.asarray(renderer.frame(49)).any()

# Straight alpha must reconstruct the emitted light on black without dark fringes.
source = np.array([[[.23, .08, .09], [0., 0., 0.]]], dtype=np.float32)
rgba = np.asarray(preview.rgba_from_light(source), dtype=float)/255
assert np.max(np.abs(rgba[:, :, :3]*rgba[:, :, 3:]-source)) < 2/255
assert not rgba[0, 1].any()
initial = np.asarray(renderer.frame(0), dtype=float)/255
late = np.asarray(renderer.frame(33), dtype=float)/255
for_colour = []
for rgba in (initial, late):
    rgb = rgba[:, :, :3]*rgba[:, :, 3:]
    bright = rgb[:, :, 0] > rgb[:, :, 0].max()*.8
    for_colour.append(float((rgb[:, :, 1][bright]/rgb[:, :, 0][bright]).mean()))
assert for_colour[0] > for_colour[1]*3, 'white-to-red shift is distinct from opacity fade'
print('PASS R2 decelerating growth, overlapping echo fade, colour change, edge-first erosion, dynamic glow and duration')
