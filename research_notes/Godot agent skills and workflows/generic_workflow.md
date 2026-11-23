# A generic, reusable workflow for agentic game development (Godot focus)

Research date: 2026-11-23. Method: WebSearch only. **arxiv.org could not be fetched from this session (DNS blocked by the session network policy)**, so every arXiv figure below comes from search-result snippets of the paper pages, not from reading the papers. Treat all numbers as "reported, not checked against the PDF" until someone with arxiv.org access verifies them. Several snippets disagreed on figures; conflicts are noted inline.

## What workflow patterns are claimed to generalize across genres, and with what evidence?

### Takeaway
No published framework shows evidence that one fixed workflow works across all genres. What is consistent across benchmarks, studio talks and practitioner accounts is a set of genre-independent *verification* practices: run the game, check behavior with executable, deterministic, per-tick assertions, replay recorded inputs, and keep a human acceptance gate for feel and presentation. The evidence is strongest for executable checks beating both "it compiles/runs" and VLM-judge evaluation.

### Cited Findings
**Executable, per-tick verification is the core reusable piece (2026 benchmarks)**
- SWE-Game (arXiv 2609.33678, 2026): 247 tasks on 41 executable Godot reference games, 13 gameplay categories, 2D and 3D; five task types (brief-to-game, GDD-to-game, skeleton completion, repair of 83 injected faults, Godot-to-Unity port). On human-labeled behaviors from 100 agent-built games, executable checks reached 92.59% balanced accuracy vs 78.41% for a video-based VLM judge. — [arXiv abs](https://arxiv.org/abs/2609.33678), [HF page](https://huggingface.co/papers/2609.33678) (snippet only, unverified)
- GameLogicBench (arXiv 2609.21562, NJU-LINK, 2026): 72 Godot/GDScript gameplay-logic tasks; the judge inspects game state and event history at every simulation tick, deterministically, with "no language model in the scoring path so verdicts replay exactly". Terminal-state-only scoring let mutants escape on 34 of 36 tasks in their ablation. — [arXiv](https://arxiv.org/abs/2609.21562v2), [GitHub](https://github.com/NJU-LINK/GameLogicBench) (snippet only, unverified)
- GameLogicBench: success falls for all twelve models (under Claude Code) as scope grows from isolated mechanics → interacting systems → repository-scale features. — [arXiv html](https://arxiv.org/html/2609.21562) (snippet)
- GUI Agents for Continual Game Generation / Play2Code (arXiv 2605.28258, 2026): using GUI playtester agents as feedback for codegen reached a 66.8% rubric pass rate, where frontier models generating directly struggle. — [arXiv html](https://arxiv.org/html/2605.28258v1) (snippet)

**Determinism + recorded-input replay as a test foundation (studio evidence, older but primary)**
- Riot (League of Legends determinism series, Rick Hoskinson): determinism was motivated by "a desire to create fast, repeatable tests driven from a set of recordable inputs", not by Chronobreak. They record server network traffic (the main uncontrolled input), and when replays diverge only the first divergence matters; workflow is re-run with detailed logging and diff logs. Kept alive by automation on dedicated hardware. — [Riot Tech: Introduction](https://technology.riotgames.com/node/67), [Implementation](https://technology.riotgames.com/node/68), [Fixing Divergences](https://technology.riotgames.com/node/84) (articles ca. 2017; not re-read in full here)
- Factorio uses deterministic lockstep; a replay is a list of input actions per tick; the same mechanism lets mod authors partially test multiplayer compliance without a server. Replays break when versions/mods change. — [Factorio wiki: Desynchronization](https://wiki.factorio.com/Desynchronization), [FFF #188](https://factorio.com/blog/post/fff-188), [forum thread](https://forums.factorio.com/viewtopic.php?p=461520)

**Layered automated tests in a shipping game (Rare, Sea of Thieves)**
- GDC 2019 "Automated Testing of Gameplay Features in Sea of Thieves" (Robert Masella): premise is that gameplay test automation was historically avoided due to perceived cost and flakiness; talk covers test types and appropriate coverage. — [GDC Vault](https://gdcvault.com/play/1026366/Automated-Testing-of-Gameplay-Features), [GDC news summary](https://gdconf.com/news/sea-thieves-devs-share-automated-testing-tips-gdc-2019)
- Rare: "the vast majority of the tests ... are what we call unit tests written in C++"; integration tests check that separately-unit-tested parts work together. — [Game Developer, part 4 of 4](https://gamedeveloper.com/design/how-rare-automates-testing-for-ai-and-more-in-sea-of-thieves-part-4-of-4-)
- Slide excerpt (unofficial host) claims ~10,000 tests run on TeamCity, core tests before every check-in. — [sambuz slides mirror](https://www.sambuz.com/doc/automated-testing-for-multiplayer-game-ai-automated-ppt-presentation-901544) (unverified mirror)
- The methodology was later adapted to Minecraft (separate GDC talk) — evidence the approach transfers across very different games, at least within studios with engineering capacity. — [GDC Vault](https://gdcvault.com/play/1027345/Lessons-Learned-in-Adapting-the)
- Rare's continuous delivery talk (Jafar Soltani, GDC 2018) ties automated testing to reduced crunch. — [Game Developer](https://gamedeveloper.com/production/video-adopting-continuous-delivery-to-combat-crunch-on-i-sea-of-thieves-i-)

**Agent tooling loop in Godot (practitioner, 2026)**
- Godot MCP servers expose editor/runtime APIs (edit scenes, attach scripts, run game); guides warn against hand-editing .tscn files (merge conflicts/corruption), note editor auto-reload breaking agent sessions and GDScript's loose typing raising failure rates. — [Codex CLI for game dev teams](https://codex.danielvaughan.com/2026/04/27/codex-cli-game-development-unity-godot-mcp-agent-driven-workflows/), [StraySpark Godot MCP guide](https://www.strayspark.studio/blog/godot-mcp-setup-claude-code-2026)
- Skill packs cover headless validation, testing and CLI export so the agent loop runs without the editor. — [vl4dt/godot-skills](https://github.com/vl4dt/godot-skills); a DAP-based MCP for runtime debugger access is in progress — [godot-dap-mcp-server](https://github.com/transitionmatrix/godot-dap-mcp-server)
- Practitioner claim: the decisive capability is verification, not generation — can the agent run the game, read the error or screenshot and self-correct. — [Medium, chierhu](https://chierhu.medium.com/ai-coding-tools-for-video-game-development-a-first-principles-analysis-of-what-actually-works-90dfa10edd13) (opinion)
- gdUnit4 runs headless (`godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://test`), exports JUnit XML, has a GitHub Action; v6.x requires Godot 4.5+. — [gdUnit4 GitHub](https://github.com/MikeSchulze/gdUnit4), [Asset Library](https://godotengine.org/asset-library/asset/4390)
- Golden-image pattern for Godot: wait for `RenderingServer.frame_post_draw`, capture the viewport Image, compare to a reference PNG, regenerate the reference only when a visual change is approved. Sources conflict on whether `--headless` can render frames (it uses a dummy renderer, so likely needs a real display/xvfb or software renderer — unverified). — [godot-testing-patterns skill](https://skillselion.com/skills/thedivergentai/gd-agentic-skills/godot-testing-patterns), [helpmetest CI guide](https://helpmetest.com/blog/godot-ci-cd-testing/), [GDSnap](https://godotengine.org/asset-library/asset/4018)

**Determinism in Godot specifically**
- Godot's built-in physics is float-based and not deterministic; it does not claim to be. `_physics_process` runs on fixed ticks, which removes frame-rate dependence but not float variance. — [GDQuest glossary](https://www.gdquest.com/library/glossary/deterministic_simulation), [Godot forum](https://forum.godotengine.org/t/is-it-normal-that-a-physics-simulation-with-the-exact-same-setup-can-produce-different-results/40856)
- Four usual nondeterminism sources: variable timestep, unseeded RNG, float variance, unordered iteration (sort by stable key). — [bugnet blog](https://bugnet.io/blog/how-to-debug-non-deterministic-physics-in-replay) (general, not Godot-specific)
- Options: Rapier for Godot with explicit fixed `space_step`, SG Physics (fixed-point). — [godot.rapier.rs determinism](https://godot.rapier.rs/docs/documentation/determinism), [Godot forum](https://forum.godotengine.org/t/best-way-to-make-a-deterministic-algorithm-in-godot/123754)

### Inferences
- The reusable workflow that the evidence supports is a *verification pipeline*, not a content or design process:
  1. Simulation core separated from presentation (own code, not engine physics, where determinism is needed); fixed tick; one seeded RNG owned by the simulation.
  2. Data-driven content (tables/resources) so changes are data diffs.
  3. Unit tests on rules (gdUnit4/GUT, headless).
  4. Scripted-input / recorded-input replays with per-tick state assertions or state hashes (GameLogicBench shows terminal-only checks miss most bugs; Riot shows "first divergence" debugging).
  5. Scene-per-feature playgrounds the agent can launch headless or windowed.
  6. Visual goldens for presentation, regenerated only after human approval.
  7. Human playtest/acceptance gate per vertical slice for feel, art and fun.
- Steps 1, 3, 4 and 7 are the ones with direct evidence; 2, 5, 6 are widely practiced but I found no comparative evidence they raise agent success.
- Executable checks (92.6%) beating a VLM judge (78.4%) in SWE-Game suggests agents should verify with state assertions first and screenshots second.

### Gaps
- No paper found that compares a fixed workflow across genres and measures transfer. The cross-genre claim is an inference from benchmarks spanning many families.
- Could not read the Sea of Thieves talk breakdown of test types/percentages (GDC Vault members-only).
- Official Godot docs on RandomNumberGenerator seeding and headless rendering were not retrieved.

## Which game types break the generic workflow and why?

### Takeaway
The generic workflow breaks where correctness is not a state predicate: game feel/real-time timing, physics-heavy play (engine physics is nondeterministic), visual/UI/animation work, multiplayer (determinism across machines), and long, content-heavy or narrative games (scope and coherence). Benchmarks consistently show agents do better on core mechanics than on content depth and art/presentation.

### Cited Findings
- GameCraft-Bench (arXiv 2606.17861, 2026): 140 Godot tasks over 15 game families (incl. platformer, strategy, tycoon, roguelike, visual novel); best agent Claude Code + Opus 4.7 high at 41.46%, GPT-5.5 high (Codex) 39.49%, Kimi-K2.6 30.65%. Agents consistently scored better on Core Mechanics than Content Depth or Art & Presentation; agents "can often produce runnable game-like artifacts, but they do not consistently realize the requested mechanics, content, visual state, and presentation"; more code or more commands did not help. — [arXiv abs](https://arxiv.org/abs/2606.17861), [project site](https://tongxuluo.github.io/gamecraft-bench-website/), [AI Weekly](https://aiweekly.co/alerts/claude-code-tops-ai-game-building-benchmark-at-41). Conflict: one snippet mentions a 68.44% figure without context; leaderboard numbers differ slightly between sites.
- GameDevBench (arXiv 2602.11103, 2026; Godot project-editing tasks): best agent 53.8%; worst on 2D graphics/animation (33.0%) and UI (32.0%), tasks needing image/asset understanding. — [arXiv pdf](https://arxiv.org/pdf/2602.11103) (snippet)
- Play2Code paper: GUI playtesters have imprecise timing on real-time games (especially platformers) and misread small or low-contrast UI. — [arXiv html](https://arxiv.org/html/2605.28258v1) (snippet)
- RSIGame (arXiv 2609.39045) per-family table (its own generator, not the benchmark's leaders): simulation lowest (38.1 over 6 tasks), platformer 43.3 (19 tasks), idle and sports higher. — [arXiv pdf](https://arxiv.org/pdf/2609.39045) (snippet, unverified)
- Game feel: autonomous Claude Code roguelite author — "experiential bugs are, by definition, hard to quantify. 'It feels wrong' isn't actionable for an AI agent"; a "silent death" bug was fixed with freeze frame, flash, animation and text; first calibration of feel metrics must come from a human. — summarized via search across [DEV Community](https://dev.to/yurukusa/ai-strategy-vs-human-intuition-a-bug-finding-showdown-2m82) and related posts (exact source attribution in snippet was unclear — verify)
- Godot metroidvania vibe-coding postmortem: abandoned after ~40 h; changing tile grid size broke things; agent struggled with the player controller; conclusion that agents only reach prototypes; a commenter noted genre strongly affects fit. — [Godot forum](https://forum.godotengine.org/t/post-mortem-of-my-failed-attempt-to-vibe-code-a-metroidvania-game/137567)
- 3D roguelite built with Claude Code then Codex: playable first build, but a human decided the intended feel and caught an inverted-controls bug. — [MindStudio](https://www.mindstudio.ai/blog/librarian-2-vibe-coded-3d-game/)
- Physics-heavy: Godot physics not deterministic (see above); Jolt adapter reportedly disclaims determinism (unverified). — [GDQuest](https://www.gdquest.com/library/glossary/deterministic_simulation)
- Multiplayer: replay/lockstep requires bit-identical simulation; Factorio desyncs come from engine bugs or mods, replays break across versions. Riot had to record network traffic as the uncontrolled input. — [Factorio wiki](https://wiki.factorio.com/Desynchronization), [Riot](https://technology.riotgames.com/node/68)
- UnityBench-Mini3D (arXiv 2610.35980) exists specifically for 3D Unity development, suggesting 3D is treated as a separate difficulty tier. — [arXiv pdf](https://arxiv.org/pdf/2610.35980) (title only; results not retrieved)
- Large projects (hundreds of scenes) exceed agent context; context management is the main practical limit. — [oreateai](https://learn.oreateai.com/learn/how-ai-agents-are-transforming-the-godot-engine-game-development-workflow) (low-quality source)

### Inferences
- Genre-independent: sim/presentation split, fixed tick + seeded RNG, data-driven content, unit + replay tests, playground scenes, CI, vertical slices with human acceptance.
- Genre-specific add-ons:
  - Action/platformer/game feel: needs human-tuned constants and frame-timed input scripts; GUI-agent playtesting is weak here.
  - Physics-heavy: either custom/fixed-point sim or accept non-bit-exact replays with tolerance-based assertions.
  - Multiplayer: separate netcode design (lockstep vs rollback vs server-authoritative) and multi-process tests; not covered by single-player replay.
  - Procedural generation: seeds make output reproducible, but "is this level good" needs metrics/human review (no source found on agent results here).
  - Narrative/content-heavy: dominated by Content Depth, where agents score lowest; needs content pipelines and human editorial review.
  - UI-heavy and 2D animation: lowest GameDevBench categories; golden images + human review.
  - 3D: separate benchmarks; asset/camera/lighting correctness is visual.
- Grid- or turn-based games with discrete state (e.g. Bomberman-like, puzzle, strategy) fit the generic workflow best because their rules are state predicates and determinism is cheap without engine physics.

### Gaps
- No family-level table from GameCraft-Bench or SWE-Game retrieved (arXiv blocked).
- No source on agent success at procedural generation quality or at netcode.

## What do recent papers (2024–2026) on LLM agents building games report about success rates and failure modes?

### Takeaway
Across 2025–2026 benchmarks, the best agents solve roughly 40–60% of game-building tasks; the dominant failure is code that runs but violates required behavior (omissions, wrong rules, missing content, wrong visuals), and success drops as scope grows. Multi-agent role-play frameworks (GameGPT, ChatDev-style) report hallucination and redundancy but offer little quantitative evidence.

### Cited Findings
| Benchmark | Date | Setup | Best reported | Key failure modes |
|---|---|---|---|---|
| V-GameGym (arXiv 2509.20136) | 2025 | 2,219 Pygame samples, 70 models | ~45% | visual game generation weak — [arXiv](https://arxiv.org/pdf/2509.20136) |
| GameDevBench (2602.11103) | 2026 | Godot project edits, multimodal | 53.8% | 2D graphics/animation 33%, UI 32% — [arXiv](https://arxiv.org/pdf/2602.11103) |
| OpenGame (2604.18394) | 2026 | end-to-end web games; reusable skills + code model + execution-grounded loop | n/a in snippet | base LLMs collapse to single-file HTML5/JS; logic hallucination, context drift, brittle integration — [arXiv](https://arxiv.org/html/2604.18394v1) |
| GameCraft-Bench (2606.17861) | 2026 | 140 Godot tasks, 15 families | 41.46% | runnable but mechanics/content/visuals not realized — [arXiv](https://arxiv.org/abs/2606.17861) |
| GameLogicBench (2609.21562) | 2026 | 72 Godot logic tasks, tick-level judge | 52.78% (20 model×scaffold) | 74.3% of failed scenarios run but violate behavior (version-dependent figure); scaffold matters (one model 26.4%–44.4%) — [arXiv](https://arxiv.org/abs/2609.21562v2) |
| SWE-Game (2609.33678) | 2026 | 247 tasks, 41 Godot reference games | <60/100; brief-to-game 50.38 | requirement omissions, gameplay logic errors — [arXiv](https://arxiv.org/abs/2609.33678) |
| Play2Code (2605.28258) | 2026 | GUI-playtester feedback loop | 66.8% rubric pass | timing in real-time games, small/low-contrast UI — [arXiv](https://arxiv.org/html/2605.28258v1) |
| A2Z GameSpec-Bench (2609.39564) | 2026 | games from design specs | n/a | compile and run but fail design, esp. interacting requirements — [HF](https://huggingface.co/papers/2609.39564) |

- GameGPT (arXiv 2310.08067, v1 Oct 2023, v2 Sep 2025): five-stage multi-agent pipeline (planning, task classification, code generation, execution, summarization); targets hallucination and "redundancy" (unnecessary tasks/code); preprint, not peer reviewed. — [arXiv](https://arxiv.org/abs/2310.08067v2)
- Other 2026 entries found but not read: GameXpert-Bench (2608.21833), GameASG-Bench (2609.21293), JAMER (2606.19830), GAMEGO (2610.06910), VibeGame (2610.33106), RSIGame (2609.39045). — [awesome-game-gen list](https://github.com/imclab/awesome-game-gen)
- All numbers from different benchmarks are not comparable to each other. — (note from search synthesis)

### Inferences
- Failure taxonomy that recurs: (1) requirement omission / scope drop, (2) runs-but-wrong rules, (3) cross-file/scene wiring breaks, (4) visual/UI/animation mismatch, (5) context drift over long tasks, (6) shortcutting architecture (single file). (1)–(3) are catchable by spec-derived executable tests; (4) needs goldens + human; (5)–(6) need small milestone scopes and enforced structure.
- Scaffold and verification loop matter as much as model choice (GameLogicBench scaffold spread; Play2Code playtester gain).

### Gaps
- Could not verify any figure from the PDFs; ChatDev-specific game results not found.

## How do studios structure automated testing, and which parts apply to small indie/agent projects? (plus remakes/ports)

### Takeaway
Studios use a pyramid: many fast unit tests, fewer integration/"actor"/level tests, deterministic replay of recorded inputs, bots for balance/soak, and human QA. A small agent project can keep the cheap parts (unit, replay with state hashes, CI gate per commit, goldens) and skip RL bots and large device farms. Remakes/ports are the best case for agents because the original is an oracle for differential testing.

### Cited Findings
- Rare: majority unit tests; integration tests; core suite before every check-in; adopted for Minecraft. — [Game Developer](https://gamedeveloper.com/design/how-rare-automates-testing-for-ai-and-more-in-sea-of-thieves-part-4-of-4-), [GDC Vault Minecraft talk](https://gdcvault.com/play/1027345/Lessons-Learned-in-Adapting-the)
- Riot: record/playback/validate real games; determinism kept by automated runs on dedicated hardware. — [Riot](https://technology.riotgames.com/node/84)
- Ubisoft La Forge: bots that let designers set parameters and test balance overnight; Rainbow Six Siege "Operation: Bots" with RL. — [Ubisoft La Forge](https://montreal.ubisoft.com/en/artificial-intelligence-through-learning-or-pavlovian-algorithm/), [Ubisoft News](https://news.ubisoft.com/en-us/article/1MlKnolSLJFuJDnATWiorr)
- EA SEED (CoG 2023): technical challenges of deploying RL agents for AAA game testing. — [arXiv 2307.11105](https://arxiv.org/abs/2307.11105), [EA SEED](https://ea.com/seed/news/cog23-challenges-deploying-rl-agents-game-testing)
- Remakes/ports with oracle: momo5502 used agents to decompile an FPS with a byte-match script against the original EXE as oracle (relocations handled), removing the need for an agent reviewer step. — [momo5502, 2026-10-09](https://momo5502.com/posts/2026-10-09-game-decompilation/)
- Matching decompilation proves recovered source reproduces original bytes; static recompilation translates without recovering idiomatic algorithms — different guarantees. — [Retro Reversing](https://www.retroreversing.com/ai-assisted-decompilation)
- Behavioral differential testing: every step compared with recorded behavior of the original so the agent "cannot drift"; example of a DX-Ball sound function matching 3,205 original x86 test cases (one function, not the game). — [awesome-reverse-engineer-anything](https://github.com/AIshihzong/awesome-reverse-engineer-anything) (curated secondary list)
- Non-game analogue: GitHub's Copilot agent runtime TS→Rust port ran all existing e2e tests at every step (in-place atomic replacement). — [AgentPatterns.ai](https://agentpatterns.ai/workflows/in-place-atomic-replacement-port/)
- SWE-Game includes Godot→Unity porting as a task type, i.e. porting is now benchmarked. — [arXiv](https://arxiv.org/abs/2609.33678)

### Inferences
- Indie/agent subset: unit tests (headless gdUnit4/GUT) → scripted/recorded-input replays with per-tick state hashes → scene playgrounds → golden screenshots (human-approved baselines) → human playtest per slice; CI runs the first two on every commit. Bots/RL and soak farms are optional.
- For a remake/port (the bomb-it-5 case: original SWF available), the oracle turns UI/art/timing from taste questions into comparison questions: extract positions/timings from source data, compare traces of the original against the port, and reserve human review for what the oracle cannot express (feel, cross-platform rendering differences). The oracle still does not answer "is it fun", but that was settled by the original.
- Byte-exact matching is usually unavailable for an AS3→GDScript port; behavioral traces (input → state sequence) are the realistic oracle, which requires instrumenting or emulating the original.

### Gaps
- No source on agentic ports from Flash/AS3 specifically.
- No published small-team case study measuring the cost/benefit of replay tests vs. unit tests for agent work.
