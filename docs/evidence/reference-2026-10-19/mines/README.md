# Landmine original-runtime evidence

Interpretation and limits: [focused report](../../edition-5-landmine-probes.md). Ten cases retain exact replay inputs, commands, fixture results, original player build/manifest, native checkpoints/timelines, selected mutation events, raw decisive event/Focus files and unmodified screenshots.

- `owner-return-power`: no timed fuse, owner departure/return, shield contact, power-two victim and cleanup.
- `other-normal-contact`, `other-shield-contact`, `other-invincible-contact`: actual original movement into a mine, normal/protected damage and the Invincible-contact scoring quirk.
- `bomb-trigger-unarmed`, `bomb-trigger-armed`: external BLAST works before/after departure; ordinary counter underflow; armed case follows through two legal ordinary bombs at capacity one.
- `capacity-and-occupancy`: ordinary same-cell placement and capacity guards while a mine exists.
- `mine-on-existing-bomb`: equipped mine bypasses ordinary placement guard; colocated ordinary center blast does not trigger it.
- `replacement-down-up`: replacement dispose, one use, held/released Space and default handler restoration.
- `pause-teardown`: paused callback absence, resume, original menu teardown and later unavailable old game.

`assessment.json` records assertions against the retained data. `sources.json` hashes original decompiled scripts/XML and lists precise function locators. `abc-methods.json` retains original method indices from execution metadata. Each `extract.json` indexes hashes/counts for all raw event files and reports collection integrity. Complete raw per-frame Focus remains in ignored investigation storage; every extracted frame includes its original hash. Raw Focus at selected checkpoints is retained here with its layout metadata.

`mutation-events.json` selects events without changing their original sequence/call/depth; parent IDs may point to omitted ancestors. `raw-events` retains complete collector output at decisive frames. IDs correlate only within one process. `tools/inspect_mine_probe.py` reads existing records only and validates their integrity; it does not execute ActionScript or run Godot tests. Stored native flags, visual flame lifetime, registered liveness and damage eligibility are reported separately.
