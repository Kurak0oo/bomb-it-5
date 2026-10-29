# Draw original screens as art plates with ghost and live widgets

Accepted on 2026-10-29 for the `original-replica` branch (#76). Reconstructed
from the header of `scripts/art/screen_layout.gd`, which cited this
record before it was committed; the original draft was not found in the repository.

The replica shows each full-screen page (menu, Game Settings, character select, How
to Play, score, dress-up, game over, game win) on the original screen art from the
ignored local pack. That art is a painted sheet: it already draws most buttons,
labels and frames, but it cannot show values that change at run time (key names,
scores, unlocked looks). The native widgets must keep working, with or without the
pack, so the menus, tests and accessibility of the flow do not depend on art the
repository cannot ship.

Each page therefore draws the sheet as a single plate, fitted to the 1280×720 page
height and centred, and keeps its native widgets on top in one of two roles:

- A **ghost** is a real button or label with its text, rectangle and hit test, drawn
  with transparent pixels because the sheet already paints that control (`baked`).
- A **live painter** draws itself over an opaque `plate` rectangle that hides the
  painted region it replaces, because the sheet cannot supply its value (`live`).

Where widgets go is a registration table (`ScreenLayout.PAGES`) measured from the
local sheets with `tools/inspect_screen_art.gd`, never chosen by eye. The pre-art
coordinates are pinned separately (`ScreenLayout.NATIVE`) so that a machine without
`original/` still checks the native fallback, and the art layout is checked against
its own table.

Rejected alternatives:

- Cutting every control out of the sheet into separate sprites: the sheets are flat
  captures, so most controls have no clean edges, and the cut-outs would be new
  derived art to maintain.
- Redrawing the screens natively in the original style: that is the art branches'
  work, not a replica.

Consequences:

- Without the pack every page falls back to the native drawing, unchanged.
- The tables carry measurements of original art but no art; nothing SWF-derived is
  committed.
- A page whose sheet is not yet measured has no table entry and uses the native
  coordinates even in art mode.
