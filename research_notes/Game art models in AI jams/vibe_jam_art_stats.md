# AI art and asset models in Vibe Jam 2025 and 2026: statistics from the jam's own data

Data pulled 2026-11-24, about 09:23 UTC, with curl through the session proxy (TLS verified).
Raw files: `/tmp/claude-0/-home-user-bomb-it-5/52544bf5-a639-5dc5-82f2-0623abd835f5/scratchpad/artstats_vj/`
(`api.json`, `games2026_cache.js`/`.json`, `home2025.html`, `games2025_inline.json`, `games2026.json`,
`scripts2026.js`, sponsor tweets `tw_*.json`). Classifier and statistics script:
`/tmp/claude-0/-home-user-bomb-it-5/52544bf5-a639-5dc5-82f2-0623abd835f5/scratchpad/artstats_scripts/analyze.py`
(run `python3 -I analyze.py <data_dir> [--hits]`; output in `out.txt` and `out_hits.txt` beside it).
These are scratch paths and may be cleared; numbers below are copied from the run.

## What fields describe tools and models per game, and how were mentions detected?

### Takeaway
Only 2026 has a structured tools field (`made_with`, filled for 917 of 945 games), and it is almost entirely
used to name the coding harness. 2025 has `made_with` in the page data but it is empty for all 1,077 rows, so
2025 tool use can only be read from the pitch and the free-text engine field. Art/asset generators are rarely
named anywhere: 28 of 945 entries in 2026 (2.96%) and 5 of 1,083 in 2025 (0.46%) name any AI asset tool.

### Cited Findings
- The public API returns 2,028 games (2025: 1,083 games, 632 still up; 2026: 945 games, 826 still up) with
  fields `year, game_name, game_url, x_username, pitch, genre, engine, multiplayer, mobile_ready, is_up,
  submitted_at`. It has no tools, rank or award field. — [vibejam.com/api](https://vibejam.com/api);
  [llms.txt](https://vibejam.com/llms.txt)
- The 2026 gallery page loads a games cache script (`window.__VIBEJAM_GAMES__`, 945 rows) that adds
  `inspiration`, `made_with`, `ai_written`, `has_portal`, `no_loading_screens`, `free_web_accessible`,
  `final_rank` and `award` per game. — [vibejam.com](https://vibejam.com/) (script
  `https://vibejam.com/2026/cache/games-5288ad4b37b007e7f970f150f68f2d1d.js`)
- Field fill in 2026: `made_with` non-empty for 917/945, `inspiration` and `pitch` for 945/945;
  `final_rank` is set for 943/945 (two are null). — games cache script, as above
- Ranking semantics: "final_rank 1-3 = the podium; every 🌿 special award is $1,000 on top" (Gold $25,000,
  Silver $10,000, Bronze $5,000), and the "winners" sort is the "Exact same order as the judge page's 'top all
  games': lower final_rank = higher. Unranked games (not in the judging DB) fall to the bottom." —
  [vibejam.com/2026/scripts.js](https://vibejam.com/2026/scripts.js)
- 2026 has 12 special awards; one (WenWare, "@boltdotnew's MOST PLAYED") is also the #3 podium game, so 14
  distinct prize-winning games. Award ranks: 3, 4, 5, 6, 7, 9, 14, 17, 19, 20, 22, 28. — games cache script
- 2025 page data (`window.__VIBEJAM_2025_GAMES__`, 1,077 rows) has a `made_with` key, but it is empty in all
  1,077 rows. 2025 has no rank or award data beyond the three podium cards on the archive page (Gold: The
  Great Taxi Assignment, Silver: Vibeware, Bronze: Vector Tango). — [vibejam.com/2025](https://vibejam.com/2025/)
- What people put in 2026 `made_with` (my tokenisation of the field): "claude code" 351, "cursor" 204,
  "codex" 171, "antigravity" 48, "gemini" 24, "chatgpt" 18, "bolt.new" 14, "lovable" 13 ... and only then
  "tripo" 7 (+1 "tripo3d"), "suno" 5, "elevenlabs" 3, "glif" 3, "pixelabs" 1, "veo3" 1, "grok imagine for
  images" 1, "gemini for assets" 1, "gpt for image generation for logo" 1. — games cache script

### Method (detection rules)
- Text scanned per game: 2025 = `pitch` + `engine` (API); 2026 = `made_with` + `pitch` + `inspiration` +
  `engine` (games cache). Case-insensitive regexes, one hit per category per game.
- Categories: 2D image = OpenAI image (gpt-image / "GPT Image" / DALL-E / ChatGPT or GPT within 40
  characters of image/art/sprite/texture/logo), GPT-4o (any mention, tracked separately), Midjourney, Flux
  (needs a model suffix or "Black Forest Labs"), Stable Diffusion / SDXL / ComfyUI, Gemini image (Nano Banana,
  Imagen, Gemini near image/asset/art words), Grok image, Ideogram, Recraft, Leonardo, Scenario, Glif,
  Krea/Firefly/other. 3D = Tripo, Meshy, Rodin/Hyper3D, Hunyuan3D, Trellis, CSM, other (Sloyd, Luma,
  World Labs). Sprite = PixelLab (incl. "pixelabs"), Retro Diffusion. Audio = Suno, Udio, ElevenLabs, and
  unspecified "AI music/voice/sfx". Video = Veo, Kling, Runway ML, Seedance, Sora. Also "AI art unspecified"
  ("AI-generated graphics", "AI image gen", "created all the assets with AI"), "procedural (any)" (any use
  of the word), "code-drawn explicit" ("zero external assets", "no assets", "100% code", "pure code",
  zzfx/sfxr), "hand-made" (hand-drawn/handcrafted/by hand/I drew/Blender/Aseprite), and asset libraries
  (Kenney, Quaternius, Mixamo, Sketchfab, Poly Pizza).
- Every non-procedural hit was read by hand (`--hits`). After tightening, the false positives removed were:
  "Neon Flux" (game title), "runway" (fashion runway, 2 games), and "AI model" (LLM opponents, 2 games).
- Known remaining noise: Temple Fist (rank 88) mentions "GPT Image 2" as inspiration for AI "games" it saw,
  while the game itself is built from AI video, so its OpenAI-image hit is uncertain. Sky Break (rank 144)
  says "i also tried tripo 3d, but it was paid", so its Tripo hit is "tried, not used". GuessPrompt (2025) is a
  game about AI images. "Procedural" mostly refers to levels or worlds, not art. Glif is described by its
  makers as a "creative agent" with "hundreds of AI models" aimed at marketing content, so a Glif mention does
  not say which asset type it made. — [@heyglif on X](https://x.com/heyglif/status/2041609295662608747)

### Inferences
- `made_with` behaves as a "which coding tool" answer. Absence of an art tool in it is not evidence that no
  art tool was used. All rates below are lower bounds on actual use.
- The 2025 to 2026 rise (0.46% to 2.96% naming any AI asset tool) is mostly a change of form: 2026 added
  `made_with` and `inspiration`, and 2025 had neither. It should not be read as adoption growth.

### Gaps
- The submission form's wording for `made_with` and `inspiration` is not published in the data, so I cannot
  say whether entrants were asked about art tools at all.
- The API row count for 2025 (1,083) and the 2025 page data (1,077) differ by 6; I used the API.

## Counts and shares per model (all entries, per year)

### Takeaway
No single art model is common in the self-reported data. Tripo is the most-named asset generator (10 games,
1.06% of 2026; 9 if the "tried, but it was paid" entry is dropped), followed by Suno (7), ElevenLabs (5 in
2026, 1 in 2025) and OpenAI image (4). Midjourney, Flux, Stable Diffusion, Ideogram, Recraft, Leonardo,
Scenario, Rodin, Trellis, CSM, Retro Diffusion and Udio have zero mentions in both years.

### Cited Findings
All counts are games (2025 n=1,083; 2026 n=945), from the API and the 2026 games cache
([vibejam.com/api](https://vibejam.com/api); [vibejam.com](https://vibejam.com/) games cache).

| Category | 2025 n (%) | 2026 n (%) | Both n (%) |
|---|---|---|---|
| OpenAI image (gpt-image/DALL-E/ChatGPT image) | 0 | 4 (0.42%) | 4 (0.20%) |
| GPT-4o (any mention) | 0 | 0 | 0 |
| Midjourney / Flux / Stable Diffusion | 0 / 0 / 0 | 0 / 0 / 0 | 0 |
| Gemini image / Nano Banana | 2 (0.18%) | 2 (0.21%) | 4 (0.20%) |
| Grok Imagine | 0 | 1 (0.11%) | 1 |
| Ideogram / Recraft / Leonardo / Scenario / Krea | 0 | 0 | 0 |
| Glif | 0 | 3 (0.32%) | 3 (0.15%) |
| **Any named 2D generator** | 2 (0.18%) | 9 (0.95%) | 11 (0.54%) |
| Tripo | 0 | 10 (1.06%) | 10 (0.49%) |
| Meshy | 0 | 1 (0.11%) | 1 |
| Hunyuan3D | 0 | 1 (0.11%) | 1 |
| Other 3D (World Labs) | 0 | 1 (0.11%) | 1 |
| Rodin / Trellis / CSM | 0 | 0 | 0 |
| **Any named 3D generator** | 0 | 12 (1.27%) | 12 (0.59%) |
| PixelLab | 0 | 2 (0.21%) | 2 |
| Retro Diffusion | 0 | 0 | 0 |
| Suno | 0 | 7 (0.74%) | 7 (0.35%) |
| Udio | 0 | 0 | 0 |
| ElevenLabs | 1 (0.09%) | 5 (0.53%) | 6 (0.30%) |
| AI audio, tool unnamed | 0 | 2 (0.21%) | 2 |
| **Any audio AI** | 1 (0.09%) | 11 (1.16%) | 12 (0.59%) |
| Video gen (Veo, Seedance) | 0 | 2 (0.21%) | 2 |
| AI art, tool unnamed | 2 (0.18%) | 4 (0.42%) | 6 (0.30%) |
| **Any visual AI (2D/3D/sprite/unnamed art)** | 4 (0.37%) | 23 (2.43%) | 27 (1.33%) |
| **Any AI asset tool (visual, audio, video)** | 5 (0.46%) | 28 (2.96%) | 33 (1.63%) |
| "Procedural" (any use of the word) | 13 (1.20%) | 27 (2.86%) | 40 (1.97%) |
| Code-drawn, explicit ("zero external assets", "100% code") | 1 (0.09%) | 4 (0.42%) | 5 (0.25%) |
| Hand-made art | 0 | 3 (0.32%) | 3 (0.15%) |
| Asset libraries (Kenney, Quaternius, Mixamo...) | 0 | 0 | 0 |

- Where the 2026 hits came from: Tripo 9 in `made_with` and 1 in `inspiration`; Suno 6 / 1; ElevenLabs 3 /
  2; Glif 3 / 0; OpenAI image 1 / 3; all "AI art unnamed" in `inspiration`. "Procedural" was 24 in `pitch`.
  — games cache script
- 2026 Tripo games by `final_rank`: 1, 75, 107, 144 ("tried ... but it was paid"), 570, 657, 677, 872, 874,
  and one unranked (DroneSim.com). Suno: 1, 9, 75, 144, 157, 578, and DroneSim.com. ElevenLabs: 1, 157, 578,
  631, 898. Glif: Moggmon (890) and the two unranked games, DroneSim.com and Voxel Derby. — games cache script
- 2025 hits: "Gemini for images" and "gemini flash exp 2 image" (engine field), "assets generated by AI"
  (Vibe Kingdom pitch), GuessPrompt (game about AI images), ElevenLabs (spellingbminus.com engine field). —
  [vibejam.com/api](https://vibejam.com/api)

### Inferences
- In the jam's own data the visible asset stack is "Tripo for 3D + Suno for music + ElevenLabs for
  voice/SFX", and it appears only in 2026. Named 2D image models are scattered (OpenAI 4, Gemini 4 across both
  years, Grok 1) with no leader.

### Gaps
- No usable data on Midjourney, Flux or Stable Diffusion use: zero mentions may only mean entrants did not
  list art tools.

## Over-representation among winners (lift)

### Takeaway
Only the 2026 data supports a winner comparison. The one robust-looking pattern is AI audio (Suno /
ElevenLabs / AI voice): 3 of the top 10 against 11 of 945 overall (lift 25.8). Tripo's high podium lift (31.5)
rests on a single game, the Gold winner. No 2D image model appears among any prize winner or the top 25.
Every result is small-n. With about 210 category-by-group tests, nothing passes a Bonferroni threshold
(p < 0.00024) except the "any audio AI" top-10 result, which is borderline.

### Cited Findings
Lift = share in group ÷ share in all 945 2026 games; p = one-sided hypergeometric (Fisher) P(X ≥ k).
Computed from the games cache `final_rank` and `award` fields ([vibejam.com](https://vibejam.com/);
rank semantics in [scripts.js](https://vibejam.com/2026/scripts.js)).

| Category (all 945) | Podium 1-3 (n=3) | Special awards (n=12) | Any prize (n=14) | Top 10 | Top 25 | Top 100 (n=99) |
|---|---|---|---|---|---|---|
| Tripo (10; 1.06%) | 1, lift 31.5, p=0.031 | 0 | 1, 6.75, p=0.14 | 1, 9.45, p=0.10 | 1, 3.78, p=0.24 | 2, 1.91, p=0.28 |
| Suno (7; 0.74%) | 1, 45.0, p=0.022 | 1, 11.3, p=0.086 | 2, 19.3, p=0.004 | 2, 27.0, p=0.002 | 2, 10.8, p=0.013 | 3, 4.09, p=0.029 |
| ElevenLabs (5; 0.53%) | 1, 63.0, p=0.016 | 0 | 1, 13.5, p=0.072 | 1, 18.9, p=0.052 | 1, 7.56, p=0.13 | 1, 1.91, p=0.43 |
| Any audio AI (11; 1.16%) | 1, 28.6, p=0.035 | 2, 14.3, p=0.008 | 3, 18.4, p<0.001 | 3, 25.8, p<0.001 | 3, 10.3, p=0.002 | 4, 3.47, p=0.021 |
| Any named 3D (12; 1.27%) | 1, 26.3, p=0.038 | 0 | 1, 5.62, p=0.17 | 1, 7.88, p=0.12 | 1, 3.15, p=0.28 | 2, 1.59, p=0.36 |
| Any named 2D (9; 0.95%) | 0 | 0 | 0 | 0 | 0 | 2, 2.12, p=0.24 |
| OpenAI image (4) | 0 | 0 | 0 | 0 | 0 | 2, 4.77, p=0.057 |
| Glif (3) | 0 | 0 | 0 | 0 | 0 | 0 |
| Any visual AI (23; 2.43%) | 1, 13.7, p=0.071 | 0 | 1, 2.93, p=0.29 | 1, 4.11, p=0.22 | 1, 1.64, p=0.46 | 5, 2.08, p=0.083 |
| Any AI asset tool (28; 2.96%) | 1, 11.3, p=0.086 | 2, 5.62, p=0.047 | 3, 7.23, p=0.007 | 3, 10.1, p=0.002 | 3, 4.05, p=0.035 | 7, 2.39, p=0.021 |
| "Procedural" (27; 2.86%) | 0 | 1, 2.92, p=0.30 | 1, 2.50, p=0.34 | 1, 3.50, p=0.25 | 1, 1.40, p=0.52 | 2, 0.71, p=0.80 |

- The winners behind these numbers: #1 A Game About Capybaras Delivering Food, `made_with` "Claude Code,
  Tripo3d, Suno, ElevenLabs"; #5 HALDANE-4 (Most Original), "AI voice" in its inspiration text and
  "procedural" in its pitch; #9 Kanso (@heyglif's Most Zen), `made_with` "Codex, GPT 5.5, Opus 4.7, Suno".
  The other 11 prize winners (Fanto's Mega-Mart, WenWare, Null Range [Best Art Direction], Eyrie, Tiny Skies,
  Undersphere, Swingers, FULL SEND, BeetleJump, KÖTTBULLAR METAL, Almost Surgery) name no art or audio tool;
  their `made_with` is just Codex, Cursor or Claude Code. — games cache script
- Sensitivity: dropping the "tried, but paid" Sky Break entry leaves Tripo at 9/945; podium lift 35.0
  (p=0.028), top 25 lift 4.2 (p=0.22), top 100 lift 2.1 (p=0.24). Dropping the unnamed "AI voice"
  (HALDANE-4) from audio leaves 10/945 and top 10 = 2/10, lift 18.9, p=0.004. — computed from games cache
- 2025 podium: none of the three podium entries names any art or audio tool in the jam data (Taxi: engine
  "ThreeJS"; Vibeware: "Just react.js and webapis"; Vector Tango: "ThreeJS"). — [vibejam.com/api](https://vibejam.com/api)
- Under-reporting check against write-ups: the 2025 Gold winner's author wrote that he used GPT-4o image
  generation for billboards (replacing a Stable Diffusion plan), Suno for music and ElevenLabs for SFX, none
  of which appears in the jam data. — [Cassovia Code blog (Bencko)](https://cassoviacode.com/i-tried-vibe-coding-how-i-created-gta-with-artificial-intelligence/);
  [vibejam.com/api](https://vibejam.com/api). A second-hand write-up says the 2026 Gold winner also used
  "GPT Images-2" and Grok for textures, which his `made_with` omits. —
  [Admix](https://admix.software/blog/ai-game-won-25k-vibejam-2026) (secondary, as cited in this repo's
  earlier notes `research_notes/Layered Godot agent workflow/vibe_jam_writeups.md`)

### Inferences
- The winner pattern looks less like "a particular model wins" and more like "entrants who list a full asset
  pipeline (3D + music + SFX) place higher". That fits the earlier write-up finding that winners were
  experienced developers who put unusual effort into polish and audio. People who bother to list asset tools
  may also be the more thorough entrants, so this is a reporting effect as much as a tool effect.
- The two winner write-ups show known tool use missing from the data (2025 Gold, 2026 Gold). The
  detection rate among winners is therefore probably also low, so lift figures are unreliable in both
  directions.
- Ranks 4 and lower are the judging database's order, not announced placings. "Top 25" and "Top 100" are
  the site's sort order, and only ranks 1-3 and the 12 awards are actual results.

### Gaps
- No 2025 ranking beyond the podium, and no 2025 tool field, so no 2025 lift can be computed (0 of 3 podium
  games name any tool).
- Lift on n=3 or n=10 groups with base counts of 5-12 cannot separate a real effect from one or two
  individual developers.

## Sponsor effects (Tripo AI and Glif, 2026)

### Takeaway
Tripo ran a public incentive (3,000 credits for entries that tag it), and it is the most-named asset tool
in 2026. Its mentions are spread across ranks and do not rise among winners beyond the single Gold game.
Glif was named by 3 entries, none ranked above 890 (two unranked). Glif sponsored a special award, which
went to Kanso; Kanso does not mention Glif.

### Cited Findings
- 2026 sponsors on the page: Bolt.new, Cursor, Glif, Tripo3D. The gallery's "MADE WITH" filter buttons are
  Cursor, Bolt.new, Glif, Tripo, Claude, Codex, VS Code. — [vibejam.com](https://vibejam.com/)
- Tripo (2026-04-10): "If you ship something for vibe jam with it, post it and tag #TripoAI. We'll hook you
  up with 3,000 points." Tripo (2026-04-13): "Tag @tripoai in your #VibeJam entry, and grab 3000 free credits
  for your work!", promoting "Tripo P1.0 Smart Mesh" with "adjustable polycount from 500 to 20,000". —
  [X @tripoai](https://x.com/tripoai/status/2042603805339193477);
  [X @tripoai](https://x.com/tripoai/status/2043713320050655555) (read via api.fxtwitter.com)
- Glif (2026-04-07): co-sponsor; "Glif is an insanely powerful creative agent ready to help you build
  marketing content & launch videos for your game - we've put hundreds of AI models and skills into one
  agent". — [X @heyglif](https://x.com/heyglif/status/2041609295662608747)
- Sponsor-named awards: "@cursor_ai's BEST ART DIRECTION" (Null Range, Cursor only), "@cursor_ai's MOST
  ORIGINAL" (HALDANE-4), "@heyglif's MOST ZEN" (Kanso), "@boltdotnew's MOST PLAYED" (WenWare). No award is
  named for Tripo. — games cache script
- One non-sponsor ad effect is visible: Harmony Isles (rank 692) says it entered after seeing "the add from
  PixelLabAI". — games cache script (`inspiration`)
- 2025 sponsors (Bolt.new, CodeRabbit, Lambda Labs per earlier notes) included no art tool, and 2025 has zero
  Tripo mentions. — [vibejam.com/2025/js/sponsors.js](https://vibejam.com/2025/js/sponsors.js) (as recorded in
  `jams_and_plugins_verification.md`)

### Inferences
- Tripo's lead among art tools may partly reflect its credit offer and its "MADE WITH" filter button, both of
  which reward naming it. That inflates its count relative to unsponsored generators such as Meshy (1).
- Outside the Gold winner, Tripo users sit at about the base rate (top 100: 2/99 vs 10/945). There is no
  sign that the sponsor's tool was favoured by judging.

### Gaps
- Whether the tagging offer changed what entrants typed into `made_with` cannot be tested from the data.

## Correlation with engine (Three.js vs others)

### Takeaway
3D generators (Tripo, Meshy) are named mainly by Three.js games (10 of 12), as expected. Named 2D generators
are spread across engines. Three.js itself is over-represented among 2026 winners (all 3 podium games, 9 of
the top 10), so engine and art-tool effects are confounded.

### Cited Findings
Engine classified as Three.js if the free-text engine field contains "three", "r3f" or "react-three";
otherwise "other". 2025: Three.js 655, other 428. 2026: Three.js 618, other 327.
— [vibejam.com/api](https://vibejam.com/api); games cache script

| 2026 category | Three.js (n=618) | Other (n=327) |
|---|---|---|
| Any named 3D | 10 (1.62%) | 2 (0.61%) |
| Tripo | 8 (1.29%) | 2 (0.61%) |
| Any named 2D | 5 (0.81%) | 4 (1.22%) |
| OpenAI image | 2 (0.32%) | 2 (0.61%) |
| Any audio AI | 9 (1.46%) | 2 (0.61%) |
| Suno | 6 (0.97%) | 1 (0.31%) |
| Any visual AI | 14 (2.27%) | 9 (2.75%) |
| "Procedural" | 23 (3.72%) | 4 (1.22%) |
| Code-drawn explicit | 3 (0.49%) | 1 (0.31%) |

- 2025: all 4 visual-AI mentions are in non-Three.js games; "procedural" is 12/655 Three.js vs 1/428 other.
- Three.js share by 2026 group: podium 3/3, special awards 8/12, any prize 10/14, top 10 9/10, top 25 19/25,
  top 100 79/99, rank > 100 or unranked 539/846 (63.7%); all games 618/945 (65.4%). — games cache script

### Inferences
- Three.js is mildly over-represented at the very top (top 10: 90% vs 65% overall), and the asset-tool users
  are also mostly Three.js. With these sample sizes the two cannot be separated.

### Gaps
- Engine is free text (2025 especially). A few Three.js games listed only as a framework (for example "React")
  may be counted as "other".
