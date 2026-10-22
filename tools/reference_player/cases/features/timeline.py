"""Per capture, each map-feature object's scalar slots and movie-clip frames, plus each
robot's cell, state and existence. Usage: timeline.py RUN_DIR (prints JSON lines)."""
import json, sys
from pathlib import Path


def named(layouts, record):
    slots = {str(s["slot"]): s["aliases"][0][0] for s in layouts.get(record.get("class"), {}).get("slots", [])}
    return {slots.get(k, k): v for k, v in record.get("values", {}).items()}


def compact(value):
    if isinstance(value, dict):
        if "display" in value:
            return {"frame": value["display"].get("current_frame"), "x": value["display"].get("x"), "y": value["display"].get("y")}
        if "point" in value:
            return value["point"]
        if "elements" in value:
            return [compact(v) for v in value["elements"]]
        return value.get("class")
    return value


run = Path(sys.argv[1])
order = [a["capture"] for a in json.loads((run / "case.json").read_text())["actions"] if "capture" in a]
for name in order:
    path = run / f"{name}.json"
    if not path.exists():
        continue
    focus = json.loads(path.read_text())
    if not focus.get("available"):
        continue
    layouts = focus["layouts"]
    features = []
    for entry in focus.get("platforms", {}).values():
        record = entry["record"]
        values = {k: compact(v) for k, v in named(layouts, record).items() if k not in ("target", "dispatchList", "game", "map", "_mainContainer")}
        features.append({"x": entry["x"], "y": entry["y"], "class": record["class"].split("::")[-1], "values": values})
    robots = []
    for robot in focus["robots"]:
        model = named(layouts, robot["model"])
        body = named(layouts, robot["robot"])
        robots.append({"cell": [model.get("currentX"), model.get("currentY")], "state": model.get("state"), "exists": body.get("isExist")})
    print(json.dumps({"capture": name, "features": features, "robots": robots}))
