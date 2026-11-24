# Head-to-head quality rankings of AI models for game art (as of November 2026)

Retrieval date for every number below: 2026-11-24, unless noted otherwise. Leaderboard numbers were taken from the raw page data (curl through the session proxy). Raw copies are in `/tmp/claude-0/-home-user-bomb-it-5/52544bf5-a639-5dc5-82f2-0623abd835f5/scratchpad/artstats_quality/`.

Access notes: `lmarena.ai` would not resolve from this session. `arena.ai` (LMArena's current domain) returned HTTP 403 to curl. So the LMArena/Arena numbers here come from search snippets and are UNVERIFIED. Artificial Analysis (AA), the Hugging Face 3D Arena backend, Crafiq and arXiv were fetched directly.

## Current top models per category (Elo/scores, dates, sample sizes)

### Takeaway
OpenAI's GPT Image 2.5/2.6 "Sunburst/Flare" family leads text-to-image on both Artificial Analysis and (unverified) LMArena. Microsoft's MAI-Image-2.7 narrowly leads AA's image-editing arena. In 3D, the long-running HF 3D Arena is topped by PicGen3D and TRELLIS-3DGS, but it leaves out most current commercial generators (Tripo, Rodin, Hunyuan3D 3.x). The only arena that ranks those (Crafiq, which puts Tripo H3.1 first) has tiny vote counts. In music, Suno v6 leads both AA music arenas. Udio does not appear on AA at all.

### Cited Findings

**Text-to-image: Artificial Analysis "AA-Image-T2I v2.1" arena** (blind pairwise votes; AA is an independent third party, not a model vendor). Format: rank, model (creator), Elo ± 95% CI half-width, appearances, release month. Source: [AA text-to-image leaderboard](https://artificialanalysis.ai/image/leaderboard/text-to-image)
1. GPT Image 2.6 Sunburst (max) (OpenAI): 1263 ±14, 5,466 appearances, Nov 2026
2. GPT Image 2.5 Sunburst (max) (OpenAI): 1229 ±10, 13,808, Sep 2026
3. GPT Image 2.6 Flare (max) (OpenAI): 1227 ±12, 7,337, Nov 2026
4. MAI-Image-2.7 (Microsoft AI): 1215 ±14, 5,149, Nov 2026
5. GPT Image 2.5 Flare (max) (OpenAI): 1210 ±10, 13,175, Sep 2026
6. GPT Image 2 (high) (OpenAI): 1195 ±11, 13,618, Apr 2026
7. Kling Image 4.0 (KlingAI): 1180 ±12, 5,683, Nov 2026
8. Nano Banana 2.1 (Google): 1175 ±11, 6,918, Oct 2026
9. MAI-Image-2.6 (Microsoft AI): 1168 ±11, 9,153, Aug 2026
10. Grok Imagine Image 2.0 (SpaceXAI): 1166 ±12, 8,200, Aug 2026
11. MAI-Image-2.7-Flash: 1160 ±12, 6,094
12. Canva Craft: 1158 ±12, 5,474
13. Nano Banana 2 (Gemini 3.1 Flash Image): 1144 ±10, 16,805
14. Seedream 5.5 (ByteDance): 1134 ±12, 5,396
15. Muse Image (Meta): 1126 ±11, 9,241
16. GPT Image 1.5 (high): 1125
17. MAI-Image-2.6-Flash: 1125
18. MAI-Image-2.5: 1118
19. Nano Banana Pro (Gemini 3 Pro Image, Nov 2025): 1117 ±10, 15,993
20. MAI-Image-2.5-Pro: 1116
21. FLUX 3 Image (Black Forest Labs): 1114 ±12, 6,877, Oct 2026
22. Nano Banana 2 Lite: 1110
23. Seedream 5.0 Pro: 1104
24. Qwen-Image-3.0-Pro (Alibaba): 1094 ±11, 7,114
25. Qwen-Image-3.0 (open weights): 1075 ±12, 6,871

**Image editing: AA editing arena.** Same format. Source: [AA image editing leaderboard](https://artificialanalysis.ai/image/leaderboard/editing)
1. MAI-Image-2.7 (Microsoft AI): 1215 ±14, 5,525 appearances, Nov 2026
2. GPT Image 2.6 Sunburst (max): 1211 ±13, 6,599
3. GPT Image 2.6 Flare (max): 1205 ±13, 6,834
4. GPT Image 2.5 Sunburst (max): 1201 ±11, 19,008
5. GPT Image 2.5 Flare (max): 1185 ±11, 19,900
6. Kling Image 4.0: 1183 ±13, 5,677
7. MAI-Image-2.7-Flash: 1179 ±13
8. Seedream 5.5: 1159 ±14
9. Krea 3 (Ultra): 1153 ±13
10. Nano Banana 2.1 (Google): 1152 ±12, 7,650
11. MAI-Image-2.6: 1151
12. MAI-Image-2.6-Flash: 1145
13. GPT Image 2 (high): 1139
14. H3-Image (MiniMax): 1136 ±16, 3,308
15. H3-Image Highspeed (MiniMax): 1133 ±16, 3,289

The top 4 editing models sit within 14 Elo of each other, which is inside their ±13–14 CIs: a statistical tie.

**LMArena / Arena text-to-image (UNVERIFIED, search snippet only; arena.ai returned 403).** In a snapshot dated 2026-11-12, GPT-Image-2.5 Sunburst is reportedly first at 1411 ±9 with 8,915 samples, followed by GPT-Image-2.6 Sunburst (Medium) and GPT-Image-2.5 Flare. A 2026-11-16 snapshot of Arena's "3D modeling" image sub-category also reportedly lists GPT-Image-2.5 Sunburst first. Arena also runs an "art" sub-category. — [Arena art leaderboard](https://arena.ai/leaderboard/image/text-to-image/art), [Arena 3D-modeling leaderboard](https://arena.ai/leaderboard/image/text-to-image/3d-modeling) (both not fetched)

**BudgetPixel arena (UNVERIFIED, search snippet; small and less established site).** GPT Image 2.5 Sunburst reportedly leads with a rating of 1593 from 9,770 blind votes as of 2026-11-23. — [BudgetPixel leaderboard](https://budgetpixel.com/arena/leaderboard)

**3D generation: Hugging Face "3D Arena"** (community image-to-3D arena; inputs from iso3D; the space was last modified 2026-10-26). Format: rank, model, score, votes, open/closed. Source: [3D Arena space](https://huggingface.co/spaces/3d-arena/3d-arena), data from its `/api/leaderboard` endpoint at `3d-arena-3d-arena.hf.space`.
1. PicGen3D: 1415, 4,378 votes, closed
2. TRELLIS-3DGS (Microsoft; Gaussian splats, not a mesh): 1398, 4,844, open
3. Meshy-6: 1349, 1,063, closed
4. 404_GEN: 1334, 1,491, closed
5. Meshy-7: 1326, 340, closed (small sample)
6. TRELLIS: 1303, 5,788, open
7. Zaohaowu3D: 1295, 2,998, closed
8. Hunyuan3D-2: 1283, 5,251, open
9. Hunyuan3D-2.1: 1271, 2,236, open
10. SAM-3D-Objects-3DGS: 1269, 1,431, open
11. InstantMesh: 1269, 11,617
12. Pixal3D: 1259, 431
13. UniLat3D-3DGS: 1257, 425
14. Unique3D: 1226, 10,095
15. SF3D (Stability): 1176, 8,038
16. MeshFormer: 1171
17. Real3D: 1138
18. TRELLIS.2-4B: 1129, 1,459, open (ranks below the original TRELLIS)
19. SPAR3D: 1112
20. TripoSR: 1081, 11,393
21. LGM: 1070
22. UniLat3D-Mesh: 1024
23. Meshy-5: 1002, 992
24. 3DTopia-XL: 939

Tripo (commercial v2.5/H3.x), Rodin (Hyper3D) and Hunyuan3D 3.x are absent from this list.

**3D generation: Crafiq 3D Arena (operated by Crafiq, a commercial asset-generation app that resells these models; low sample).** Order: 1 Tripo H3.1, 2 Hunyuan3D 3.1, 3 Hi3D v3.0, 4 Rodin 2.5, 5 Meshy 6, 6 Meshy 7, 7 Meshy T2.5, 8 Pixal3D, 9 Tripo 2.5, 10 Tripo P1, 11 Rodin Low-Poly, 12 Hunyuan3D 2.1, 13 TRELLIS.2, then Meshy 5, Seed3D, Rodin 2, Idol Max Turbo, Idol Max, TRELLIS, Hunyuan3D 2 and TripoSR (21 models). Per-model vote counts in the page data are tiny: for example Tripo H3.1 38, Rodin 2.5 35, Hi3D v3.0 34, Meshy 7 30, Rodin Low-Poly 6. — [Crafiq 3D rankings](https://crafiq.ai/rankings/3d); dataset at [HF crafiq/3d-arena](https://huggingface.co/datasets/crafiq/3d-arena)

**Artificial Analysis 3D:** no 3D leaderboard exists. `artificialanalysis.ai/3d/arena`, `/3d/leaderboard` and `/text-to-3d` all return 404, and the site nav lists only image, video, speech, music and other categories. — [AA site](https://artificialanalysis.ai/image/leaderboard/text-to-image) (nav links)

**Music: AA music arenas.**
- AA-Music-Instrumental v1.1. Format: model: Elo ±CI, appearances (release date). Source: [AA instrumental](https://artificialanalysis.ai/music/leaderboard/instrumental)
  1. Suno v6: 1148 ±22, 2,208 (2026-09-09)
  2. Suno v6-mini: 1114 ±21, 2,332
  3. Mureka V9.5: 1084 ±21, 2,297
  4. Mureka V9: 1083
  5. Lyria 3 Pro (Google): 1080
  6. Lyria 3.5: 1078
  7. Eleven Music (ElevenLabs): 1021, 2,213 (2025-08-05)
  8. Stable Audio 3 Large: 1014
  9. Eleven Music v2: 1011
  10. MiniMax Music 2.5+: 1007
- AA vocals leaderboard. Source: [AA vocals](https://artificialanalysis.ai/music/leaderboard/vocals)
  1. Suno v6: 1145 ±18, 3,073
  2. Suno v6-mini: 1133
  3. Mureka V9.5: 1101
  4. Mureka V9: 1063
  5. Lyria 3.5: 1050
  6. Lyria 3 Pro: 1048
  7. Eleven Music v2.5: 1017, 3,253 (2026-09-11)
  8. Eleven Music v2: 1001
  9. MiniMax Music 3.0: 1000
  10. Eleven Music: 999
- Udio does not appear on either AA music leaderboard.

**SFX:** no sound-effects arena was found. AA's audio leaderboards cover speech and music only. — [AA music arena](https://artificialanalysis.ai/music/arena)

### Inferences
- The "winner" in 2D image quality is clearly OpenAI's GPT Image line on general blind preference. Its lead of about 34 Elo over the #2 entry on AA is outside the CIs. Microsoft's MAI-Image series is the strongest non-OpenAI family. The best open-weights model (Qwen-Image-3.0) is about 190 Elo behind the leader on AA.
- 3D rankings are fragmented and stale. The large-sample HF arena does not include the commercial tools jam developers are most likely to use (Tripo, Rodin, Hunyuan3D 3.x). The arena that does include them has fewer than 40 votes per model, so its order is close to noise.
- These arenas measure general aesthetic preference on generic prompts. None of them measures sprite-sheet consistency, transparency, tileability or topology.

### Gaps
- The LMArena/Arena text-to-image, art and 3D-modeling leaderboards could not be fetched (403 / DNS block), so those numbers are unverified.
- HF 3D Arena page data has no "as of" date beyond the space's last modification (2026-10-26). No CIs are published.
- No Artificial Analysis 3D arena exists. No independent arena was found that ranks Tripo vs Rodin vs Hunyuan3D 3.x with adequate samples.
- No independent Suno vs Udio head-to-head was found for 2026, because Udio is not on AA.

## Which models do well on game-specific needs (consistent characters, transparency, sprite sheets, tileable textures, clean topology, UV alignment)

### Takeaway
I found no independent, current benchmark that ranks image models on sprite-sheet consistency, transparent backgrounds or tileable textures. The one 2026 pixel-art benchmark (PixelBench) evaluates LLM agents drawing pixel art through code tools, not diffusion/image models. GPT-6 Astra wins it. For 3D, the 2026 literature says production-readiness (topology, UVs, rigging) has no standardized benchmark, and current generators generally do not produce clean topology.

### Cited Findings
- **PixelBench (arXiv:2611.20628, submitted 2026-11-16):**
  - **Setup:** benchmarks language-model agents that create and edit pixel art by calling drawing tools in code, under canvas-size and palette limits. It has 100 tasks (75 generation, 25 editing) and 12 model configurations. Ten raters with professional art backgrounds produced complete rankings of 1,200 artworks. — [arXiv abs](https://arxiv.org/abs/2611.20628), [HTML](https://arxiv.org/html/2611.20628)
  - **Leaderboard (judge score / mean human rank, lower rank is better):**
    - GPT-6 Astra (high): 83.76 / 3.34
    - Claude Opus 5 (low): 78.49 / 4.88
    - Qwen3.8 Max: 78.04 / 5.13
    - GPT-5.6 Sol (medium): 76.9 (judge score)
    - DeepSeek V4 Flash (high): 65.5 (judge score)
  - **Rater agreement:** nine of the ten raters individually ranked GPT-6 Astra first.
  - **Judge validity:** the MLLM judge agrees with the human consensus at a per-task Kendall τb of 0.557, and the judge and human leaderboards correlate at a model-level Spearman ρ of 0.958.
  - **Where models separate:** raters agree most, and models separate most, on characters and on larger canvases.
  - Source for the leaderboard and agreement figures: [HTML](https://arxiv.org/html/2611.20628)
- **Sprite Sheet Diffusion (arXiv:2412.03685, late 2024)** defines a sprite-sheet generation task and evaluates consistency, pose alignment and sequence quality. It predates the current models and does not rank commercial 2026 image models. — [arXiv](https://arxiv.org/html/2412.03685v2) (via search; not re-read)
- **Survey "From Visual Synthesis to Interactive Worlds: Toward Production-Ready 3D Asset Generation" (arXiv:2604.23629, 2026-04-26)** says engine constraints (topology, UV parameterization, PBR materials, skeletal rigging) are not met by current methods: "a persistent gap separates the outputs of current methods from the production-ready standard". It consolidates usability metrics but publishes no vendor ranking. — [arXiv abs](https://arxiv.org/abs/2604.23629)
- **Springer paper "Topology-based failure modes in AI-generated 3D assets for production rigging pipelines"** proposes a Topological Integrity Score covering manifold validity, edge loops, UV layout, subdivision, weight mapping and normals. Per the search snippet, its weights are "a conceptual starting point pending empirical validation". No per-generator results were confirmed. — [Springer](https://link.springer.com/article/10.1007/s11042-026-21944-w) (snippet only, UNVERIFIED)
- **AssetGen (arXiv:2605.26137)** reportedly notes that its outputs "do not enforce clean topology, artist-friendly edge flow, skeletal rigging constraints" and may need retopology for rigged characters. — [arXiv](https://arxiv.org/pdf/2605.26137) (search snippet, UNVERIFIED)
- Rigging/animation-readiness work exists but publishes no cross-vendor game rankings: Rigel3D (rig-aware latents), and 3AGameFactory-Motion with its DivDynBench rigging benchmark over six morphology categories. — [Rigel3D](https://arxiv.org/html/2605.13129), [3AGameFactory-Motion](https://arxiv.org/html/2611.30013) (search results, not read)
- Crafiq lists a dedicated "Rodin Low-Poly" (Hyper3D PolyGen) model in its arena, ranked 11th on only 6 votes. That is the only low-poly-specific entry seen on any arena. — [Crafiq 3D rankings](https://crafiq.ai/rankings/3d)

### Inferences
- PixelBench suggests that frontier LLMs drawing through code can produce strong palette-constrained pixel art. This is a different route from image-model generation followed by pixelation, and its winner (GPT-6 Astra) is not an image-arena model.
- On game-specific properties (transparent PNGs, consistent sprite sheets, seamless tiles, clean low-poly topology), the evidence base is anecdotal and vendor-claimed, not benchmarked. Arena Elo should be treated as a proxy for general visual appeal only.

### Gaps
- No independent benchmark was found for transparent-background output quality, sprite-sheet / multi-pose character consistency, or tileable-texture seams across 2026 image models.
- No published per-vendor topology, UV or rigging scores were found for Tripo / Meshy / Rodin / Hunyuan3D / TRELLIS.
- Vendor technical reports (Tripo, Hunyuan3D 3.x, Rodin) were not read. Any self-reported comparisons in them would be vendor-run.

## How quality rankings compare with what jam winners used

### Takeaway
That comparison is for the report writer. Use these anchors: top-ranked image = GPT Image 2.5/2.6 (OpenAI), editing ≈ MAI-Image-2.7 / GPT Image 2.6, music = Suno v6, 3D = unsettled (HF arena: PicGen3D / TRELLIS / Meshy; Crafiq: Tripo H3.1 / Hunyuan3D 3.1, low-sample).

### Cited Findings
- On AA, the top general-purpose consumer tools are OpenAI (GPT Image 2.x), Google (Nano Banana 2 / 2.1 / Pro) and Microsoft (MAI-Image). Google's Nano Banana Pro (released Nov 2025, 15,993 appearances) now sits at #19 on AA text-to-image at 1117. — [AA T2I](https://artificialanalysis.ai/image/leaderboard/text-to-image)
- Meshy-6 (#3, 1349) and Meshy-7 (#5, 1326) are the highest-ranked mainstream commercial 3D tools on the HF 3D Arena. TripoSR (the old open model, not Tripo's commercial service) is #20 at 1081. — [3D Arena](https://huggingface.co/spaces/3d-arena/3d-arena)
- ElevenLabs music models sit roughly 125–150 Elo below Suno v6 on both AA music boards. — [AA instrumental](https://artificialanalysis.ai/music/leaderboard/instrumental), [AA vocals](https://artificialanalysis.ai/music/leaderboard/vocals)

### Inferences
- If jam winners mostly used Midjourney, Stable Diffusion/FLUX open models, or hand-made art, this would show a gap between arena "winners" and practical choices. Midjourney does not appear in the AA top 25 parsed here, and open FLUX/Qwen models rank in the 1075–1114 range. Factors like price, transparency support, style control and licensing likely drive the choices, rather than arena Elo.

### Gaps
- No data on jam-winner tool usage was collected here (out of scope; another researcher covers it).
- Midjourney's AA position was not checked beyond the top 25. It may be absent because AA ranks only API-accessible models.
