"""Lists the props of a Pac-Man opening capture (focus Grid slot 3): coin and item counts,
the non-coin cells, and the empty floor cells. Usage: pac_props.py RUN_DIR (prints JSON)."""
import json, sys, collections
from pathlib import Path
run = Path(sys.argv[1])
focus = json.loads((run / "opening-board.json").read_text())
props = {}
for cell in focus["cells"]:
    p = cell["grid"]["values"].get("3")
    if p: props[(cell["x"], cell["y"])] = p.get("class", "?").split("::")[-1] if isinstance(p, dict) else str(p)
count = collections.Counter(props.values())
items = {f"{x},{y}": k for (x, y), k in props.items() if k != "CoinProp"}
floor = sum(1 for c in focus["cells"] if c["grid"]["values"].get("1") is None and c["grid"]["values"].get("13") not in (2, 3) and 0 < c["x"] < 16 and 0 < c["y"] < 14)
print(json.dumps({"layout_world": focus["world_set"]["class"].split("::")[-1], "mode": focus["mode"]["class"].split("::")[-1],
                  "prop_counts": count, "non_coin_props": items, "empty_floor_cells": floor}, indent=1))
