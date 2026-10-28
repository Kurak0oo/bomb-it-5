# Original pack from the SWF (#73)

Built on the user's machine, 2026-10-28, from the recorded publisher build
`agame-bomb-it-5-zh-fix.swf` (sha256 `718c04c7…0408a2`).

```
python tools/art_pipeline/original_pack.py --swf ~/Downloads/agame-bomb-it-5-zh-fix.swf
```

- FFDec 26.3.0 export, manifest `unresolved_sources: []`, 5056 assets kept.
- 112 slot sheets in 108 s, 0 failed, 0 empty; `original/active.json` written.
- Nothing under `original/` is tracked; the pack stays on this machine.

## Captures

`tools/capture_game.gd` with Godot 4.5 (`4.5.stable.official.876b29033`) at 1280×720,
`original` profile, seed 42, one human against three AI on Magic Library.

- [match](match.png): original robot art and HUD portraits, the spellbook centrepiece,
  original pickups, bombs and chrome. Stage floors, walls and blocks are still native
  because those slots have no source (#74).
- [results](results.png): the same pack art through the result screen.

The control hint still reads "Eight directions · equal speed" under the original
profile, which is an adapted claim; it is listed for #74/#77 follow-up.
