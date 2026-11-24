# Douyin export

Export is deferred beyond the current work. The plan is in [development.md](development.md); earlier platform choices are in `DESIGN.md` under the `pre-restart` tag.

## New-art decision (owner, 2026-11-24)

The owner accepted the art recommendation in
[Game art models in AI jams](../reports/Game%20art%20models%20in%20AI%20jams.md) (section "For
bomb-it-5"). It applies only to the Douyin build's art pack; the replica keeps the original SWF
art and uses no generator. No Douyin art work starts before its checkpoint.

1. **Style first, then source.** Fix one style for the whole build before choosing a model.
   Default: vector art drawn in code by the agent (tiles, blocks, bombs and flames are simple
   shapes, and code art keeps the package small).
2. **Raster art, if wanted:** one image model for everything, GPT Image 2.x. Check transparency,
   sprite consistency and tiling per asset; no benchmark covers them.
3. **Audio:** Suno v6 for music, ElevenLabs for voice and sound effects.
4. **Not used:** 3D generators (the game is 2D) and Midjourney.
5. **The owner is the art gate.** Generated or code-drawn art is a placeholder until the owner
   accepts it; a passing check only means ready for review.

Model names are as of 2026-11-24; re-check them when the Douyin art checkpoint starts. Before
the build ships generated art, verify China's rules for labelling AI-generated content against
official sources and record them here.

## Inherited platform notes — verify before export

These statements were carried forward from the original DESIGN.md (now under `pre-restart`) and AGENTS.md on 2026-10-16. They have no cited official source in this repo and were not independently verified during the documentation reorganization.

- The official Godot exporter lists Godot 4.5 only and rejects custom export templates.
- WebSocket is available; TCP, UDP, WebRTC, threads, GDExtension, and C# are unavailable.
- The official Godot Douyin table lists portrait only, which conflicts with the project's landscape requirement.
- The main package budget is approximately 4 MB; a normal package is approximately 20 MB.

When export is attempted, set `game.json` `deviceOrientation` to `landscape` and verify the result. Preserve the project's decision to wait if the exporter forces portrait. Before relying on the platform notes, add current official source links and verification dates here, including the precise meaning of the package limits.
