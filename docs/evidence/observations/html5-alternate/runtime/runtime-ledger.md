> Imported Dots record; claims are retained as delivered. See the [integration assessment](../../../edition-5-play-observations.md) for verification, missing files, and authority limits. Original relative paths in code spans refer to the [unaltered bundle](../../../../../.scratch/edition-5-research/observations/html5-alternate/runtime/runtime-ledger.md).

# Runtime evidence ledger

## Environment and identity
- Exact publisher URL: https://www8.agame.com/games/flash/b/bomb_it_5/bomb-it-5-zh-fix.swf
- Downloaded 2026-10-16 19:58 UTC, 6,942,081 bytes; SHA-256 718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2.
- Browser Chromium 154.0.8037.57 Debian 13, cloud browser. Screenshots are uncropped viewport JPEGs (1180×757 while demo visible). Official Ruffle demo https://ruffle.rs/demo/ actually used; context menu verifies **0.8.0-nightly.2026.10.16**. High quality selected. Default playback speed, no speed override. Actual stage cadence unmeasured.
- Ruffle 0.7.1 npm package downloaded but NOT successfully used to play: localhost harness requests failed ERR_CONNECTION_REFUSED, including after server reported Serving HTTP. This is a harness availability failure, not evidence that 0.7.1 cannot run game.
- No game logic edits, cheats, or substitute editions used.
- Initial native app binding and browser dev-log inspection were unavailable. Native desktop use was subsequently explicitly authorized; see continuation. Browser dev-log inspection was not retried.

## Observed screen flow and exact actions
All images in screenshots/; capture-times.json records UTC timestamps before each screenshot request (not exact exposure times).
1. Loaded exact local SWF via official demo Select File. 001-publisher-play-gate shows title/preloader with PLAY button. Click (585,662) starts A10 intro, then main menu.
2. 002-title-menu: title Bomb It 5; version v.1.6.1 upper-right; Start, How To Play, More Games; display/audio/music icons; blank language selector top-left. Language labels otherwise English.
3. Click Start (888,332). 003-mode-selection: GAME SETTINGS combines modes and match options. Arcade selected; modes displayed ARCADE, R_BATTLE ROYALE, PAC-MAN, GREEN ZONE. Arcade card says KILL ALL ENEMIES. Options players 1/2; enemies 3/2/1/0; levels 5/10/15/20; arena dropdown; Easy/Normal/Hard.
4. Click arena dropdown (756,588). 004-arena-menu shows Birthday Party, Candy Factory, Zoo, Luxury Shop, Magic Library, Cinema, Random. Click Birthday Party (567,343), captured 005-first-match-settings.
5. Exact first attempted match setup: Arcade; 1 human; 3 enemies; 5 levels; Birthday Party; Easy. Next (841,712) reveals character screen 006-character-selection. Default blue robot selected P1, no costume chosen. Eight character portraits; cosmetic hat/outfit grid. Opponents not revealed because round did not load.
6. Click Start (835,707), capture first-start-000 through first-start-099 as sequential uncropped frames. Screen becomes R_ARCADE loading panel with text “Place your bombs tactically to kill all enemies!” and illustrative board thumbnail. THIS THUMBNAIL IS NOT THE FIRST GENERATED BOARD and must not be transcribed as such.
7. Loading animation continued looping from ~20:07:39 through 20:08:49 UTC (over 70 seconds), no gameplay board reached. 007-loading-state, 008-ruffle-info, 009-player-context-menu and 010-first-round-loading-failure preserve this failure. No complete match observed. No starting board exists in this capture.
8. Ruffle info panel reports SWF 700×510, version 14 / FP 11.1 / ActionScript 3, header frame rate 30, 3 frames. This is metadata, not achieved cadence or contradiction of source startup override to 35.
9. Click reload icon led to JavaScript confirmation “Reload the current SWF?” Pending user approval, not accepted as of 20:09 UTC.
10. Independently opened user supplied https://www.7k7k.com/swf/103707.htm. Navigation initially timed out but page then rendered. 011-7k7k-browser-unsupported.jpg shows “当前浏览器或模式不支持打开游戏” (current browser or mode does not support opening game). It recommends browsers/Flash plugin, not followed. No playable alternate bytes loaded and no edition substitution.

## Unknown runtime behavior
Movement, simultaneous keys, bomb press/hold/release, fuse, blast blocking, chain reactions, soft-block removal and drops, damage, life decrement, scoring, round end, pause, victory/defeat/results, all requested special-item behavior: NOT OBSERVED. No estimated timing should be attributed to these runtime captures.

## Layout observed
At initial demo size: viewport 1180×757; top demo toolbar y=0..47; game image x≈103..1076, y=48..756 (aspect ratio corresponds to 700×510). These are player/menu bounds, not gameplay board/HUD bounds. Info panel changes player fit and layout; retain uncropped captures.

## Continuation and corrections (2026-10-16 20:22 UTC)
The chronological status above is superseded here: reload was subsequently approved and accepted. Native cloud player control/download/run was explicitly approved later; native work below was a new authorized attempt. Browser developer-console inspection remained unavailable and was not retried.

### Exact build: instructions and second controlled arena attempt
- 20:10:37, after reload, opened How To Play. 012-instructions-controls: single-player arrow keys movement, Space bomb; two-player P1 WASD/Space and P2 arrows/Enter. This is observed instructional text, not tested key behavior.
- 20:10:43, clicked next instruction page. 013-instructions-powerups labels Bomb +1, Power Blast +1, Speed +10%, Life +1, Shield, Push The Bomb, Invincibility. Weapons: Boxing Glove, Landmine, Flamethrower, Lightning Gun, Hammer, Machine Gun, Fireball Launcher. Vehicles: Frog, Sport Car, Mammoth, Skateboard. These names are menu evidence only. No item encountered in actual gameplay. No mapping to bouncer, magic carpet or heavy bomb established.
- 20:11:05, selected Arcade/1 player/3 enemies/5 levels/Easy/Candy Factory, default blue robot. Changed arena only relative to first attempt. Clicked Next then Start. second-start-000..079 show animated Loading only. 015-second-arena-loading-failure at 20:12:19 still no board. This repeats the first failure on another arena; does not establish whether game, emulator, or environment caused it.

### Alternate normal publisher build: explicitly NOT exact requested revision
- Source: https://web.archive.org/web/20130111075920id_/http://www8.agame.com/games/flash/b/bomb_it_5/bomb_it_5.swf
- SHA-256 926a6c59e06b4a541d43aa9c587a1f1fe60afd6eb8d45dec3ffa9828f53d33ec; 8,260,379 bytes. Historical publisher copy, no cheat edition used.
- Loaded same official web nightly demo in separate tab after exact-build failures recorded. A01 startup 20:12:55, A02 title 20:13:11 shows **v.1.04**. This does not match v.1.6.1.
- A03 20:13:38 settings: Arcade, 1 player, 3 enemies, 5 levels, Easy, Birthday Party, default blue robot. Next and Start. A-first-start-000..049 capture only loading animation. A04 at 20:22:21 remains Loading (more than eight minutes later). No alternate gameplay finding or board was obtained.

### Official stable native player: environment rendering failure
- Official release https://github.com/ruffle-rs/ruffle/releases/tag/v0.7.1; Linux x86_64 tarball https://github.com/ruffle-rs/ruffle/releases/download/v0.7.1/ruffle-0.7.1-linux-x86_64.tar.gz . Asset SHA-256 displayed by GitHub: 67950dfdde643f9087ae478eb3637fe52e0deefc79bdb55fe43cd69dab9fdd99.
- Native desktop and command workspace proved separate. Command-workspace binary launch failed without display. Browser downloaded official binary and exact publisher SWF to actual native desktop; SHA-256 printed by native sha256sum matches requested SWF. No SWF alteration.
- ~20:19 default native launch opens Ruffle - exact.swf but blank white window (N01-native-default-blank.png). Visible native log says loaded SWF14,700x510, fallback OpenGL llvmpipe LLVM19.1.7 CPU; repeated `MESA: error: Failed to attach to x11 shm`. Audio device unavailable; OpenH264 download fails. These are observed diagnostics, not proven explanation of web Loading stall.
- ~20:20 retry `LIBGL_ALWAYS_INDIRECT=1 ./ruffle --graphics gl exact.swf` opens another window but no rendered game, stale underlying desktop appears (N02 at ~20:21:59). No useful scene.
- ~20:22 retry `GALLIUM_DRIVER=softpipe LIBGL_ALWAYS_SOFTWARE=1 ./ruffle --graphics gl exact.swf` also no rendered game (N03 at ~20:22:21). Renderer-only changes, no game code or game-state changes.
- `native-startup-visible-log.txt` is accessibility text from the log shown in Mousepad, not a console extraction from browser. Native captures are full desktop, uncropped. No frame rate/speed/lag measurement possible in these failed native renders.

## Recordings and timing limits
`recordings/first-start-loading-only.mp4`, `second-start-loading-only.mp4`, `A-first-start-loading-only.mp4` are assembled from uncropped screenshot sequences using actual pre-request UTC timestamp gaps in capture-times.json. Original frames remain authoritative. Video sampling/encoding rate is not achieved SWF FPS. Sparse screenshot sampling cannot measure game cadence. These clips show Loading animation only, not movement, bombs, explosions, damage, death, or transitions to a match. No gameplay timing claim is supported.

## First board transcription: unavailable
No generated gameplay board was observed in any attempted player/build. Dimensions, cells, spawn placement, special features, opponent identity and starting HUD therefore have no runtime transcription here. The Loading-panel example is deliberately excluded. Source-derived templates belong in a separate, explicitly static-source section and cannot be described as the first observed board.

## Unresolved and contradictions requiring real gameplay
1. All match mechanics, outcomes, HUD layout and requested animation sequences remain unknown at runtime.
2. Menu Power-ups names do not establish requested bouncer/magic-carpet/heavy-bomb identity; Boxing Glove is only a label until encountered and used.
3. SWF header metadata 30 FPS is not the later source-requested 35 FPS and neither proves achieved timing.
4. Source loading path reportedly has embedded map data and short row-build timers; repeated web Loading lasting minutes is inconsistent with a normal completed initialization, but exact cause remains unknown.
5. Prior research from a different build/player must not be promoted to observed evidence for this SHA-256. No direct runtime contradiction of prior input/fuse assertions can be established without gameplay.
6. Pause, victory, defeat, results, complete match and untouched first board were not reached. The evidence pack is partial, not a completed playtest.

## Online-video gap attempt
At 20:23 UTC opened https://www.youtube.com/watch?v=e6jCL6FA5nA in cloud Chromium. Page identifies GoGy Games, “Bomb it 5 Full Gameplay Walkthrough All levels”, length39:45. Player showed black buffering spinner at0:00; toggled Play and sought once with seek-slider Right Arrow to0:05, still black spinner. V01-youtube-buffering-no-frames.jpg preserves failure, then paused. No video frame viewed. Edition/build/mode cannot be verified from frames and no mechanics, board or timing attributed to this source. Comments are not used as build evidence.
