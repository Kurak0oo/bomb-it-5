# Permit eight-direction phone movement

Accepted on 2026-10-19 as the user's replacement for Q17's four-direction recommendation. The phone stick will support the four cardinal and four diagonal movement directions. This deliberately departs from the original's cardinal controller path; [the movement evidence](../evidence/edition-5-movement-and-board.md) separately records that the original already moves continuously within cells.

The user prefers diagonal control on the phone and explicitly recognizes that diagonal routes can change difficulty. This makes exact cardinal movement parity subordinate to the accepted phone adaptation. [DESIGN.md](../../DESIGN.md) owns the accepted requirement, and the development frontier owns unresolved control-feel questions.

The user subsequently accepted Q19–Q21: normalize diagonals to the same top speed as straight travel, preserve full-footprint blocking with wall sliding and no blocked-corner shortcuts, and give later AI the same movement capability/collision rules. This removes the accidental two-axis speed advantage and exclusive player access to diagonals while retaining the deliberate route/balance change. It does not claim the original difficulty is preserved.

Q23–Q25 then settle fixed visible anchoring with responsive visual feedback, normal-speed requests outside the deadzone, and departure from any currently overlapping bomb followed by blocked re-entry once clear. The user rejects Q22's early phone prototype: publication-ready main Godot development comes first, then physical phone/iOS testing. Development must not block on early phone evaluation or silently copy another game's sprint/deflection model.

Q26 clarifies that the deliverable is the whole runnable Godot 4.5 game; practice is only an intermediate milestone. The user does not thereby approve the earlier exact acceleration/heading-response proposal. Q27–Q28 accept collision-safe corridor assistance within the movement budget and the corrected recorded CinemaStage1 layout with working paired portals. The source supplies the movement baseline; detailed tuning and AI decision behavior remain implementation/design work for the complete game.
