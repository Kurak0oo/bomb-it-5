# Agent notes

Read [DESIGN.md](DESIGN.md) before editing. The settled list there is the spec. The open list is not.

## Now

Ask the user the two open questions in DESIGN.md. Do not start a match, a board, a HUD, a timer, a score, or an AI until those answers exist.

The Godot 4.5 project already opens on `scenes/main.tscn`. Leave that scene empty of gameplay. Do not bump `config/features` off 4.5. Do not set `physics/common/physics_ticks_per_second`. The original tick rate is not known, and 35 belongs to bomb-it-1.

## When the open questions are settled

If commands are accepted, add a tick that reads one command per actor and does not draw. Keep the four item names as empty slots: glove, bouncer, carpet, heavy bomb. Do not invent their behavior.

Do not add a map, a generator, or a 15×13 stand-in. The first board is transcribed from edition 5.

Do not copy files from `C:\Users\Eiji\Github\bomb-it-1`.

## Douyin

Not this session. Export is Godot 4.5, landscape, Compatibility. Main package budget is about 4MB, and a normal package is about 20MB. Recovered original art does not go in that package.

## Checks

There is no test runner yet. When the tick exists, add a headless check that one bomb blast and one broken soft block match the behavior written down from the SWF. Do not lock a behavior that has not been read.
