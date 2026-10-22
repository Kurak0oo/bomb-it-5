"""Compact per-capture summaries of the stage-feature runs (engine tick = 20 + 7 x capture
index; the opening capture is at tick 20). Usage: summarize.py RUNS_DIR OUT_DIR."""
import json, sys
from pathlib import Path

TRACK = [(8, 9), (8, 10), (8, 11), (9, 11), (10, 11), (11, 11), (12, 11), (12, 10), (12, 9), (12, 8), (12, 7),
         (12, 6), (12, 5), (12, 4), (12, 3), (11, 3), (10, 3), (9, 3), (8, 3), (7, 3), (6, 3), (5, 3), (4, 3),
         (4, 4), (4, 5), (4, 6), (4, 7), (4, 8), (4, 9), (4, 10), (4, 11), (5, 11), (6, 11)]


def named(layouts, record):
    slots = {str(s["slot"]): s["aliases"][0][0] for s in layouts.get(record.get("class"), {}).get("slots", [])}
    return {slots.get(k, k): v for k, v in record.get("values", {}).items()}


def captures(run):
    order = [a["capture"] for a in json.loads((run / "case.json").read_text())["actions"] if "capture" in a]
    names = [n for n in order if n.startswith("f") or n == "opening-board"]
    for index, name in enumerate(names):
        path = run / f"{name}.json"
        if path.exists():
            yield 20 + 7 * index, json.loads(path.read_text())


def features(focus, cls):
    out = []
    for entry in focus.get("platforms", {}).values():
        if entry["record"]["class"].endswith(cls):
            out.append((entry["x"], entry["y"], named(focus["layouts"], entry["record"])))
    return sorted(out, key=lambda e: (e[0], e[1]))


def props(focus):
    return {(c["x"], c["y"]): c["grid"]["values"]["3"]["class"].split("::")[-1]
            for c in focus["cells"] if isinstance(c["grid"]["values"].get("3"), dict)}


def bombs(focus):
    out = []
    for record in focus["bombs"].values():
        v = named(focus["layouts"], record)
        adder = v.get("_bombAdder")
        out.append({"cell": [v.get("_xN"), v.get("_yN")], "fuse": v.get("_blastTime"),
                    "adder": (adder or {}).get("class", "").split("::")[-1] if isinstance(adder, dict) else None})
    return out


def frame(value):
    return value.get("display", {}).get("current_frame") if isinstance(value, dict) else None


runs, out = Path(sys.argv[1]), Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
rows = []
for tick, focus in captures(runs / "zoo-idle"):
    rows.append({"tick": tick, "crocodiles": [[x, y, v["_currState"], v["_currFrame"], v["isDanger"], frame(v.get("_mc"))]
                                              for x, y, v in features(focus, "Crocodile")]})
(out / "zoo-crocodiles.json").write_text(json.dumps(rows) + "\n")
rows = []
for tick, focus in captures(runs / "birthday-idle"):
    rows.append({"tick": tick, "hands": [[x, y, v["_direction"], v["_state"], v["_currFrame"], v["_totalFrame"], v["_pushStep"],
                                          frame(v.get("_handMc"))] for x, y, v in features(focus, "ToyHand")]})
(out / "birthday-toy-hands.json").write_text(json.dumps(rows) + "\n")
rows = []
for tick, focus in captures(runs / "candy-idle"):
    belt = features(focus, "ConveyorBelt")[0][2]
    on_track = {cell: kind for cell, kind in props(focus).items() if cell in TRACK}
    rows.append({"tick": tick, "build_frame": belt["_totalFrame"],
                 "track_props": sorted([TRACK.index(cell), kind] for cell, kind in on_track.items())})
(out / "candy-belt.json").write_text(json.dumps(rows) + "\n")
rows = []
for tick, focus in captures(runs / "magic-idle"):
    rows.append({"tick": tick, "spellbook_bombs": [b for b in bombs(focus) if b["adder"] == "Spellbook"]})
(out / "magic-spellbook.json").write_text(json.dumps(rows) + "\n")
