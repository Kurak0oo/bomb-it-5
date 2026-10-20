# Integrate gameplay through the admitted round

The 2026-10-20 fidelity implementation retains this seam while separating hazard,
action, protection, occupancy, death and settlement responsibilities. Source host
Tween/Timer delays become simulation deadlines, rounded up, so the accepted pause
and bounded catch-up rules remain authoritative. Reproducing the original global
Tween clock would permit paused recovery and stale resume-Space firing, directly
conflicting with the accepted input lifecycle. DESIGN.md records the conversions;
the evidence retains the observed host-time runs independently.

Heading is resolved from the admitted direction before starting an available
action. The action can lock displacement in that same tick. This preserves source
turn-and-fire without a private AI-facing mutation or an extra moving turn tick;
the human and AI receive the same capability through the existing command shape.
Placement still uses the tick-start cell. Physical movement and logical occupancy
remain distinct, and original callback mutation is translated within the accepted
phase order rather than replacing it with an AVM2 runtime.

During the authorized complete-game implementation on 2026-10-19, the existing bomb tick target was deepened into the round instead of introducing separate rendering, hazard and AI clocks. The scene manually drives one scheduler and consumes copied results; one AI decision rotates per tick while all actors receive commands. This keeps pause, rejection and bounded catch-up authoritative across the whole game, at the cost of translating original callback/tween phases into explicit logical phases rather than claiming universal SWF frame parity. [The current design](../../DESIGN.md) records the phase policy and [runtime evidence](../evidence/edition-5-runtime-systems.md) separates recovered facts from conversions.
