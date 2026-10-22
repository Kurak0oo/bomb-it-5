"""Writes stage-feature observation cases: an Arcade (or given mode) opening on one set,
then the player idles while captures repeat every EVERY frames. Input only."""
import json, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "stages"))
from make_cases import opening  # noqa: E402

CASES = {
    # name: (mode, arena, captures, every)
    "zoo-idle": ("arcade", "zoo", 120, 7),
    "birthday-idle": ("arcade", "birthday_party", 120, 7),
    "candy-idle": ("arcade", "candy_factory", 120, 7),
    "magic-idle": ("arcade", "magic_library", 120, 7),
    "magic-pac-idle": ("pac_man", "magic_library", 60, 35),
    "birthday-pac-idle": ("pac_man", "birthday_party", 60, 35),
}


def periodic(captures, every):
    return [{"command": f"step {every}", "capture": f"f{index:03d}"} for index in range(1, captures + 1)]


if __name__ == "__main__":
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent
    for name, (mode, arena, captures, every) in CASES.items():
        case = opening(name, mode=mode, arena=arena, after=periodic(captures, every))
        case["origin"] += f"; then idle, capturing every {every} frames"
        (out / f"{name}.json").write_text(json.dumps(case, indent=2) + "\n")
