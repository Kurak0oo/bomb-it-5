# Expand delivery to the complete edition 5 game

Accepted on 2026-10-21 at the user's request. This widens the first build's
single-map Normal Arcade scope.

The runnable build is one fixed Cinema board in Normal Arcade, which is a playable
arena for testing rather than the game. The user wants the complete edition 5
game: every selectable mode (Arcade, Kill, Green Zone, Pac-Man), the menu,
settings, character select, How to Play, key rebinding, pause and score screens,
all six stage sets with level progression, three difficulties and the cloth and
hat unlocks. The user chose to deliver the four modes together rather than Arcade
first, and asked that future modes, maps, rules and enemy designs stay easy to add.

Modes are therefore rule modules on the existing admitted round, as the original
"replaceable ending" decision anticipated. A mode supplies its ending, settings,
pickups, drop table and respawn; maps are data; enemy behavior is an AI profile.
Keeping one round and one scheduler preserves the accepted pause, input and
batch-timing guarantees in every mode, and lets a new mode or map arrive without
touching gameplay phases. The alternative, a separate loop per mode, would copy
the original class-per-mode structure but duplicate the guarantees and their tests.

Consequences:

- Mode rules, stage data, difficulty tuning and unlock conditions must be
  recovered from the SWF before implementation, as with Arcade. Arcade on Normal
  has the strongest evidence; Kill, Green Zone, Pac-Man, Easy/Hard and unlocks
  need recovery work, which delivering all four together puts up front.
- Unlocks add local save data. There are still no accounts or networking.
- Local 2-player and MORE GAMES are excluded. Co-op across phones, then PvP,
  remain the later multiplayer order.
- Issue #21 stays the final desktop acceptance gate, now blocked by the new
  specification's tickets as well as by #20.

[DESIGN.md](../../DESIGN.md) owns the current scope.
