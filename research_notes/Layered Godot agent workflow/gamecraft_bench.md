# GameCraft-Bench (arXiv 2606.17861): primary-source verification

Sources read in full (downloaded 2026-11-24, treated as untrusted data):
- arXiv abstract page: https://arxiv.org/abs/2606.17861 (only v1 exists)
- arXiv full HTML: https://arxiv.org/html/2606.17861 (Sections 1–7, Limitations, Appendices A–C)
- Project site: https://tongxuluo.github.io/gamecraft-bench-website/ (leaderboard updated after the paper)

Short labels below: "paper" = arXiv HTML v1; "site" = project site.

## Is the arXiv ID, date, title, author list and task count correct? What are the 15 families?

### Takeaway
All identity claims from the earlier notes are correct. The ID is 2606.17861 (v1 only), submitted Tue 16 Jun 2026. It has 25 authors led by Tongxu Luo, with Benyou Wang as corresponding author. The benchmark has 140 Godot tasks in 15 families. The largest families are Platformer (19), Strategy (17) and Tycoon (16).

### Cited Findings
- Title: "GameCraft-Bench: Can Agents Build Playable Games End-to-End in a Real Game Engine?" Version history: "[v1] Tue, 16 Jun 2026 12:34:39 UTC (5,503 KB)". No later version exists. — [arXiv abs](https://arxiv.org/abs/2606.17861)
- Authors (citation metadata, in order): Tongxu Luo, Rongsheng Wang, Jiaxi Bi, Chenming Xu, Zhengyang Tang, Jianlong Chen, Juhao Liang, Ke Ji, Shuqi Guo, Yuhao Du, Fan Bu, Wenyu Du, Xiaotong Zhang, Kyle Li, Shaobo Wang, Linfeng Zhang, Yuxuan Liu, Xin Lai, Chenxin Li, Yiduo Guo, Zhexin Zhang, Xinyuan Wang, Tianyi Bai, Ziniu Li, Benyou Wang (25 in total). Affiliations: CUHK-Shenzhen, Shenzhen Loop Area Institute, Tencent Hunyuan Team, USTB, DualverseAI, SJTU and NUS. Benyou Wang is the corresponding author. — [arXiv abs](https://arxiv.org/abs/2606.17861); [arXiv HTML](https://arxiv.org/html/2606.17861)
- Abstract: "a benchmark comprising 140 Godot tasks across 15 game families … the strongest agent achieves only 41.46%, and most agents score below 40%." — [arXiv abs](https://arxiv.org/abs/2606.17861)
- Table 3 (task counts, which "exclude the example task"): Platformer 19, Strategy 17, Tycoon 16, Open-world 15, Roguelike 14, Visual novel 11, Puzzle 8, Shooter 7, Simulation 6, Card game 5, Horror 5, Rhythm 5, Idle 4, Racing 4, Sports 4. These sum to 140. The site shows the same list. — [arXiv HTML §3.4, Table 3](https://arxiv.org/html/2606.17861); [site](https://tongxuluo.github.io/gamecraft-bench-website/)
- §3.4 explains how the families were chosen: "continuous control and collision in platformers and racing games, rule and state management in card and strategy games, progression and economy in tycoon and idle games, exploration and spatial layout in open-world and roguelike games, and narrative or presentation-heavy interaction in visual novels, horror, rhythm, and sports games." — [arXiv HTML §3.4](https://arxiv.org/html/2606.17861)
- Scope: all games are 2D in Godot 4. The reference runtime is Godot 4.6.2 stable on Ubuntu 22.04 with Python 3.12. The benchmark does not cover 3D, multiplayer, large-scale physics or audio. — [arXiv HTML Limitations; Appendix A](https://arxiv.org/html/2606.17861)
- Tasks were authored on the Harbor framework by 12 annotators. Each task has a `task.toml`, an `instruction.md` (public spec) and a `tests/rubric.json` (hidden rubric of at most 24 items). Each annotator also wrote an oracle "minimal playable sketch in Godot" to check that the spec, rubric and replay agree. — [arXiv HTML §3.4](https://arxiv.org/html/2606.17861)

### Inferences
- About 52% of the tasks (72/140) fall in the first four families (platformer, strategy, tycoon, open-world). Families with 4–5 tasks (idle, racing, sports, card game, horror, rhythm) have high per-family variance, so their rankings are fragile.

### Gaps
- None for identity facts.

## Exact headline scores and sub-scores; the 68.44% figure

### Takeaway
The paper's headline numbers are confirmed exactly by Table 4. Claude Code with Opus-4.7 high scores 41.46 overall, 55.34 Mechanics, 39.48 Depth, 42.78 Visuals and 36.86 Art. Codex with GPT-5.5 high scores 39.49 overall. The earlier "55.3%" is 55.34 rounded. The "stray" 68.44% is not in the paper. It is the top entry on the project site's later leaderboard: Claude Code with "Opus 5 xhigh", model release date 2026-07-24.

### Cited Findings
- **Table 4 (paper, "Benchmark-level results (%)")**, all seven configurations, each run on all 140 tasks:

| Harness | Model | Overall | Mechanics | Depth | Visuals | Art |
|---|---|---|---|---|---|---|
| Claude Code | Opus-4.7 high | 41.46 | 55.34 | 39.48 | 42.78 | 36.86 |
| Claude Code | MiMo-V2.5-Pro | 24.10 | 32.33 | 22.59 | 27.45 | 20.65 |
| Codex | GPT-5.5 high | 39.49 | 54.36 | 38.61 | 41.84 | 32.94 |
| Codex | DeepSeek-V4-Pro | 2.15 | 2.25 | 1.69 | 1.97 | 2.63 |
| Kimi Code | Kimi-K2.6 | 30.65 | 39.76 | 28.07 | 33.66 | 27.99 |
| Code Buddy | GLM-5.1 | 18.29 | 25.23 | 17.80 | 21.14 | 14.59 |
| Code Buddy | MiniMax-M2.7 | 10.95 | 14.27 | 9.92 | 14.92 | 8.85 |

  — [arXiv HTML §4, Table 4](https://arxiv.org/html/2606.17861)
- Paper text: "The strongest completed configuration, Opus-4.7 high under Claude Code, reaches only 41.46% overall. GPT-5.5 high follows closely at 39.49%, while Kimi-K2.6 reaches 30.65%. MiMo-V2.5-Pro drops to 24.10%, and DeepSeek-V4-Pro reaches only 2.15%." — [arXiv HTML §4](https://arxiv.org/html/2606.17861)
- Correction to earlier notes: MiMo-V2.5-Pro was run under **Claude Code**, not as its own harness. DeepSeek-V4-Pro was run under **Codex**. GLM-5.1 and MiniMax-M2.7 were run under **Code Buddy**. — [arXiv HTML §4 Experimental Setup](https://arxiv.org/html/2606.17861)
- **The 68.44% figure** comes from the site: "The strongest configuration reaches 68.44%." The site's leaderboard ("Overall and category scores on the full 140-task benchmark"; release date = model's public release) lists:

| Rank | Agent | Model | Type | Model release | Overall | Mech | Depth | Vis | Art |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Claude Code | Opus 5 xhigh | Vision | 2026-07-24 | 68.44 | 76.75 | 63.31 | 68.04 | 70.11 |
| 2 | Claude Code | Fable 5 high | Vision | 2026-06-09 | 65.72 | 76.52 | 58.61 | 66.93 | 67.68 |
| 3 | Codex | GPT-5.6-sol high | Vision | 2026-07-09 | 60.50 | 74.50 | 56.10 | 64.80 | 57.00 |
| 4 | Kimi Code | Kimi-K3 | Vision | 2026-07-16 | 56.96 | 73.03 | 53.38 | 56.90 | 53.59 |
| 5 | SeeleAgent | Seele02-pro | Vision | 2026-07-09 | 50.70 | 68.42 | 48.76 | 52.74 | 44.17 |
| 6 | Claude Code | Opus-4.7 high | Vision | 2026-04-16 | 41.46 | 55.34 | 39.48 | 42.78 | 36.86 |
| 7 | Claude Code | Deepseek-V4-Flash-0731 | Text | 2026-07-31 | 40.61 | 52.11 | 37.14 | 43.70 | 37.72 |
| 8 | Codex | GPT-5.5 high | Vision | 2026-04-23 | 39.49 | 54.36 | 38.61 | 41.84 | 32.94 |
| 9 | Claude Code | GLM-5.2 | Text | 2026-06-16 | 39.12 | 50.09 | 36.40 | 41.06 | 36.29 |
| 10–14 | (paper rows) | Kimi-K2.6, MiMo-V2.5-Pro, GLM-5.1, MiniMax-M2.7, DeepSeek-V4-Pro | | | 30.65, 24.10, 18.29, 10.95, 2.15 | | | | |

  — [site leaderboard](https://tongxuluo.github.io/gamecraft-bench-website/)
- The paper rows on the site (ranks 6, 8, 10–14) match Table 4 exactly. — [site](https://tongxuluo.github.io/gamecraft-bench-website/); [arXiv HTML Table 4](https://arxiv.org/html/2606.17861)
- Overall uses the weighted formula `Score = BUILD × (0.15·M + 0.35·D + 0.15·V + 0.35·A)`. Content Depth and Art are weighted highest "because a complete game should extend beyond minimal mechanics and functional prototypes." — [arXiv HTML §3.2 Stage 5](https://arxiv.org/html/2606.17861)

### Inferences
- The weights explain why Mechanics in the mid-50s gives an overall of about 40. Recomputing from the benchmark-level category means gives 41.44 for Opus-4.7, close to the reported 41.46. The small difference is expected because the formula is applied per task before averaging.
- Rows 1–5, 7 and 9 of the site leaderboard were added after the paper. Their models (for example "Opus 5", "Fable 5", "GPT-5.6-sol") were released after the 16 Jun 2026 submission, except Fable 5. The paper does not describe these runs. Assume the same protocol but treat them as unreviewed. Any claim that "Claude Code tops at 41%" is now stale as a "best agent" statement: the site's top is 68.44.
- Across the site's rows, Art and Presentation rises sharply for the newest models (Opus 5 xhigh Art 70.11 versus Opus-4.7 36.86). The paper's main pattern, mechanics well ahead of art, is much weaker at the top of the newer leaderboard.

### Gaps
- The site does not say whether the newer runs used the same judge (GPT-5.5), the same reasoning effort or the same timeouts. It gives no per-family breakdown for them. The site also has no version or date stamp for when rows were added. **[unverifiable from paper]**
- The site lists "Fable 5 high" with a 2026-06-09 release date, before the paper's submission, but the paper does not include it. Why is unexplained. **[unverified]**
- The earlier notes said leaderboard numbers "differ slightly between sites". The primary paper and the project site agree exactly on all shared rows. Any differences come from secondary coverage (e.g. AI Weekly), which I did not re-read.

## Full per-family result table: best and worst families, and the paper's explanation

### Takeaway
Appendix B Table 6 gives per-family scores (overall and M/D/V/A) for all seven configurations. For the three strong agents (Opus-4.7, GPT-5.5, Kimi-K2.6), the highest families are Idle, Sports and Horror. The lowest are Card game, Tycoon, Racing, Platformer and Open-world. Card game is the lowest family for every one of the three. The paper gives no family-by-family explanation. It only says performance varies "sharply across game families". It frames each family by the construction demand it tests.

### Cited Findings
- **Table 6, Overall score per family (%)** (column order as in the paper; task counts from Table 3):

| Family (n) | Opus-4.7 (CC) | GPT-5.5 (Codex) | Kimi-K2.6 | MiMo-V2.5-Pro (CC) | GLM-5.1 | MiniMax-M2.7 | DeepSeek-V4-Pro |
|---|---|---|---|---|---|---|---|
| Benchmark overall | 41.46 | 39.49 | 30.65 | 24.10 | 18.29 | 10.95 | 2.15 |
| Platformer (19) | 36.57 | 37.26 | 28.94 | 22.64 | 15.09 | 7.85 | 1.77 |
| Strategy (17) | 44.73 | 39.81 | 32.48 | 20.72 | 16.60 | 9.79 | 0.66 |
| Tycoon (16) | 36.45 | 31.55 | 30.79 | 31.66 | 18.98 | 14.66 | 0.00 |
| Open-world (15) | 40.80 | 40.17 | 23.61 | 18.37 | 17.10 | 6.46 | 0.40 |
| Roguelike (14) | 40.10 | 34.55 | 35.17 | 24.31 | 19.62 | 12.72 | 2.09 |
| Visual novel (11) | 43.60 | 42.15 | 37.85 | 21.36 | 16.88 | 10.82 | 1.06 |
| Puzzle (8) | 35.87 | 46.80 | 25.42 | 24.58 | 23.71 | 6.24 | 0.00 |
| Shooter (7) | 40.28 | 41.30 | 33.66 | 25.96 | 17.74 | 14.55 | 0.00 |
| Simulation (6) | 38.29 | 38.81 | 36.14 | 27.21 | 29.15 | 21.34 | 5.76 |
| Card game (5) | 33.78 | 25.50 | 18.48 | 14.14 | 13.88 | 7.29 | 2.45 |
| Horror (5) | 57.30 | 49.05 | 28.94 | 34.55 | 22.21 | 16.05 | 6.79 |
| Rhythm (5) | 46.57 | 42.65 | 25.80 | 17.76 | 13.22 | 10.88 | 1.69 |
| Idle (4) | 56.99 | 64.91 | 41.65 | 38.87 | 25.41 | 15.78 | 17.01 |
| Racing (4) | 45.26 | 37.15 | 19.81 | 19.39 | 13.94 | 10.17 | 0.00 |
| Sports (4) | 48.24 | 49.71 | 41.61 | 31.66 | 19.77 | 8.61 | 12.91 |

  — [arXiv HTML Appendix B, Table 6](https://arxiv.org/html/2606.17861)
- **Table 6 category rows for the top agent, Claude Code + Opus-4.7 high (M / D / V / A)**: Platformer 45.77/35.50/46.28/29.55; Strategy 54.91/46.78/62.60/30.65; Tycoon 48.31/39.42/45.11/24.69; Open-world 47.88/34.43/29.57/48.94; Roguelike 64.87/38.79/46.50/28.05; Visual novel 56.33/42.22/50.99/35.21; Puzzle 51.43/26.43/43.36/35.44; Shooter 55.00/40.57/38.20/34.58; Simulation 61.17/37.33/44.13/26.93; Card game 54.67/26.25/18.48/38.92; Horror 72.67/49.00/50.50/61.92; Rhythm 62.00/40.00/24.70/55.90; Idle 76.67/61.25/23.12/58.82; Racing 55.83/45.31/23.15/50.15; Sports 66.25/40.62/39.38/51.95. — [arXiv HTML Table 6](https://arxiv.org/html/2606.17861)
- **Table 6, Codex + GPT-5.5 high (M / D / V / A)**: Platformer 50.51/34.66/45.49/30.65; Strategy 50.96/40.69/56.61/26.94; Tycoon 42.64/36.85/41.01/17.45; Open-world 54.48/39.23/27.29/40.51; Roguelike 50.99/32.60/43.42/25.65; Visual novel 56.00/45.61/50.46/28.50; Puzzle 67.97/37.97/53.34/43.75; Shooter 64.00/33.71/44.89/37.62; Simulation 53.83/37.50/40.10/33.11; Card game 50.67/23.25/17.73/20.29; Horror 59.67/36.50/44.00/59.20; Rhythm 57.33/40.75/32.84/42.45; Idle 90.83/72.19/28.12/62.29; Racing 57.50/35.00/25.23/35.69; Sports 52.08/55.62/33.75/49.61. — [arXiv HTML Table 6](https://arxiv.org/html/2606.17861)
- **Table 6, Kimi Code + Kimi-K2.6 (M / D / V / A)**: Platformer 34.32/22.71/39.27/28.43; Strategy 47.65/32.22/44.17/21.23; Tycoon 38.50/32.04/39.30/22.60; Open-world 26.99/23.10/19.05/24.62; Roguelike 52.31/33.22/43.30/26.27; Visual novel 45.73/40.09/46.49/27.75; Puzzle 30.47/18.12/35.51/26.23; Shooter 43.00/30.43/29.65/34.61; Simulation 47.50/40.83/38.42/25.60; Card game 29.00/11.50/10.57/24.33; Horror 34.67/17.50/19.00/42.19; Rhythm 41.00/14.50/22.91/31.84; Idle 64.58/38.75/15.62/45.87; Racing 20.00/8.12/8.33/36.32; Sports 39.17/44.38/25.62/46.74. — [arXiv HTML Table 6](https://arxiv.org/html/2606.17861)
- The paper's only general statement on family variance: agents fail "across core mechanics, content depth, functional visuals, and art and presentation, with performance varying sharply across game families." — [arXiv HTML §1 "Observations"](https://arxiv.org/html/2606.17861)
- The judge-versus-human calibration (Table 5) found the largest permissive gap on Idle: judge 41.65 versus human 32.89, Δ +8.76. The judge gave Depth +12.19 and Art +11.50 more than humans. Card game was nearly matched (Δ −0.27). — [arXiv HTML §5.2, Table 5](https://arxiv.org/html/2606.17861)

### Inferences
(Computed by me from Table 6; not stated in the paper.)
- Mean overall of the three strong agents (Opus-4.7, GPT-5.5, Kimi-K2.6), by family: Idle 54.5, Sports 46.5, Horror 45.1, Visual novel 41.2, Strategy 39.0, Shooter 38.4, Rhythm 38.3, Simulation 37.8, Roguelike 36.6, Puzzle 36.0, Open-world 34.9, Platformer 34.3, Racing 34.1, Tycoon 32.9, Card game 25.9.
- The best family, Idle, is also where the paper's human check found the judge most permissive (+8.76). Part of the Idle lead may be judge inflation. Idle, Sports, Horror, Racing and Rhythm have only 4–5 tasks each.
- **Functional Visuals collapses in some families.** In Card game, Idle, Racing and Rhythm, the top agents score only about 15–33 on V, even when M is 55–90 (e.g. GPT-5.5 Idle M 90.83 versus V 28.12; Opus Card game V 18.48). These families depend on readable state UI (card states, counters, speed and timing feedback). This fits the paper's point that "functional visual feedback" is a main weakness.
- **Art lags in systems-heavy families.** Strategy, Tycoon, Roguelike and Simulation score high on M but have the lowest Art (Opus Tycoon A 24.69; GPT-5.5 Tycoon A 17.45). Presentation-led families score higher on Art (Horror A 59–62, Idle A 59–62).
- Large families relevant to an action/arcade 2D game: Platformer is in the bottom half for every strong agent (36.57 / 37.26 / 28.94). Shooter sits in the middle (40.28 / 41.30 / 33.66). The paper groups platformer and racing as "continuous control and collision" demands. Both are below the overall average for most agents. A maze-bomber game, which needs grid movement and real-time collision, would likely look like these families plus strategy-style state readability. This is an analogy, not a measured result.
- Using Table 3 counts, the task-weighted mean of Table 6 family overall scores reproduces Table 4 for six of the seven agents. Opus-4.7 gives 41.29 against the reported 41.46. The cause is unknown. It may be rounding or the excluded example task.

### Gaps
- The paper gives no causal per-family explanation, no per-family failure taxonomy, and no per-task scores. Per-task data may be in the released repo ([github.com/tongxuluo/gamecraft-bench](https://github.com/tongxuluo/gamecraft-bench), linked from the site), which I did not inspect.
- The site leaderboard models (Opus 5, Fable 5, GPT-5.6-sol, etc.) have no per-family breakdown.

## Scoring method, harness details, and failure modes with frequencies

### Takeaway
Scoring has a hard launch gate. The project must launch under `godot --headless --path /workspace/game --quit-after 5` and at least one demo trace must parse; otherwise BUILD = 0. The agent also submits 1–10 deterministic input traces. The verifier replays each trace in a fresh Godot instance at 1280×720 and 30 fps, records video, and samples 2 frames/s from at most a 20 s window. A GPT-5.5 judge scores each hidden-rubric item 0/0.5/1. Reported failure modes are: work stops at partial mechanics; content and presentation are thin; visual feedback is poor; and demo traces are missing or invalid. Few failure frequencies are given; most are in figures.

### Cited Findings
- Five-stage pipeline: (1) Task Packaging (spec + Godot environment + hidden rubric); (2) Agent Generation; (3) Build Gate; (4) Replay; (5) Scoring and Aggregation. — [arXiv HTML §3.2, Fig. 5](https://arxiv.org/html/2606.17861)
- Build Gate: "If the project fails to launch, or if no submitted trace can be parsed, the verifier sets BUILD=0 and the final score is zero." Example build check: `"cmd": "godot --headless --path /workspace/game --quit-after 5"`. — [arXiv HTML §3.2; Appendix C rubric.json](https://arxiv.org/html/2606.17861)
- Replay: "the verifier starts a fresh Godot instance, replays input at 30 frames per second, records the 1280×720 display through ffmpeg, and stores a compressed 854×480 version." Frames are sampled every 0.5 s. The default is at most 10 demos and at most a 20 s window per demo. Traces are JSON files of timed `mouse_click` / `mouse_down` / `mouse_up` / `mouse_move` / `key_press` / `key_down` / `key_up` / `wait` events, with an optional `scenario`. `duration_frames` is capped at 600. The game must support `-- --scenario <id>` to start a named state deterministically with seeded RNG. — [arXiv HTML Appendix A; Appendix C "Format Instruction"](https://arxiv.org/html/2606.17861)
- Tooling: Harbor, local subprocess sandbox, Xvfb (headless display), xdotool (synthetic input), ffmpeg. Agent timeout 7,200 s and verifier timeout 1,800 s. "We do not impose an explicit tool-call limit beyond the task timeout." Shared assets are Kenney CC0 packs and OpenGameArt entries, mounted read-only. A `/workspace/tools/screenshot.sh` helper is provided. — [arXiv HTML Appendix A; Appendix C](https://arxiv.org/html/2606.17861)
- Judge: "We use GPT-5.5 as the multimodal judge." Prompt: "You are a strict but fair video-game evaluator… Score every requirement on a 0.0 to 1.0 scale where 0.0 = not demonstrated at all (or contradicted), 0.5 = partially demonstrated / ambiguous, and 1.0 = clearly and unambiguously demonstrated…" It returns strict JSON with scores and one-sentence rationales. — [arXiv HTML Appendix A](https://arxiv.org/html/2606.17861)
- Rubric: four fixed categories, Core Mechanics (M*), Content Depth (D*), Functional Visuals (V*) and Art & Presentation (A*), with at most 24 items. Scenario-specific items use `max` across demos. Persistent properties (readability, feedback, art consistency, UI overlap, presentation) use `mean`. Weak evidence is capped at 0.5 "when a feature is label-only, decorative, static, disconnected from gameplay, represented only by names or colors, dominated by default widgets, or built primarily from raw programmatic shapes." The example Strategy rubric needs "real sprites or illustrated assets" for a score of 1, and gives 0 for "raw ColorRect shapes, default Godot widgets". — [arXiv HTML §3.2, §3.4, Appendix C](https://arxiv.org/html/2606.17861)
- Audio is excluded: "Do not ask for audio requirements, because the verifier scores visual evidence." — [arXiv HTML §3.4](https://arxiv.org/html/2606.17861)
- Judge reliability: in 10 repeated GPT-5.5 runs on fixed evidence (Simulation and Card game), standard deviations were 0.0037 / 0.0038 for Kimi-K2.6 and 0.0050 / 0.0036 for Opus-4.7. In the human calibration on Kimi-K2.6 submissions (Card game, Idle, Racing), human overall was 22.69 and judge 26.02 (Δ +3.32). By category: ΔM +1.92, ΔD +5.38, ΔV −5.87, ΔA +5.80. The judge is "slightly more permissive overall" but stricter on Functional Visuals. The authors call this "a calibration check rather than a definitive human-agreement study." — [arXiv HTML §5.2, Fig. 9, Table 5](https://arxiv.org/html/2606.17861)
- Category correlations: for Kimi-K2.6, Mechanics correlates with Depth at r = 0.61 and with Visuals at r = 0.53, while Art correlates with Visuals at only r = 0.11. MiMo-V2.5-Pro Art correlates with M/D/V at r = 0.56 / 0.39 / 0.26. Findings 5: "Game generation capability is partially factorized." — [arXiv HTML §5.3, Fig. 10](https://arxiv.org/html/2606.17861)
- **Failure modes and the few frequencies reported:**
  - Partial mechanics and incomplete games. Findings 1: "Agents more often produce recognizable local mechanics, but still fail to assemble them into complete, coherent interactive systems." — [arXiv HTML §4](https://arxiv.org/html/2606.17861)
  - Missing or invalid demo traces. "DeepSeek-V4-Pro often ignores or violates the demonstration-trace requirement, producing a large gap between build pass rate and valid-trace rate" (rates only in Figure 6, an image). — [arXiv HTML §4, Fig. 6](https://arxiv.org/html/2606.17861)
  - A write-first, bash-heavy loop (MiMo-V2.5-Pro). Shell commands are "56.3% of all tool calls across 140 tasks"; Read + Edit is "only 16.5%". The median is 128 tool calls per task. Score versus tool calls correlates at r = +0.016. "Of the five zero-score tasks, all produced a valid build but submitted no demo traces." — [arXiv HTML §5.1, Fig. 8](https://arxiv.org/html/2606.17861)
  - Failures that only show in rendering: "incorrect camera framing, unreadable UI, missing visual feedback, broken level layout, or demo states that fail to reveal the intended mechanic" (listed, not counted). — [arXiv HTML §5.1](https://arxiv.org/html/2606.17861)
  - Failures that only show during play (from §2.2, motivating the method rather than measured): "unresponsive controls, incorrect collisions, inactive enemies, unreachable objectives, missing UI feedback, broken state transitions". — [arXiv HTML §2.2](https://arxiv.org/html/2606.17861)

### Inferences
- The rubric strongly penalizes programmatic or placeholder art: features drawn as shapes or default widgets are capped at 0.5. Together with Art and Depth carrying 70% of the weight, this makes the benchmark a test of "shippable micro-game" polish as much as of correctness. Scores do not map directly onto "does the logic work".
- The submission contract is a reusable pattern for Godot agent workflows: deterministic `--scenario <id>` boot states, JSON input traces, and headless replay recorded with Xvfb, xdotool and ffmpeg at a fixed viewport.

### Gaps
- Build-pass rate, valid-trace rate, and demo count and duration per agent appear only in Figure 6, an image with no numeric text in the HTML. **[unverified numbers]**
- The paper gives no failure taxonomy with percentages (e.g. "X% of failures are collision bugs"). The only counted failure statistics are those listed above.
- The paper lists no per-configuration cost, token or wall-clock figures beyond the 7,200 s timeout.

## Does the paper compare harnesses or feedback types?

### Takeaway
Not in a controlled way. Each model runs in one harness, so harness and model effects cannot be separated. There is no ablation of screenshot or playtest feedback. The only feedback evidence is observational: counts of screenshot-helper use per agent, plus one qualitative case study. The paper concludes that "Rendered interaction helps agents debug failures that are not observable in source code" (Findings 2) but gives no with/without comparison.

### Cited Findings
- Configurations: "Claude Code with Opus-4.7 high and MiMo-V2.5-Pro, Codex with GPT-5.5 high and DeepSeek-V4-Pro, Kimi Code with Kimi-K2.6, and Code Buddy with GLM-5.1 and MiniMax-M2.7… under the same benchmark interface and environment." — [arXiv HTML §4](https://arxiv.org/html/2606.17861)
- Screenshot use: Kimi-K2.6 made "2,998 rendered-screen inspections, averaging 21.41 per task with a median of 19; only 4 tasks use no screenshots". Opus-4.7 "invokes the helper 1,952 times (13.94 per task)". GPT-5.5 "uses it much more sparingly, with 268 calls (1.91 per task)." Case study: Kimi on Strategy-Skirmish fixed misaligned unit placement and missing selection highlights after inspecting frames. — [arXiv HTML §5.1, Fig. 7](https://arxiv.org/html/2606.17861)
- "Visual interaction turns game generation from one-shot code synthesis into perception-guided iteration." (Findings 2) — [arXiv HTML §5.1](https://arxiv.org/html/2606.17861)
- The site leaderboard tags models as "Vision" or "Text" but does not analyze the difference. Text-only Deepseek-V4-Flash-0731 under Claude Code scores 40.61, close to vision models of the same era. — [site](https://tongxuluo.github.io/gamecraft-bench-website/)

### Inferences
- Screenshot use does not track score. GPT-5.5 used screenshots about 7× less than Opus-4.7 (1.91 versus 13.94 per task) yet scored only 1.97 points lower overall. It also scored nearly equal on Visuals (41.84 versus 42.78) and lower on Art (32.94 versus 36.86). Kimi-K2.6 used screenshots most and scored 30.65. Screenshot frequency alone is a weak predictor. This counters a strong reading of Findings 2, though the paper does not draw this conclusion.
- Two pairs share a model family across harnesses on the site, but in different versions (GLM-5.1 in Code Buddy at 18.29; GLM-5.2 in Claude Code at 39.12). This cannot be read as a harness effect.
- For harness or feedback comparisons, GameDevBench (screenshots and video raise success by about 10 points) and GameLogicBench (scaffold ablations), covered in the earlier notes, are better sources. GameCraft-Bench does not support such claims.

### Gaps
- No ablation of screenshot or video feedback, no playtesting-agent loop, and no same-model, different-harness comparison in the paper. **[not in paper]**
- Whether newer site entries changed harness settings (e.g. effort levels "xhigh") is unstated.
