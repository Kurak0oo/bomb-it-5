# Quality switch (#86)

Authority build `agame-bomb-it-5-zh-fix.swf` (sha256 `718c04c7…0408a2`). Static source from the
FFDec 26.3.0 script export.

## Source

- **Where.** `MainMenuUI` and `PauseUI` each have a `quality` switch, a three-frame clip
  (sprite 3797): frame 1 is HIGH, frame 2 MEDIUM, frame 3 LOW.
- **Cycling.** `qualityCtlHandle` moves to the next frame, from 3 back to 1, and sets
  `stage.quality` and `GameModel.quality` to `StageQuality.HIGH`, `MEDIUM` or `LOW`.
- **Default.** `MainMenuUI.initView` sets HIGH when `GameModel.quality` is null.
  `GameConfig.DEFAULT_QUALITY` is HIGH but nothing reads it.
- **Persistence.** The level lives in the static `GameModel.quality`, not in `Cookie`. It
  lasts for the session and is lost on reload.
- **A no-op on open.** On opening, both screens compare `stage.quality == …` instead of
  assigning it. Only the switch changes the stage quality.
- The sound and music switches (sprites 3802 and 3807) use frame 1 for on and frame 2 for
  off. Frame 3 repeats frame 2.

Flash `StageQuality` levels:

| Level | Shapes | Bitmaps |
| --- | --- | --- |
| HIGH | anti-aliased (4×4 grid) | smoothed |
| MEDIUM | anti-aliased (2×2 grid) | not smoothed |
| LOW | not anti-aliased | not smoothed |

## Port

`scripts/quality.gd` keeps the level in a static variable, so it lasts for the session and
is not saved. It cycles in the same order and starts at HIGH.

The game uses the Compatibility renderer, which has no 2D multisampling: GLES3 warns
"2D MSAA is not yet supported", and FXAA has no 2D effect. So each level maps onto what
that renderer can vary:

- **Bitmaps:** the viewport's default canvas texture filter. HIGH is linear; MEDIUM and LOW
  are nearest.
- **Shapes:** the antialiased flag that every procedural line and arc passes
  (`Quality.edges`). It is on for HIGH and MEDIUM and off for LOW.

MSAA is still requested on renderers that support it.

The switches on the main menu and the pause screen draw the original frames from the pack
(`ui.quality_switch`, `ui.sound_switch`, `ui.music_switch`) at the measured instance
positions. The capture
[quality-levels.png](../verification/quality-2026-10-29/quality-levels.png) shows the three
levels in a round at 3× zoom:

- board sprites are smoothed only at HIGH;
- the touch stick's ring is anti-aliased at HIGH and MEDIUM and stair-stepped at LOW.
