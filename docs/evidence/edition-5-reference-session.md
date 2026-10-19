# Independently reproduced original session

Verified locally on 2026-10-19 for [recovery #22](https://github.com/Kurak0oo/bomb-it-5/issues/22).
This supersedes the previous audit's statement that no independent playback had
been performed. It does not complete the subsequent behavior-recovery tickets.

## Authority and player

The authority is the publisher SWF at
`.scratch/edition-5-research/agame-bomb-it-5-zh-fix.swf`, 6,942,081 bytes,
SHA-256 `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2`.
It remains unchanged. No alternate HTML5 edition was loaded.

Built the supplied original harness against Ruffle revision
`45366370ed7d1a59c89aa3cf7b765c7a274407cd`, using its exact supplied dependency
lock, Rust/Cargo 1.97.0, MSVC x86-64 on Windows NT 10.0.26200.0, profile `ci`.
The baseline changes only the workspace membership/lock and adds the supplied
probe package; core and renderer are unchanged. Its executable SHA-256 is
`848250e92912794cd7b1d32b0b3567a22ec96f4afc4b59e8bd23e1b9c328a07f`.
[Build identity and source/lock hashes](reference-2026-10-19/baseline-build.json)
are retained separately from the later
[observer build](reference-2026-10-19/observer-build.json).

Rendering uses Vulkan on an NVIDIA GeForce RTX 3080 Laptop GPU, driver 555.85,
at the full 700×510 viewport. There is no audio backend or persistent saved data.
The player starts with Ruffle's memory storage. This is emulator evidence, not
a native Flash comparison.

The first attempt from `.scratch` stalled at controls setup. Primary Ruffle
source rejects dot-prefixed path components in `SharedObject.getLocal`;
the game's `HowToPlayUI.initData/saveKeys` then cannot use that local object.
The driver now verifies the authority hash and loads byte-identical bytes from
a temporary path without dot-prefixed components. It records that path and
removes the copy afterward. No SWF patch is required. See the
[source-linked diagnosis](edition-5-reference-trace-design.md).

## Reproduction and synchronization

Use [the checked-in player, lock and setup instructions](../../tools/reference_player/README.md)
and [input case](../../tools/reference_player/cases/normal-arcade.json).
The driver waits for each matching acknowledgement; it checks the expected
frame counter and every PNG's signature, dimensions and hash. Captures are
uncropped. Inputs at counter N arrive before frame N+1, with explicit down/up
events and no synthesized keyboard repeat. Each step is `run_frame` followed
by `update_timers(1000/frame_rate)`; rendering is synchronous when requested.
Nominal frame rate is 35. Host monotonic timestamps and player wall milliseconds
are retained alongside frame counters. Fast stepping is not real-time play.

The case explicitly selects Arcade, one human, three enemies, Normal difficulty
and Cinema, then selects the blue character. The match opens at frame 721.
Right is pressed at 721 and released at 731; Space is pressed at 731 and
released at 732; Left runs 732–742 and Down 742–752. The human places a bomb,
walks away, and the original explosion follows. The first baseline's original
HUD progresses from TIME 179 to 178; the faster repeat still shows 179 at its
last capture. Equal frame counts do not imply equal host-time progression.

| Evidence | What it preserves |
| --- | --- |
| [First baseline log](reference-2026-10-19/cinema-base-01/commands.jsonl) and [manifest](reference-2026-10-19/cinema-base-01/manifest.json) | Full acknowledged input/frame/host-time chronology and hashes of all 12 captures |
| [Selected settings](reference-2026-10-19/cinema-base-01/settings-cinema.png), [opening](reference-2026-10-19/cinema-base-01/opening-board.png), [movement](reference-2026-10-19/cinema-base-01/moved.png), [bomb](reference-2026-10-19/cinema-base-01/bomb.png), [explosion](reference-2026-10-19/cinema-base-01/explosion.png), [after fire](reference-2026-10-19/cinema-base-01/after-fire.png) | Independently inspected full-viewport original gameplay |
| [Repeat log](reference-2026-10-19/cinema-base-02/commands.jsonl), [manifest](reference-2026-10-19/cinema-base-02/manifest.json), [opening](reference-2026-10-19/cinema-base-02/opening-board.png) | Same acknowledged protocol completed in a fresh process |
| [Logging-player stderr](reference-2026-10-19/cinema-log-01/player-stderr.log) | Emulator diagnostics in a third completed session, with tracing subscriber added but unchanged core |
| [Observed opening](reference-2026-10-19/cinema-observed-01/opening-board-summary.json) and [bomb state](reference-2026-10-19/cinema-observed-01/bomb-summary.json) | Original stored state: Arcade, Normal, one human plus three AI, movement and owner capacity; observer classified separately |

All complete raw captures, post-step graphs and build executables remain in
ignored `.scratch/edition-5-research/reference-runs/` and the pinned checkout.
The committed manifests index their hashes; the case regenerates them.

## Repeat findings and limits

The protocol is reproducible; the entire session state is not deterministic.
Fresh processes vary AI character selections, routes/bomb schedules, Cinema
layout/template selection, soft-block occupancy and appearances. The original
generated board is not necessarily the selected recorded Godot board; level 1
does not by itself identify CinemaStage1. Both baselines demonstrate Cinema
entry, human spawn, movement and action flow. No RNG seed was fixed or captured,
and no pixel-equality claim is made
between full screens from different sessions.

The observer session has 6,204 reachable objects at opening with no truncation.
It confirms the human container moves from (213,70) to (243,70) after the ten
rightward frames, logical cell (1,1) to (2,1), and capacity changes from zero
to one owned bomb. The observer reads stored/native values without executing
game getters. Its pointer identities are local to that process.

The original countdown polls `new Date().getSeconds()` in `Game.countTime`.
Extra graph capture delays therefore change the countdown even when the same
number of game frames is stepped. Frame-based fuse observations must not use
the displayed clock as their time base. Observed timer progression is retained,
not promoted to a real-time pacing benchmark.

The diagnostic log contains missing device-font and unsupported filter/stub
warnings, Vulkan overlay-manifest errors, and `Unexpected PlaceObject during
goto` messages. The match still runs and captures complete, but those diagnostics
limit exact text/filter/timeline rendering claims. There is no native Flash,
audio, phone/iOS or final Godot presentation validation here. Later recovery
records must verify action geometry/lifecycles individually.
