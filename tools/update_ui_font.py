"""Regenerate the UI font subset from a licensed full Noto Sans SC font."""
import argparse
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools import subset

PROJECT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path, help='Path to the full NotoSansSC.ttf')
args = parser.parse_args()
text = ''.join(path.read_text() for path in (PROJECT / 'lib').rglob('*.dart'))
text += ''.join(path.read_text() for path in (PROJECT / 'assets/legal').glob('*.html'))
text += '取景0123456789%°·…→—，。！？：（）/ iOS ANDROID'
font = TTFont(args.source)
font = instantiateVariableFont(font, {'wght': 400}, inplace=True)
options = subset.Options()
options.name_IDs = ['*']
options.name_legacy = True
subsetter = subset.Subsetter(options=options)
subsetter.populate(text=text)
subsetter.subset(font)
output = PROJECT / 'assets/fonts/FrameSans-Regular.ttf'
font.save(output)
print(f'Updated UI font: {len(set(text))} characters, {output.stat().st_size} bytes')
