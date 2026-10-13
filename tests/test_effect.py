"""Validate source effect assets and shader reconstruction, without running the game."""
import importlib.util
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('render_effect', ROOT/'scripts/render_effect.py')
effect = importlib.util.module_from_spec(spec)
spec.loader.exec_module(effect)
metadata = json.loads((ROOT/'assets/effect.json').read_text())
assert metadata['font_family'] == 'HakusyuGyosyoExtraBold'
assert metadata['font_bundled'] is False
assert metadata['frames'] == 48 and metadata['texture_size'] == 512
assert np.array_equal(effect.noise(1), effect.noise(1)), 'noise must be reproducible'
for i in range(48):
    frame = Image.open(ROOT/f'assets/frames/{i:03}.png').convert('RGBA')
    pixels = np.asarray(frame)
    assert frame.size == (512, 512)
    assert pixels[:, :, 2].max() == 0 and pixels[:, :, 3].min() == 255
    rgba = np.asarray(effect.composite(frame))
    assert not rgba[:2, :, 3].any() and not rgba[-2:, :, 3].any(), 'glow must not be clipped at canvas edges'
    if i in (0, 47): assert not rgba[:, :, 3].any(), 'first/last frames should be transparent'
peak = np.asarray(Image.open(ROOT/'assets/frames/012.png'))[:, :, :2]
assert peak.max() > 100 and (peak[:, :, 1] > 30).sum() > 1000
assert not np.array_equal(peak, np.asarray(Image.open(ROOT/'assets/frames/024.png'))[:, :, :2])
print('PASS font effect metadata, 48 higher-resolution shader masks, evolving highlights and transparent boundaries')
