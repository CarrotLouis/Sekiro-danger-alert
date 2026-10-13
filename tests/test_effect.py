"""Validate the approved effect native colour basis, frames and stable scale."""
import importlib.util
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('import_effect', ROOT/'scripts/import_effect.py')
effect = importlib.util.module_from_spec(spec)
spec.loader.exec_module(effect)
metadata = json.loads((ROOT/'assets/effect.json').read_text())
assert metadata['approved_revision'] == 'R2'
assert metadata['font_family'] == 'HakusyuGyosyoExtraBold' and not metadata['font_bundled']
assert metadata['frames'] == 50 and metadata['texture_size'] == 512
assert len(metadata['source_frames']) == 50 and metadata['colours'] == effect.COLOURS
assert abs(metadata['quad_ratio_to_v020']*.35 - .38*300/512) < 1e-8
rgb = np.sort(np.random.default_rng(42).random((64, 64, 3)), axis=2)[:, :, ::-1].copy()
mask = effect.encode(rgb)
assert np.max(np.abs(effect.decode(mask)-rgb)) < 1.6/255
alpha = np.clip(np.asarray(mask, dtype=float)[:, :, :3].sum(axis=2)/255, 0, 1)
assert np.max(np.abs(alpha-rgb[:, :, 0])) < 1.6/255
energies = []
for i in range(50):
    frame = Image.open(ROOT/f'assets/frames/{i:03}.png').convert('RGBA')
    pixels = np.asarray(frame)
    assert frame.size == (512, 512) and pixels[:, :, 3].min() == 255
    decoded = effect.decode(frame)
    assert not decoded[:2].any() and not decoded[-2:].any()
    assert not decoded[:, :2].any() and not decoded[:, -2:].any()
    energies.append(float(decoded.sum()))
assert energies[0] > 0 and energies[46] > 0 and energies[49] == 0
assert all(energies[i] > energies[i+1] for i in range(29, 49))
print('PASS approved R2 masks, exact RGB/alpha basis, 50 frames, transparent tail and baseline glyph scale')
