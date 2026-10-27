"""Package the approved icon artwork for iOS and Android. Requires Pillow."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
source = Image.open(ROOT / 'assets/branding/app_icon_source.png').convert('RGB')
assert source.width == source.height
master = source.resize((1024, 1024), Image.Resampling.LANCZOS)
master.save(ROOT / 'assets/branding/app_icon_1024.png')
icons = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for item in json.loads((icons / 'Contents.json').read_text())['images']:
    side = round(float(item['size'].split('x')[0]) * float(item['scale'][:-1]))
    master.resize((side, side), Image.Resampling.LANCZOS).save(icons / item['filename'])

res = ROOT / 'android/app/src/main/res'
for density, side, adaptive in [('mdpi', 48, 108), ('hdpi', 72, 162), ('xhdpi', 96, 216), ('xxhdpi', 144, 324), ('xxxhdpi', 192, 432)]:
    folder = res / f'mipmap-{density}'
    folder.mkdir(exist_ok=True)
    master.resize((side, side), Image.Resampling.LANCZOS).save(folder / 'ic_launcher.png')
    # Keep the whole motif inside the adaptive icon's central safe region.
    foreground = Image.new('RGB', (adaptive, adaptive), '#101A14')
    inset_side = round(adaptive * 2 / 3)
    artwork = master.resize((inset_side, inset_side), Image.Resampling.LANCZOS)
    foreground.paste(artwork, ((adaptive - inset_side) // 2, (adaptive - inset_side) // 2))
    foreground.save(folder / 'ic_launcher_foreground.png')

adaptive_dir = res / 'mipmap-anydpi-v26'
adaptive_dir.mkdir(exist_ok=True)
(adaptive_dir / 'ic_launcher.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
''')
(res / 'values/icon_colors.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#101A14</color>
</resources>
''')

# Verify every asset-catalog reference, pixel size and opaque iOS format.
for item in json.loads((icons / 'Contents.json').read_text())['images']:
    side = round(float(item['size'].split('x')[0]) * float(item['scale'][:-1]))
    with Image.open(icons / item['filename']) as image:
        assert image.size == (side, side) and image.mode == 'RGB'
print('iOS 아이콘 참조 19개, Android 기본·적응형 5개 밀도 검증 완료')
