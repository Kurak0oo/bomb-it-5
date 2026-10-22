"""The workbench's named slots, read from catalog.json. tests/art_catalog_check.gd keeps that
file equal to scripts/art/catalog.gd (`WRITE_CATALOG=1` regenerates it)."""
import json

from common import ROOT

CATALOG_JSON = ROOT / 'tools' / 'art_pipeline' / 'catalog.json'
CONFIG_JSON = ROOT / 'tools' / 'art_pipeline' / 'config.json'
DIRECTIONS = ['Down', 'Right', 'Up', 'Left']  # Workbench row order for four-row sheets.


def entries():
    return [{'id': e['id'], 'category': e['category'], 'size': tuple(e['size'])}
            for e in json.loads(CATALOG_JSON.read_text(encoding='utf-8'))]


def check_against_catalog():
    """Every catalogue slot needs a source decision in config.json (null = no SWF art)."""
    listed = {e['id'] for e in entries()}
    configured = set(json.loads(CONFIG_JSON.read_text(encoding='utf-8'))['slots'])
    problems = [f'{slot} has no config.json source entry' for slot in sorted(listed - configured)]
    problems += [f'config.json slot {slot} is not in the catalogue' for slot in sorted(configured - listed)]
    return problems


def find(slot):
    return next((e for e in entries() if e['id'] == slot), None)
