"""Writes the #84 mode x difficulty AI trace cases: original menu inputs only (seed 2), Cinema,
3 enemies, then 420 frames of play with AI-package events and a focused snapshot every 70."""
import json
from pathlib import Path

# Game Settings stage coordinates (tools/measure_screen_art.py): mode cards, difficulty row.
MODES = {'arcade': (133, 180), 'kill': (276, 180), 'pac_man': (418, 180), 'green_zone': (560, 180)}
DIFFICULTIES = {'easy': (288, 428), 'normal': (416, 428), 'hard': (545, 428)}

for mode, (mx, my) in MODES.items():
    for difficulty, (dx, dy) in DIFFICULTIES.items():
        actions = [{'command': 'seed 2'}, {'command': 'step 301'}, {'command': 'click 349 440'}, {'command': 'step 240'},
                   {'command': 'click 569 203'}, {'command': 'step 30'}, {'command': f'click {mx} {my}'}, {'command': 'step 5'},
                   {'command': 'click 255 275'}, {'command': 'step 5'}, {'command': 'click 255 312'}, {'command': 'step 5'},
                   {'command': f'click {dx} {dy}'}, {'command': 'step 10'}, {'command': 'click 470 389'}, {'command': 'step 2'},
                   {'command': 'click 335 356'}, {'command': 'step 2', 'capture': 'settings'},
                   {'command': 'click 533 477'}, {'command': 'step 40'}, {'command': 'click 528 475'},
                   {'observe_command': 'events events 200000 zlong.bombit5.gameengine.ai'},
                   {'command': 'step 81', 'capture': 'opening-board'}]
        for index in range(6):
            actions.append({'command': 'step 70', 'capture': f'play-{index + 1:02d}'})
        actions.append({'observe_command': 'events off'})
        name = f'ai-{mode.replace("_", "-")}-{difficulty}'
        Path(__file__).with_name(name + '.json').write_text(json.dumps({'name': name, 'actions': actions}, indent=1) + '\n')
