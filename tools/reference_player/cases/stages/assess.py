"""Classifies an observed opening board (focus JSON) and matches it to the recorded
layout templates. Grid slots (focus `layouts`): 1 box, 6 platForm, 9 fixedBox,
11 unfixedBox, 13 _midBox, 23 conveyorBelt. Usage: assess.py RUN_DIR [RUN_DIR...]"""
import csv, json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
MAPS = ROOT / "docs/evidence/observations/swf-v1.6.1/maps"
WORLD = {"Cinema": "Cinema", "LuxuryStores": "LuxuryStores", "Zoo": "Zoo", "CandyFactory": "CandyFactory",
         "BirthdayParty": "BirthdayParty", "MagicLibrary": "MagicLibrary"}


def template(name):
    cells = {}
    with open(MAPS / f"{name}.csv") as handle:
        for row in csv.DictReader(handle):
            cells[(int(row["x"]), int(row["y"]))] = row["instance_name"]
    return cells


def kind(name):
    if name.startswith("unfixedProp"):
        return "candidate"
    if name.startswith("fixedProp") or name in ("centerProp", "holdProp"):
        return "solid"
    return "other"


def observe(run):
    focus = json.loads((Path(run) / "opening-board.json").read_text())
    world = focus["world_set"]["class"].split("::")[-1]
    observed = {}
    for cell in focus["cells"]:
        values = cell["grid"]["values"]
        box = values.get("1") is not None
        center = values.get("13") in (2, 3)
        if center:
            state = "solid"
        elif box and (values.get("9") or 0) > 0:
            state = "solid"
        elif box:
            state = "soft"
        else:
            state = "floor"
        observed[(cell["x"], cell["y"])] = {"state": state, "soft_chance": values.get("11"),
                                            "platform": (values.get("6") or {}).get("class")}
    return world, focus["mode"]["class"].split("::")[-1], observed


def assess(run):
    world, mode, observed = observe(run)
    pac = mode == "PacManMode"
    names = [f"{world}Stage_PacMan_{n}" if pac else f"{world}Stage{n}" for n in (1, 2, 3)]
    results = []
    for name in names:
        cells = template(name)
        mismatches = []
        for xy, instance in cells.items():
            seen = observed[xy]["state"]
            expected = kind(instance)
            if expected == "solid" and seen != "solid":
                mismatches.append([*xy, instance, seen])
            elif expected == "other" and seen == "soft":
                mismatches.append([*xy, instance, seen])
            elif expected == "candidate" and seen == "solid":
                mismatches.append([*xy, instance, seen])
        candidates = [xy for xy, instance in cells.items() if kind(instance) == "candidate"]
        soft = sum(observed[xy]["state"] == "soft" for xy in candidates)
        results.append({"layout": name, "mismatches": len(mismatches), "examples": mismatches[:5],
                        "candidates": len(candidates), "soft": soft})
    best = min(results, key=lambda result: result["mismatches"])
    chances = sorted({str(cell["soft_chance"]) for cell in observed.values() if cell["soft_chance"]})
    platforms = sorted({cell["platform"].split("::")[-1] for cell in observed.values() if cell["platform"]})
    return {"run": Path(run).name, "world": world, "mode": mode, "match": best["layout"],
            "mismatches": best["mismatches"], "soft": best["soft"], "candidates": best["candidates"],
            "soft_chances": chances, "platforms": platforms,
            "others": {r["layout"]: r["mismatches"] for r in results if r is not best}}


if __name__ == "__main__":
    print(json.dumps([assess(run) for run in sys.argv[1:]], indent=1))
