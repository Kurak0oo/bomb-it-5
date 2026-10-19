> Imported Dots supplemental record; assertions are retained as delivered. Read the [integration assessment](../../edition-5-play-observations.md) for confidence, corrections and remaining limits. Source-relative paths in code spans refer to the [unaltered original](../../../../.scratch/edition-5-research/observations/swf-v1.6.1-supplement/REPRO.md).

# REPRO: Bomb It 5 v.1.6.1 frame-exact harness (supplement to the first evidence pack)

Status key: **LOGGED** means it is copied verbatim from the harness's own stdout log (`logs/harness-command-log.out.log`, one line per command, written by `main.rs`). **RECONSTRUCTED** means it was put back together afterwards from files, process state or scripts, and is marked wherever it is used.

## 1. Exact toolchain (verified 2026-10-17 on the build box)
| item | value | how verified |
|---|---|---|
| Ruffle checkout | `https://github.com/ruffle-rs/ruffle`, commit **45366370ed7d1a59c89aa3cf7b765c7a274407cd** (2026-10-16T07:41:43Z, "web: Avoid a reference cycle in audio buffer callbacks") | `git rev-parse HEAD` → `ruffle-checkout/HEAD.txt` |
| Local changes | root `Cargo.toml` adds `"probe"` to workspace members; `Cargo.lock` gains the `probe` package entry; new `probe/Cargo.toml` and `probe/src/main.rs`. Nothing under `core/` or `render/` was changed. | `ruffle-checkout/git-status.txt`, `git-diff.patch` (exact), `git-diff-stat.txt` |
| Cargo.lock | the exact lock file of the checkout that was built | `ruffle-checkout/Cargo.lock` |
| **rustc that built the binary** | **rustc 1.99.1 (58cf8f9c3 2026-10-13)**, LLVM 23.1.1, rustup toolchain `stable-x86_64-unknown-linux-gnu` in `~/.rustup` | the `.comment` section of `target/release/probe` (`ruffle-checkout/probe-binary-comment.txt`); `target/.rustc_info.json`; a re-run of `cargo build --release -p probe` reports `Finished` with no rebuild |
| cargo | cargo 1.99.1 (5f94df478 2026-08-27) (`~/.cargo/bin/cargo`) | `cargo -V` |
| Linker | LLD 23.1.1 (rust-lld), plus GCC 14.2.0 (Debian 14.2.0-19) crt objects | `.comment` section |
| System rustc (NOT used) | `/usr/bin/rustc` = rustc 1.85.1 (4eb161250 2025-03-15). It was too old: the ruffle workspace needs edition 2024 / a newer MSRV, so the first attempt was abandoned and rustup stable was installed. | first attempt in `logs/cargo-build-first-attempt.log` |
| **Correction** | The first report's "rustc 1.9x stable" was imprecise. The exact compiler is **1.99.1**. | |
| Binary | `target/release/probe`, sha256 in `ruffle-checkout/probe-binary.sha256` | |
| GPU path | wgpu **Vulkan** backend on **llvmpipe (LLVM 19.1.7, 256 bits)**, driver_info **Mesa 25.0.7-2+deb13u1 (LLVM 19.1.7)**, device_type Cpu. Packages: `mesa-vulkan-drivers 25.0.7-2+deb13u1`, `libvulkan1 1.4.309.0-1`. | harness stderr `logs/harness-stderr.err.log` (adapter line), `dpkg -l` |
| OS | Debian 13 (trixie) x86_64 box, no GPU, no sound card (no audio backend is attached to the Player) | |
| SWF | `bomb-it-5-zh-fix.swf`, SHA-256 `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2` | |

## 2. Exact build commands
```bash
git clone https://github.com/ruffle-rs/ruffle /workspace/ruffle-build/ruffle
cd /workspace/ruffle-build/ruffle && git checkout 45366370ed7d1a59c89aa3cf7b765c7a274407cd
curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain stable    # gave rustc/cargo 1.99.1
mkdir -p probe/src && cp <pack>/tools/ruffle-probe/Cargo.toml probe/ && cp <pack>/tools/ruffle-probe/main.rs probe/src/
git apply <pack>/tools/ruffle-probe/workspace-members.patch    # adds "probe" to [workspace] members
# for a byte-exact lock: cp <pack>/ruffle-checkout/Cargo.lock .  (or git apply ruffle-checkout/git-diff.patch instead of the two lines above)
~/.cargo/bin/cargo build --release -p probe
```
(The clone/rustup lines are RECONSTRUCTED from the box state. The resulting tree is exactly `git-diff.patch` + `git-status.txt`.)

## 3. Exact launch (RECONSTRUCTED from `/proc/<pid>/fd` of the running harness: fd0 = in.fifo, fd1 = out.log, fd2 = err.log)
```bash
cd /workspace/probe-run && mkfifo in.fifo
sleep infinity > in.fifo &         # keeps the FIFO open between commands (exact holder process not logged)
/workspace/ruffle-build/ruffle/target/release/probe /workspace/bombit5-evidence/bomb-it-5-zh-fix.swf < in.fifo > out.log 2> err.log &
./c.sh "step 300" "shot /tmp/x.png"   # c.sh writes commands into in.fifo and waits for the matching OK lines
```
Wall-clock pacing for the timeout run used `slow.sh DIR N 4`: `step 4`, then `sleep 0.75`, repeated, giving about 4 frames per wall second (see §6).

## 4. Command protocol and frame semantics (from `main.rs`)
- `step N`: N times { `preload`; `run_frame()`; `update_timers(1000/frameRate ms)`; frame += 1; if capturing, render and save `f<frame>.png` }. **Frame k = state after the k-th `run_frame()`**, and `f00k.png` shows exactly that state.
- `kd K` / `ku K` / `click x y`: delivered to `Player::handle_event` immediately, between frames. The log line reports the current counter N, so the input acts from **run_frame N+1** onward. Keys: left/right/up/down/space/enter/esc/p.
- `cap DIR` / `cap off`: per-frame capture on/off. `shot PATH`: one capture of the current state.
- No OS key auto-repeat: one KeyDown per `kd`.
- Every command echoes `OK frame=N wall_ms=T fps_setting=F cmd=...`. That echo is the LOGGED input log below.
- The AS3 game engine runs on `ENTER_FRAME` only. `GameEngine.countTimer = new Timer(25)` gets a listener but is never started (`start()` is never called on it), so `update_timers` does not double-tick the engine. [source, verified]

## 5. Per-probe key events (absolute frames; frame numbers come from the LOGGED log and the per-frame captures)
| probe/run | inputs (key → acts from frame) | observed event frames |
|---|---|---|
| p01 run1_right / run1_left / run2_down / run2_up / run3_right | kd right→1211 … ku; kd left→1246; kd down→1281; kd up→1304; kd right→1327 (exact kd/ku lines in §7) | 1 cell per 8 frames (e.g. 1211–1219) |
| p05 run1 | kd space→1350, ku space later (see §7) | bomb visible 1350; blast 1422; flame 1422–1438; drop bubble 1433 |
| p09 run1 | walk into the drop | pickup 1483 |
| p02 run1/2/3 | hold left; kd up / ku up (see §7) | captures 1505–1537, 1561–1593, 1617–1649 |
| p03 va/vb/vc run1–3 | see §7 | 3636–3987 |
| p11 run1 | kd p→1857 | PAUSE drawn 1860; P again 1878–1893 and esc 1894–1909 have no effect; space → resumed 1911 |
| p11 run2 / run3 | kd p→4014 / →4048 | PAUSE 4017 / 4051 |
| p10 run1 | own bomb | silhouette 959, YOU LOSE ~1019, LEVEL FAILED 1073 |
| p10 run2 | AI bomb | silhouette 1978 |
| p10 run3 | AI bomb | flame 4303, silhouette 4304, GAME OVER 4405 |
| p12 run1 | hide at (1,1); `slow.sh` pacing | TIME'S UP 2910–2919, LEVEL COMPLETE 2920 |
| p04 run1_held | kd space→3165 (held, no ku until after the blast) | bomb 3165, blast 3237, flame to 3253 |
| p04 run2_repeated | kd/ku space every 4 frames from 3297 | bomb 3297, blast 3369 |
| p08 run1/2/3 | A: kd space→3499/4132/4277; B: 9 frames later | both blast 3571 / 4204 / 4349 |

## 6. Wall clock vs frames
`logs/harness-timeline.csv` (LOGGED wall_ms for each of the 924 commands). The round clock is wall-clock based (`Game.countTime` compares `new Date().getSeconds()` and adds 1 on change, polled from the tween list every 4 engine frames). It therefore depends on how fast the operator stepped. For the timeout run, `slow.sh` paced about 4 frames per ~1.0 s wall (`step 4` + `sleep 0.75` + command latency). Raw per-step lines are in `logs/slow.log`.

## 7. Full input log, segmented by capture directory (LOGGED, verbatim commands)
Directories renamed after capture are noted inline. Helper captures (`boot/`, `start/`, `run2_start`, `run3_start`, `lvl2_start`) were not packed, except the boot shots and first-board frames in `keyframes_fullcolour/`.

### boot / setup

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 1 | 134 | 1 | `step 1` | advanced to frame 1 (frames 1–1 executed) |
| 2 | 314 | 1 | `shot /workspace/probe-run/a.png` | single capture of the frame-1 state |
| 3 | 9735 | 51 | `step 50` | advanced to frame 51 (frames 2–51 executed) |
| 4 | 10461 | 51 | `shot /workspace/probe-run/boot/b1.png` | single capture of the frame-51 state |
| 5 | 10586 | 101 | `step 50` | advanced to frame 101 (frames 52–101 executed) |
| 6 | 10656 | 101 | `shot /workspace/probe-run/boot/b2.png` | single capture of the frame-101 state |
| 7 | 10803 | 151 | `step 50` | advanced to frame 151 (frames 102–151 executed) |
| 8 | 10873 | 151 | `shot /workspace/probe-run/boot/b3.png` | single capture of the frame-151 state |
| 9 | 11021 | 201 | `step 50` | advanced to frame 201 (frames 152–201 executed) |
| 10 | 11084 | 201 | `shot /workspace/probe-run/boot/b4.png` | single capture of the frame-201 state |
| 11 | 11234 | 251 | `step 50` | advanced to frame 251 (frames 202–251 executed) |
| 12 | 11292 | 251 | `shot /workspace/probe-run/boot/b5.png` | single capture of the frame-251 state |
| 13 | 11454 | 301 | `step 50` | advanced to frame 301 (frames 252–301 executed) |
| 14 | 11515 | 301 | `shot /workspace/probe-run/boot/b6.png` | single capture of the frame-301 state |
| 15 | 18870 | 301 | `click 349 440` | mouse move+down+up at (349,440) before run_frame 302 |
| 16 | 19085 | 341 | `step 40` | advanced to frame 341 (frames 302–341 executed) |
| 17 | 19100 | 341 | `shot /workspace/probe-run/boot/c1.png` | single capture of the frame-341 state |
| 18 | 19298 | 381 | `step 40` | advanced to frame 381 (frames 342–381 executed) |
| 19 | 19315 | 381 | `shot /workspace/probe-run/boot/c2.png` | single capture of the frame-381 state |
| 20 | 19511 | 421 | `step 40` | advanced to frame 421 (frames 382–421 executed) |
| 21 | 19585 | 421 | `shot /workspace/probe-run/boot/c3.png` | single capture of the frame-421 state |
| 22 | 19724 | 461 | `step 40` | advanced to frame 461 (frames 422–461 executed) |
| 23 | 19744 | 461 | `shot /workspace/probe-run/boot/c4.png` | single capture of the frame-461 state |
| 24 | 19941 | 501 | `step 40` | advanced to frame 501 (frames 462–501 executed) |
| 25 | 19958 | 501 | `shot /workspace/probe-run/boot/c5.png` | single capture of the frame-501 state |
| 26 | 20240 | 541 | `step 40` | advanced to frame 541 (frames 502–541 executed) |
| 27 | 20530 | 541 | `shot /workspace/probe-run/boot/c6.png` | single capture of the frame-541 state |
| 28 | 27882 | 541 | `click 569 203` | mouse move+down+up at (569,203) before run_frame 542 |
| 29 | 27901 | 571 | `step 30` | advanced to frame 571 (frames 542–571 executed) |
| 30 | 28142 | 571 | `shot /workspace/probe-run/boot/d1.png` | single capture of the frame-571 state |
| 31 | 36405 | 571 | `click 140 180` | mouse move+down+up at (140,180) before run_frame 572 |
| 32 | 36407 | 576 | `step 5` | advanced to frame 576 (frames 572–576 executed) |
| 33 | 36408 | 576 | `click 255 275` | mouse move+down+up at (255,275) before run_frame 577 |
| 34 | 36411 | 581 | `step 5` | advanced to frame 581 (frames 577–581 executed) |
| 35 | 36411 | 581 | `click 255 312` | mouse move+down+up at (255,312) before run_frame 582 |
| 36 | 36416 | 586 | `step 5` | advanced to frame 586 (frames 582–586 executed) |
| 37 | 36417 | 586 | `click 415 428` | mouse move+down+up at (415,428) before run_frame 587 |
| 38 | 36424 | 596 | `step 10` | advanced to frame 596 (frames 587–596 executed) |
| 39 | 36475 | 596 | `shot /workspace/probe-run/boot/d2.png` | single capture of the frame-596 state |
| 40 | 36483 | 596 | `click 533 477` | mouse move+down+up at (533,477) before run_frame 597 |
| 41 | 36532 | 636 | `step 40` | advanced to frame 636 (frames 597–636 executed) |
| 42 | 36706 | 636 | `shot /workspace/probe-run/boot/d3.png` | single capture of the frame-636 state |

### `/workspace/probe-run/start` (not packed: helper capture)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 43 | 47416 | 636 | `cap /workspace/probe-run/start` | start saving every frame from 637 to `/workspace/probe-run/start` (not packed: helper capture) |
| 44 | 47441 | 636 | `click 528 475` | mouse move+down+up at (528,475) before run_frame 637 |
| 45 | 63390 | 886 | `step 250` | advanced to frame 886 (frames 637–886 executed) |
| 46 | 63390 | 886 | `cap off` | stop per-frame capture |

### between probes (setup / repositioning)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 47 | 205046 | 886 | `kd space` | key DOWN `space` delivered before run_frame 887 |
| 48 | 205063 | 887 | `step 1` | advanced to frame 887 (frames 887–887 executed) |
| 49 | 205063 | 887 | `ku space` | key UP `space` delivered before run_frame 888 |
| 50 | 205090 | 890 | `step 3` | advanced to frame 890 (frames 888–890 executed) |
| 51 | 205185 | 890 | `shot /workspace/probe-run/bomb1.png` | single capture of the frame-890 state |

### play/frames/p10_death/run1_selfbomb

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 52 | 448652 | 890 | `cap /workspace/probe-run/p10_death_r1` | start saving every frame from 891 to play/frames/p10_death/run1_selfbomb  (harness dir `/workspace/probe-run/p10_death_r1`, renamed after capture) |
| 53 | 460579 | 1090 | `step 200` | advanced to frame 1090 (frames 891–1090 executed) |
| 54 | 460579 | 1090 | `cap off` | stop per-frame capture |

### `/workspace/probe-run/run2_start` (not packed: helper capture)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 55 | 498675 | 1090 | `cap /workspace/probe-run/run2_start` | start saving every frame from 1091 to `/workspace/probe-run/run2_start` (not packed: helper capture) |
| 56 | 498712 | 1090 | `click 543 421` | mouse move+down+up at (543,421) before run_frame 1091 |
| 57 | 506918 | 1210 | `step 120` | advanced to frame 1210 (frames 1091–1210 executed) |
| 58 | 506918 | 1210 | `cap off` | stop per-frame capture |

### play/frames/p01_hold_dir/run1_right

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 59 | 528112 | 1210 | `cap /workspace/probe-run/frames/p01_hold_dir/run1_right` | start saving every frame from 1211 to play/frames/p01_hold_dir/run1_right |
| 60 | 528116 | 1210 | `kd right` | key DOWN `right` delivered before run_frame 1211 |
| 61 | 530021 | 1240 | `step 30` | advanced to frame 1240 (frames 1211–1240 executed) |
| 62 | 530022 | 1240 | `ku right` | key UP `right` delivered before run_frame 1241 |
| 63 | 530303 | 1245 | `step 5` | advanced to frame 1245 (frames 1241–1245 executed) |
| 64 | 530303 | 1245 | `cap off` | stop per-frame capture |

### play/frames/p01_hold_dir/run1_left

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 65 | 530304 | 1245 | `cap /workspace/probe-run/frames/p01_hold_dir/run1_left` | start saving every frame from 1246 to play/frames/p01_hold_dir/run1_left |
| 66 | 530306 | 1245 | `kd left` | key DOWN `left` delivered before run_frame 1246 |
| 67 | 532233 | 1275 | `step 30` | advanced to frame 1275 (frames 1246–1275 executed) |
| 68 | 532233 | 1275 | `ku left` | key UP `left` delivered before run_frame 1276 |
| 69 | 532571 | 1280 | `step 5` | advanced to frame 1280 (frames 1276–1280 executed) |
| 70 | 532571 | 1280 | `cap off` | stop per-frame capture |

### play/frames/p01_hold_dir/run2_down

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 71 | 577994 | 1280 | `cap /workspace/probe-run/frames/p01_hold_dir/run2_down` | start saving every frame from 1281 to play/frames/p01_hold_dir/run2_down |
| 72 | 578007 | 1280 | `kd down` | key DOWN `down` delivered before run_frame 1281 |
| 73 | 579330 | 1300 | `step 20` | advanced to frame 1300 (frames 1281–1300 executed) |
| 74 | 579330 | 1300 | `ku down` | key UP `down` delivered before run_frame 1301 |
| 75 | 579509 | 1303 | `step 3` | advanced to frame 1303 (frames 1301–1303 executed) |
| 76 | 579509 | 1303 | `cap off` | stop per-frame capture |

### play/frames/p01_hold_dir/run2_up

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 77 | 579509 | 1303 | `cap /workspace/probe-run/frames/p01_hold_dir/run2_up` | start saving every frame from 1304 to play/frames/p01_hold_dir/run2_up |
| 78 | 579511 | 1303 | `kd up` | key DOWN `up` delivered before run_frame 1304 |
| 79 | 580626 | 1323 | `step 20` | advanced to frame 1323 (frames 1304–1323 executed) |
| 80 | 580626 | 1323 | `ku up` | key UP `up` delivered before run_frame 1324 |
| 81 | 580774 | 1326 | `step 3` | advanced to frame 1326 (frames 1324–1326 executed) |
| 82 | 580774 | 1326 | `cap off` | stop per-frame capture |

### play/frames/p01_hold_dir/run3_right

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 83 | 580775 | 1326 | `cap /workspace/probe-run/frames/p01_hold_dir/run3_right` | start saving every frame from 1327 to play/frames/p01_hold_dir/run3_right |
| 84 | 580776 | 1326 | `kd right` | key DOWN `right` delivered before run_frame 1327 |
| 85 | 581942 | 1346 | `step 20` | advanced to frame 1346 (frames 1327–1346 executed) |
| 86 | 581942 | 1346 | `ku right` | key UP `right` delivered before run_frame 1347 |
| 87 | 582115 | 1349 | `step 3` | advanced to frame 1349 (frames 1347–1349 executed) |
| 88 | 582115 | 1349 | `cap off` | stop per-frame capture |

### play/frames/p05_fuse/run1

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 89 | 614239 | 1349 | `cap /workspace/probe-run/frames/p05_fuse/run1` | start saving every frame from 1350 to play/frames/p05_fuse/run1 |
| 90 | 614243 | 1349 | `kd space` | key DOWN `space` delivered before run_frame 1350 |
| 91 | 614356 | 1350 | `step 1` | advanced to frame 1350 (frames 1350–1350 executed) |
| 92 | 614356 | 1350 | `ku space` | key UP `space` delivered before run_frame 1351 |
| 93 | 614358 | 1350 | `kd left` | key DOWN `left` delivered before run_frame 1351 |
| 94 | 614985 | 1360 | `step 10` | advanced to frame 1360 (frames 1351–1360 executed) |
| 95 | 614985 | 1360 | `ku left` | key UP `left` delivered before run_frame 1361 |
| 96 | 614989 | 1360 | `kd down` | key DOWN `down` delivered before run_frame 1361 |
| 97 | 615564 | 1370 | `step 10` | advanced to frame 1370 (frames 1361–1370 executed) |
| 98 | 615564 | 1370 | `ku down` | key UP `down` delivered before run_frame 1371 |
| 99 | 620720 | 1460 | `step 90` | advanced to frame 1460 (frames 1371–1460 executed) |
| 100 | 620720 | 1460 | `cap off` | stop per-frame capture |

### play/frames/p09_drop_pickup/run1

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 101 | 658176 | 1460 | `cap /workspace/probe-run/frames/p09_drop_pickup/run1` | start saving every frame from 1461 to play/frames/p09_drop_pickup/run1 |
| 102 | 658188 | 1460 | `kd up` | key DOWN `up` delivered before run_frame 1461 |
| 103 | 658783 | 1469 | `step 9` | advanced to frame 1469 (frames 1461–1469 executed) |
| 104 | 658783 | 1469 | `ku up` | key UP `up` delivered before run_frame 1470 |
| 105 | 658784 | 1469 | `kd right` | key DOWN `right` delivered before run_frame 1470 |
| 106 | 659975 | 1489 | `step 20` | advanced to frame 1489 (frames 1470–1489 executed) |
| 107 | 659975 | 1489 | `ku right` | key UP `right` delivered before run_frame 1490 |
| 108 | 660796 | 1504 | `step 15` | advanced to frame 1504 (frames 1490–1504 executed) |
| 109 | 660796 | 1504 | `cap off` | stop per-frame capture |

### between probes (setup / repositioning)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 110 | 660821 | 1504 | `shot /workspace/probe-run/after_pick.png` | single capture of the frame-1504 state |

### play/frames/p02_left_up/run1

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 111 | 690346 | 1504 | `cap /workspace/probe-run/frames/p02_left_up/run1` | start saving every frame from 1505 to play/frames/p02_left_up/run1 |
| 112 | 690349 | 1504 | `kd left` | key DOWN `left` delivered before run_frame 1505 |
| 113 | 690596 | 1508 | `step 4` | advanced to frame 1508 (frames 1505–1508 executed) |
| 114 | 690597 | 1508 | `kd up` | key DOWN `up` delivered before run_frame 1509 |
| 115 | 691145 | 1518 | `step 10` | advanced to frame 1518 (frames 1509–1518 executed) |
| 116 | 691146 | 1518 | `ku up` | key UP `up` delivered before run_frame 1519 |
| 117 | 692157 | 1534 | `step 16` | advanced to frame 1534 (frames 1519–1534 executed) |
| 118 | 692157 | 1534 | `ku left` | key UP `left` delivered before run_frame 1535 |
| 119 | 692325 | 1537 | `step 3` | advanced to frame 1537 (frames 1535–1537 executed) |
| 120 | 692325 | 1537 | `cap off` | stop per-frame capture |

### between probes (setup / repositioning)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 121 | 692326 | 1537 | `kd right` | key DOWN `right` delivered before run_frame 1538 |
| 122 | 692388 | 1557 | `step 20` | advanced to frame 1557 (frames 1538–1557 executed) |
| 123 | 692388 | 1557 | `ku right` | key UP `right` delivered before run_frame 1558 |
| 124 | 692403 | 1560 | `step 3` | advanced to frame 1560 (frames 1558–1560 executed) |

### play/frames/p02_left_up/run2

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 125 | 693712 | 1560 | `cap /workspace/probe-run/frames/p02_left_up/run2` | start saving every frame from 1561 to play/frames/p02_left_up/run2 |
| 126 | 693714 | 1560 | `kd left` | key DOWN `left` delivered before run_frame 1561 |
| 127 | 693936 | 1564 | `step 4` | advanced to frame 1564 (frames 1561–1564 executed) |
| 128 | 693937 | 1564 | `kd up` | key DOWN `up` delivered before run_frame 1565 |
| 129 | 694483 | 1574 | `step 10` | advanced to frame 1574 (frames 1565–1574 executed) |
| 130 | 694484 | 1574 | `ku up` | key UP `up` delivered before run_frame 1575 |
| 131 | 695403 | 1590 | `step 16` | advanced to frame 1590 (frames 1575–1590 executed) |
| 132 | 695403 | 1590 | `ku left` | key UP `left` delivered before run_frame 1591 |
| 133 | 695567 | 1593 | `step 3` | advanced to frame 1593 (frames 1591–1593 executed) |
| 134 | 695567 | 1593 | `cap off` | stop per-frame capture |

### between probes (setup / repositioning)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 135 | 695569 | 1593 | `kd right` | key DOWN `right` delivered before run_frame 1594 |
| 136 | 695629 | 1613 | `step 20` | advanced to frame 1613 (frames 1594–1613 executed) |
| 137 | 695629 | 1613 | `ku right` | key UP `right` delivered before run_frame 1614 |
| 138 | 695639 | 1616 | `step 3` | advanced to frame 1616 (frames 1614–1616 executed) |

### play/frames/p02_left_up/run3

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 139 | 697047 | 1616 | `cap /workspace/probe-run/frames/p02_left_up/run3` | start saving every frame from 1617 to play/frames/p02_left_up/run3 |
| 140 | 697049 | 1616 | `kd left` | key DOWN `left` delivered before run_frame 1617 |
| 141 | 697267 | 1620 | `step 4` | advanced to frame 1620 (frames 1617–1620 executed) |
| 142 | 697268 | 1620 | `kd up` | key DOWN `up` delivered before run_frame 1621 |
| 143 | 697756 | 1630 | `step 10` | advanced to frame 1630 (frames 1621–1630 executed) |
| 144 | 697757 | 1630 | `ku up` | key UP `up` delivered before run_frame 1631 |
| 145 | 698697 | 1646 | `step 16` | advanced to frame 1646 (frames 1631–1646 executed) |
| 146 | 698697 | 1646 | `ku left` | key UP `left` delivered before run_frame 1647 |
| 147 | 698858 | 1649 | `step 3` | advanced to frame 1649 (frames 1647–1649 executed) |
| 148 | 698858 | 1649 | `cap off` | stop per-frame capture |

### between probes (setup / repositioning)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 149 | 698860 | 1649 | `kd right` | key DOWN `right` delivered before run_frame 1650 |
| 150 | 698917 | 1669 | `step 20` | advanced to frame 1669 (frames 1650–1669 executed) |
| 151 | 698917 | 1669 | `ku right` | key UP `right` delivered before run_frame 1670 |
| 152 | 698926 | 1672 | `step 3` | advanced to frame 1672 (frames 1670–1672 executed) |

### play/frames/p03_two_dirs/portal_incidental_run1_RD_at_3_1

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 153 | 711876 | 1672 | `cap /workspace/probe-run/frames/p03_two_dirs/run1_same_frame_RD` | start saving every frame from 1673 to play/frames/p03_two_dirs/portal_incidental_run1_RD_at_3_1  (harness dir `/workspace/probe-run/frames/p03_two_dirs/run1_same_frame_RD`, renamed after capture) |
| 154 | 711877 | 1672 | `kd right` | key DOWN `right` delivered before run_frame 1673 |
| 155 | 711886 | 1672 | `kd down` | key DOWN `down` delivered before run_frame 1673 |
| 156 | 712791 | 1686 | `step 14` | advanced to frame 1686 (frames 1673–1686 executed) |
| 157 | 712791 | 1686 | `ku right` | key UP `right` delivered before run_frame 1687 |
| 158 | 712791 | 1686 | `ku down` | key UP `down` delivered before run_frame 1687 |
| 159 | 712983 | 1689 | `step 3` | advanced to frame 1689 (frames 1687–1689 executed) |
| 160 | 712983 | 1689 | `cap off` | stop per-frame capture |

### between probes (setup / repositioning)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 161 | 713791 | 1689 | `kd left` | key DOWN `left` delivered before run_frame 1690 |
| 162 | 713791 | 1689 | `kd up` | key DOWN `up` delivered before run_frame 1690 |
| 163 | 713834 | 1709 | `step 20` | advanced to frame 1709 (frames 1690–1709 executed) |
| 164 | 713834 | 1709 | `ku left` | key UP `left` delivered before run_frame 1710 |
| 165 | 713834 | 1709 | `ku up` | key UP `up` delivered before run_frame 1710 |
| 166 | 713838 | 1711 | `step 2` | advanced to frame 1711 (frames 1710–1711 executed) |
| 167 | 713839 | 1711 | `kd left` | key DOWN `left` delivered before run_frame 1712 |
| 168 | 713861 | 1721 | `step 10` | advanced to frame 1721 (frames 1712–1721 executed) |
| 169 | 713861 | 1721 | `ku left` | key UP `left` delivered before run_frame 1722 |
| 170 | 713862 | 1721 | `kd up` | key DOWN `up` delivered before run_frame 1722 |
| 171 | 713889 | 1731 | `step 10` | advanced to frame 1731 (frames 1722–1731 executed) |
| 172 | 713889 | 1731 | `ku up` | key UP `up` delivered before run_frame 1732 |
| 173 | 713902 | 1733 | `step 2` | advanced to frame 1733 (frames 1732–1733 executed) |

### play/frames/p03_two_dirs/portal_incidental_run2_RD_at_3_1

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 174 | 714007 | 1733 | `cap /workspace/probe-run/frames/p03_two_dirs/run2_same_frame_RD` | start saving every frame from 1734 to play/frames/p03_two_dirs/portal_incidental_run2_RD_at_3_1  (harness dir `/workspace/probe-run/frames/p03_two_dirs/run2_same_frame_RD`, renamed after capture) |
| 175 | 714009 | 1733 | `kd right` | key DOWN `right` delivered before run_frame 1734 |
| 176 | 714009 | 1733 | `kd down` | key DOWN `down` delivered before run_frame 1734 |
| 177 | 714816 | 1747 | `step 14` | advanced to frame 1747 (frames 1734–1747 executed) |
| 178 | 714816 | 1747 | `ku right` | key UP `right` delivered before run_frame 1748 |
| 179 | 714816 | 1747 | `ku down` | key UP `down` delivered before run_frame 1748 |
| 180 | 714989 | 1750 | `step 3` | advanced to frame 1750 (frames 1748–1750 executed) |
| 181 | 714989 | 1750 | `cap off` | stop per-frame capture |

### between probes (setup / repositioning)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 182 | 715715 | 1750 | `kd left` | key DOWN `left` delivered before run_frame 1751 |
| 183 | 715715 | 1750 | `kd up` | key DOWN `up` delivered before run_frame 1751 |
| 184 | 715758 | 1770 | `step 20` | advanced to frame 1770 (frames 1751–1770 executed) |
| 185 | 715758 | 1770 | `ku left` | key UP `left` delivered before run_frame 1771 |
| 186 | 715758 | 1770 | `ku up` | key UP `up` delivered before run_frame 1771 |
| 187 | 715764 | 1772 | `step 2` | advanced to frame 1772 (frames 1771–1772 executed) |
| 188 | 715764 | 1772 | `kd left` | key DOWN `left` delivered before run_frame 1773 |
| 189 | 715786 | 1782 | `step 10` | advanced to frame 1782 (frames 1773–1782 executed) |
| 190 | 715787 | 1782 | `ku left` | key UP `left` delivered before run_frame 1783 |
| 191 | 715787 | 1782 | `kd up` | key DOWN `up` delivered before run_frame 1783 |
| 192 | 715814 | 1792 | `step 10` | advanced to frame 1792 (frames 1783–1792 executed) |
| 193 | 715814 | 1792 | `ku up` | key UP `up` delivered before run_frame 1793 |
| 194 | 715822 | 1794 | `step 2` | advanced to frame 1794 (frames 1793–1794 executed) |

### play/frames/p03_two_dirs/portal_incidental_run3_RD_at_3_1

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 195 | 715928 | 1794 | `cap /workspace/probe-run/frames/p03_two_dirs/run3_same_frame_RD` | start saving every frame from 1795 to play/frames/p03_two_dirs/portal_incidental_run3_RD_at_3_1  (harness dir `/workspace/probe-run/frames/p03_two_dirs/run3_same_frame_RD`, renamed after capture) |
| 196 | 715930 | 1794 | `kd right` | key DOWN `right` delivered before run_frame 1795 |
| 197 | 715931 | 1794 | `kd down` | key DOWN `down` delivered before run_frame 1795 |
| 198 | 716782 | 1808 | `step 14` | advanced to frame 1808 (frames 1795–1808 executed) |
| 199 | 716782 | 1808 | `ku right` | key UP `right` delivered before run_frame 1809 |
| 200 | 716782 | 1808 | `ku down` | key UP `down` delivered before run_frame 1809 |
| 201 | 716974 | 1811 | `step 3` | advanced to frame 1811 (frames 1809–1811 executed) |
| 202 | 716974 | 1811 | `cap off` | stop per-frame capture |

### between probes (setup / repositioning)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 203 | 717699 | 1811 | `kd left` | key DOWN `left` delivered before run_frame 1812 |
| 204 | 717699 | 1811 | `kd up` | key DOWN `up` delivered before run_frame 1812 |
| 205 | 717762 | 1831 | `step 20` | advanced to frame 1831 (frames 1812–1831 executed) |
| 206 | 717762 | 1831 | `ku left` | key UP `left` delivered before run_frame 1832 |
| 207 | 717762 | 1831 | `ku up` | key UP `up` delivered before run_frame 1832 |
| 208 | 717766 | 1833 | `step 2` | advanced to frame 1833 (frames 1832–1833 executed) |
| 209 | 717767 | 1833 | `kd left` | key DOWN `left` delivered before run_frame 1834 |
| 210 | 717784 | 1843 | `step 10` | advanced to frame 1843 (frames 1834–1843 executed) |
| 211 | 717784 | 1843 | `ku left` | key UP `left` delivered before run_frame 1844 |
| 212 | 717785 | 1843 | `kd up` | key DOWN `up` delivered before run_frame 1844 |
| 213 | 717804 | 1853 | `step 10` | advanced to frame 1853 (frames 1844–1853 executed) |
| 214 | 717804 | 1853 | `ku up` | key UP `up` delivered before run_frame 1854 |
| 215 | 717808 | 1855 | `step 2` | advanced to frame 1855 (frames 1854–1855 executed) |
| 216 | 726236 | 1856 | `step 1` | advanced to frame 1856 (frames 1856–1856 executed) |
| 217 | 726308 | 1856 | `shot /workspace/probe-run/now.png` | single capture of the frame-1856 state |

### play/frames/p11_pause/run1_P

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 218 | 738001 | 1856 | `cap /workspace/probe-run/frames/p11_pause/run1_P` | start saving every frame from 1857 to play/frames/p11_pause/run1_P |
| 219 | 738001 | 1856 | `kd p` | key DOWN `p` delivered before run_frame 1857 |
| 220 | 738088 | 1857 | `step 1` | advanced to frame 1857 (frames 1857–1857 executed) |
| 221 | 738088 | 1857 | `ku p` | key UP `p` delivered before run_frame 1858 |
| 222 | 739133 | 1877 | `step 20` | advanced to frame 1877 (frames 1858–1877 executed) |
| 223 | 739133 | 1877 | `cap off` | stop per-frame capture |

### between probes (setup / repositioning)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 224 | 739173 | 1877 | `shot /workspace/probe-run/frames/p11_pause/run1_paused.png` | single capture of the frame-1877 state |

### play/frames/p11_pause/run1_P_again

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 225 | 739173 | 1877 | `cap /workspace/probe-run/frames/p11_pause/run1_P_again` | start saving every frame from 1878 to play/frames/p11_pause/run1_P_again |
| 226 | 739173 | 1877 | `kd p` | key DOWN `p` delivered before run_frame 1878 |
| 227 | 739222 | 1878 | `step 1` | advanced to frame 1878 (frames 1878–1878 executed) |
| 228 | 739222 | 1878 | `ku p` | key UP `p` delivered before run_frame 1879 |
| 229 | 739948 | 1893 | `step 15` | advanced to frame 1893 (frames 1879–1893 executed) |
| 230 | 739948 | 1893 | `cap off` | stop per-frame capture |

### play/frames/p11_pause/run1_esc

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 231 | 739948 | 1893 | `cap /workspace/probe-run/frames/p11_pause/run1_esc` | start saving every frame from 1894 to play/frames/p11_pause/run1_esc |
| 232 | 739949 | 1893 | `kd esc` | key DOWN `esc` delivered before run_frame 1894 |
| 233 | 739993 | 1894 | `step 1` | advanced to frame 1894 (frames 1894–1894 executed) |
| 234 | 739993 | 1894 | `ku esc` | key UP `esc` delivered before run_frame 1895 |
| 235 | 740683 | 1909 | `step 15` | advanced to frame 1909 (frames 1895–1909 executed) |
| 236 | 740683 | 1909 | `cap off` | stop per-frame capture |

### play/frames/p11_pause/run1_space

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 237 | 740683 | 1909 | `cap /workspace/probe-run/frames/p11_pause/run1_space` | start saving every frame from 1910 to play/frames/p11_pause/run1_space |
| 238 | 740684 | 1909 | `kd space` | key DOWN `space` delivered before run_frame 1910 |
| 239 | 740767 | 1910 | `step 1` | advanced to frame 1910 (frames 1910–1910 executed) |
| 240 | 740768 | 1910 | `ku space` | key UP `space` delivered before run_frame 1911 |
| 241 | 741985 | 1930 | `step 20` | advanced to frame 1930 (frames 1911–1930 executed) |
| 242 | 741985 | 1930 | `cap off` | stop per-frame capture |

### play/frames/p10_death/run2_ai_bomb_after_pause

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 243 | 767908 | 1930 | `cap /workspace/probe-run/frames/p10_death/run2` | start saving every frame from 1931 to play/frames/p10_death/run2_ai_bomb_after_pause  (harness dir `/workspace/probe-run/frames/p10_death/run2`, renamed after capture) |
| 244 | 776356 | 2080 | `step 150` | advanced to frame 2080 (frames 1931–2080 executed) |
| 245 | 776356 | 2080 | `cap off` | stop per-frame capture |

### between probes (setup / repositioning)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 246 | 805145 | 2120 | `step 40` | advanced to frame 2120 (frames 2081–2120 executed) |
| 247 | 805269 | 2120 | `shot /workspace/probe-run/res2.png` | single capture of the frame-2120 state |

### `/workspace/probe-run/run3_start` (not packed: helper capture)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 248 | 805283 | 2120 | `cap /workspace/probe-run/run3_start` | start saving every frame from 2121 to `/workspace/probe-run/run3_start` (not packed: helper capture) |
| 249 | 805304 | 2120 | `click 543 421` | mouse move+down+up at (543,421) before run_frame 2121 |
| 250 | 810112 | 2195 | `step 75` | advanced to frame 2195 (frames 2121–2195 executed) |
| 251 | 810112 | 2195 | `cap off` | stop per-frame capture |

### between probes (setup / repositioning)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 252 | 810146 | 2195 | `shot /workspace/probe-run/run3_first.png` | single capture of the frame-2195 state |

### play/frames/p12_timeout_win/run1

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 253 | 817990 | 2195 | `cap /workspace/probe-run/frames/p12_timeout_win/run1` | start saving every frame from 2196 to play/frames/p12_timeout_win/run1 |
| 254 | 818051 | 2196 | `step 1` | advanced to frame 2196 (frames 2196–2196 executed) |
| 255 | 819129 | 2197 | `step 1` | advanced to frame 2197 (frames 2197–2197 executed) |
| 256 | 820199 | 2198 | `step 1` | advanced to frame 2198 (frames 2198–2198 executed) |
| 257 | 821260 | 2199 | `step 1` | advanced to frame 2199 (frames 2199–2199 executed) |
| 258 | 822330 | 2200 | `step 1` | advanced to frame 2200 (frames 2200–2200 executed) |
| 259 | 823398 | 2201 | `step 1` | advanced to frame 2201 (frames 2201–2201 executed) |
| 260 | 824476 | 2202 | `step 1` | advanced to frame 2202 (frames 2202–2202 executed) |
| 261 | 825560 | 2203 | `step 1` | advanced to frame 2203 (frames 2203–2203 executed) |
| 262 | 826619 | 2204 | `step 1` | advanced to frame 2204 (frames 2204–2204 executed) |
| 263 | 827682 | 2205 | `step 1` | advanced to frame 2205 (frames 2205–2205 executed) |
| 264 | 828762 | 2206 | `step 1` | advanced to frame 2206 (frames 2206–2206 executed) |
| 265 | 829822 | 2207 | `step 1` | advanced to frame 2207 (frames 2207–2207 executed) |
| 266 | 830892 | 2208 | `step 1` | advanced to frame 2208 (frames 2208–2208 executed) |
| 267 | 831961 | 2209 | `step 1` | advanced to frame 2209 (frames 2209–2209 executed) |
| 268 | 833020 | 2210 | `step 1` | advanced to frame 2210 (frames 2210–2210 executed) |
| 269 | 834095 | 2211 | `step 1` | advanced to frame 2211 (frames 2211–2211 executed) |
| 270 | 835171 | 2212 | `step 1` | advanced to frame 2212 (frames 2212–2212 executed) |
| 271 | 836220 | 2213 | `step 1` | advanced to frame 2213 (frames 2213–2213 executed) |
| 272 | 837293 | 2214 | `step 1` | advanced to frame 2214 (frames 2214–2214 executed) |
| 273 | 838351 | 2215 | `step 1` | advanced to frame 2215 (frames 2215–2215 executed) |
| 274 | 839422 | 2216 | `step 1` | advanced to frame 2216 (frames 2216–2216 executed) |
| 275 | 840480 | 2217 | `step 1` | advanced to frame 2217 (frames 2217–2217 executed) |
| 276 | 841561 | 2218 | `step 1` | advanced to frame 2218 (frames 2218–2218 executed) |
| 277 | 842625 | 2219 | `step 1` | advanced to frame 2219 (frames 2219–2219 executed) |
| 278 | 843688 | 2220 | `step 1` | advanced to frame 2220 (frames 2220–2220 executed) |
| 279 | 844766 | 2221 | `step 1` | advanced to frame 2221 (frames 2221–2221 executed) |
| 280 | 845833 | 2222 | `step 1` | advanced to frame 2222 (frames 2222–2222 executed) |
| 281 | 846896 | 2223 | `step 1` | advanced to frame 2223 (frames 2223–2223 executed) |
| 282 | 847956 | 2224 | `step 1` | advanced to frame 2224 (frames 2224–2224 executed) |
| 283 | 849032 | 2225 | `step 1` | advanced to frame 2225 (frames 2225–2225 executed) |
| 284 | 850088 | 2226 | `step 1` | advanced to frame 2226 (frames 2226–2226 executed) |
| 285 | 851168 | 2227 | `step 1` | advanced to frame 2227 (frames 2227–2227 executed) |
| 286 | 852221 | 2228 | `step 1` | advanced to frame 2228 (frames 2228–2228 executed) |
| 287 | 853287 | 2229 | `step 1` | advanced to frame 2229 (frames 2229–2229 executed) |
| 288 | 854356 | 2230 | `step 1` | advanced to frame 2230 (frames 2230–2230 executed) |
| 289 | 855428 | 2231 | `step 1` | advanced to frame 2231 (frames 2231–2231 executed) |
| 290 | 856491 | 2232 | `step 1` | advanced to frame 2232 (frames 2232–2232 executed) |
| 291 | 857563 | 2233 | `step 1` | advanced to frame 2233 (frames 2233–2233 executed) |
| 292 | 858623 | 2234 | `step 1` | advanced to frame 2234 (frames 2234–2234 executed) |
| 293 | 859698 | 2235 | `step 1` | advanced to frame 2235 (frames 2235–2235 executed) |
| 294 | 860773 | 2236 | `step 1` | advanced to frame 2236 (frames 2236–2236 executed) |
| 295 | 861835 | 2237 | `step 1` | advanced to frame 2237 (frames 2237–2237 executed) |
| 296 | 862900 | 2238 | `step 1` | advanced to frame 2238 (frames 2238–2238 executed) |
| 297 | 863968 | 2239 | `step 1` | advanced to frame 2239 (frames 2239–2239 executed) |
| 298 | 865035 | 2240 | `step 1` | advanced to frame 2240 (frames 2240–2240 executed) |
| 299 | 866105 | 2241 | `step 1` | advanced to frame 2241 (frames 2241–2241 executed) |
| 300 | 867174 | 2242 | `step 1` | advanced to frame 2242 (frames 2242–2242 executed) |
| 301 | 868253 | 2243 | `step 1` | advanced to frame 2243 (frames 2243–2243 executed) |
| 302 | 869305 | 2244 | `step 1` | advanced to frame 2244 (frames 2244–2244 executed) |
| 303 | 870375 | 2245 | `step 1` | advanced to frame 2245 (frames 2245–2245 executed) |
| 304 | 871455 | 2246 | `step 1` | advanced to frame 2246 (frames 2246–2246 executed) |
| 305 | 872510 | 2247 | `step 1` | advanced to frame 2247 (frames 2247–2247 executed) |
| 306 | 873594 | 2248 | `step 1` | advanced to frame 2248 (frames 2248–2248 executed) |
| 307 | 874660 | 2249 | `step 1` | advanced to frame 2249 (frames 2249–2249 executed) |
| 308 | 875726 | 2250 | `step 1` | advanced to frame 2250 (frames 2250–2250 executed) |
| 309 | 876796 | 2251 | `step 1` | advanced to frame 2251 (frames 2251–2251 executed) |
| 310 | 877857 | 2252 | `step 1` | advanced to frame 2252 (frames 2252–2252 executed) |
| 311 | 878928 | 2253 | `step 1` | advanced to frame 2253 (frames 2253–2253 executed) |
| 312 | 879995 | 2254 | `step 1` | advanced to frame 2254 (frames 2254–2254 executed) |
| 313 | 881074 | 2255 | `step 1` | advanced to frame 2255 (frames 2255–2255 executed) |
| 314 | 882141 | 2256 | `step 1` | advanced to frame 2256 (frames 2256–2256 executed) |
| 315 | 883208 | 2257 | `step 1` | advanced to frame 2257 (frames 2257–2257 executed) |
| 316 | 884281 | 2258 | `step 1` | advanced to frame 2258 (frames 2258–2258 executed) |
| 317 | 885346 | 2259 | `step 1` | advanced to frame 2259 (frames 2259–2259 executed) |
| 318 | 886415 | 2260 | `step 1` | advanced to frame 2260 (frames 2260–2260 executed) |
| 319 | 887474 | 2261 | `step 1` | advanced to frame 2261 (frames 2261–2261 executed) |
| 320 | 888547 | 2262 | `step 1` | advanced to frame 2262 (frames 2262–2262 executed) |
| 321 | 889612 | 2263 | `step 1` | advanced to frame 2263 (frames 2263–2263 executed) |
| 322 | 890692 | 2264 | `step 1` | advanced to frame 2264 (frames 2264–2264 executed) |
| 323 | 891759 | 2265 | `step 1` | advanced to frame 2265 (frames 2265–2265 executed) |
| 324 | 892826 | 2266 | `step 1` | advanced to frame 2266 (frames 2266–2266 executed) |
| 325 | 893909 | 2267 | `step 1` | advanced to frame 2267 (frames 2267–2267 executed) |
| 326 | 894951 | 2268 | `step 1` | advanced to frame 2268 (frames 2268–2268 executed) |
| 327 | 896012 | 2269 | `step 1` | advanced to frame 2269 (frames 2269–2269 executed) |
| 328 | 897088 | 2270 | `step 1` | advanced to frame 2270 (frames 2270–2270 executed) |
| 329 | 898165 | 2271 | `step 1` | advanced to frame 2271 (frames 2271–2271 executed) |
| 330 | 899225 | 2272 | `step 1` | advanced to frame 2272 (frames 2272–2272 executed) |
| 331 | 900312 | 2273 | `step 1` | advanced to frame 2273 (frames 2273–2273 executed) |
| 332 | 901376 | 2274 | `step 1` | advanced to frame 2274 (frames 2274–2274 executed) |
| 333 | 902506 | 2275 | `step 1` | advanced to frame 2275 (frames 2275–2275 executed) |
| 334 | 903514 | 2276 | `step 1` | advanced to frame 2276 (frames 2276–2276 executed) |
| 335 | 904578 | 2277 | `step 1` | advanced to frame 2277 (frames 2277–2277 executed) |
| 336 | 905653 | 2278 | `step 1` | advanced to frame 2278 (frames 2278–2278 executed) |
| 337 | 906716 | 2279 | `step 1` | advanced to frame 2279 (frames 2279–2279 executed) |
| 338 | 907786 | 2280 | `step 1` | advanced to frame 2280 (frames 2280–2280 executed) |
| 339 | 908852 | 2281 | `step 1` | advanced to frame 2281 (frames 2281–2281 executed) |
| 340 | 909928 | 2282 | `step 1` | advanced to frame 2282 (frames 2282–2282 executed) |
| 341 | 910988 | 2283 | `step 1` | advanced to frame 2283 (frames 2283–2283 executed) |
| 342 | 912045 | 2284 | `step 1` | advanced to frame 2284 (frames 2284–2284 executed) |
| 343 | 913123 | 2285 | `step 1` | advanced to frame 2285 (frames 2285–2285 executed) |
| 344 | 914193 | 2286 | `step 1` | advanced to frame 2286 (frames 2286–2286 executed) |
| 345 | 915267 | 2287 | `step 1` | advanced to frame 2287 (frames 2287–2287 executed) |
| 346 | 916349 | 2288 | `step 1` | advanced to frame 2288 (frames 2288–2288 executed) |
| 347 | 917405 | 2289 | `step 1` | advanced to frame 2289 (frames 2289–2289 executed) |
| 348 | 918482 | 2290 | `step 1` | advanced to frame 2290 (frames 2290–2290 executed) |
| 349 | 919545 | 2291 | `step 1` | advanced to frame 2291 (frames 2291–2291 executed) |
| 350 | 920611 | 2292 | `step 1` | advanced to frame 2292 (frames 2292–2292 executed) |
| 351 | 921680 | 2293 | `step 1` | advanced to frame 2293 (frames 2293–2293 executed) |
| 352 | 922748 | 2294 | `step 1` | advanced to frame 2294 (frames 2294–2294 executed) |
| 353 | 923819 | 2295 | `step 1` | advanced to frame 2295 (frames 2295–2295 executed) |
| 354 | 924886 | 2296 | `step 1` | advanced to frame 2296 (frames 2296–2296 executed) |
| 355 | 925963 | 2297 | `step 1` | advanced to frame 2297 (frames 2297–2297 executed) |
| 356 | 927010 | 2298 | `step 1` | advanced to frame 2298 (frames 2298–2298 executed) |
| 357 | 928088 | 2299 | `step 1` | advanced to frame 2299 (frames 2299–2299 executed) |
| 358 | 929148 | 2300 | `step 1` | advanced to frame 2300 (frames 2300–2300 executed) |
| 359 | 930221 | 2301 | `step 1` | advanced to frame 2301 (frames 2301–2301 executed) |
| 360 | 931297 | 2302 | `step 1` | advanced to frame 2302 (frames 2302–2302 executed) |
| 361 | 932359 | 2303 | `step 1` | advanced to frame 2303 (frames 2303–2303 executed) |
| 362 | 933427 | 2304 | `step 1` | advanced to frame 2304 (frames 2304–2304 executed) |
| 363 | 934501 | 2305 | `step 1` | advanced to frame 2305 (frames 2305–2305 executed) |
| 364 | 935567 | 2306 | `step 1` | advanced to frame 2306 (frames 2306–2306 executed) |
| 365 | 936632 | 2307 | `step 1` | advanced to frame 2307 (frames 2307–2307 executed) |
| 366 | 937707 | 2308 | `step 1` | advanced to frame 2308 (frames 2308–2308 executed) |
| 367 | 938762 | 2309 | `step 1` | advanced to frame 2309 (frames 2309–2309 executed) |
| 368 | 939828 | 2310 | `step 1` | advanced to frame 2310 (frames 2310–2310 executed) |
| 369 | 940908 | 2311 | `step 1` | advanced to frame 2311 (frames 2311–2311 executed) |

### play/frames/p12_timeout_win/run1

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 370 | 943724 | 2311 | `cap /workspace/probe-run/frames/p12_timeout_win/run1` | start saving every frame from 2312 to play/frames/p12_timeout_win/run1 |
| 371 | 944156 | 2315 | `step 4` | advanced to frame 2315 (frames 2312–2315 executed) |
| 372 | 945346 | 2319 | `step 4` | advanced to frame 2319 (frames 2316–2319 executed) |
| 373 | 946534 | 2323 | `step 4` | advanced to frame 2323 (frames 2320–2323 executed) |
| 374 | 947711 | 2327 | `step 4` | advanced to frame 2327 (frames 2324–2327 executed) |
| 375 | 948877 | 2331 | `step 4` | advanced to frame 2331 (frames 2328–2331 executed) |
| 376 | 950042 | 2335 | `step 4` | advanced to frame 2335 (frames 2332–2335 executed) |
| 377 | 951044 | 2339 | `step 4` | advanced to frame 2339 (frames 2336–2339 executed) |
| 378 | 952239 | 2343 | `step 4` | advanced to frame 2343 (frames 2340–2343 executed) |
| 379 | 953406 | 2347 | `step 4` | advanced to frame 2347 (frames 2344–2347 executed) |
| 380 | 954578 | 2351 | `step 4` | advanced to frame 2351 (frames 2348–2351 executed) |
| 381 | 955740 | 2355 | `step 4` | advanced to frame 2355 (frames 2352–2355 executed) |
| 382 | 956932 | 2359 | `step 4` | advanced to frame 2359 (frames 2356–2359 executed) |
| 383 | 958120 | 2363 | `step 4` | advanced to frame 2363 (frames 2360–2363 executed) |
| 384 | 959317 | 2367 | `step 4` | advanced to frame 2367 (frames 2364–2367 executed) |
| 385 | 960480 | 2371 | `step 4` | advanced to frame 2371 (frames 2368–2371 executed) |
| 386 | 961678 | 2375 | `step 4` | advanced to frame 2375 (frames 2372–2375 executed) |
| 387 | 962850 | 2379 | `step 4` | advanced to frame 2379 (frames 2376–2379 executed) |
| 388 | 964024 | 2383 | `step 4` | advanced to frame 2383 (frames 2380–2383 executed) |
| 389 | 965212 | 2387 | `step 4` | advanced to frame 2387 (frames 2384–2387 executed) |
| 390 | 966389 | 2391 | `step 4` | advanced to frame 2391 (frames 2388–2391 executed) |
| 391 | 967557 | 2395 | `step 4` | advanced to frame 2395 (frames 2392–2395 executed) |
| 392 | 968773 | 2399 | `step 4` | advanced to frame 2399 (frames 2396–2399 executed) |
| 393 | 969945 | 2403 | `step 4` | advanced to frame 2403 (frames 2400–2403 executed) |
| 394 | 971098 | 2407 | `step 4` | advanced to frame 2407 (frames 2404–2407 executed) |
| 395 | 972277 | 2411 | `step 4` | advanced to frame 2411 (frames 2408–2411 executed) |
| 396 | 973468 | 2415 | `step 4` | advanced to frame 2415 (frames 2412–2415 executed) |
| 397 | 974622 | 2419 | `step 4` | advanced to frame 2419 (frames 2416–2419 executed) |
| 398 | 975625 | 2423 | `step 4` | advanced to frame 2423 (frames 2420–2423 executed) |
| 399 | 976810 | 2427 | `step 4` | advanced to frame 2427 (frames 2424–2427 executed) |
| 400 | 978054 | 2431 | `step 4` | advanced to frame 2431 (frames 2428–2431 executed) |
| 401 | 979173 | 2435 | `step 4` | advanced to frame 2435 (frames 2432–2435 executed) |
| 402 | 980343 | 2439 | `step 4` | advanced to frame 2439 (frames 2436–2439 executed) |
| 403 | 981539 | 2443 | `step 4` | advanced to frame 2443 (frames 2440–2443 executed) |
| 404 | 982708 | 2447 | `step 4` | advanced to frame 2447 (frames 2444–2447 executed) |
| 405 | 983856 | 2451 | `step 4` | advanced to frame 2451 (frames 2448–2451 executed) |
| 406 | 985012 | 2455 | `step 4` | advanced to frame 2455 (frames 2452–2455 executed) |
| 407 | 986010 | 2459 | `step 4` | advanced to frame 2459 (frames 2456–2459 executed) |
| 408 | 987205 | 2463 | `step 4` | advanced to frame 2463 (frames 2460–2463 executed) |
| 409 | 988394 | 2467 | `step 4` | advanced to frame 2467 (frames 2464–2467 executed) |
| 410 | 989549 | 2471 | `step 4` | advanced to frame 2471 (frames 2468–2471 executed) |
| 411 | 990722 | 2475 | `step 4` | advanced to frame 2475 (frames 2472–2475 executed) |
| 412 | 991898 | 2479 | `step 4` | advanced to frame 2479 (frames 2476–2479 executed) |
| 413 | 993074 | 2483 | `step 4` | advanced to frame 2483 (frames 2480–2483 executed) |
| 414 | 994070 | 2487 | `step 4` | advanced to frame 2487 (frames 2484–2487 executed) |
| 415 | 995239 | 2491 | `step 4` | advanced to frame 2491 (frames 2488–2491 executed) |
| 416 | 996398 | 2495 | `step 4` | advanced to frame 2495 (frames 2492–2495 executed) |
| 417 | 997558 | 2499 | `step 4` | advanced to frame 2499 (frames 2496–2499 executed) |
| 418 | 998525 | 2503 | `step 4` | advanced to frame 2503 (frames 2500–2503 executed) |
| 419 | 999509 | 2507 | `step 4` | advanced to frame 2507 (frames 2504–2507 executed) |
| 420 | 1000486 | 2511 | `step 4` | advanced to frame 2511 (frames 2508–2511 executed) |
| 421 | 1001677 | 2515 | `step 4` | advanced to frame 2515 (frames 2512–2515 executed) |
| 422 | 1002876 | 2519 | `step 4` | advanced to frame 2519 (frames 2516–2519 executed) |
| 423 | 1004051 | 2523 | `step 4` | advanced to frame 2523 (frames 2520–2523 executed) |
| 424 | 1005222 | 2527 | `step 4` | advanced to frame 2527 (frames 2524–2527 executed) |
| 425 | 1006395 | 2531 | `step 4` | advanced to frame 2531 (frames 2528–2531 executed) |
| 426 | 1007606 | 2535 | `step 4` | advanced to frame 2535 (frames 2532–2535 executed) |
| 427 | 1008786 | 2539 | `step 4` | advanced to frame 2539 (frames 2536–2539 executed) |
| 428 | 1009951 | 2543 | `step 4` | advanced to frame 2543 (frames 2540–2543 executed) |
| 429 | 1011149 | 2547 | `step 4` | advanced to frame 2547 (frames 2544–2547 executed) |
| 430 | 1012360 | 2551 | `step 4` | advanced to frame 2551 (frames 2548–2551 executed) |
| 431 | 1013508 | 2555 | `step 4` | advanced to frame 2555 (frames 2552–2555 executed) |
| 432 | 1014710 | 2559 | `step 4` | advanced to frame 2559 (frames 2556–2559 executed) |
| 433 | 1015875 | 2563 | `step 4` | advanced to frame 2563 (frames 2560–2563 executed) |
| 434 | 1017045 | 2567 | `step 4` | advanced to frame 2567 (frames 2564–2567 executed) |
| 435 | 1018233 | 2571 | `step 4` | advanced to frame 2571 (frames 2568–2571 executed) |
| 436 | 1019401 | 2575 | `step 4` | advanced to frame 2575 (frames 2572–2575 executed) |
| 437 | 1020582 | 2579 | `step 4` | advanced to frame 2579 (frames 2576–2579 executed) |
| 438 | 1021768 | 2583 | `step 4` | advanced to frame 2583 (frames 2580–2583 executed) |
| 439 | 1022915 | 2587 | `step 4` | advanced to frame 2587 (frames 2584–2587 executed) |
| 440 | 1024121 | 2591 | `step 4` | advanced to frame 2591 (frames 2588–2591 executed) |
| 441 | 1025295 | 2595 | `step 4` | advanced to frame 2595 (frames 2592–2595 executed) |
| 442 | 1026465 | 2599 | `step 4` | advanced to frame 2599 (frames 2596–2599 executed) |
| 443 | 1027665 | 2603 | `step 4` | advanced to frame 2603 (frames 2600–2603 executed) |
| 444 | 1028887 | 2607 | `step 4` | advanced to frame 2607 (frames 2604–2607 executed) |
| 445 | 1030048 | 2611 | `step 4` | advanced to frame 2611 (frames 2608–2611 executed) |
| 446 | 1031216 | 2615 | `step 4` | advanced to frame 2615 (frames 2612–2615 executed) |
| 447 | 1032426 | 2619 | `step 4` | advanced to frame 2619 (frames 2616–2619 executed) |
| 448 | 1033598 | 2623 | `step 4` | advanced to frame 2623 (frames 2620–2623 executed) |
| 449 | 1034750 | 2627 | `step 4` | advanced to frame 2627 (frames 2624–2627 executed) |
| 450 | 1035920 | 2631 | `step 4` | advanced to frame 2631 (frames 2628–2631 executed) |
| 451 | 1037115 | 2635 | `step 4` | advanced to frame 2635 (frames 2632–2635 executed) |
| 452 | 1038298 | 2639 | `step 4` | advanced to frame 2639 (frames 2636–2639 executed) |
| 453 | 1039478 | 2643 | `step 4` | advanced to frame 2643 (frames 2640–2643 executed) |
| 454 | 1040659 | 2647 | `step 4` | advanced to frame 2647 (frames 2644–2647 executed) |
| 455 | 1041837 | 2651 | `step 4` | advanced to frame 2651 (frames 2648–2651 executed) |
| 456 | 1043011 | 2655 | `step 4` | advanced to frame 2655 (frames 2652–2655 executed) |
| 457 | 1044195 | 2659 | `step 4` | advanced to frame 2659 (frames 2656–2659 executed) |
| 458 | 1045386 | 2663 | `step 4` | advanced to frame 2663 (frames 2660–2663 executed) |
| 459 | 1046604 | 2667 | `step 4` | advanced to frame 2667 (frames 2664–2667 executed) |
| 460 | 1047745 | 2671 | `step 4` | advanced to frame 2671 (frames 2668–2671 executed) |
| 461 | 1048960 | 2675 | `step 4` | advanced to frame 2675 (frames 2672–2675 executed) |
| 462 | 1050149 | 2679 | `step 4` | advanced to frame 2679 (frames 2676–2679 executed) |
| 463 | 1051286 | 2683 | `step 4` | advanced to frame 2683 (frames 2680–2683 executed) |
| 464 | 1052493 | 2687 | `step 4` | advanced to frame 2687 (frames 2684–2687 executed) |
| 465 | 1053673 | 2691 | `step 4` | advanced to frame 2691 (frames 2688–2691 executed) |
| 466 | 1054841 | 2695 | `step 4` | advanced to frame 2695 (frames 2692–2695 executed) |
| 467 | 1056020 | 2699 | `step 4` | advanced to frame 2699 (frames 2696–2699 executed) |
| 468 | 1057230 | 2703 | `step 4` | advanced to frame 2703 (frames 2700–2703 executed) |
| 469 | 1058409 | 2707 | `step 4` | advanced to frame 2707 (frames 2704–2707 executed) |
| 470 | 1059582 | 2711 | `step 4` | advanced to frame 2711 (frames 2708–2711 executed) |
| 471 | 1060780 | 2715 | `step 4` | advanced to frame 2715 (frames 2712–2715 executed) |
| 472 | 1061913 | 2719 | `step 4` | advanced to frame 2719 (frames 2716–2719 executed) |
| 473 | 1063157 | 2723 | `step 4` | advanced to frame 2723 (frames 2720–2723 executed) |
| 474 | 1064287 | 2727 | `step 4` | advanced to frame 2727 (frames 2724–2727 executed) |
| 475 | 1065479 | 2731 | `step 4` | advanced to frame 2731 (frames 2728–2731 executed) |
| 476 | 1066663 | 2735 | `step 4` | advanced to frame 2735 (frames 2732–2735 executed) |
| 477 | 1067862 | 2739 | `step 4` | advanced to frame 2739 (frames 2736–2739 executed) |
| 478 | 1069030 | 2743 | `step 4` | advanced to frame 2743 (frames 2740–2743 executed) |
| 479 | 1070207 | 2747 | `step 4` | advanced to frame 2747 (frames 2744–2747 executed) |
| 480 | 1071374 | 2751 | `step 4` | advanced to frame 2751 (frames 2748–2751 executed) |
| 481 | 1072548 | 2755 | `step 4` | advanced to frame 2755 (frames 2752–2755 executed) |
| 482 | 1073750 | 2759 | `step 4` | advanced to frame 2759 (frames 2756–2759 executed) |
| 483 | 1074942 | 2763 | `step 4` | advanced to frame 2763 (frames 2760–2763 executed) |
| 484 | 1076109 | 2767 | `step 4` | advanced to frame 2767 (frames 2764–2767 executed) |
| 485 | 1077301 | 2771 | `step 4` | advanced to frame 2771 (frames 2768–2771 executed) |
| 486 | 1078468 | 2775 | `step 4` | advanced to frame 2775 (frames 2772–2775 executed) |
| 487 | 1079623 | 2779 | `step 4` | advanced to frame 2779 (frames 2776–2779 executed) |
| 488 | 1080842 | 2783 | `step 4` | advanced to frame 2783 (frames 2780–2783 executed) |
| 489 | 1082007 | 2787 | `step 4` | advanced to frame 2787 (frames 2784–2787 executed) |
| 490 | 1083215 | 2791 | `step 4` | advanced to frame 2791 (frames 2788–2791 executed) |
| 491 | 1084364 | 2795 | `step 4` | advanced to frame 2795 (frames 2792–2795 executed) |
| 492 | 1085542 | 2799 | `step 4` | advanced to frame 2799 (frames 2796–2799 executed) |
| 493 | 1086720 | 2803 | `step 4` | advanced to frame 2803 (frames 2800–2803 executed) |
| 494 | 1087934 | 2807 | `step 4` | advanced to frame 2807 (frames 2804–2807 executed) |
| 495 | 1089133 | 2811 | `step 4` | advanced to frame 2811 (frames 2808–2811 executed) |
| 496 | 1090299 | 2815 | `step 4` | advanced to frame 2815 (frames 2812–2815 executed) |
| 497 | 1091457 | 2819 | `step 4` | advanced to frame 2819 (frames 2816–2819 executed) |
| 498 | 1092639 | 2823 | `step 4` | advanced to frame 2823 (frames 2820–2823 executed) |
| 499 | 1093842 | 2827 | `step 4` | advanced to frame 2827 (frames 2824–2827 executed) |
| 500 | 1095018 | 2831 | `step 4` | advanced to frame 2831 (frames 2828–2831 executed) |
| 501 | 1096179 | 2835 | `step 4` | advanced to frame 2835 (frames 2832–2835 executed) |
| 502 | 1097332 | 2839 | `step 4` | advanced to frame 2839 (frames 2836–2839 executed) |
| 503 | 1098516 | 2843 | `step 4` | advanced to frame 2843 (frames 2840–2843 executed) |
| 504 | 1099721 | 2847 | `step 4` | advanced to frame 2847 (frames 2844–2847 executed) |
| 505 | 1100855 | 2851 | `step 4` | advanced to frame 2851 (frames 2848–2851 executed) |
| 506 | 1102063 | 2855 | `step 4` | advanced to frame 2855 (frames 2852–2855 executed) |
| 507 | 1103238 | 2859 | `step 4` | advanced to frame 2859 (frames 2856–2859 executed) |
| 508 | 1104409 | 2863 | `step 4` | advanced to frame 2863 (frames 2860–2863 executed) |
| 509 | 1105596 | 2867 | `step 4` | advanced to frame 2867 (frames 2864–2867 executed) |
| 510 | 1106757 | 2871 | `step 4` | advanced to frame 2871 (frames 2868–2871 executed) |
| 511 | 1107934 | 2875 | `step 4` | advanced to frame 2875 (frames 2872–2875 executed) |
| 512 | 1109100 | 2879 | `step 4` | advanced to frame 2879 (frames 2876–2879 executed) |
| 513 | 1110300 | 2883 | `step 4` | advanced to frame 2883 (frames 2880–2883 executed) |
| 514 | 1111508 | 2887 | `step 4` | advanced to frame 2887 (frames 2884–2887 executed) |
| 515 | 1112671 | 2891 | `step 4` | advanced to frame 2891 (frames 2888–2891 executed) |
| 516 | 1113850 | 2895 | `step 4` | advanced to frame 2895 (frames 2892–2895 executed) |
| 517 | 1115058 | 2899 | `step 4` | advanced to frame 2899 (frames 2896–2899 executed) |
| 518 | 1116207 | 2903 | `step 4` | advanced to frame 2903 (frames 2900–2903 executed) |
| 519 | 1117397 | 2907 | `step 4` | advanced to frame 2907 (frames 2904–2907 executed) |
| 520 | 1118624 | 2911 | `step 4` | advanced to frame 2911 (frames 2908–2911 executed) |
| 521 | 1119754 | 2915 | `step 4` | advanced to frame 2915 (frames 2912–2915 executed) |
| 522 | 1120904 | 2919 | `step 4` | advanced to frame 2919 (frames 2916–2919 executed) |
| 523 | 1122091 | 2923 | `step 4` | advanced to frame 2923 (frames 2920–2923 executed) |
| 524 | 1123188 | 2927 | `step 4` | advanced to frame 2927 (frames 2924–2927 executed) |
| 525 | 1124166 | 2931 | `step 4` | advanced to frame 2931 (frames 2928–2931 executed) |
| 526 | 1125135 | 2935 | `step 4` | advanced to frame 2935 (frames 2932–2935 executed) |
| 527 | 1126093 | 2939 | `step 4` | advanced to frame 2939 (frames 2936–2939 executed) |
| 528 | 1127072 | 2943 | `step 4` | advanced to frame 2943 (frames 2940–2943 executed) |
| 529 | 1128034 | 2947 | `step 4` | advanced to frame 2947 (frames 2944–2947 executed) |
| 530 | 1129003 | 2951 | `step 4` | advanced to frame 2951 (frames 2948–2951 executed) |
| 531 | 1129957 | 2955 | `step 4` | advanced to frame 2955 (frames 2952–2955 executed) |
| 532 | 1130956 | 2959 | `step 4` | advanced to frame 2959 (frames 2956–2959 executed) |
| 533 | 1131924 | 2963 | `step 4` | advanced to frame 2963 (frames 2960–2963 executed) |
| 534 | 1132887 | 2967 | `step 4` | advanced to frame 2967 (frames 2964–2967 executed) |
| 535 | 1133842 | 2971 | `step 4` | advanced to frame 2971 (frames 2968–2971 executed) |
| 536 | 1134815 | 2975 | `step 4` | advanced to frame 2975 (frames 2972–2975 executed) |
| 537 | 1135809 | 2979 | `step 4` | advanced to frame 2979 (frames 2976–2979 executed) |
| 538 | 1136756 | 2983 | `step 4` | advanced to frame 2983 (frames 2980–2983 executed) |
| 539 | 1137731 | 2987 | `step 4` | advanced to frame 2987 (frames 2984–2987 executed) |
| 540 | 1138713 | 2991 | `step 4` | advanced to frame 2991 (frames 2988–2991 executed) |
| 541 | 1139677 | 2995 | `step 4` | advanced to frame 2995 (frames 2992–2995 executed) |
| 542 | 1140637 | 2999 | `step 4` | advanced to frame 2999 (frames 2996–2999 executed) |
| 543 | 1141578 | 3003 | `step 4` | advanced to frame 3003 (frames 3000–3003 executed) |
| 544 | 1142566 | 3007 | `step 4` | advanced to frame 3007 (frames 3004–3007 executed) |
| 545 | 1143535 | 3011 | `step 4` | advanced to frame 3011 (frames 3008–3011 executed) |
| 546 | 1144500 | 3015 | `step 4` | advanced to frame 3015 (frames 3012–3015 executed) |
| 547 | 1145472 | 3019 | `step 4` | advanced to frame 3019 (frames 3016–3019 executed) |
| 548 | 1146465 | 3023 | `step 4` | advanced to frame 3023 (frames 3020–3023 executed) |
| 549 | 1147410 | 3027 | `step 4` | advanced to frame 3027 (frames 3024–3027 executed) |
| 550 | 1148375 | 3031 | `step 4` | advanced to frame 3031 (frames 3028–3031 executed) |
| 551 | 1149340 | 3035 | `step 4` | advanced to frame 3035 (frames 3032–3035 executed) |
| 552 | 1150314 | 3039 | `step 4` | advanced to frame 3039 (frames 3036–3039 executed) |
| 553 | 1151287 | 3043 | `step 4` | advanced to frame 3043 (frames 3040–3043 executed) |
| 554 | 1152259 | 3047 | `step 4` | advanced to frame 3047 (frames 3044–3047 executed) |
| 555 | 1153231 | 3051 | `step 4` | advanced to frame 3051 (frames 3048–3051 executed) |
| 556 | 1154212 | 3055 | `step 4` | advanced to frame 3055 (frames 3052–3055 executed) |
| 557 | 1155184 | 3059 | `step 4` | advanced to frame 3059 (frames 3056–3059 executed) |
| 558 | 1156141 | 3063 | `step 4` | advanced to frame 3063 (frames 3060–3063 executed) |

### `/workspace/probe-run/lvl2_start` (not packed: helper capture)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 559 | 1190132 | 3063 | `cap /workspace/probe-run/lvl2_start` | start saving every frame from 3064 to `/workspace/probe-run/lvl2_start` (not packed: helper capture) |
| 560 | 1190182 | 3063 | `click 543 421` | mouse move+down+up at (543,421) before run_frame 3064 |
| 561 | 1196053 | 3153 | `step 90` | advanced to frame 3153 (frames 3064–3153 executed) |
| 562 | 1196053 | 3153 | `cap off` | stop per-frame capture |

### between probes (setup / repositioning)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 563 | 1196083 | 3153 | `shot /workspace/probe-run/lvl2.png` | single capture of the frame-3153 state |
| 564 | 1220127 | 3153 | `kd right` | key DOWN `right` delivered before run_frame 3154 |
| 565 | 1220159 | 3163 | `step 10` | advanced to frame 3163 (frames 3154–3163 executed) |
| 566 | 1220160 | 3163 | `ku right` | key UP `right` delivered before run_frame 3164 |
| 567 | 1220163 | 3164 | `step 1` | advanced to frame 3164 (frames 3164–3164 executed) |

### play/frames/p04_space/run1_held

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 568 | 1220341 | 3164 | `cap /workspace/probe-run/frames/p04_space/run1_held` | start saving every frame from 3165 to play/frames/p04_space/run1_held |
| 569 | 1220343 | 3164 | `kd space` | key DOWN `space` delivered before run_frame 3165 |
| 570 | 1220441 | 3166 | `step 2` | advanced to frame 3166 (frames 3165–3166 executed) |
| 571 | 1220443 | 3166 | `kd left` | key DOWN `left` delivered before run_frame 3167 |
| 572 | 1220898 | 3176 | `step 10` | advanced to frame 3176 (frames 3167–3176 executed) |
| 573 | 1220898 | 3176 | `ku left` | key UP `left` delivered before run_frame 3177 |
| 574 | 1220901 | 3176 | `kd down` | key DOWN `down` delivered before run_frame 3177 |
| 575 | 1221507 | 3186 | `step 10` | advanced to frame 3186 (frames 3177–3186 executed) |
| 576 | 1221507 | 3186 | `ku down` | key UP `down` delivered before run_frame 3187 |
| 577 | 1226509 | 3286 | `step 100` | advanced to frame 3286 (frames 3187–3286 executed) |
| 578 | 1226509 | 3286 | `ku space` | key UP `space` delivered before run_frame 3287 |
| 579 | 1227020 | 3296 | `step 10` | advanced to frame 3296 (frames 3287–3296 executed) |
| 580 | 1227020 | 3296 | `cap off` | stop per-frame capture |

### between probes (setup / repositioning)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 581 | 1227050 | 3296 | `shot /workspace/probe-run/now.png` | single capture of the frame-3296 state |

### play/frames/p04_space/run2_repeated

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 582 | 1278199 | 3296 | `cap /workspace/probe-run/frames/p04_space/run2_repeated` | start saving every frame from 3297 to play/frames/p04_space/run2_repeated |
| 583 | 1278202 | 3296 | `kd space` | key DOWN `space` delivered before run_frame 3297 |
| 584 | 1278316 | 3297 | `step 1` | advanced to frame 3297 (frames 3297–3297 executed) |
| 585 | 1278316 | 3297 | `ku space` | key UP `space` delivered before run_frame 3298 |
| 586 | 1278481 | 3300 | `step 3` | advanced to frame 3300 (frames 3298–3300 executed) |
| 587 | 1278481 | 3300 | `kd space` | key DOWN `space` delivered before run_frame 3301 |
| 588 | 1278527 | 3301 | `step 1` | advanced to frame 3301 (frames 3301–3301 executed) |
| 589 | 1278527 | 3301 | `ku space` | key UP `space` delivered before run_frame 3302 |
| 590 | 1278661 | 3304 | `step 3` | advanced to frame 3304 (frames 3302–3304 executed) |
| 591 | 1278661 | 3304 | `kd space` | key DOWN `space` delivered before run_frame 3305 |
| 592 | 1278703 | 3305 | `step 1` | advanced to frame 3305 (frames 3305–3305 executed) |
| 593 | 1278703 | 3305 | `ku space` | key UP `space` delivered before run_frame 3306 |
| 594 | 1278820 | 3308 | `step 3` | advanced to frame 3308 (frames 3306–3308 executed) |
| 595 | 1278822 | 3308 | `kd up` | key DOWN `up` delivered before run_frame 3309 |
| 596 | 1278822 | 3308 | `kd space` | key DOWN `space` delivered before run_frame 3309 |
| 597 | 1278896 | 3309 | `step 1` | advanced to frame 3309 (frames 3309–3309 executed) |
| 598 | 1278896 | 3309 | `ku space` | key UP `space` delivered before run_frame 3310 |
| 599 | 1279057 | 3312 | `step 3` | advanced to frame 3312 (frames 3310–3312 executed) |
| 600 | 1279057 | 3312 | `kd space` | key DOWN `space` delivered before run_frame 3313 |
| 601 | 1279111 | 3313 | `step 1` | advanced to frame 3313 (frames 3313–3313 executed) |
| 602 | 1279111 | 3313 | `ku space` | key UP `space` delivered before run_frame 3314 |
| 603 | 1279275 | 3316 | `step 3` | advanced to frame 3316 (frames 3314–3316 executed) |
| 604 | 1279388 | 3318 | `step 2` | advanced to frame 3318 (frames 3317–3318 executed) |
| 605 | 1279388 | 3318 | `ku up` | key UP `up` delivered before run_frame 3319 |
| 606 | 1279392 | 3318 | `kd right` | key DOWN `right` delivered before run_frame 3319 |
| 607 | 1279392 | 3318 | `kd space` | key DOWN `space` delivered before run_frame 3319 |
| 608 | 1279444 | 3319 | `step 1` | advanced to frame 3319 (frames 3319–3319 executed) |
| 609 | 1279444 | 3319 | `ku space` | key UP `space` delivered before run_frame 3320 |
| 610 | 1279648 | 3322 | `step 3` | advanced to frame 3322 (frames 3320–3322 executed) |
| 611 | 1279648 | 3322 | `kd space` | key DOWN `space` delivered before run_frame 3323 |
| 612 | 1279699 | 3323 | `step 1` | advanced to frame 3323 (frames 3323–3323 executed) |
| 613 | 1279699 | 3323 | `ku space` | key UP `space` delivered before run_frame 3324 |
| 614 | 1279867 | 3326 | `step 3` | advanced to frame 3326 (frames 3324–3326 executed) |
| 615 | 1279868 | 3326 | `kd space` | key DOWN `space` delivered before run_frame 3327 |
| 616 | 1279913 | 3327 | `step 1` | advanced to frame 3327 (frames 3327–3327 executed) |
| 617 | 1279913 | 3327 | `ku space` | key UP `space` delivered before run_frame 3328 |
| 618 | 1280062 | 3330 | `step 3` | advanced to frame 3330 (frames 3328–3330 executed) |
| 619 | 1280062 | 3330 | `kd space` | key DOWN `space` delivered before run_frame 3331 |
| 620 | 1280103 | 3331 | `step 1` | advanced to frame 3331 (frames 3331–3331 executed) |
| 621 | 1280104 | 3331 | `ku space` | key UP `space` delivered before run_frame 3332 |
| 622 | 1280263 | 3334 | `step 3` | advanced to frame 3334 (frames 3332–3334 executed) |
| 623 | 1280263 | 3334 | `ku right` | key UP `right` delivered before run_frame 3335 |
| 624 | 1284142 | 3424 | `step 90` | advanced to frame 3424 (frames 3335–3424 executed) |
| 625 | 1284142 | 3424 | `cap off` | stop per-frame capture |

### play/frames/p09_drop_pickup/run2

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 626 | 1321892 | 3424 | `cap /workspace/probe-run/frames/p09_drop_pickup/run2` | start saving every frame from 3425 to play/frames/p09_drop_pickup/run2 |
| 627 | 1321908 | 3424 | `kd left` | key DOWN `left` delivered before run_frame 3425 |
| 628 | 1322732 | 3442 | `step 18` | advanced to frame 3442 (frames 3425–3442 executed) |
| 629 | 1322732 | 3442 | `ku left` | key UP `left` delivered before run_frame 3443 |
| 630 | 1322734 | 3442 | `kd down` | key DOWN `down` delivered before run_frame 3443 |
| 631 | 1323556 | 3460 | `step 18` | advanced to frame 3460 (frames 3443–3460 executed) |
| 632 | 1323556 | 3460 | `ku down` | key UP `down` delivered before run_frame 3461 |
| 633 | 1323719 | 3464 | `step 4` | advanced to frame 3464 (frames 3461–3464 executed) |
| 634 | 1323719 | 3464 | `cap off` | stop per-frame capture |

### between probes (setup / repositioning)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 635 | 1323746 | 3464 | `shot /workspace/probe-run/n_after2.png` | single capture of the frame-3464 state |

### play/frames/p08_chain/run1

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 636 | 1337095 | 3464 | `cap /workspace/probe-run/frames/p08_chain/run1` | start saving every frame from 3465 to play/frames/p08_chain/run1 |
| 637 | 1337098 | 3464 | `kd up` | key DOWN `up` delivered before run_frame 3465 |
| 638 | 1337821 | 3481 | `step 17` | advanced to frame 3481 (frames 3465–3481 executed) |
| 639 | 1337821 | 3481 | `ku up` | key UP `up` delivered before run_frame 3482 |
| 640 | 1337823 | 3481 | `kd right` | key DOWN `right` delivered before run_frame 3482 |
| 641 | 1338599 | 3498 | `step 17` | advanced to frame 3498 (frames 3482–3498 executed) |
| 642 | 1338599 | 3498 | `ku right` | key UP `right` delivered before run_frame 3499 |
| 643 | 1338599 | 3498 | `kd space` | key DOWN `space` delivered before run_frame 3499 |
| 644 | 1338648 | 3499 | `step 1` | advanced to frame 3499 (frames 3499–3499 executed) |
| 645 | 1338648 | 3499 | `ku space` | key UP `space` delivered before run_frame 3500 |
| 646 | 1338650 | 3499 | `kd left` | key DOWN `left` delivered before run_frame 3500 |
| 647 | 1339006 | 3507 | `step 8` | advanced to frame 3507 (frames 3500–3507 executed) |
| 648 | 1339006 | 3507 | `ku left` | key UP `left` delivered before run_frame 3508 |
| 649 | 1339006 | 3507 | `kd space` | key DOWN `space` delivered before run_frame 3508 |
| 650 | 1339047 | 3508 | `step 1` | advanced to frame 3508 (frames 3508–3508 executed) |
| 651 | 1339048 | 3508 | `ku space` | key UP `space` delivered before run_frame 3509 |
| 652 | 1339048 | 3508 | `kd left` | key DOWN `left` delivered before run_frame 3509 |
| 653 | 1339426 | 3517 | `step 9` | advanced to frame 3517 (frames 3509–3517 executed) |
| 654 | 1339426 | 3517 | `ku left` | key UP `left` delivered before run_frame 3518 |
| 655 | 1339428 | 3517 | `kd down` | key DOWN `down` delivered before run_frame 3518 |
| 656 | 1340285 | 3535 | `step 18` | advanced to frame 3535 (frames 3518–3535 executed) |
| 657 | 1340285 | 3535 | `ku down` | key UP `down` delivered before run_frame 3536 |
| 658 | 1343806 | 3615 | `step 80` | advanced to frame 3615 (frames 3536–3615 executed) |
| 659 | 1343806 | 3615 | `cap off` | stop per-frame capture |

### between probes (setup / repositioning)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 660 | 1343833 | 3615 | `shot /workspace/probe-run/n_chain.png` | single capture of the frame-3615 state |
| 661 | 1373849 | 3615 | `kd up` | key DOWN `up` delivered before run_frame 3616 |
| 662 | 1373895 | 3633 | `step 18` | advanced to frame 3633 (frames 3616–3633 executed) |
| 663 | 1373895 | 3633 | `ku up` | key UP `up` delivered before run_frame 3634 |
| 664 | 1373899 | 3635 | `step 2` | advanced to frame 3635 (frames 3634–3635 executed) |

### play/frames/p03_two_dirs/va_run1

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 665 | 1374063 | 3635 | `cap /workspace/probe-run/frames/p03_two_dirs/va` | start saving every frame from 3636 to play/frames/p03_two_dirs/va_run1  (harness dir `/workspace/probe-run/frames/p03_two_dirs/va`, renamed after capture) |
| 666 | 1374066 | 3635 | `kd right` | key DOWN `right` delivered before run_frame 3636 |
| 667 | 1374067 | 3635 | `kd down` | key DOWN `down` delivered before run_frame 3636 |
| 668 | 1374647 | 3647 | `step 12` | advanced to frame 3647 (frames 3636–3647 executed) |
| 669 | 1374647 | 3647 | `ku right` | key UP `right` delivered before run_frame 3648 |
| 670 | 1374647 | 3647 | `ku down` | key UP `down` delivered before run_frame 3648 |
| 671 | 1374736 | 3649 | `step 2` | advanced to frame 3649 (frames 3648–3649 executed) |
| 672 | 1374736 | 3649 | `cap off` | stop per-frame capture |

### between probes (setup / repositioning)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 673 | 1375455 | 3649 | `kd left` | key DOWN `left` delivered before run_frame 3650 |
| 674 | 1375513 | 3661 | `step 12` | advanced to frame 3661 (frames 3650–3661 executed) |
| 675 | 1375513 | 3661 | `ku left` | key UP `left` delivered before run_frame 3662 |
| 676 | 1375514 | 3661 | `kd up` | key DOWN `up` delivered before run_frame 3662 |
| 677 | 1375550 | 3673 | `step 12` | advanced to frame 3673 (frames 3662–3673 executed) |
| 678 | 1375550 | 3673 | `ku up` | key UP `up` delivered before run_frame 3674 |
| 679 | 1375555 | 3675 | `step 2` | advanced to frame 3675 (frames 3674–3675 executed) |

### play/frames/p03_two_dirs/vb_run1

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 680 | 1375668 | 3675 | `cap /workspace/probe-run/frames/p03_two_dirs/vb` | start saving every frame from 3676 to play/frames/p03_two_dirs/vb_run1  (harness dir `/workspace/probe-run/frames/p03_two_dirs/vb`, renamed after capture) |
| 681 | 1375670 | 3675 | `kd right` | key DOWN `right` delivered before run_frame 3676 |
| 682 | 1375815 | 3678 | `step 3` | advanced to frame 3678 (frames 3676–3678 executed) |
| 683 | 1375818 | 3678 | `kd down` | key DOWN `down` delivered before run_frame 3679 |
| 684 | 1376346 | 3690 | `step 12` | advanced to frame 3690 (frames 3679–3690 executed) |
| 685 | 1376346 | 3690 | `ku right` | key UP `right` delivered before run_frame 3691 |
| 686 | 1376346 | 3690 | `ku down` | key UP `down` delivered before run_frame 3691 |
| 687 | 1376419 | 3692 | `step 2` | advanced to frame 3692 (frames 3691–3692 executed) |
| 688 | 1376419 | 3692 | `cap off` | stop per-frame capture |

### between probes (setup / repositioning)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 689 | 1377158 | 3692 | `kd left` | key DOWN `left` delivered before run_frame 3693 |
| 690 | 1377186 | 3704 | `step 12` | advanced to frame 3704 (frames 3693–3704 executed) |
| 691 | 1377186 | 3704 | `ku left` | key UP `left` delivered before run_frame 3705 |
| 692 | 1377188 | 3704 | `kd up` | key DOWN `up` delivered before run_frame 3705 |
| 693 | 1377212 | 3716 | `step 12` | advanced to frame 3716 (frames 3705–3716 executed) |
| 694 | 1377212 | 3716 | `ku up` | key UP `up` delivered before run_frame 3717 |
| 695 | 1377215 | 3718 | `step 2` | advanced to frame 3718 (frames 3717–3718 executed) |

### play/frames/p03_two_dirs/vc_run1

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 696 | 1377370 | 3718 | `cap /workspace/probe-run/frames/p03_two_dirs/vc` | start saving every frame from 3719 to play/frames/p03_two_dirs/vc_run1  (harness dir `/workspace/probe-run/frames/p03_two_dirs/vc`, renamed after capture) |
| 697 | 1377376 | 3718 | `kd down` | key DOWN `down` delivered before run_frame 3719 |
| 698 | 1377523 | 3721 | `step 3` | advanced to frame 3721 (frames 3719–3721 executed) |
| 699 | 1377526 | 3721 | `kd right` | key DOWN `right` delivered before run_frame 3722 |
| 700 | 1378070 | 3733 | `step 12` | advanced to frame 3733 (frames 3722–3733 executed) |
| 701 | 1378073 | 3733 | `ku right` | key UP `right` delivered before run_frame 3734 |
| 702 | 1378073 | 3733 | `ku down` | key UP `down` delivered before run_frame 3734 |
| 703 | 1378161 | 3735 | `step 2` | advanced to frame 3735 (frames 3734–3735 executed) |
| 704 | 1378161 | 3735 | `cap off` | stop per-frame capture |

### between probes (setup / repositioning)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 705 | 1378853 | 3735 | `kd left` | key DOWN `left` delivered before run_frame 3736 |
| 706 | 1378881 | 3747 | `step 12` | advanced to frame 3747 (frames 3736–3747 executed) |
| 707 | 1378881 | 3747 | `ku left` | key UP `left` delivered before run_frame 3748 |
| 708 | 1378882 | 3747 | `kd up` | key DOWN `up` delivered before run_frame 3748 |
| 709 | 1378906 | 3759 | `step 12` | advanced to frame 3759 (frames 3748–3759 executed) |
| 710 | 1378906 | 3759 | `ku up` | key UP `up` delivered before run_frame 3760 |
| 711 | 1378910 | 3761 | `step 2` | advanced to frame 3761 (frames 3760–3761 executed) |

### play/frames/p03_two_dirs/va_run2

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 712 | 1393268 | 3761 | `cap /workspace/probe-run/frames/p03_two_dirs/va_run2` | start saving every frame from 3762 to play/frames/p03_two_dirs/va_run2 |
| 713 | 1393280 | 3761 | `kd right` | key DOWN `right` delivered before run_frame 3762 |
| 714 | 1393282 | 3761 | `kd down` | key DOWN `down` delivered before run_frame 3762 |
| 715 | 1393876 | 3773 | `step 12` | advanced to frame 3773 (frames 3762–3773 executed) |
| 716 | 1393876 | 3773 | `ku right` | key UP `right` delivered before run_frame 3774 |
| 717 | 1393876 | 3773 | `ku down` | key UP `down` delivered before run_frame 3774 |
| 718 | 1393966 | 3775 | `step 2` | advanced to frame 3775 (frames 3774–3775 executed) |
| 719 | 1393966 | 3775 | `cap off` | stop per-frame capture |

### between probes (setup / repositioning)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 720 | 1394744 | 3775 | `kd left` | key DOWN `left` delivered before run_frame 3776 |
| 721 | 1394783 | 3787 | `step 12` | advanced to frame 3787 (frames 3776–3787 executed) |
| 722 | 1394783 | 3787 | `ku left` | key UP `left` delivered before run_frame 3788 |
| 723 | 1394784 | 3787 | `kd up` | key DOWN `up` delivered before run_frame 3788 |
| 724 | 1394820 | 3799 | `step 12` | advanced to frame 3799 (frames 3788–3799 executed) |
| 725 | 1394820 | 3799 | `ku up` | key UP `up` delivered before run_frame 3800 |
| 726 | 1394824 | 3801 | `step 2` | advanced to frame 3801 (frames 3800–3801 executed) |

### play/frames/p03_two_dirs/vb_run2

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 727 | 1394957 | 3801 | `cap /workspace/probe-run/frames/p03_two_dirs/vb_run2` | start saving every frame from 3802 to play/frames/p03_two_dirs/vb_run2 |
| 728 | 1394960 | 3801 | `kd right` | key DOWN `right` delivered before run_frame 3802 |
| 729 | 1395109 | 3804 | `step 3` | advanced to frame 3804 (frames 3802–3804 executed) |
| 730 | 1395113 | 3804 | `kd down` | key DOWN `down` delivered before run_frame 3805 |
| 731 | 1395595 | 3816 | `step 12` | advanced to frame 3816 (frames 3805–3816 executed) |
| 732 | 1395595 | 3816 | `ku right` | key UP `right` delivered before run_frame 3817 |
| 733 | 1395595 | 3816 | `ku down` | key UP `down` delivered before run_frame 3817 |
| 734 | 1395682 | 3818 | `step 2` | advanced to frame 3818 (frames 3817–3818 executed) |
| 735 | 1395682 | 3818 | `cap off` | stop per-frame capture |

### between probes (setup / repositioning)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 736 | 1396446 | 3818 | `kd left` | key DOWN `left` delivered before run_frame 3819 |
| 737 | 1396484 | 3830 | `step 12` | advanced to frame 3830 (frames 3819–3830 executed) |
| 738 | 1396484 | 3830 | `ku left` | key UP `left` delivered before run_frame 3831 |
| 739 | 1396486 | 3830 | `kd up` | key DOWN `up` delivered before run_frame 3831 |
| 740 | 1396525 | 3842 | `step 12` | advanced to frame 3842 (frames 3831–3842 executed) |
| 741 | 1396525 | 3842 | `ku up` | key UP `up` delivered before run_frame 3843 |
| 742 | 1396529 | 3844 | `step 2` | advanced to frame 3844 (frames 3843–3844 executed) |

### play/frames/p03_two_dirs/vc_run2

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 743 | 1396655 | 3844 | `cap /workspace/probe-run/frames/p03_two_dirs/vc_run2` | start saving every frame from 3845 to play/frames/p03_two_dirs/vc_run2 |
| 744 | 1396658 | 3844 | `kd down` | key DOWN `down` delivered before run_frame 3845 |
| 745 | 1396813 | 3847 | `step 3` | advanced to frame 3847 (frames 3845–3847 executed) |
| 746 | 1396817 | 3847 | `kd right` | key DOWN `right` delivered before run_frame 3848 |
| 747 | 1397350 | 3859 | `step 12` | advanced to frame 3859 (frames 3848–3859 executed) |
| 748 | 1397353 | 3859 | `ku right` | key UP `right` delivered before run_frame 3860 |
| 749 | 1397353 | 3859 | `ku down` | key UP `down` delivered before run_frame 3860 |
| 750 | 1397442 | 3861 | `step 2` | advanced to frame 3861 (frames 3860–3861 executed) |
| 751 | 1397442 | 3861 | `cap off` | stop per-frame capture |

### between probes (setup / repositioning)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 752 | 1398193 | 3861 | `kd left` | key DOWN `left` delivered before run_frame 3862 |
| 753 | 1398234 | 3873 | `step 12` | advanced to frame 3873 (frames 3862–3873 executed) |
| 754 | 1398234 | 3873 | `ku left` | key UP `left` delivered before run_frame 3874 |
| 755 | 1398237 | 3873 | `kd up` | key DOWN `up` delivered before run_frame 3874 |
| 756 | 1398281 | 3885 | `step 12` | advanced to frame 3885 (frames 3874–3885 executed) |
| 757 | 1398281 | 3885 | `ku up` | key UP `up` delivered before run_frame 3886 |
| 758 | 1398288 | 3887 | `step 2` | advanced to frame 3887 (frames 3886–3887 executed) |

### play/frames/p03_two_dirs/va_run3

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 759 | 1398416 | 3887 | `cap /workspace/probe-run/frames/p03_two_dirs/va_run3` | start saving every frame from 3888 to play/frames/p03_two_dirs/va_run3 |
| 760 | 1398419 | 3887 | `kd right` | key DOWN `right` delivered before run_frame 3888 |
| 761 | 1398420 | 3887 | `kd down` | key DOWN `down` delivered before run_frame 3888 |
| 762 | 1399004 | 3899 | `step 12` | advanced to frame 3899 (frames 3888–3899 executed) |
| 763 | 1399004 | 3899 | `ku right` | key UP `right` delivered before run_frame 3900 |
| 764 | 1399004 | 3899 | `ku down` | key UP `down` delivered before run_frame 3900 |
| 765 | 1399095 | 3901 | `step 2` | advanced to frame 3901 (frames 3900–3901 executed) |
| 766 | 1399095 | 3901 | `cap off` | stop per-frame capture |

### between probes (setup / repositioning)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 767 | 1399798 | 3901 | `kd left` | key DOWN `left` delivered before run_frame 3902 |
| 768 | 1399820 | 3913 | `step 12` | advanced to frame 3913 (frames 3902–3913 executed) |
| 769 | 1399820 | 3913 | `ku left` | key UP `left` delivered before run_frame 3914 |
| 770 | 1399821 | 3913 | `kd up` | key DOWN `up` delivered before run_frame 3914 |
| 771 | 1399841 | 3925 | `step 12` | advanced to frame 3925 (frames 3914–3925 executed) |
| 772 | 1399842 | 3925 | `ku up` | key UP `up` delivered before run_frame 3926 |
| 773 | 1399845 | 3927 | `step 2` | advanced to frame 3927 (frames 3926–3927 executed) |

### play/frames/p03_two_dirs/vb_run3

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 774 | 1400008 | 3927 | `cap /workspace/probe-run/frames/p03_two_dirs/vb_run3` | start saving every frame from 3928 to play/frames/p03_two_dirs/vb_run3 |
| 775 | 1400011 | 3927 | `kd right` | key DOWN `right` delivered before run_frame 3928 |
| 776 | 1400144 | 3930 | `step 3` | advanced to frame 3930 (frames 3928–3930 executed) |
| 777 | 1400146 | 3930 | `kd down` | key DOWN `down` delivered before run_frame 3931 |
| 778 | 1400663 | 3942 | `step 12` | advanced to frame 3942 (frames 3931–3942 executed) |
| 779 | 1400663 | 3942 | `ku right` | key UP `right` delivered before run_frame 3943 |
| 780 | 1400663 | 3942 | `ku down` | key UP `down` delivered before run_frame 3943 |
| 781 | 1400754 | 3944 | `step 2` | advanced to frame 3944 (frames 3943–3944 executed) |
| 782 | 1400754 | 3944 | `cap off` | stop per-frame capture |

### between probes (setup / repositioning)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 783 | 1401508 | 3944 | `kd left` | key DOWN `left` delivered before run_frame 3945 |
| 784 | 1401532 | 3956 | `step 12` | advanced to frame 3956 (frames 3945–3956 executed) |
| 785 | 1401532 | 3956 | `ku left` | key UP `left` delivered before run_frame 3957 |
| 786 | 1401533 | 3956 | `kd up` | key DOWN `up` delivered before run_frame 3957 |
| 787 | 1401562 | 3968 | `step 12` | advanced to frame 3968 (frames 3957–3968 executed) |
| 788 | 1401563 | 3968 | `ku up` | key UP `up` delivered before run_frame 3969 |
| 789 | 1401566 | 3970 | `step 2` | advanced to frame 3970 (frames 3969–3970 executed) |

### play/frames/p03_two_dirs/vc_run3

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 790 | 1401719 | 3970 | `cap /workspace/probe-run/frames/p03_two_dirs/vc_run3` | start saving every frame from 3971 to play/frames/p03_two_dirs/vc_run3 |
| 791 | 1401723 | 3970 | `kd down` | key DOWN `down` delivered before run_frame 3971 |
| 792 | 1401873 | 3973 | `step 3` | advanced to frame 3973 (frames 3971–3973 executed) |
| 793 | 1401875 | 3973 | `kd right` | key DOWN `right` delivered before run_frame 3974 |
| 794 | 1402381 | 3985 | `step 12` | advanced to frame 3985 (frames 3974–3985 executed) |
| 795 | 1402384 | 3985 | `ku right` | key UP `right` delivered before run_frame 3986 |
| 796 | 1402384 | 3985 | `ku down` | key UP `down` delivered before run_frame 3986 |
| 797 | 1402473 | 3987 | `step 2` | advanced to frame 3987 (frames 3986–3987 executed) |
| 798 | 1402473 | 3987 | `cap off` | stop per-frame capture |

### between probes (setup / repositioning)

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 799 | 1403207 | 3987 | `kd left` | key DOWN `left` delivered before run_frame 3988 |
| 800 | 1403232 | 3999 | `step 12` | advanced to frame 3999 (frames 3988–3999 executed) |
| 801 | 1403232 | 3999 | `ku left` | key UP `left` delivered before run_frame 4000 |
| 802 | 1403233 | 3999 | `kd up` | key DOWN `up` delivered before run_frame 4000 |
| 803 | 1403259 | 4011 | `step 12` | advanced to frame 4011 (frames 4000–4011 executed) |
| 804 | 1403259 | 4011 | `ku up` | key UP `up` delivered before run_frame 4012 |
| 805 | 1403263 | 4013 | `step 2` | advanced to frame 4013 (frames 4012–4013 executed) |

### play/frames/p11_pause/run2/P

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 806 | 1417503 | 4013 | `cap /workspace/probe-run/frames/p11_pause/run2/P` | start saving every frame from 4014 to play/frames/p11_pause/run2/P |
| 807 | 1417503 | 4013 | `kd p` | key DOWN `p` delivered before run_frame 4014 |
| 808 | 1417565 | 4014 | `step 1` | advanced to frame 4014 (frames 4014–4014 executed) |
| 809 | 1417565 | 4014 | `ku p` | key UP `p` delivered before run_frame 4015 |
| 810 | 1418017 | 4022 | `step 8` | advanced to frame 4022 (frames 4015–4022 executed) |
| 811 | 1418017 | 4022 | `cap off` | stop per-frame capture |

### play/frames/p11_pause/run2/esc

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 812 | 1418018 | 4022 | `cap /workspace/probe-run/frames/p11_pause/run2/esc` | start saving every frame from 4023 to play/frames/p11_pause/run2/esc |
| 813 | 1418018 | 4022 | `kd esc` | key DOWN `esc` delivered before run_frame 4023 |
| 814 | 1418053 | 4023 | `step 1` | advanced to frame 4023 (frames 4023–4023 executed) |
| 815 | 1418053 | 4023 | `ku esc` | key UP `esc` delivered before run_frame 4024 |
| 816 | 1418390 | 4031 | `step 8` | advanced to frame 4031 (frames 4024–4031 executed) |
| 817 | 1418390 | 4031 | `cap off` | stop per-frame capture |

### play/frames/p11_pause/run2/P_again

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 818 | 1418390 | 4031 | `cap /workspace/probe-run/frames/p11_pause/run2/P_again` | start saving every frame from 4032 to play/frames/p11_pause/run2/P_again |
| 819 | 1418391 | 4031 | `kd p` | key DOWN `p` delivered before run_frame 4032 |
| 820 | 1418432 | 4032 | `step 1` | advanced to frame 4032 (frames 4032–4032 executed) |
| 821 | 1418432 | 4032 | `ku p` | key UP `p` delivered before run_frame 4033 |
| 822 | 1418794 | 4040 | `step 8` | advanced to frame 4040 (frames 4033–4040 executed) |
| 823 | 1418794 | 4040 | `cap off` | stop per-frame capture |

### play/frames/p11_pause/run2/space

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 824 | 1418794 | 4040 | `cap /workspace/probe-run/frames/p11_pause/run2/space` | start saving every frame from 4041 to play/frames/p11_pause/run2/space |
| 825 | 1418795 | 4040 | `kd space` | key DOWN `space` delivered before run_frame 4041 |
| 826 | 1418839 | 4041 | `step 1` | advanced to frame 4041 (frames 4041–4041 executed) |
| 827 | 1418839 | 4041 | `ku space` | key UP `space` delivered before run_frame 4042 |
| 828 | 1419110 | 4047 | `step 6` | advanced to frame 4047 (frames 4042–4047 executed) |
| 829 | 1419110 | 4047 | `cap off` | stop per-frame capture |

### play/frames/p11_pause/run3/P

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 830 | 1419835 | 4047 | `cap /workspace/probe-run/frames/p11_pause/run3/P` | start saving every frame from 4048 to play/frames/p11_pause/run3/P |
| 831 | 1419836 | 4047 | `kd p` | key DOWN `p` delivered before run_frame 4048 |
| 832 | 1419895 | 4048 | `step 1` | advanced to frame 4048 (frames 4048–4048 executed) |
| 833 | 1419896 | 4048 | `ku p` | key UP `p` delivered before run_frame 4049 |
| 834 | 1420351 | 4056 | `step 8` | advanced to frame 4056 (frames 4049–4056 executed) |
| 835 | 1420351 | 4056 | `cap off` | stop per-frame capture |

### play/frames/p11_pause/run3/esc

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 836 | 1420351 | 4056 | `cap /workspace/probe-run/frames/p11_pause/run3/esc` | start saving every frame from 4057 to play/frames/p11_pause/run3/esc |
| 837 | 1420351 | 4056 | `kd esc` | key DOWN `esc` delivered before run_frame 4057 |
| 838 | 1420398 | 4057 | `step 1` | advanced to frame 4057 (frames 4057–4057 executed) |
| 839 | 1420398 | 4057 | `ku esc` | key UP `esc` delivered before run_frame 4058 |
| 840 | 1420755 | 4065 | `step 8` | advanced to frame 4065 (frames 4058–4065 executed) |
| 841 | 1420755 | 4065 | `cap off` | stop per-frame capture |

### play/frames/p11_pause/run3/P_again

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 842 | 1420755 | 4065 | `cap /workspace/probe-run/frames/p11_pause/run3/P_again` | start saving every frame from 4066 to play/frames/p11_pause/run3/P_again |
| 843 | 1420755 | 4065 | `kd p` | key DOWN `p` delivered before run_frame 4066 |
| 844 | 1420801 | 4066 | `step 1` | advanced to frame 4066 (frames 4066–4066 executed) |
| 845 | 1420802 | 4066 | `ku p` | key UP `p` delivered before run_frame 4067 |
| 846 | 1421168 | 4074 | `step 8` | advanced to frame 4074 (frames 4067–4074 executed) |
| 847 | 1421168 | 4074 | `cap off` | stop per-frame capture |

### play/frames/p11_pause/run3/space

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 848 | 1421168 | 4074 | `cap /workspace/probe-run/frames/p11_pause/run3/space` | start saving every frame from 4075 to play/frames/p11_pause/run3/space |
| 849 | 1421170 | 4074 | `kd space` | key DOWN `space` delivered before run_frame 4075 |
| 850 | 1421214 | 4075 | `step 1` | advanced to frame 4075 (frames 4075–4075 executed) |
| 851 | 1421215 | 4075 | `ku space` | key UP `space` delivered before run_frame 4076 |
| 852 | 1421441 | 4081 | `step 6` | advanced to frame 4081 (frames 4076–4081 executed) |
| 853 | 1421441 | 4081 | `cap off` | stop per-frame capture |

### play/frames/p11_pause/esc_ingame_run1

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 854 | 1430655 | 4081 | `cap /workspace/probe-run/frames/p11_pause/esc_ingame_run1` | start saving every frame from 4082 to play/frames/p11_pause/esc_ingame_run1 |
| 855 | 1430655 | 4081 | `kd esc` | key DOWN `esc` delivered before run_frame 4082 |
| 856 | 1430696 | 4082 | `step 1` | advanced to frame 4082 (frames 4082–4082 executed) |
| 857 | 1430696 | 4082 | `ku esc` | key UP `esc` delivered before run_frame 4083 |
| 858 | 1431146 | 4092 | `step 10` | advanced to frame 4092 (frames 4083–4092 executed) |
| 859 | 1431146 | 4092 | `cap off` | stop per-frame capture |

### play/frames/p11_pause/esc_ingame_run2

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 860 | 1431480 | 4092 | `cap /workspace/probe-run/frames/p11_pause/esc_ingame_run2` | start saving every frame from 4093 to play/frames/p11_pause/esc_ingame_run2 |
| 861 | 1431480 | 4092 | `kd esc` | key DOWN `esc` delivered before run_frame 4093 |
| 862 | 1431534 | 4093 | `step 1` | advanced to frame 4093 (frames 4093–4093 executed) |
| 863 | 1431534 | 4093 | `ku esc` | key UP `esc` delivered before run_frame 4094 |
| 864 | 1431991 | 4103 | `step 10` | advanced to frame 4103 (frames 4094–4103 executed) |
| 865 | 1431991 | 4103 | `cap off` | stop per-frame capture |

### play/frames/p11_pause/esc_ingame_run3

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 866 | 1432301 | 4103 | `cap /workspace/probe-run/frames/p11_pause/esc_ingame_run3` | start saving every frame from 4104 to play/frames/p11_pause/esc_ingame_run3 |
| 867 | 1432301 | 4103 | `kd esc` | key DOWN `esc` delivered before run_frame 4104 |
| 868 | 1432351 | 4104 | `step 1` | advanced to frame 4104 (frames 4104–4104 executed) |
| 869 | 1432351 | 4104 | `ku esc` | key UP `esc` delivered before run_frame 4105 |
| 870 | 1432795 | 4114 | `step 10` | advanced to frame 4114 (frames 4105–4114 executed) |
| 871 | 1432795 | 4114 | `cap off` | stop per-frame capture |

### play/frames/p08_chain/run2

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 872 | 1452799 | 4114 | `cap /workspace/probe-run/frames/p08_chain/run2` | start saving every frame from 4115 to play/frames/p08_chain/run2 |
| 873 | 1452804 | 4114 | `kd right` | key DOWN `right` delivered before run_frame 4115 |
| 874 | 1453566 | 4131 | `step 17` | advanced to frame 4131 (frames 4115–4131 executed) |
| 875 | 1453566 | 4131 | `ku right` | key UP `right` delivered before run_frame 4132 |
| 876 | 1453566 | 4131 | `kd space` | key DOWN `space` delivered before run_frame 4132 |
| 877 | 1453614 | 4132 | `step 1` | advanced to frame 4132 (frames 4132–4132 executed) |
| 878 | 1453615 | 4132 | `ku space` | key UP `space` delivered before run_frame 4133 |
| 879 | 1453617 | 4132 | `kd left` | key DOWN `left` delivered before run_frame 4133 |
| 880 | 1454046 | 4140 | `step 8` | advanced to frame 4140 (frames 4133–4140 executed) |
| 881 | 1454046 | 4140 | `ku left` | key UP `left` delivered before run_frame 4141 |
| 882 | 1454046 | 4140 | `kd space` | key DOWN `space` delivered before run_frame 4141 |
| 883 | 1454091 | 4141 | `step 1` | advanced to frame 4141 (frames 4141–4141 executed) |
| 884 | 1454092 | 4141 | `ku space` | key UP `space` delivered before run_frame 4142 |
| 885 | 1454092 | 4141 | `kd left` | key DOWN `left` delivered before run_frame 4142 |
| 886 | 1454511 | 4150 | `step 9` | advanced to frame 4150 (frames 4142–4150 executed) |
| 887 | 1454511 | 4150 | `ku left` | key UP `left` delivered before run_frame 4151 |
| 888 | 1454514 | 4150 | `kd down` | key DOWN `down` delivered before run_frame 4151 |
| 889 | 1455382 | 4168 | `step 18` | advanced to frame 4168 (frames 4151–4168 executed) |
| 890 | 1455383 | 4168 | `ku down` | key UP `down` delivered before run_frame 4169 |
| 891 | 1458542 | 4238 | `step 70` | advanced to frame 4238 (frames 4169–4238 executed) |
| 892 | 1458546 | 4238 | `kd up` | key DOWN `up` delivered before run_frame 4239 |
| 893 | 1459296 | 4256 | `step 18` | advanced to frame 4256 (frames 4239–4256 executed) |
| 894 | 1459297 | 4256 | `ku up` | key UP `up` delivered before run_frame 4257 |
| 895 | 1459423 | 4259 | `step 3` | advanced to frame 4259 (frames 4257–4259 executed) |
| 896 | 1459423 | 4259 | `cap off` | stop per-frame capture |

### play/frames/p08_chain/run3

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 897 | 1459570 | 4259 | `cap /workspace/probe-run/frames/p08_chain/run3` | start saving every frame from 4260 to play/frames/p08_chain/run3 |
| 898 | 1459578 | 4259 | `kd right` | key DOWN `right` delivered before run_frame 4260 |
| 899 | 1460333 | 4276 | `step 17` | advanced to frame 4276 (frames 4260–4276 executed) |
| 900 | 1460333 | 4276 | `ku right` | key UP `right` delivered before run_frame 4277 |
| 901 | 1460333 | 4276 | `kd space` | key DOWN `space` delivered before run_frame 4277 |
| 902 | 1460379 | 4277 | `step 1` | advanced to frame 4277 (frames 4277–4277 executed) |
| 903 | 1460379 | 4277 | `ku space` | key UP `space` delivered before run_frame 4278 |
| 904 | 1460382 | 4277 | `kd left` | key DOWN `left` delivered before run_frame 4278 |
| 905 | 1460744 | 4285 | `step 8` | advanced to frame 4285 (frames 4278–4285 executed) |
| 906 | 1460745 | 4285 | `ku left` | key UP `left` delivered before run_frame 4286 |
| 907 | 1460745 | 4285 | `kd space` | key DOWN `space` delivered before run_frame 4286 |
| 908 | 1460793 | 4286 | `step 1` | advanced to frame 4286 (frames 4286–4286 executed) |
| 909 | 1460793 | 4286 | `ku space` | key UP `space` delivered before run_frame 4287 |
| 910 | 1460794 | 4286 | `kd left` | key DOWN `left` delivered before run_frame 4287 |
| 911 | 1461259 | 4295 | `step 9` | advanced to frame 4295 (frames 4287–4295 executed) |
| 912 | 1461260 | 4295 | `ku left` | key UP `left` delivered before run_frame 4296 |
| 913 | 1461262 | 4295 | `kd down` | key DOWN `down` delivered before run_frame 4296 |
| 914 | 1462067 | 4313 | `step 18` | advanced to frame 4313 (frames 4296–4313 executed) |
| 915 | 1462068 | 4313 | `ku down` | key UP `down` delivered before run_frame 4314 |
| 916 | 1465558 | 4383 | `step 70` | advanced to frame 4383 (frames 4314–4383 executed) |
| 917 | 1465558 | 4383 | `kd up` | key DOWN `up` delivered before run_frame 4384 |
| 918 | 1466233 | 4401 | `step 18` | advanced to frame 4401 (frames 4384–4401 executed) |
| 919 | 1466233 | 4401 | `ku up` | key UP `up` delivered before run_frame 4402 |
| 920 | 1466353 | 4404 | `step 3` | advanced to frame 4404 (frames 4402–4404 executed) |
| 921 | 1466353 | 4404 | `cap off` | stop per-frame capture |

### play/frames/p10_death/run3_gameover

| # | wall ms | frame counter after cmd | command | meaning |
|---|---|---|---|---|
| 922 | 1531832 | 4404 | `cap /workspace/probe-run/frames/p10_death/run3_gameover` | start saving every frame from 4405 to play/frames/p10_death/run3_gameover |
| 923 | 1535423 | 4524 | `step 120` | advanced to frame 4524 (frames 4405–4524 executed) |
| 924 | 1535423 | 4524 | `cap off` | stop per-frame capture |
