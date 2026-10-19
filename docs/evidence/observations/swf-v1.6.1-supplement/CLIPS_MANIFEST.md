> Imported Dots supplemental record; assertions are retained as delivered. Read the [integration assessment](../../edition-5-play-observations.md) for confidence, corrections and remaining limits. Source-relative paths in code spans refer to the [unaltered original](../../../../.scratch/edition-5-research/observations/swf-v1.6.1-supplement/CLIPS_MANIFEST.md).

# Clip manifest (play/clips/ of the first pack)

All clips were made by `tools/ruffle-probe/clip.sh name dir first last 35 [crop]`: ffmpeg H.264 crf 23 yuv420p plus a 128-colour GIF, 35 fps (one video frame = one engine frame; this is NOT wall-clock speed, see CORRECTIONS #2). For cropped clips the crop `w:h:x:y` is in 700×510 source pixels and is then scaled ×2 with nearest-neighbour.

**Provenance: RECONSTRUCTED.** clip.sh did not log its arguments. Source range and crop were recovered on 2026-10-17 by matching the decoded first and last clip frames against every candidate source frame (FFT sum-of-squared-differences over all crop offsets; mean squared error per pixel is shown, and H.264 noise accounts for it). The frame count of each clip equals last−first+1, and all source frames exist in the range.

| clip (.mp4 + .gif) | source frames dir | first | last | frames | output px | crop w:h:x:y (source px) | match MSE |
|---|---|---|---|---|---|---|---|
| p01_hold_left_run1 | play/frames/p01_hold_dir/run1_left | 1246 | 1262 | 17 | 320x160 | 160:80:183:10 | 26.0 |
| p02_left_then_up_run1 | play/frames/p02_left_up/run1 | 1505 | 1537 | 33 | 320x160 | 160:80:183:10 | 21.2 |
| p03_down_then_right_run1 | play/frames/p03_two_dirs/vc_run1 | 3719 | 3735 | 17 | 240x200 | 120:100:183:20 | 30.6 |
| p03_right_then_down_run1 | play/frames/p03_two_dirs/vb_run1 | 3676 | 3692 | 17 | 240x200 | 120:100:183:20 | 30.4 |
| p04_space_held_run1 | play/frames/p04_space/run1_held | 3165 | 3296 | 132 | 320x240 | 160:120:183:10 | 21.2 |
| p04_space_repeated_run2 | play/frames/p04_space/run2_repeated | 3297 | 3424 | 128 | 320x240 | 160:120:183:10 | 19.4 |
| p05_fuse_flame_softblock_run1 | play/frames/p05_fuse/run1 | 1350 | 1460 | 111 | 320x240 | 160:120:183:10 | 20.2 |
| p08_chain_run1 | play/frames/p08_chain/run1 | 3494 | 3594 | 101 | 360x260 | 180:130:183:10 | 22.1 |
| p09_pickup_run1 | play/frames/p09_drop_pickup/run1 | 1461 | 1504 | 44 | 360x200 | 180:100:183:10 | 17.6 |
| p10_death_selfbomb_to_results_run1 | play/frames/p10_death/run1_selfbomb | 950 | 1090 | 141 | 700x510 | none (full 700x510) | 34.9 |
| p11_pause_P_run1 | play/frames/p11_pause/run1_P | 1857 | 1877 | 21 | 700x510 | none (full 700x510) | 68.3 |
| p12_timeout_timesup_to_complete | play/frames/p12_timeout_win/run1 | 2880 | 2995 | 116 | 700x510 | none (full 700x510) | 36.5 |

The packed sequences under `frames_256colour/` keep the same frame numbers. Note that p12 packed frames are every 8th frame below 2860 and all frames from 2860; the clip uses 2880–2995.
