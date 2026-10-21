# Permit SWF-derived candidate art under manual review

Accepted on 2026-10-21 at the user's request. This replaces the earlier rule that
copied SWF sprites and level art stay out of production art entirely.

Artwork extracted from the edition 5 publisher SWF may be modified into
**candidate art** for the Art Workbench's named slots. A batch pipeline
(`tools/art_pipeline/`) extracts vectors and bitmaps and applies small,
deterministic, configurable changes: hue/saturation shifts, outline weight,
palette remapping, an optional external img2img result, upscaling of bitmaps and
palette/vector cleanup. Candidates are never applied automatically. The pipeline
does not write `assets/skins/active.json` or `assets/skins/imports/`. The user
reviews each candidate and chooses any for Apply to game through the workbench.

The user wants a starting point closer to the original painting style than the
rejected generated pass, and keeps final authority over what ships. Automated
change percentages are a review aid, not an approval.

Consequences:

- A small modification, about 10% by default, leaves a candidate clearly derived
  from the original artwork. Its release is a publication and rights question
  that this ADR does not settle. Store identity and release readiness remain open.
- The SWF and everything extracted or generated from it stay in ignored local
  storage (`.scratch/`, `candidates/`). Only pipeline code, configuration, the
  manifest and documentation are committed.
- Original SWF screenshots in the evidence folders remain view-only references.
  The workbench still rejects imports from the research and evidence folders;
  candidates are imported from `candidates/`.
- Unmodified copies of SWF art, music and branding are not production assets.
- Gameplay, collision and action timing are unaffected; slots remain visual.

[DESIGN.md](../../DESIGN.md) owns the current asset boundary.
