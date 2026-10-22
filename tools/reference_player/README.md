# Original-SWF reference player

Research tooling only. Godot does not load this code, the SWF or its artwork.
The input protocol derives from the supplied [Dots harness](../../docs/evidence/observations/swf-v1.6.1-supplement/REPRO.md).
Ruffle is pinned to `45366370ed7d1a59c89aa3cf7b765c7a274407cd`;
`Cargo.lock` pins the dependency graph, including this workspace package.

On Windows with Rust/MSVC build tools and a Vulkan adapter:

```powershell
./tools/reference_player/build.ps1
python tools/replay_reference.py --observe --output .scratch/edition-5-research/reference-runs/cinema-observed-01
```

The build script uses a task-owned Ruffle checkout under ignored storage. It copies
this package into that workspace and applies the recorded research patch chain:
observer → fixtures → events → compact → focus → actors → geometry → drops →
session-state → class-names → actor-bombs → ai-returns → move-step → active-pickups → platforms.
It first reverses exact matching installed
patches in reverse order and rejects other core changes. The default probe exposes
full observation; fixture commands require `-Fixtures`, event/seed commands require
`-Events`, compact graph commands require `-Compact`, and focused commands require
`-Focus`. Event collection starts
disabled. Compiled fixture methods do nothing until explicitly invoked.
It records the compiler, platform, hashes and tracked changes in that checkout's
`reference-build.json` / `reference-changes.patch`. For an unchanged-core comparison,
use a **separate** checkout:

```powershell
./tools/reference_player/build.ps1 -Baseline -Checkout .scratch/edition-5-research/ruffle-baseline
python tools/replay_reference.py --player .scratch/edition-5-research/ruffle-baseline/target/ci/probe.exe --output .scratch/edition-5-research/reference-runs/cinema-baseline-01
```

`-CheckOnly` performs locked Rust checks without rebuilding the executable.
Do not use the setup script against a checkout containing unrelated work.
The authority SWF must already exist at the default research path, or be passed
with `--swf`. The driver rejects a different hash. It stages byte-identical bytes
in a temporary path without dot-prefixed components: loading directly from
`.scratch` makes this game's `SharedObject.getLocal` fail during controls setup.
The driver removes that temporary copy after the process exits.

The case JSON records input chronology. Each command waits for the exact matching
acknowledgement before continuing; PNG dimensions and frame counters are checked.
Logs retain both host monotonic time and the player's wall time. Output directories
must be new. The manifest deliberately does not certify visual/gameplay correctness.
Inspect the captures and state before drawing conclusions.

For controlled research scenarios with all capabilities:

```powershell
./tools/reference_player/build.ps1 -Fixtures -Events -Compact -Focus
python tools/replay_reference.py --observe --focus --fixtures --case tools/reference_player/cases/weapons/hammer-right.json --output .scratch/edition-5-research/reference-runs/hammer-01
```

`fixture` actions in a case require the explicit driver flag. They invoke original
allowlisted constructors/methods and are classified separately from input-only play.
They never write weapon, health, score or result fields directly. See the fixture
guards, original side effects and failure limits in the trace-design record.

Protocol (one command per line):

- `step N`: preload, run one frame, then update timers by `1000/frame_rate` milliseconds, N times.
- `kd KEY` / `ku KEY`: deliver one key-down/up between frames; no synthesized repeat.
- `click X Y`, `move X Y`: pointer input in the 700×510 viewport.
- `shot FILE.png`: render and synchronously save the complete viewport.
- `cap DIR` / `cap off`: render/capture every stepped frame.
- `state FILE.json`: bounded native slot graph, available with the observer feature.
- `trace DIR` / `trace off`: save a state graph after each stepped frame.
- `compact FILE.json`, `trace-compact DIR` / `trace-compact off`: omit native painting trees, retaining logical objects and directly referenced animation frame numbers. `--observe --compact` selects compact snapshots in the driver.
- `focus FILE.json`, `trace-focus DIR` / `trace-focus off`: explicit game/actor/AI/callback/cell/bomb/map-feature projection (`platforms`: each `maps.platform` object a Grid slot references) with physical-slot layouts, available with `-Focus`. `--observe --focus` selects this mode. An expensive initial full-graph bootstrap is explicitly marked.
- `fixture FILE.json`: explicit original-method fixture; saves `FILE-result.json` beside it.
- `events DIR [CAPACITY] [PREFIX...]`: collect selected method/RNG events and drain them after each frame. Defaults: capacity 20,000 and game-package methods. `events on` keeps events buffered for manual draining; `events-dump FILE.json` drains them. `events off` writes a final tail and disables capture. Overflow is explicit.
- `seed N`: explicit nonzero original-RNG initial seed, only before any frame/RNG use. This is a controlled fixture, not unseeded baseline playback.
- `realtime 1` / `realtime 0`: optionally pace steps to their nominal duration.
- `quit`: exit, without an acknowledgement.

An acknowledgement reports the state **after** its frame counter; input at counter N
is delivered before frame N+1. State is observed after timer advancement. Rendering
is separate, and wall time is not a simulation clock. No audio backend, persistent
saved game or OS keyboard repeat is attached. The default memory storage starts
fresh in each process.

The observer reads slots, dynamic storage, arrays, bound callback receivers and
native display state without running ActionScript getters/methods. Its weak Game
cache does not keep a disposed session alive. Pointer identities vary between
processes; raw graph IDs are not deterministic scenario IDs. Truncation is explicit,
and a missing/truncated root is not evidence that a gameplay object never existed.
See the [trace design and limitations](../../docs/evidence/edition-5-reference-trace-design.md).

Ruffle is an emulator. Its font/filter/stub/timeline warnings remain in the logs;
this tool does not establish native Flash rendering or enumeration equivalence.

Allowlisted fixtures use original constructors or public methods. `pickup` takes
one of the 14 documented `kind` values; `reposition` takes integer `x`/`y` and
requires empty floor without another actor's footprint. Both accept optional
`actor` (current Game.players index 0–3); `bomb` also accepts that selector.
`ai-control` requires an AI actor and `mode: stop|start`; it controls the original
brain/listeners, leaving the actor registered and delayed callbacks intact.
`move-step` takes `direction: left|right|up|down` and optional actor. It invokes
one original RobotController movement callback, including model acceleration,
HitMove and occupancy effects, without advancing a frame or scheduling input.

`build-soft`/`break-soft` take a board cell and invoke original block methods;
the latter bypasses attack targeting and credit, while original drop animation
continues. `time-passed` takes integer `seconds` 0–180 and invokes the Arcade
spawn callback without advancing Date, pastTime, timeout or score clocks.
Fixture results report the selected actor, before/after state and budget fields.
Unknown fields, invalid selectors and dead actors reject the call. Interrupted
actors reject movement/control operations; pickup construction remains available
so original collection/disposal during an active action can be observed.
These are controlled setups and callback experiments, not input-only play.

Geometry metadata records bounded native Script bounds and raw transforms without
AS getters. Class references include the represented `defined_class`. Event return
metadata captures AstartPath cost/path and AI perception arrays at their actual
return boundary, before later selectors can mutate them. These reads introduce
no game writes, retained GC roots or RNG interception. Event array truncation and
collector loss must be checked before using a trace.
