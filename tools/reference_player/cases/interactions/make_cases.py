"""Writes the #83 interaction cases: a stage opening with the AI stopped, an original-method
fixture to set the scene, then idle or scripted input with a focus trace every frame."""
import json, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "stages"))
from make_cases import opening  # noqa: E402

STOP_AI = [{"fixture": {"op": "ai-control", "actor": actor, "mode": "stop"}} for actor in (1, 2, 3)]


def traced(steps, label):
    return [{"observe_command": f"trace-focus {label}-trace"}, *steps, {"observe_command": "trace-focus off"}]


CASES = {
    # Belt ride: stand on the down run above the first corner and idle (ConveyorBelt.robotMove).
    "belt-ride": dict(arena="candy_factory", seed=11, after=STOP_AI + [
        {"fixture": {"op": "reposition", "x": 8, "y": 10}},
        *traced([{"command": "step 180", "capture": "belt-ride"}], "belt")]),
    # Toy hand push: stand in the right hand's reach at (12,7), box behind at (13,7) on seed 11
    # (BirthdayPartyStage2), and idle through its next opening (ToyHand.handPushSetting).
    "toy-hand-push": dict(arena="birthday_party", seed=11, after=STOP_AI + [
        {"fixture": {"op": "reposition", "x": 12, "y": 7}},
        *traced([{"command": "step 760", "capture": "toy-hand"}], "hand")]),
    # Crocodile bite: Zoo seed 11 has a crocodile at (8,11) with free (8,12) below. The AI are
    # stopped 50 frames into the round, before their first bombs, so no elimination ends it;
    # then walk up onto the crocodile and wait through its cycle (Crocodile.as).
    "crocodile-bite": dict(arena="zoo", seed=11, early_stop=True, after=[
        {"fixture": {"op": "reposition", "x": 8, "y": 12}},
        *traced([{"command": "kd up"}, {"command": "step 9"}, {"command": "ku up"},
                 {"command": "step 391", "capture": "crocodile"}], "croc")]),
    # Horse jump: Birthday Party seed 11 (layout 2) has (3,9) free, a box at (4,9) and (5,9) free.
    "horse-jump": dict(arena="birthday_party", seed=11, early_stop=True, after=[
        {"fixture": {"op": "reposition", "x": 3, "y": 9}},
        {"fixture": {"op": "pickup", "kind": "horse"}},
        *traced([{"command": "step 10"}, {"command": "kd right"}, {"command": "step 40"}, {"command": "ku right"},
                 {"command": "step 10", "capture": "horse"}], "horse")]),
    # Dragon crash: Zoo seed 11 (layout 2) has a soft block at (3,1) with (2,1) free.
    "dragon-crash": dict(arena="zoo", seed=11, early_stop=True, after=[
        {"fixture": {"op": "reposition", "x": 2, "y": 1}},
        {"fixture": {"op": "pickup", "kind": "dragon"}},
        *traced([{"command": "step 10"}, {"command": "kd right"}, {"command": "step 40"}, {"command": "ku right"},
                 {"command": "step 30", "capture": "dragon"}], "dragon")]),
    # Pac-Man catch: Cinema seed 11, ghosts stopped at their corners; the player takes an
    # Invincibility pickup one cell along (its coin eaten) and runs along row 1 into the top-right ghost.
    "pac-man-catch": dict(mode="pac_man", arena="cinema", seed=11, early_stop=True, after=[
        {"command": "kd right"}, {"command": "step 9"}, {"command": "ku right"}, {"command": "step 4"},
        {"fixture": {"op": "pickup", "kind": "invincibility"}},
        *traced([{"command": "step 30"}, {"command": "kd right"}, {"command": "step 120"}, {"command": "ku right"},
                 {"command": "step 50", "capture": "pac-man"}], "pac")]),
}


if __name__ == "__main__":
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent
    for name, spec in CASES.items():
        case = opening(name, mode=spec.get("mode", "arcade"), arena=spec["arena"], seed=spec.get("seed"), after=spec["after"])
        if spec.get("early_stop"):
            # Split the opening's final 81-frame step to stop the AI before they act.
            index = next(i for i, action in enumerate(case["actions"]) if action.get("command") == "step 81")
            case["actions"][index:index + 1] = [{"command": "step 62", "capture": "early"}, *STOP_AI, {"command": "step 19", "capture": "opening-board"}]
        case["origin"] += "; AI stopped, scene set by original-method fixtures, focus-traced (#83)"
        (out / f"{name}.json").write_text(json.dumps(case, indent=2) + "\n")
