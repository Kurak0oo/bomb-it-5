# GameDevBench and peer game-building benchmarks: primary-source check

Research date: 2026-11-24. Method: fetched arXiv abstract pages (`arxiv.org/abs/<id>`) and full HTML (`arxiv.org/html/<id>v<n>`) through the session proxy, converted to text and read the relevant sections and tables. Also fetched the ICML 2026 poster page, the PMLR v306 page and the GameDevBench GitHub README. Versions read:

| Paper | arXiv ID | Version read | Engine / runtime |
|---|---|---|---|
| GameDevBench | 2602.11103 | v2 (30 Jun 2026); v1 (11 Feb 2026) for comparison | Godot 4 (README pins 4.4.1) |
| SWE-Game | 2609.33678 | v3 (7 Oct 2026) | Godot, plus Unity for the porting task |
| GameLogicBench | 2609.21562 | v2 (21 Sep 2026) | Godot 4.4 / GDScript |
| GameCraft-Bench | 2606.17861 | v1 (16 Jun 2026) | Godot |
| CEGame-Bench | 2610.26098 | v2 (20 Nov 2026) | Defold, Godot, Roblox Studio, Unity, Unreal Engine |
| WebGameBench | 2605.17637 | v2 (21 May 2026) | Browser (stack not fixed) |
| OpenGame | 2604.18394 | v2 (15 Sep 2026) | Web, Phaser 3 |
| V-GameGym | 2509.20136 | v1 (24 Sep 2025) | Python / Pygame |

All IDs in the earlier notes resolve to the paper titles they claimed. Earlier notes relied on search snippets; the corrections are listed under each question.

## GameDevBench: ID, venue, task count, headline, categories, feedback gain, models and harnesses

### Takeaway
GameDevBench is arXiv 2602.11103, published at ICML 2026 (PMLR 306:19395–19423). The camera-ready (arXiv v2) has 333 Godot tasks. The headline 53.8% is **Gemini 3 Pro in gemini-cli with screenshot and video feedback**, not a GPT or Claude run. The skill-category figures (gameplay 51.4%, 2D graphics/animation 33.0%, UI 32.0%, 3D 38.4%) are verified, but they are averages over 8 agent configurations, not the best agent's scores. The "~10-point" feedback gain is GPT-5.4's 41.1% → 52.0% (+10.9 pp), the largest gain in the paper, not a typical one. The paper has no per-genre breakdown.

### Cited Findings
**Identity and versions**
- Title "GameDevBench: Evaluating Agentic Capabilities Through Game Development"; v1 submitted 11 Feb 2026, v2 on 30 Jun 2026. — [arXiv abs](https://arxiv.org/abs/2602.11103)
- Published in "Proceedings of the 43rd International Conference on Machine Learning, PMLR 306:19395-19423, 2026"; its abstract says 333 tasks and 53.8%. — [PMLR](https://proceedings.mlr.press/v306/chi26a.html); [ICML poster page](https://icml.cc/virtual/2026/poster/64919)
- v1: "GameDevBench consists of 132 tasks"; best agent with feedback 54.5% (Gemini 3 Pro, screenshot+video, Table 2); "without additional support, the best agent succeeds at only 47.0%"; gameplay 46.9% vs 2D graphics 31.6%. v1 task mix: 35.6% gameplay logic, 25.7% 3D, 19.7% 2D, 15.9% UI. — [arXiv v1 HTML](https://arxiv.org/html/2602.11103v1)
- v2: "GameDevBench consists of 333 tasks derived from web and video tutorials"; mix 33.3% 2D graphics and animation, 26.7% 3D graphics and animation, 20.1% UI, 19.8% gameplay logic (Table 1, §3.2). Reference solutions average 4.7 files, 114.1 lines, 3.2 file types. — [arXiv v2 HTML](https://arxiv.org/html/2602.11103v2)
- v2 Appendix H, Table 4 splits "Core" tasks (built by the tutorial pipeline) from "Full" tasks (core plus variants "designed to explicitly test for multimodal understanding"). The headline numbers are the Full pass@1. — [arXiv v2 HTML](https://arxiv.org/html/2602.11103v2)
- Tasks come from Godot 4 tutorials: 57 YouTube video tutorials and 31 top-ranked KidsCanCode "Godot Recipes" pages, turned into tasks by Codex with GPT-5-family models. Grading uses Godot's testing framework (deterministic unit tests, e.g. "if objects are in view of the camera or if object colliders have interacted"). — [arXiv v2 §2, §3.2](https://arxiv.org/html/2602.11103v2)

**Headline and models/harnesses (v2 Table 2, Full pass@1 %)**
- Harnesses: "claude-code for Claude models, gemini-cli for Gemini models, and codex for ChatGPT models"; Kimi K2.5 and Qwen3.5-397B via OpenHands; Haiku 4.5, Gemini 3 Flash and GPT-5.4 Mini also run in OpenHands for comparison. — [arXiv v2 §4](https://arxiv.org/html/2602.11103v2)
- Baseline → with screenshot MCP + video, native harness: Claude Haiku 4.5 13.8 → 16.5; Claude Sonnet 4.5 28.8 → 34.8; GPT-5.4 Mini 36.9 → 39.0; GPT-5.4 41.1 → 52.0; Gemini 3 Flash 45.4 → 44.1; **Gemini 3 Pro 50.1 → 53.8 (best)**. OpenHands: Haiku 15.6 → 17.7; GPT-5.4 Mini 38.4 → 36.9; Gemini 3 Flash 30.3 → 31.8; Kimi K2.5 18.9 → 20.7; Qwen3.5-397B 5.4 → 5.1. — [arXiv v2 Table 2](https://arxiv.org/html/2602.11103v2)
- Single-feedback ablations: GPT-5.4 Mini screenshot-only 37.8, video-only 43.2; Haiku screenshot-only 15.6, video-only 18.6; Gemini 3 Flash 45.4 / 46.9. "Surprisingly, video runtime often provides more improvement than enabling both forms of multimodal feedback." — [arXiv v2 Table 2, §4](https://arxiv.org/html/2602.11103v2)
- "GPT-5.4 increases from 41.1% to 52.0% pass@1, a 10.9 percentage-point gain and a 26.5% relative improvement." Exceptions to the gain: GPT-5.4 Mini in OpenHands and Gemini 3 Flash, which "marginally decreases". — [arXiv v2 §4, §6](https://arxiv.org/html/2602.11103v2)
- The two feedback tools: an MCP server that opens the Godot editor and returns a screenshot, and instructions for recording gameplay video with Godot's built-in recording ("otherwise frequently ignored or misused"). Models "typically" turn videos into frames with Python. — [arXiv v2 §4](https://arxiv.org/html/2602.11103v2)
- Core-set pass@1 (Table 4) is higher. Best core score is GPT-5.4 + feedback at 56.5 vs Gemini 3 Pro + feedback at 54.5: "GPT-5.4 and Gemini 3 Pro swap first and second place". — [arXiv v2 Appendix H.1](https://arxiv.org/html/2602.11103v2)

**Per-category results**
- "agents perform best at gameplay logic tasks (51.4%) and worst at 2D graphics and animation (33.0%) and UI (32.0%) tasks ... 3D graphics (38.4%) sit in between (scores are averages computed across the 8 agents in their native agentic harness with multimodal feedback enabled)." — [arXiv v2 §4](https://arxiv.org/html/2602.11103v2)
- Editor-type axis (scene, script, contextual editors): the stronger agents (GPT-5.4 Mini, GPT-5.4, Gemini 3 Pro/Flash, Claude Sonnet 4.5) "maintain similar success across all editors"; Haiku 4.5, Kimi K2.5 and Qwen3.5-397B "drop sharply on the more multimodally demanding contextual and scene editors." — [arXiv v2 §4](https://arxiv.org/html/2602.11103v2)
- Easy/hard split (Appendix H.2, Table 5): almost every configuration does worse on the hard subset (e.g. GPT-5.4 Mini baseline 51.9 easy vs 27.2 hard; Sonnet 4.5 + feedback 46.6 vs 27.2). The only exception is Gemini 3 Pro. — [arXiv v2 Table 5](https://arxiv.org/html/2602.11103v2)
- The paper reports no per-genre results. Tasks are classified by skill and editor only; genre appears only in examples such as a platformer tutorial split into animation, controls and tilemap tasks. — [arXiv v2 §2–3](https://arxiv.org/html/2602.11103v2)

**Post-paper leaderboard (repo, not peer reviewed)**
- README: "Claude Opus 5.5 achieves 70.6% (xhigh) and 68.2% (high)"; "GPT-6.1 Sol (xhigh) achieves 70.0%"; "GPT 6 Astra (High) passes 229/333 tasks (68.8%) using Codex with runtime-video and strict confinement". Leaderboard runs require Godot 4.4.1 exactly. — [GitHub README](https://raw.githubusercontent.com/waynchi/gamedevbench/HEAD/README.md)
- Conflict: the README's copy of the abstract says the best agent solves "**63.7%**", while the paper, ICML and PMLR all say 53.8%. — [GitHub README](https://raw.githubusercontent.com/waynchi/gamedevbench/HEAD/README.md) vs [PMLR](https://proceedings.mlr.press/v306/chi26a.html)

### Inferences
- Corrections to the earlier notes and report:
  - "Best agent 53.8%" is right, but the configuration is Gemini 3 Pro + screenshot + video in gemini-cli. GPT-5.4 + feedback is second at 52.0.
  - "UI 32%, 2D 33%, gameplay ~51%" is right, but these are 8-agent averages, not the best agent's per-category scores. Reading them as "the best agent scores 32% on UI" is wrong.
  - "~10 points from feedback" holds only for GPT-5.4 (+10.9). Sonnet 4.5 gained 6.0, Gemini 3 Pro 3.7, Haiku 2.7, and Gemini 3 Flash lost 1.3. "Roughly ten points" overstates the typical gain.
  - Task counts: 132 (v1) and 333 (v2/ICML) are verified; the 358-task version is not (see Gaps).
- For a 2D, UI-heavy remake like this project, GameDevBench's weakest categories (2D graphics/animation and UI) are the dominant work, and its tests check engine state (camera visibility, collider contact) rather than pixels. That matches a node-level comparison against reference data.

### Gaps
- "358 tasks (best baseline 49.0%)" from the earlier competitions note appears in neither arXiv v1 (132) nor v2 (333). It may come from OpenReview or an intermediate leaderboard; I could not verify it.
- "Claude Sonnet 4.5 from 34.4% to 44.7% in an earlier version" matches neither v1 (claude-code 33.3 → 46.2; OpenHands 43.2 → 51.1) nor v2 (28.8 → 34.8). It is unverified and likely wrong.
- Per-model, per-category numbers appear only in Figure 5 (an image), which I did not extract. The text gives only 8-agent averages.

## SWE-Game: executable checks vs VLM judge, scores, categories, porting

### Takeaway
All the claimed numbers check out in v3: executable checks reach 92.59% balanced accuracy against approximately 78.41% for a video VLM judge (Table 5), the best construction score is below 60/100, and Brief-to-Game is 50.38. The best model is "Opus5" on every task type. The paper reports no per-category (13 gameplay categories) results. Godot-to-Unity porting is the one benchmarked port task.

### Cited Findings
- "247 tasks grounded in 41 executable reference Godot games spanning 13 gameplay categories in 2D and 3D." Five task types: Brief-to-Game, GDD-to-Game, Skeleton Completion, Bug Repair (83 injected-fault cases) and Godot-to-Unity Porting; each non-repair type has 41 tasks. — [arXiv 2609.33678v3 abstract, §1](https://arxiv.org/html/2609.33678v3)
- Models: Qwen3.8 Flash, Grok4.6, GPT-5.6 Luna, Opus5, GLM5.3 Flash and Minimax M3, "each with its own agent framework and tools". The paper does not name the frameworks in the main text, and its limitations section notes that "Each model is evaluated with a single agent framework". — [§4.1, §6](https://arxiv.org/html/2609.33678v3)
- Table 3 totals (0–100) for Opus5: Brief-to-Game 50.38, GDD-to-Game 59.68, Skeleton Completion 54.06, Bug Repair 83.46, Porting 72.40. Runner-up: Grok4.6 on Brief-to-Game (39.01); GPT-5.6 Luna on the other four (52.67, 43.10, 58.05, 59.85). — [Table 3](https://arxiv.org/html/2609.33678v3)
- Mechanics is the weakest component everywhere. Opus5 scores Mechanics 27.55 / Content 48.26 / Playability 80.99 / VLM 69.23 on Brief-to-Game, and in Skeleton Completion "Content scores range from 11.97 to 36.93". — [Table 3, §4.2](https://arxiv.org/html/2609.33678v3)
- Porting (Godot → Unity): Opus5 Mechanics 70.66, Playability 65.88, Structure 90.53, Visual 58.40, Stability 88.60, Total 72.40. GPT-5.6 Luna: Structure 82.87, Playability 51.44, Visual 31.60. "GPT-5.6 Luna and Opus5 score higher in Structure than in Playability and Visual." — [Table 3, §4.2](https://arxiv.org/html/2609.33678v3)
- Validity (Table 5): "Executable checks correctly accept 411/452 correct assertions and detect 705/748 defective ones, achieving 92.59% balanced accuracy versus approximately 78.41% for the video-based VLM judge, with an 18.85-percentage-point advantage in defect detection" (defect detection 94.25 vs 75.40; correct acceptance 90.93 vs 81.41). The sample is 1,200 human-labeled assertions from 100 games under Modes 1–3. — [§4.5, Table 5](https://arxiv.org/html/2609.33678v3)
- The visual rubric VLM correlates with human ratings of 200 clips at Spearman ρ = 0.829 (MAE 0.103); "These results support assigning behavioral correctness to executable checks and perceptual quality to the visual rubric." — [§4.5](https://arxiv.org/html/2609.33678v3)
- Errors: "Requirement omissions are the most common category for GPT and Opus, accounting for 56.4% and 36.9% of their categorized problems"; for GLM, "gameplay logic errors are the largest category, at 52.2%". — [§4.3](https://arxiv.org/html/2609.33678v3)
- Reference-video ablation (Table 4): giving the agent the reference gameplay video raised the VLM total by 5.60 (GPT-5.6 Luna) and 2.23 (Opus5). Content Composition fell with video for both, by 6.01 and 9.93. "The consistent gain is therefore in presentation." — [§4.4](https://arxiv.org/html/2609.33678v3)
- Reference matching: construction Mechanics includes "certified routes that replay reference inputs" authored and validated on the reference game, plus matched no-input controls. Repair runs the same scenarios on reference, faulty and repaired versions. — [§3, Table 3 note](https://arxiv.org/html/2609.33678v3)
- Table 6 lists the 41 reference games by category (24 2D games, e.g. Shooting, Puzzle, Sports), but no table reports scores by category. — [Table 6](https://arxiv.org/html/2609.33678v3)

### Inferences
- The "92.6% vs 78.4%" and "<60/100" claims are verified. The "executable beats VLM by ~14 points" line in the earlier report is accurate for balanced accuracy (14.18 pp). On defect detection, the most relevant measure for catching bugs, the gap is 18.85 pp.
- SWE-Game is the closest benchmark to this project's setting: an executable reference game, replayed reference inputs and engine-state probes. Its port task shows agents get structure right well before playability and visuals.

### Gaps
- No per-gameplay-category scores were found, so a per-genre view is unavailable.
- The agent frameworks per model are not named in the main text. Appendix E may name them; I did not read it.

## GameLogicBench: terminal-state checks, 52.78%, scaffolds, genres

### Takeaway
The figures are verified in v2, but the "34 of 36" claim needs precise wording. In a 36-task audit set, terminal-state-only scoring let *at least one* mutant escape on 34 of 36 tasks. Overall, 236/666 mutants (35.4%) escaped, and solve rates were inflated by +8.9%. It does not mean that final-state checks "missed bugs on 34 of 36 tasks" in a blanket sense. The best run (Claude-Opus-5 in Claude Code) scores 52.78%. The library spans twelve genres but reports results by tier and capability class, not by genre.

### Cited Findings
- "72 gameplay-logic tasks in Godot projects ... 403 hand-designed scenarios, seeded parameter variations produce 1,451 test cases". The evaluator checks rules "at every simulation tick"; "no language model in the scoring path, replaying the same submission, scenario, and seed produces the same verdict." — [arXiv 2609.21562v2 abstract, §3](https://arxiv.org/html/2609.21562v2)
- Scaffolds: Claude Code 2.1.177, Codex 0.144.1, OpenCode 1.17.18; Godot 4.4; effort=high; 3,600 s limit. — [§4](https://arxiv.org/html/2609.21562v2)
- Table 3 (solve %, Atom / Combo / Repo / Average): Claude Code + Claude-Opus-5 61.90 / 53.57 / 43.48 / **52.78**; Qwen-3.8-Max 44.44; GPT-5.6-Sol 41.67; DeepSeek-V4-Pro-0813 41.67; GLM-5.2 37.50; Kimi-K3 36.11; Claude-Sonnet-5 25.00 (Repo 8.70). Under Codex: GPT-5.6-Sol 34.72, Qwen-3.8-Max 26.39. Under OpenCode: GPT-5.6-Sol 34.72, Qwen-3.8-Max 29.17. — [Table 3](https://arxiv.org/html/2609.21562v2)
- "Qwen-3.8-Max's solve rate ranges from 26.39% to 44.44% across the three scaffolds"; "Claude Code yields the highest solve rate for every model". — [§4](https://arxiv.org/html/2609.21562v2)
- "mechanism failures account for 74.3% of failed scenarios" (runs and is judgeable but violates a behavioral contract); 17.2% have no judgeable solution; 8.5% are nonviable. The Engine-contract capability class has the highest pooled strict pass rate (88.75%); Commitment, Spatial and Timing are the bottom three (53.4%–58.57%). — [§4](https://arxiv.org/html/2609.21562v2)
- Table 5 (36-task audit set): Terminal-only lets 236/666 (35.4%) mutants escape, with escapes on 34/36 tasks, 64/488 (13.1%) FAIL→PASS solutions and a mean solve-rate inflation of +8.9%. Preview-only: 508/666 (76.3%), 36/36, 418/488, +58.1%. Without mutant validation, "127 of 666 mutants passed, revealing 24 missing checks across 19 of the 36 tasks." — [Table 5, §5](https://arxiv.org/html/2609.21562v2)
- "The 72-task library spans twelve game genres", but it is organized "by functional capability rather than genre"; "a genre with no task is not a gap, whereas a capability with no task is." — [§3, appendix](https://arxiv.org/html/2609.21562v2)
- Contamination: "agents copying code from the original public repositories when network access is open"; main runs use "egress sealed". — [abstract (v2 wording), Table 3 caption](https://arxiv.org/html/2609.21562v2)
- Its no-regression reference stores numbers from the original upstream code on the same scenarios. "Differential execution ... is used only during construction ... and never for scoring", because it "would kill implementation freedoms the specification allows". — [appendix](https://arxiv.org/html/2609.21562v2)

### Inferences
- The earlier report's sentence "checking only the terminal state let injected faults escape on 34 of 36 tasks" is literally correct, but the earlier generic_workflow note's "terminal-only checks miss most bugs" overstates it. About a third of mutants escaped (35.4%), and the inflation on real agent submissions was +8.9%.
- The 74.3% figure is consistent in v2 (abstract area and §4). The earlier "version-dependent" caveat can be dropped for v2.
- For a remake, the authors' choice not to score by differential execution is a design difference worth noting. They want freedom of implementation, whereas a faithful port wants exactly the reference behavior.

### Gaps
- No per-genre solve rates. Figure 4 shows genre composition only, as an image.
- v1 was not read separately; v2 followed v1 by three days with an identical file size.

## GameCraft-Bench (cited in the earlier report): verification and per-family results

### Takeaway
Verified in v1: 140 Godot tasks in 15 families. The best agent is Claude Code + Opus-4.7 high at 41.46% (Mechanics 55.34, Depth 39.48, Visuals 42.78, Art 36.86). The judge is GPT-5.5. Per-family results exist (Appendix B, Table 6).

### Cited Findings
- Table 4 (overall / Mechanics / Depth / Visuals / Art): Claude Code + Opus-4.7 high 41.46 / 55.34 / 39.48 / 42.78 / 36.86; Codex + GPT-5.5 high 39.49 / 54.36 / 38.61 / 41.84 / 32.94; Kimi Code + Kimi-K2.6 30.65; Claude Code + MiMo-V2.5-Pro 24.10; Code Buddy + GLM-5.1 18.29; MiniMax-M2.7 10.95; Codex + DeepSeek-V4-Pro 2.15. — [arXiv 2606.17861v1 Table 4](https://arxiv.org/html/2606.17861v1)
- "We use GPT-5.5 as the multimodal judge." The build check is `godot --headless --path /workspace/game --quit-after 5`, and the score is multiplied by BUILD. — [Appendix A, example rubric](https://arxiv.org/html/2606.17861v1)
- Task counts per family: Platformer 19, Strategy 17, Tycoon 16, Open-world 15, Roguelike 14, Visual novel 11, Puzzle 8, Shooter 7, Simulation 6, Card game 5, Horror 5, Rhythm 5, Idle 4, Racing 4, Sports 4. — [Table 3](https://arxiv.org/html/2606.17861v1)
- Family-level overall for Opus-4.7 high (Table 6): Platformer 36.57, Strategy 44.73, Tycoon 36.45, Open-world 40.80, Roguelike 40.10, Visual novel 43.60, Puzzle 35.87, Shooter 40.28, Simulation 38.29, **Card game 33.78 (lowest)**, Horror 57.30, Rhythm 46.57, Idle 56.99, Racing 45.26, Sports 48.24. For GPT-5.5 high: Platformer 37.26, Puzzle 46.80, Card game 25.50 (lowest), Idle 64.91 (highest). — [Appendix B, Table 6](https://arxiv.org/html/2606.17861v1)
- Opus-4.7 Functional Visuals by family: Strategy 62.60 but Card game 18.48, Idle 23.12, Racing 23.15 and Rhythm 24.70; Platformer Art 29.55. — [Table 6](https://arxiv.org/html/2606.17861v1)

### Inferences
- The earlier report's GameCraft figures are verified. The "68.44%" figure from one earlier snippet does not appear in the v1 text; treat it as unsupported.
- Genre effects are real but noisy: families with 4–5 tasks (Idle, Horror, Card game) produce both the highest and lowest scores. Families with many tasks (Platformer, Strategy, Tycoon) cluster around 36–45.

### Gaps
- Small family sizes make per-family differences statistically weak; the paper reports no confidence intervals per family.

## CEGame-Bench: multi-engine long-horizon creation (previously unverified)

### Takeaway
CEGame-Bench (arXiv 2610.26098, v2 20 Nov 2026) is verified: 10 tasks on each of five engines, built from an empty project and a design document. Agents earn most integration points but under half the gameplay points, and only 16% of runs reach the ending. **Godot is the engine where the least of the build turns into playable game**: the gameplay-point share is 23% on Godot vs 57% on Unity. In same-game swaps, the heavyweight engines (Unity, Unreal) beat Godot by about 10–22 F points, because they check more before play.

### Cited Findings
- "the first long-horizon benchmark for complete-game creation across five production engines: Defold, Godot, Roblox Studio, Unity, and Unreal Engine"; "runs averaging up to 295 steps and 65M tokens"; "games reach the ending in only 16% of runs". The Game Completion Boost skill "raises the execution-based score of three models by 14.1-24.3 points". — [arXiv abs](https://arxiv.org/abs/2610.26098)
- Configurations: Codex CLI with GPT-6 Astra, GPT-5.6 Sol, GPT-5.6 Terra and DeepSeek-V4-Pro; DeepSeek Harness with DeepSeek-V4-Pro; Claude Code with Claude Opus 5; Kimi Code with Kimi K3. Three runs per game; 1,050 runs total. — [§5.1](https://arxiv.org/html/2610.26098v2)
- Table 2, Godot track F (out of 90): GPT-6 Astra 49.8; DeepSeek Harness/V4-Pro 35.4; Codex/V4-Pro 34.2; GPT-5.6 Sol 21.5; **Claude Code + Opus 5 21.4**; GPT-5.6 Terra 16.4; Kimi K3 14.5. All-engine F: GPT-6 Astra 65.0, GPT-5.6 Sol 41.0, Claude Opus 5 38.3. — [Table 2](https://arxiv.org/html/2610.26098v2)
- "the references that engineers built with coding agents are all solved and average 87.3 of 90 on F ... against 65.0 for the best autonomous configuration"; "the share of gameplay points runs from 23% on Godot to 57% on Unity". — [§5.2](https://arxiv.org/html/2610.26098v2)
- Failure stage by capability third: the lowest third fails mostly on completeness (D2), the middle on mechanics (D3), the top on lifecycle (D4: "transitions, restarts, or reopening"). — [§5.2](https://arxiv.org/html/2610.26098v2)
- Same-game swaps (Table 3): Unity leads Godot by +10.4 ± 3.1 F and Unreal leads Godot by +21.5 ± 15.8. "the advantage is widest against Defold and Godot, whose dynamically typed scripts fail only at run time". — [§5.3, Table 3](https://arxiv.org/html/2610.26098v2)
- "No two engines rank configurations alike (Kendall's tau 0.14-0.62)"; "A single-engine leaderboard therefore ranks configurations for that engine alone." — [§5.3](https://arxiv.org/html/2610.26098v2)
- "playing and viewing the game take at most 13.3% of any configuration's steps"; "Kimi Code never plays or views its game". — [§5.3–5.4](https://arxiv.org/html/2610.26098v2)
- GCB under Codex CLI (Table 4, 15 games): DeepSeek-V4-Pro F 50.6 → 71.6 (+21.0); GPT-5.6 Sol 27.0 → 41.1 (+14.1). — [Table 4](https://arxiv.org/html/2610.26098v2)
- Figure 2 shows genre coverage, but the main text reports no per-genre scores. — [§3](https://arxiv.org/html/2610.26098v2)

### Inferences
- This is the strongest evidence that Godot specifically needs extra runtime checking. Its type and scene errors surface only at run time, so an agent workflow on Godot should run the game, and assert on it, more than one on Unity would.
- The Godot result for Claude Code + Opus 5 (21.4/90) is weak relative to its other engines (Unity 60.5). That is a warning against inferring Godot ability from cross-engine averages.

### Gaps
- Per-genre results are not in the main text; the appendix tables (16–19) were only partly checked.

## WebGameBench, OpenGame, V-GameGym

### Takeaway
All three are verified, and none uses Godot. WebGameBench: best usable rate 76.9% but excellent rate only 20.2% (Opus 4.7). OpenGame: best scores BH 72.4 / VU 67.2 / IA 65.1 with Sonnet 4.6, and a per-genre IA breakdown (Platformer 76.8 down to Puzzle/UI 52.6). Its "base models fall back to a single HTML file" is a qualitative statement, not a measured result. V-GameGym: GPT-5 tops 70 models at 45.0 on single-file Pygame generation; it is a code-LLM benchmark, not an agent benchmark.

### Cited Findings
**WebGameBench (2605.17637v2)**
- "Across 111 tasks, 12 coding agents, and 14 evaluation configurations ... the best configuration reaches a 76.9% usable rate but only a 20.2% excellent rate." The runtime evaluator is Codex CLI 0.115.0 with `gpt-5.4-agent` at XHigh, driving Chrome via Playwright. — [arXiv abs](https://arxiv.org/abs/2605.17637); [§3](https://arxiv.org/html/2605.17637v2)
- Table 1 (usable rate): opus-4-7 76.9 (excellent 20.2), opus-4-6 73.0, gpt-5-5 63.6, gemini-3.1-pro 63.6, kimi-k2.6 61.0, sonnet-4-5 47.1, kimi-k2.5 38.3. On the hardest D4 specs, opus-4-7 manages 3/6 usable and most configurations 0–2/7. — [Table 1](https://arxiv.org/html/2605.17637v2)
- Agreement with humans on usable vs unusable: 66.7% (Medium), 82.1% (High) and 85.0% (XHigh) accuracy; exact three-way agreement under XHigh is only 50.0%. — [§4.3](https://arxiv.org/html/2605.17637v2)
- Seven mechanic families are defined (Puzzle/Matching, Action/Arcade/Platform, Shooting/Combat, etc.), but no per-family results table was found. The specification "does not specify a concrete technology stack". — [§3, Appendix A](https://arxiv.org/html/2605.17637v2)

**OpenGame (2604.18394v2)**
- "A common failure mode in AI game generation is that base LLMs bypass multi-file software engineering by defaulting to single-file vanilla HTML5/JavaScript implementations." Baselines were therefore instructed to use Phaser 3. — [§4.1](https://arxiv.org/html/2604.18394v2)
- OpenGame-Bench: 150 prompts across five genres; Build Health, Visual Usability and Intent Alignment are scored by headless browser plus VLM judge. Best: OpenGame + Claude Sonnet 4.6 at BH 72.4, VU 67.2, IA 65.1, beating Cursor + Sonnet 4.6 by 5.6 / 5.8 / 6.2. — [§4, Table 1](https://arxiv.org/html/2604.18394v2)
- Per-genre IA: Platformers 76.8, Top-Down Shooters 71.4, Arcade 66.5, Strategy 58.2, Puzzle/UI 52.6. "When logic desynchronizes, the resulting failures are often silent, triggering neither compiler warnings nor runtime crashes." — [§4.5](https://arxiv.org/html/2604.18394v2)
- The debug-iteration ablation: zero-shot (T=0) Build Health 58.4, with the "steepest gains occurring between T=0 and T=3". — [§4.4](https://arxiv.org/html/2604.18394v2)

**V-GameGym (2509.20136v1)**
- "2,219 high-quality samples across 100 thematic clusters derived from real-world Pygame repositories"; "GPT-5 topping the list at 45.0 points"; 70 models; "All models perform strongly in code generation (most over 70 points) but are generally weaker in image and video evaluation (most under 25 points)". — [arXiv abs](https://arxiv.org/abs/2509.20136); [§4, Table 2](https://arxiv.org/html/2509.20136v1)
- Dataset genres: arcade 47.3%, shooter 17.7%, other 23.7% (Figure 30). No per-genre score table was found. — [Appendix](https://arxiv.org/html/2509.20136v1)

### Inferences
- OpenGame is the only peer with an explicit per-genre score breakdown. It agrees with GameDevBench and GameCraft that UI- and logic-abstract games (Puzzle/UI) score lowest on intent, because their failures are silent.
- The earlier table's "~45%" for V-GameGym is correct, but it measures single-file Pygame code generation, not agents. It is not comparable with the agent benchmarks.

### Gaps
- OpenGame's single-HTML fallback is asserted, not quantified (no rate reported).
- The genre chart for OpenGame is labeled "Figure 4" in the HTML, the same number as the debug-iteration figure. This is a numbering inconsistency in the source.

## Remakes, ports and reference-matching

### Takeaway
No paper benchmarks remaking a game from a non-Godot original such as a Flash/SWF game. The closest evidence: SWE-Game's Godot-to-Unity porting (Opus5 72.40/100; structure far ahead of visuals) and its certified reference-input replay; CEGame-Bench's same-game cross-engine swaps; and GameLogicBench's upstream-reference numbers and its finding that agents copy original public code when the network is open.

### Cited Findings
- SWE-Game porting supplies "the Godot source, GDD, assets, reference video, and a target Unity interface" and requires a buildable Unity project that preserves controls and mechanics. Results: Structure 90.53 > Mechanics 70.66 > Playability 65.88 > Visual 58.40 for Opus5. — [arXiv 2609.33678v3 §3, Table 3](https://arxiv.org/html/2609.33678v3)
- The SWE-Game limitations call porting "an initial study of engine migration". — [§6](https://arxiv.org/html/2609.33678v3)
- CEGame-Bench rebuilds the same games on another engine; same game, different engine moves F by +10.4 to +21.5 against Godot. — [arXiv 2610.26098v2 Table 3](https://arxiv.org/html/2610.26098v2)
- GameLogicBench uses stored outputs of the upstream original as a no-regression reference, and deliberately avoids scoring by differential execution against the original. — [arXiv 2609.21562v2 appendix](https://arxiv.org/html/2609.21562v2)
- In SWE-Game, giving agents the reference video improved presentation scores, not mechanics or content. — [Table 4](https://arxiv.org/html/2609.33678v3)

### Inferences
- For a faithful remake, the evidence supports the same ordering as this project's comparison loop. Agents reach structural parity first. Behavior is best checked by replaying reference inputs against engine state. Visual parity lags most, and vision-model judges are the weakest arbiter of behavior.

### Gaps
- No benchmark covers Flash/AS3 → any engine ports, line-by-line ports, or pixel or node-level parity against an original's display list.
