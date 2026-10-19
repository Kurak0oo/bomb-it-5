> Imported Dots record; claims are retained as delivered. See the [integration assessment](../../../../../edition-5-play-observations.md) for verification, missing files, and authority limits. Original relative paths in code spans refer to the [unaltered bundle](../../../../../../../.scratch/edition-5-research/observations/html5-alternate/runtime/html5-alternate/recordings/README.md).

# Timestamp-paced gameplay evidence: Y8 HTML5 alternate

These compact clips are assembled from actual uncropped browser screenshots, not a continuous screen recording. They show running gameplay rather than a loader. This is the Y8 HTML5 alternate, a different, unverified build; it is NOT proof of behavior or visual fidelity in the requested exact SWF build.

## Clips

- `010-stationary-bomb.mp4`: 20 samples spanning 7.348 seconds, 2026-10-16 20:40:55.353–20:41:02.701 UTC. Explosion, player death, YOU LOSE, then level-failed results. Sampling: approximately 2.586 samples/second; gaps 0.333–0.431 seconds.
- `025-focus-bomb.mp4`: 14 samples spanning 1.866 seconds, 2026-10-16 20:43:23.823–20:43:25.689 UTC. Visible bombs and flames/explosion. No death shown in this group. Sampling: approximately 6.967 samples/second; gaps 0.112–0.182 seconds.
- `029-second-bomb.mp4`: 35 samples spanning 3.925 seconds, 2026-10-16 20:43:57.402–20:44:01.327 UTC. Bomb/explosion sequence, death sprite and YOU LOSE. Sampling: approximately 8.662 samples/second; gaps 0.075–0.171 seconds.

## Timing and limitations

Each screenshot is held until the next recorded timestamp, using the actual millisecond gaps in `../capture-times.json`. The clips use variable frame timestamps, not an assumed 30/60 fps sequence. No motion interpolation or generated gameplay frames were inserted. These are sparse samples: animation frames, precise bomb-placement input timing, and transient effects between captures are missing. Sampling frequency is NOT measured or achieved game FPS; MP4 timebase/encoder metadata is not game FPS either. Recorded capture timestamps are the available wall-clock timing evidence, not instrumented game-render timestamps.

All original JPGs remain unchanged in the parent directory. The full captured browser viewport is preserved, including page chrome and advertising; the video adds only right/bottom padding to make odd image dimensions compatible with H.264. No cropping, zoom, labels or visual overlays are applied. The final sample is encoded for 1 millisecond beyond its recorded timestamp; all preceding holds correspond to real timestamp differences. There is no captured audio.

`*-timestamps.csv` provides source filenames, absolute UTC timestamps, elapsed times and hold durations. `clip-manifest.json` gives clip metadata. `*.ffconcat` and `assemble.py` provide reproducible assembly. Validation checked decoded frame counts, first/last timestamps and complete error-free decode for each MP4.

## Additional timed input sequence043

`043-fuse-tap.mp4` contains 25 samples spanning 9.255 seconds (2026-10-16 20:47:40.545–20:47:49.800 UTC), encoded duration 9.256 seconds. The approximate sampling rate is 2.593 samples/second, with actual gaps 0.342–0.430 seconds. This is sparse capture, NOT game FPS.

Independent visual inspection finds the top-left bomb intact in sample005 (20:47:42.487 UTC), then an explosion at that position in sample006 (20:47:42.873 UTC). Relative to the Space input request recorded in `../fuse-tap-action.json` at 20:47:40.482 UTC, the observed transition is bracketed by (2.005, 2.391] seconds. These are capture-time observations, not verified game-state times. Browser input latency, screenshot latency and acceptance of the requested placement are not instrumented. A bomb is already visible in the first sample; there is no proven pre-input empty cell and corresponding accepted placement in this clip. Therefore this bracket must NOT be reported as the bomb's confirmed fuse duration. Another explosion appears later near the pink enemy's bomb. No claim about exact SWF behavior follows from this HTML5 alternate.
