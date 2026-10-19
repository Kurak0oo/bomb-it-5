# Douyin export

Export is deferred beyond the current work. The project's accepted platform and presentation choices are in [DESIGN.md](../DESIGN.md).

## Inherited platform notes — verify before export

These statements were carried forward from the original DESIGN.md and AGENTS.md on 2026-10-16. They have no cited official source in this repo and were not independently verified during the documentation reorganization.

- The official Godot exporter lists Godot 4.5 only and rejects custom export templates.
- WebSocket is available; TCP, UDP, WebRTC, threads, GDExtension, and C# are unavailable.
- The official Godot Douyin table lists portrait only, which conflicts with the project's landscape requirement.
- The main package budget is approximately 4 MB; a normal package is approximately 20 MB.

When export is attempted, set `game.json` `deviceOrientation` to `landscape` and verify the result. Preserve the project's decision to wait if the exporter forces portrait. Before relying on the platform notes, add current official source links and verification dates here, including the precise meaning of the package limits.
