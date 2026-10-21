"""Summarizes focus captures of a mode run: per capture, the game clock and each
player's life, kill and point fields with its robot's existence, state, weapon and
cell. Usage: summarize.py RUN_DIR [RUN_DIR...] (prints JSON)."""
import json, sys
from pathlib import Path


def named(layouts, obj):
    slots = {str(s["slot"]): s["aliases"][0][0] for s in layouts.get(obj.get("class"), {}).get("slots", [])}
    return {slots.get(k, k): v for k, v in obj.get("values", {}).items()}


def summarize_capture(path):
    focus = json.loads(path.read_text())
    if "layouts" not in focus or not focus.get("game"):
        return None
    layouts = focus["layouts"]
    game = named(layouts, focus["game"])
    players = []
    for player, robot in zip(focus["players"], focus["robots"]):
        p = named(layouts, player)
        model = named(layouts, robot["model"])
        body = named(layouts, robot["robot"])
        players.append({
            "name": p.get("_name"), "robot": p.get("_robotID"), "life": p.get("_life"),
            "kills": p.get("_killNum"), "level_point": p.get("_levelPoint"), "coins": p.get("_coinsNum"),
            "item_point": p.get("_itemPoint"), "exists": body.get("isExist"), "state": model.get("state"),
            "weapon": model.get("weapon"), "vehicle": model.get("vehicle"),
            "cell": [model.get("currentX"), model.get("currentY")],
            "base_weapon": (body.get("_baseWeapon") or {}).get("class", "").split("::")[-1] or None,
        })
    return {"capture": path.stem, "past_time": game.get("pastTime"), "game_over": game.get("gameOver"),
            "ending": focus.get("ending") is not None, "players": players}


if __name__ == "__main__":
    runs = []
    for run in sys.argv[1:]:
        manifest = json.loads((Path(run) / "case.json").read_text())
        order = [a["capture"] for a in manifest["actions"] if "capture" in a]
        captures = [summarize_capture(Path(run) / f"{name}.json") for name in order if (Path(run) / f"{name}.json").exists()]
        runs.append({"run": Path(run).name, "captures": [c for c in captures if c]})
    print(json.dumps(runs, indent=1))
