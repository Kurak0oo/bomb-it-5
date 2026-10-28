# Build a faithful original replica beside the adapted game

Accepted on 2026-10-28 at the user's request, for the `original-replica` branch.

The user wants two delivery lines: original art made on separate branches, and a
faithful reproduction of edition 5 delivered as a final product. The replica also
gives the project the original game, running in Godot, as a reference it did not
have; the Ruffle reference player remains research tooling.

Everything on the replica refers to the original game design, so the accepted
adaptations (eight-direction movement, Arcade loss on timeout, the 5-level fix,
simulation clock, readable labels and the others listed in DESIGN.md) are undone
there. They are undone through a fidelity profile in the shared code rather than by
editing the rules on one branch only. A forked rule set would conflict in the
gameplay code at every merge with the art branches; a profile keeps one round and
one test suite, with checks for both profiles.

The repository is public. Original art and audio belong to the publisher, so they
stay out of git: the game reads them from an ignored local pack built from the
user's own SWF and falls back to the native presentation without it.

Consequences:

- The replica is a private reference build. Publishing it, or any build carrying the
  original pack, is a rights question this ADR does not settle.
- Original defects come back on purpose (timeout always completes an Arcade level,
  the five-levels button sets one). They are reproduced, not fixed.
- Rules whose exact source behaviour is not yet ported stay on the adapted
  implementation and are listed in DESIGN.md until replaced from recovered source.
- [DESIGN.md](../../DESIGN.md) owns the current rules for both profiles.
