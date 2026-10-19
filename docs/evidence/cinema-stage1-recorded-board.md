# CinemaStage1 recorded-board reconstruction

Audited 2026-10-19. This reconstructs the rendered CinemaStage1 instance in restored frames 697 and 698 of the publisher edition 5 SWF, SHA-256 `718c04c741604bda2bcf4efb19ca3f7cf240b79bc6163f274045c3157e0408a2`. It resolves the earlier image-transcription uncertainty with one correction. It is **rendered-image evidence, not an independent runtime collision-state dump**.

## Result and correction

All 110 candidate soft-block cells were classified independently in both frames: **68 present, 42 empty**, with no unclassified candidate. The original transcription is correct in the previously uncertain rows 3, 5, 6, 8, 9 and 11. One error occurs elsewhere: **(14,10) contains a glasses soft block**, not floor. Corrected row 10 is `##s###.#s#.###s##`.

The [canonical reconstructed CSV](cinema-stage1-recorded-board.csv) contains all 255 cells in original coordinates: 125 solid cells (including the center 3×3), 68 soft blocks, 58 ordinary floor cells and four portals. Portal pair 1 is (8,1)↔(8,13); pair 2 is (4,7)↔(12,7). Source geometry, pairing and collision semantics remain in [the movement/board record](edition-5-movement-and-board.md).

The [machine-readable audit](cinema-stage1-recorded-board-audit.json) records source image hashes, counts, correction and CSV SHA-256. The [imported transcription](observations/swf-v1.6.1/play/first-board.md) remains preserved as delivered; this record supersedes its occupancy uncertainty and incorrect cell rather than silently rewriting source claims. The static template remains a list of possible cells, not this particular random realization.

## Reproduction

Source images are the restored [frame 697](../../.scratch/edition-5-research/observations/swf-v1.6.1-supplement/keyframes_fullcolour/first_board/f000697.png) and [frame 698](../../.scratch/edition-5-research/observations/swf-v1.6.1-supplement/keyframes_fullcolour/first_board/f000698.png). The source-derived rendered cell pitch is 32 pixels; board origin is (163.2, 12.66666667). For cell (x,y), set `left=int(163.2+32*x)` and `top=int(12.66666667+32*y)` and inspect rows `top+1:top+15`, columns `left+2:left+30`. This top 14×28 patch avoids lower-cell sprite overlap.

Use full patches at (3,1) and (5,1) as the glasses/clapper references, and (6,1) as floor. Sixty-five soft patches and 38 floor patches match their references completely, pixel for pixel. Three other soft patches and four empty patches are affected by portal glow. The soft-art diagnostic pixels still match exact reference RGB values in the three occupied cases. In both frames, the entire patch at disputed cell (14,10) equals the known glasses patch at (3,1).

Reproducible read-only classification, with Python/Pillow/NumPy and the static template:

```python
from pathlib import Path
import csv
import numpy as np
from PIL import Image

base = Path('.scratch/edition-5-research/observations/swf-v1.6.1-supplement/keyframes_fullcolour/first_board')
template = list(csv.DictReader(open('docs/evidence/observations/swf-v1.6.1/maps/CinemaStage1.csv')))
def patch(image, x, y):
    left, top = int(163.2 + 32*x), int(12.66666667 + 32*y)
    return image[top+1:top+15, left+2:left+30]
reference = np.asarray(Image.open(base / 'f000697.png').convert('RGB'))
glasses, clapper = patch(reference, 3, 1), patch(reference, 5, 1)
gm = (glasses[:,:,0] > 170) & (glasses[:,:,1] > 135) & (glasses[:,:,2] < 120)
cm = (clapper[:,:,0] < 130) & (clapper[:,:,1] > 130) & (clapper[:,:,2] > 145)
for frame in ['f000697.png', 'f000698.png']:
    image = np.asarray(Image.open(base / frame).convert('RGB'))
    present = []
    for cell in template:
        if not cell['instance_name'].startswith('unfixed'):
            continue
        x, y = int(cell['x']), int(cell['y'])
        q = patch(image, x, y)
        if np.array_equal(q[gm], glasses[gm]) or np.array_equal(q[cm], clapper[cm]):
            present.append((x,y))
    print(frame, len(present), present)
```

Both frames contain the same 68 occupied candidate coordinates. The parent investigation independently reran these measurements and matched both image hashes, counts and the correction. Media were not edited and no supplied playback harness was executed.

The two frames show one recorded instance; they are not independent playthroughs. For runtime corroboration, the smallest additional artifact would be one pre-input, post-map-load dump of `map.getBox(x,y)` and `box.isExist` across all 255 cells, paired with template identity and screenshot. That extra artifact is not needed merely to correct the rendered transcription.
