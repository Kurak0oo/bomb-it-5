"""Writes stage-opening cases: menu → settings (mode, 1 player, 3 enemies, 5 levels,
chosen arena, difficulty) → character → opening board. Input only, optional seed."""
import json, sys
from pathlib import Path

ARENA_Y = {"birthday_party": 211, "candy_factory": 240, "zoo": 269, "luxury_stores": 298,
           "magic_library": 327, "cinema": 356, "random": 385}
MODE_X = {"arcade": 140, "kill": 285, "pac_man": 430, "green_zone": 568}
DIFF_X = {"easy": 287, "normal": 415, "hard": 543}


def opening(name, mode="arcade", arena="cinema", difficulty="normal", seed=None, after=()):
    actions = [{"command": f"seed {seed}"}] if seed else []
    actions += [
        {"command": "step 301"}, {"command": "click 349 440"}, {"command": "step 240"},
        {"command": "click 569 203"}, {"command": "step 30"},
        {"command": f"click {MODE_X[mode]} 180"}, {"command": "step 5"},
        {"command": "click 255 275"}, {"command": "step 5"},
        {"command": "click 255 312"}, {"command": "step 5"},
        {"command": f"click {DIFF_X[difficulty]} 428"}, {"command": "step 10"},
        {"command": "click 470 389"}, {"command": "step 2"},
        {"command": f"click 335 {ARENA_Y[arena]}"}, {"command": "step 2", "capture": "settings"},
        {"command": "click 533 477"}, {"command": "step 40", "capture": "character"},
        {"command": "click 528 475"}, {"command": "step 81", "capture": "opening-board"},
    ]
    actions += list(after)
    origin = "Input-only menu path to a chosen mode/arena/difficulty opening" + (f" with original-RNG seed {seed}" if seed else "")
    return {"name": name, "origin": origin, "actions": actions}


if __name__ == "__main__":
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent
    for arena in ARENA_Y:
        if arena == "random":
            continue
        for seed in (11, 22, 33, 44, 55, 66):
            case = opening(f"arcade-{arena}-seed{seed}", arena=arena, seed=seed)
            (out / f"arcade-{arena}-seed{seed}.json").write_text(json.dumps(case, indent=2) + "\n")
