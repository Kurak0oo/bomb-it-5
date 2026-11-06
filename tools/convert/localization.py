"""Write the en-US text of every localised TextField (scenes/swf/localization.json).

    python tools/convert/localization.py

`NewTransText.updateText` (the `translation_*` clips) replaces its TextField's text with
`BrandingManager.getLocalizedObject(tf.name).value`; the branding system's strings are the
`localizedText` XML of `LocalizationPack`. The reference player has no branding system, so
the goldens keep the fields' authoring placeholders (`U_TOTAL SCORE:`, `R_ARCADE` ...).
The art pass loads this table into the reference player (`localize`, record_screen.py), which
replays updateText on the placeholder fields, so the art shows the en-US text; layout.py
writes it as those fields' `text` (the golden's as `golden_text`), and the comparison expects it.
Reads the decompiled AS3 in the ignored local pack (.scratch/as3).
"""
import html
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / '.scratch' / 'as3' / 'scripts' / 'LocalizationPack.as'
OUT = ROOT / 'scenes' / 'swf' / 'localization.json'
ITEM = re.compile(r'<item id="([^"]+)">(.*?)</item>', re.S)
EN_US = re.compile(r'<en-US[^>]*>(.*?)</en-US>', re.S)


def main() -> int:
    if not SOURCE.exists():
        print(f'missing {SOURCE.relative_to(ROOT)} (decompiled AS3)', file=sys.stderr)
        return 1
    text = SOURCE.read_text(encoding='utf-8')
    strings = {}
    for item_id, body in ITEM.findall(text):
        match = EN_US.search(body)
        if match:
            strings[item_id] = html.unescape(match.group(1))
    OUT.write_text(json.dumps({'source': 'LocalizationPack localizedText, en-US', 'strings': strings},
                              ensure_ascii=False, indent='\t', sort_keys=True) + '\n', encoding='utf-8')
    print(f'{len(strings)} strings -> {OUT.relative_to(ROOT)}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
