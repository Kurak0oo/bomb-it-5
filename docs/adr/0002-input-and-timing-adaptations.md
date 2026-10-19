# Adapt original input and timing for the new game

Accepted on 2026-10-17: preserve the original's ordered bomb input events within each per-actor command, and use a 35-tick logical schedule with a clock driven by simulation time. The event list avoids losing repeats and ordering between ticks, while simulation time keeps the round countdown aligned with gameplay during pauses and stalls instead of reproducing the original Date-polling behavior.

The user also chose timeout defeat while enemies remain, intentionally replacing the source-supported timeout-completion anomaly. These choices trade exact reproduction of those original quirks for coherent round timing and elimination victory; [DESIGN.md](../../DESIGN.md) owns the current requirements, and [the evidence assessment](../evidence/edition-5-play-observations.md) retains the original behavior independently.

On 2026-10-18 the user chose bounded catch-up to avoid processing a long unseen interval in one rendered frame, fresh gameplay input after an explicit resume, and tick-start event capture committed only after batch acceptance. This accepts simulation slowdown after excessive delays while keeping input consumption aligned with accepted ticks.

The scheduler implementation uses a Node's `_process` elapsed time, independently of global physics settings. The same elapsed-time interface supports deterministic headless checks with the real command module and queues. Attaching the Node enables automatic scheduling; the command-boundary main scene remains empty. [ADR 0003](0003-bomb-batch-timing.md) subsequently records placement-before-movement, uniform newborn countdowns, actor priority, and bomb input before existing countdowns and explosions.
