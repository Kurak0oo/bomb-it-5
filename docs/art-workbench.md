# Art Workbench

Double-click [Art Workbench.cmd](../Art%20Workbench.cmd) in the repository root.
Alternatively, run `./tools/art-workbench.ps1`. Godot 4.5 opens the tool directly;
you do not need to use the Godot editor. The normal game still starts through
`./tools/play.ps1`.

1. Click a category or search for a component. Select its card.
2. Compare **Applied in game** with **Your draft**. **Reference** opens the
   preserved original-game context, where available.
3. Click **Replace image…** and choose your PNG, JPG or WebP. You can also drop
   an image onto the window to replace the selected slot.
4. For a sheet, set **Frames across**. One row is a simple strip; four rows face
   Down, Right, Up, Left. Adjust scale, offsets and tint. Play/pause or scrub the
   preview. Source action timing remains authoritative in the game.
5. Click **Preview in game** to try the draft in the actual game. It starts in
   practice; **Start Match** adds the three real AI. Close that preview to return.
6. Click **Apply to game** when ready. Future normal game launches use the choices.

**Use default** removes the selected draft replacement. **Undo** restores the
previous draft change, including a reset. Applying is explicit; importing an
image does not immediately change normal play. Draft choices persist between
workbench sessions. Reopening **Preview in game** starts a fresh preview with all
current settings, including menu-button styles.

The catalogue has 89 visual slots: 10 board pieces, 20 character poses/portraits,
14 pickup icons, 13 held weapons/actions/projectiles, 12 effects/ride states,
5 control graphics, 10 interface backgrounds/button states and 5 optional outcome
illustrations. Dynamic text, layout and hit areas remain native. The four unresolved
gameplay item slots remain disabled and are not invented as new effects.

Character sheets are selected by facing. Idle is the fallback for an unassigned
walk/action pose. Action sheets follow the recovered action phase; changing a
sheet's frame count does not change hit timing. Laser/flamer cell graphics repeat
over authoritative affected cells. Menu buttons use their first frame, stretched
to the existing button; their sprite-placement controls are disabled. Transparent
overlays work best for protection, transit and HUD panels.

The original reference viewer displays preserved **context screenshots**, not an
exported per-component source atlas. Some contexts cover several slots, and a
missing reference is labelled. Research images remain separate from replacement
files; import from the research/evidence folders is rejected. No new art is generated
or treated as approved by this tool.

The separate [art pipeline](../tools/art_pipeline/README.md) can produce
SWF-derived candidate images in the ignored `candidates/` folder, with a review
page. It never applies anything. Review each candidate yourself and import the
ones you choose with **Replace image…** ([ADR 0006](adr/0006-swf-derived-candidate-art.md)).

Applied choices live in `assets/skins/active.json`; imported images are copied by
content hash into `assets/skins/imports/`. Keep those together when sharing or
committing your work. Original image files are left in place. The autosaved draft
is `user://art_workbench_draft.json` in Godot's project user-data folder. Applying
an empty mapping restores the previous game presentation.

The workbench is a desktop development tool. Phone testing, device cutout checks,
export and publication are not performed. [Verification](verification/art-workbench-2026-10-20/README.md)
records the checked workflow and its limits.
