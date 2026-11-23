# Godot AI-agent tooling ecosystem (state as of 2026-11-23)

Scope: MCP servers, skill/rule packs, in-editor assistants, Godot LLM benchmarks, Godot's own stance. The dsh plugins (dsh-godot-skill, godot-bridge) are excluded; another researcher covers them.

Method note: GitHub star counts and push dates come from the GitHub search API, queried 2026-11-23. The per-repo API endpoints were blocked in this session, so release tags were not collected. READMEs were read in full from raw.githubusercontent.com. godotengine.org and forum.godotengine.org could not be fetched (DNS blocked in the sandbox), so claims from those sites come from search-engine summaries and are marked **[snippet only]**. Most blog sources (ziva.sh, summerengine, flockbay, fennara, strayspark, gamedevaihub) are vendors comparing themselves to competitors. Treat their rankings as marketing.

## Which tools are most adopted/maintained, and what do they actually expose?

### Takeaway
Adoption is concentrated in a few free MIT MCP servers. Coding-Solo/godot-mcp has 6.7k stars but is stale (last push April 2026) and only launches the game and reads its logs. hi-godot/godot-ai has 3.7k stars, is the most actively maintained (pushed 2026-11-22) and requires Godot 4.7+. Runtime control (screenshots, input injection, live scene tree, eval) is now common: Godot MCP Pro, tugcantopaloglu, Godot MCP Runtime, Ziva and GDAI offer it. Skill packs have outgrown the MCP servers in stars: Claude-Code-Game-Studios has 40.7k, awesome-gamedev-agent-skills 10.5k and godogen 7.4k. Most are prompt and knowledge packs, not tools.

### Cited Findings

**MCP servers (stars / last push as of 2026-11-23, GitHub search API)**
- Coding-Solo/godot-mcp: ★6,740, created 2025-02-26, last push 2026-04-16, MIT. Tools: launch_editor, run_project, get_debug_output, stop_project, get_godot_version, list_projects, get_project_info, create_scene, add_node, load_sprite, export_mesh_library, save_scene, get_uid, update_project_uids (4.4+). It has no screenshot, input or live-tree tools. Install: `claude mcp add godot -- npx @coding-solo/godot-mcp`. Needs Node ≥18. — [README](https://raw.githubusercontent.com/Coding-Solo/godot-mcp/HEAD/README.md)
- hi-godot/godot-ai: ★3,662, created 2026-04-12, last push 2026-11-22, MIT. "46 tools and 120+ operations" build scenes, edit nodes and scripts, wire signals, and configure UI, materials, animation, particles, cameras and environments. It requires **Godot 4.7+** and uv (Python server). The architecture is MCP client → `godot-ai attach` (stdio) → Python server (authenticated HTTP :8000) → editor plugin (authenticated WebSocket :9500, loopback only). GDScript is "parse-validated, hot-reloaded, attached, and outlined". C# is text-only, with no .NET build and no compiler errors. Security claims: signed releases, rotating credentials, and writes confined to the project, with `project.godot`, `override.cfg` and `.godot/` off-limits. Self-reported telemetry: "21,000+ monthly active installs · 30M+ tool calls in the last three months" (to 2026-10-25). The dock auto-configures 26 clients, including Claude Code, Codex and Cursor. It links a testing doc ("Run the scene test suite"). — [README](https://raw.githubusercontent.com/hi-godot/godot-ai/HEAD/README.md)
- youichi-uda/godot-mcp-pro: ★649, created 2026-02-24, last push 2026-09-24. The README claims "187 powerful tools" (repo description: 162; Asset Library listing: 163). The tool count is inconsistent across sources. The public repo holds only the addon. The Node MCP server is paid, sold as a one-time purchase (other sources say $15). Architecture: stdio ↔ Node ↔ WebSocket :6505 ↔ editor plugin, using the editor UndoRedo system. Runtime tools: get_editor_screenshot, get_game_screenshot, compare_screenshots, capture_frames, simulate_action, simulate_sequence (input events with frame delays), get_game_scene_tree, get_game_node_properties, set_game_node_property, execute_game_script, start/stop/replay_recording, find_ui_elements, and set_game_speed (Engine.time_scale). Six testing tools include run_test_scenario, run_stress_test and get_test_report. It offers tool-subset "modes" (e.g. `--3d`) to fit client tool limits. — [README](https://raw.githubusercontent.com/youichi-uda/godot-mcp-pro/HEAD/README.md)
- Erodenn/godot-mcp-runtime: ★103, last push 2026-11-13, MIT. It needs no addon: `npx -y godot-mcp-runtime`, Node 20+, Godot 4.5+. Headless editing covers scenes, nodes, scripts, signals and GDScript validation. On `run_project` it injects an `McpBridge` autoload (localhost TCP), which provides:
  - screenshots: a 960x540 inline preview plus the full PNG, with pixel stats and a `likelyBlank` verdict
  - batched input: keys, mouse, UI clicks by node path, actions, typed text, waits
  - UI discovery: visible Controls with position, text and disabled state
  - live GDScript execution
  - profiling: functions, FPS, monitors

  `render_movie` uses the engine's movie writer to render N frames and report "blank or not, moving or not". It offers a background/off-screen window mode, an attach mode for externally launched games (where `get_debug_output` returns null), and multiple sessions. It explicitly says: "not a playtesting replacement. It doesn't catch the subtle feel issues." Its comparison table: Coding-Solo has no runtime; GDAI is "editor-mediated", proprietary, $19; Godot MCP Pro is proprietary, $15; tugcantopaloglu has full runtime via a committed autoload. — [README](https://raw.githubusercontent.com/Erodenn/godot-mcp-runtime/HEAD/README.md)
- 3ddelano/gdai-mcp-plugin-godot (GDAI MCP): ★103, last push 2026-09-11, proprietary ("© 2025 Delano Lourenco. All rights reserved"), sold at gdaimcp.com. Godot 4.1+. Features: scene, node, resource and script creation; debugger, output and script-error reading (get_open_script_errors); res:// search; and "Automatically takes screenshots to visually understand the editor and running game". Its FAQ says Claude Desktop "most of the times is able to one-shot simple games". — [README](https://raw.githubusercontent.com/3ddelano/gdai-mcp-plugin-godot/HEAD/README.md)
- Other MCP servers from GitHub search (stars and last push, 2026-11-23):
  - yurineko73/Godot-MCP-Native ★882 (2026-08-03): MCP server implemented natively in Godot, no dependencies
  - ee0pdt/Godot-MCP ★623 (last push 2025-03-19, abandoned)
  - DaxianLee/godot-mcp ★558 (2026-01-14)
  - tugcantopaloglu/godot-mcp ★525 (2026-10-09): "157 tools", GDScript and C#
  - tomyud1/godot-mcp ★454 (2026-10-17)
  - IvanMurzak/Godot-MCP ★383 (2026-11-23): C#
  - Glade-tool/glade-mcp ★204 (2026-11-01): Unity and Godot, "275+ tools"
  - NPGameDev/godot-mcp-toolkit ★147 (2026-11-22)
  - aigengame/godot-agent ★59 (2026-11-02): CLI, Agent Skill or MCP

  — [GitHub search API, "godot mcp"](https://api.github.com/search/repositories?q=godot+mcp&sort=stars)
- The Godot Asset Library lists many more MCP plugins, among them Godot MCP Pro (asset 4961), GDMCP (5403), Fennara MCP (5201), Godot .NET MCP (4923), Godot MCP Toolkit (5375), Open Godot MCP (5360), Godot Editor MCP (5434, "180 tools across 29 categories"), Swallowtail (5367) and Godot MCP (5470). Forum launch threads exist for Beckett ("zero-sidecar MCP server for Godot 4.2+ (the AI sees, and optionally playtests, your game)"), Open Godot MCP ("deterministic playtesting, multiplayer testing, DAP debugging, LSP") and GodotIQ ("spatial intelligence"). **[snippet only]** — [Asset Library 4961](https://godotengine.org/asset-library/asset/4961); [Beckett thread](https://forum.godotengine.org/t/beckett-zero-sidecar-mcp-server-for-godot-4-2-the-ai-sees-and-optionally-playtests-your-game/141177); [Open Godot MCP thread](https://forum.godotengine.org/t/open-godot-mcp-ai-plays-tests-your-game-not-just-edits-files/141986); [GodotIQ thread](https://forum.godotengine.org/t/godotiq-mcp-server-that-gives-ai-agents-spatial-intelligence-for-godot/135304)
- A 2026 roundup recommends hi-godot/godot-ai for Godot 4.7+ and Erodenn/godot-mcp-runtime for older 4.x. The publisher, Summer Engine, sells a competing custom engine. — [summerengine.com](https://www.summerengine.com/blog/best-godot-mcp-server)

**In-editor assistants**
- Ziva (ziva.sh): an editor plugin for Godot 4.2+, MIT per the Asset Library listing, version 0.2.5. Its claims: reads and edits scenes, scripts, resources, project settings and TileMapLayer cells; reads debugger errors with file and line; runs tests; captures screenshots; "playtest your game with real input"; plan mode; an MCP server exposing "163 tools across 39 MCP endpoints". A Feb 2026 forum post says users can connect their own Claude or Codex subscription via OAuth. Independent reviews are scarce. **[snippet only]** — [Asset Library 4879](https://www.godotengine.org/asset-library/asset/4879); [forum release thread](https://forum.godotengine.org/t/release-ziva-sh-ai-godot-development-agent/131964); [ziva.sh/godot-ai](https://ziva.sh/godot-ai)
- Smaller plugins that call a provider API directly from the editor are low-adoption (≤6★): TheCronkTM/godot-ollama-assistant, mkgiga/godot-ai-helper, slothitude/godotcode and danielvaitekunas/Godot-AI-Assistant-Plugin. godot-fun/gai (★240, pushed 2026-11-23) is "an AI coding agent built in Godot". — [GitHub search API](https://api.github.com/search/repositories?q=godot+ai+assistant+plugin&sort=stars)

**Skill / rule packs (stars / last push 2026-11-23)**
- Donchitos/Claude-Code-Game-Studios ★40,690 (2026-11-09): "49 AI agents, 75 workflow skills". It is generic studio role-play, not Godot tooling. — [GitHub search API](https://api.github.com/search/repositories?q=godot+claude+skill&sort=stars)
- gamedev-skills/awesome-gamedev-agent-skills ★10,534 (2026-11-12), Apache-2.0. It has 79 skills plus a router across 12 engines, pinned to Godot 4.7.2 (checked 2026-11-11). It claims code examples were "run or compiled on the real toolchains for 10 of the 12 engines", and that "in 366 blind test prompts the right skill loaded for 98.7%". Install: `npx skills add …`. It runs paid sponsor slots. — [README](https://raw.githubusercontent.com/gamedev-skills/awesome-gamedev-agent-skills/HEAD/README.md)
- htdt/godogen ★7,388 (2026-11-21): two skills. engine-guide covers Godot (C# or GDScript), Bevy, Babylon.js, three.js and HTML, including "headless capture to screenshots and video, and the traps that fail without an error". asset-gen generates images and sprites (GPT-Image), 3D models, SFX and voice. Design note: early versions scripted the agent step by step (PLAN.md, STRUCTURE.md, a decomposer and an architect). The current version deliberately "doesn't plan for it, check its work or decide when it's done". — [README](https://raw.githubusercontent.com/htdt/godogen/HEAD/README.md)
- jame581/GodotPrompter ★985 (2026-11-14), MIT, v1.17.x: 59 skills for Godot 4.3+, built on obra/superpowers. It includes `godot-testing` ("TDD with GUT and gdUnit4 — test structure, mocking, CI") and Godot 4.8-beta3 callouts. It ships for Claude Code, Codex, Copilot CLI, Cursor, OpenCode, Antigravity and Grok, with CI validating skills and hooks. — [README](https://raw.githubusercontent.com/jame581/GodotPrompter/HEAD/README.md)
- thedivergentai/Game-Dev-Agentic-Skills ★989 ("Deep Godot 4.7+ (99 skills, 27 genre blueprints)"); haxqer/godot-skill ★259; BlueBirdBack/godot-cursorrules ★119 (Godot 4.4 Cursor rules, last push 2025-03-25). A long tail of 0–1★ "stop Godot 3 code" rule packs appeared in Oct–Nov 2026 (scoyoc5/godot-ai-agent-rules, shipthejam/godot-jam-rules, bigchair10/godot4-agent-lite). — [GitHub search API](https://api.github.com/search/repositories?q=godot+agent+skills&sort=stars)

### Inferences
- Stars track age and marketing more than capability. Coding-Solo leads on stars but exposes the least, and has not been pushed in seven months. For a project that needs runtime verification, the effective choice in Nov 2026 is:
  - hi-godot/godot-ai (free, Godot 4.7+, editor-attached)
  - Godot MCP Runtime (free, no addon, 4.5+)
  - Godot MCP Pro or GDAI (paid, addon)
- The ecosystem is fragmented: dozens of overlapping servers with 100–190 tools each. Tool-count inflation forces subset "modes" (Godot MCP Pro) and "tool domains" (godot-ai) to stay under client tool limits.
- Two architectural camps exist. Editor-plugin servers get UndoRedo and the live editor tree but require committing an addon and keeping the editor open. Headless/CLI servers have zero footprint and are CI-friendly, but get no editor state.

### Gaps
- Release tags and dates were not collected, because the per-repo GitHub API was blocked. Download counts are available only from self-reported telemetry (godot-ai).
- GDAI's and Ziva's actual tool lists were not verified beyond marketing text.
- Whether godot-ai's "Run the scene test suite" wraps GUT, GdUnit4 or its own runner was not checked (docs/testing.md was not read).

## What failure modes do practitioners report?

### Takeaway
The recurring failures fall into five groups:
- LLMs writing Godot 3 APIs in Godot 4 projects
- MCP connection and config confusion
- malformed or stale .tscn and editor-cache state after file writes
- runtime errors not surfacing to the agent
- headless test runs that exit 0 or hang

No Hacker News or r/godot thread was found through search. Evidence is mostly from the Godot forum and vendor blogs.

### Cited Findings
- On the Godot forum, users report LLMs "confuse Godot 4 and Godot 3 functions. Sometimes I received completely invented functions" and "can't always distinguish between Godot 3 and Godot 4 and can confidently lie/hallucinate". **[snippet only]** — [forum: ChatGPT to learn](https://forum.godotengine.org/t/is-it-bad-to-use-chatgpt-to-help-me-learn-specific-situations-in-godot/121995); [forum: AI for scripting](https://forum.godotengine.org/t/opinions-on-using-ai-for-scripting/125613?page=2)
- Classic Godot 3-in-4 errors: `KinematicBody2D`, `move_and_slide()` called with arguments, and `export var` without `@`. Others are `rand_range` (now `randf_range`/`randi_range`) and `yield()` (now `await`). — [flockbay godot-llm-bench README](https://raw.githubusercontent.com/flockbay/godot-llm-bench/HEAD/README.md); [ziva.sh blog](https://ziva.sh/blogs/chatgpt-godot-3-code) (vendor)
- Ziva tested 150 answers (May 2026, vendor test). It found GPT-4o produced Godot 3 syntax (KinematicBody, Spatial.translation) where later Claude models did not. **[snippet only]** — [ziva.sh/blogs/claude-godot](https://ziva.sh/blogs/claude-godot)
- MCP connection issues: "even when it says connected, Claude desktop keeps saying Godot is only returning mock data". Claude Code reads `.mcp.json` from the launch directory, while Claude Desktop uses a different file. "Godot editor is not connected" means the server is up but the plugin is not. **[snippet only]** — [forum: free MCP server](https://forum.godotengine.org/t/godot-free-open-source-mcp-server-addon/133890); [godotawesome guide](https://godotawesome.com/godot-mcp-claude-code-setup/)
- Malformed .tscn: Godot may refuse to load an MCP-edited scene, and a guide suggests checking `instance=` line formatting. **[snippet only]** — [godotawesome guide](https://godotawesome.com/godot-mcp-claude-code-setup/)
- A developer tested several Godot MCPs on a 3.6→4.6 migration. The biggest problems were stale editor output, runtime errors not returned clearly, and editor cache issues after file writes. The author is the Fennara vendor. **[snippet only]** — [dev.to/fennaraofficial](https://dev.to/fennaraofficial/i-tested-popular-godot-mcps-by-migrating-a-godot-36-project-to-godot-46-34d2)
- Godot MCP Runtime documents that `get_debug_output` returns null for externally launched games, because stdout/stderr flow only through processes it started. — [README](https://raw.githubusercontent.com/Erodenn/godot-mcp-runtime/HEAD/README.md)
- A dev.to author building with coding agents reported that collision-rectangle bugs slipped through while tests passed. They concluded that screenshots and human playtesting remain important. **[snippet only]** — [dev.to/abagames](https://dev.to/abagames/godot-is-well-suited-for-game-development-with-ai-coding-agents-2lcm)
- Security and permissions: comparisons flag that some servers execute code in the running game or write, move and delete files. godot-ai confines writes and forbids `project.godot`/`.godot/`, and its 4.3.1 release removed compromised emSign root certs (Oct 2026). — [godot-ai README](https://raw.githubusercontent.com/hi-godot/godot-ai/HEAD/README.md); [ziva.sh comparison](https://ziva.sh/blogs/godot-mcp-server-claude-code-cursor) (vendor)

### Inferences
- The highest-value guardrails are:
  - a machine check that every generated script parses against the pinned Godot binary (headless `--check-only` or a validator)
  - forcing the agent to read Godot's own error output after each change
  - preferring editor-API edits over raw .tscn text writes, or reloading the editor after them

### Gaps
- No HN or r/godot discussion was retrievable through search. Reddit coverage is a gap.
- No independent (non-vendor) incident reports were found quantifying how often MCP .tscn edits corrupt scenes.

## Godot LLM benchmarks / evals

### Takeaway
Small community benchmarks appeared in 2026. All judge by running headless Godot 4.7. Frontier models now saturate basic Godot-4 API tasks: three models scored 15/15 on flockbay's suite, and Claude Opus 4.8 scored 300/300 on GDScript-Eval v2. Small local models still fail heavily, mainly through Godot 3 contamination.

### Cited Findings
- flockbay/godot-llm-bench (repo created 2026-10-13): 15 GDScript tasks, each touching a 3→4-changed API (move_and_slide, FileAccess/JSON, tweens, TileMapLayer, ray queries, AStarGrid2D, AnimationLibrary, lambda captures). Each is judged by running headless on official Godot 4.7.2, results from 2026-10-06, one run per model:
  - Claude Opus 5.5 / Claude Code: 15/15
  - Claude Sonnet 5.5: 15/15
  - GPT-6.1 Sol / Codex: 15/15
  - Claude Haiku 4.5: 11/15 first try, 14/15 after one fix

  Across 28 models, 12 passed all 15 first try. The authors say "these tasks are now the floor, not the ceiling". flockbay is a vendor. — [README](https://raw.githubusercontent.com/flockbay/godot-llm-bench/HEAD/README.md)
- blugart-dev/estragon (2026-08-31): GDScript-Eval v2, 300 held-out tasks in 10 categories. A task passes only if the file parses and its runtime assertions hold in a pinned Godot `4.7.stable.official.5b4e0cb0f` binary. Scores:
  - Qwen3-8B: 38.3%
  - phi-4: 48.7%
  - gemma-4-12B: 70.3%
  - Qwen3.5-9B: 73.0%
  - Estragon-9B fine-tune: 82.7%
  - Claude Opus 4.8: 100%

  Rationale: "small local models write confidently wrong GDScript — usually Godot 3 syntax with Godot 4 sprinkles". — [README](https://raw.githubusercontent.com/blugart-dev/estragon/HEAD/README.md)
- Other small benches (≤3★): oubakiou/godot-llm-gamebench (same game task delegated to multiple vendors' CLIs) and Lost-Rabbit-Digital/godot-model-bench (Godot 4.7, 7 rounds). — [GitHub search API](https://api.github.com/search/repositories?q=gdscript+benchmark+llm&sort=stars)

### Inferences
- With current frontier models, raw API correctness on small tasks is mostly solved. Failures move to integration: scenes, signals across files, input, feel, and silent runtime errors. Benchmarks do not yet measure that level. flockbay's "game-level head-to-heads" are a blog, not a reproducible harness.

### Gaps
- There is no benchmark for .tscn editing correctness, multi-scene integration, or visual or feel outcomes.
- No independent benchmark from a non-vendor or academic source was found, other than estragon (a solo project).

## Does Godot's own project have an official stance or features that these tools rely on?

### Takeaway
The Godot Foundation's 2026 stance on AI concerns engine contributions, not game developers. In mid-2026 it moved to ban AI-authored code and agent-submitted PRs to the engine repo. There is no official AI assistant or MCP in the engine. The tools instead build on general engine features:
- headless mode (dummy renderer, so no pixels)
- Movie Maker (`--write-movie`)
- the 4.4+ embedded Game view with runtime node selection
- the remote scene tree and debugger
- EditorPlugin, autoloads and UID files (4.4+)

### Cited Findings
- Godot published "contribution policy 2026", announcing that it is updating its contribution policies "including adding a stricter policy on AI contributions". Press coverage (June–July 2026) says it will bar AI-authored code, PRs submitted by AI agents, and AI-generated text in human communication. Menial uses (code completion, regex, find/replace, translation, lookup) stay allowed, with disclosure. Coverage disagrees on whether the policy is already in force or pending. **[snippet only; primary page not fetchable from sandbox]** — [godotengine.org article](https://godotengine.org/article/contribution-policy-2026/); [GamingOnLinux, 2026-07](https://gamingonlinux.com/2026/07/godot-engine-to-get-stricter-on-ai-contributed-code); [PC Gamer](https://pcgamer.com/gaming-industry/open-source-game-engine-godot-will-no-longer-accept-ai-authored-code-contributions-we-cant-trust-heavy-users-of-ai-to-understand-their-code-enough-to-fix-it)
- Ziva's listing states "Godot has no built-in AI assistant" (vendor framing, consistent with no official feature found). **[snippet only]** — [Asset Library 4879](https://www.godotengine.org/asset-library/asset/4879)
- Godot 4.4 added game embedding and runtime selection of 2D/3D nodes in the running game, which opens them in the inspector. Suspend mode allows node selection and frame skipping (frame stepping). Docs exist for 4.7, which supports floating-window and main-window embedding. The game stays a separate process. **[snippet only]** — [docs 4.7 game_embedding](https://docs.godotengine.org/en/4.7/tutorials/editor/game_embedding.html); [W4 Games interview](https://www.w4games.com/blog/w4-games-news-1/interview-with-michael-alexsander-better-runtime-debugging-tools-in-godot-4-4-80)
- In Godot 4, `--headless` uses the Dummy rendering server, so it produces no image. Screenshot tools need a display server, and Xvfb is the usual Linux workaround (software GL only). **[snippet only]** — [ask.godotengine.org 150510](https://ask.godotengine.org/150510/godot-headless-not-same-godot-window-cant-render-the-backend); [glama godot-forge screenshot tool](https://glama.ai/mcp/servers/gregario/godot-forge/tools/godot_screenshot)
- Godot MCP Runtime's `render_movie` uses the engine's movie writer (Movie Maker) in a separate short run to check that frames render and move. godogen's engine-guide covers "headless capture to screenshots and video". — [godot-mcp-runtime README](https://raw.githubusercontent.com/Erodenn/godot-mcp-runtime/HEAD/README.md); [godogen README](https://raw.githubusercontent.com/htdt/godogen/HEAD/README.md)
- Coding-Solo's UID tools target the Godot 4.4+ `.uid` files. — [README](https://raw.githubusercontent.com/Coding-Solo/godot-mcp/HEAD/README.md)

### Inferences
- No surveyed MCP server documents using the 4.4 embedded Game view or its runtime-selection API. They reimplement runtime access with an injected autoload and a TCP/WebSocket bridge. That approach works in exported and headless-ish runs too, but it duplicates the engine's debugger protocol.
- Contributors to Godot itself cannot use agents for engine PRs. This does not restrict game projects.

### Gaps
- Whether `--write-movie` works under `--headless` (dummy) or only with a display/Xvfb was not confirmed.
- The primary text of the 2026 contribution policy and its exact effective date were not fetched (godotengine.org blocked).

## How well do the tools cover the six capability areas, and what is still done by hand?

### Takeaway
- **Visual feedback** and **driving the running game** are well covered by paid and newer tools: screenshots, frame capture, input sequences, live tree, eval, and time scale.
- **Tests** are covered only by skill guidance and a few wrappers, and headless pitfalls are well documented.
- **GDScript correctness** relies on parse validation plus error-log reading. LSP and docs lookup are rare.
- **.tscn editing** is done through editor APIs or text, with corruption reports.
- **Human review of art and feel** is explicitly unsolved: tools say so in their READMEs.

### Cited Findings
- **Visual feedback:**
  - Godot MCP Pro: editor and game screenshots, compare_screenshots, capture_frames — [README](https://raw.githubusercontent.com/youichi-uda/godot-mcp-pro/HEAD/README.md)
  - Godot MCP Runtime: screenshots with a `likelyBlank` pixel-stat verdict; render_movie blank/moving check — [README](https://raw.githubusercontent.com/Erodenn/godot-mcp-runtime/HEAD/README.md)
  - GDAI: automatic editor and game screenshots — [README](https://raw.githubusercontent.com/3ddelano/gdai-mcp-plugin-godot/HEAD/README.md)
  - Coding-Solo: none — [README](https://raw.githubusercontent.com/Coding-Solo/godot-mcp/HEAD/README.md)
- **Frame stepping:** Godot MCP Pro's `set_game_speed` (Engine.time_scale) and `simulate_sequence` with frame delays. The engine's own suspend/frame-skip lives in the 4.4+ Game view. — [Godot MCP Pro README](https://raw.githubusercontent.com/youichi-uda/godot-mcp-pro/HEAD/README.md); [docs game_embedding](https://docs.godotengine.org/en/4.7/tutorials/editor/game_embedding.html)
- **Driving the game:**
  - input injection: key, mouse, action, sequences; record/replay in Pro; UI click by path in Runtime
  - scene-tree and property queries
  - `execute_game_script` / live GDScript

  "Open Godot MCP" advertises deterministic playtesting, multiplayer testing, DAP debugging and LSP **[snippet only]**. — [Godot MCP Pro README](https://raw.githubusercontent.com/youichi-uda/godot-mcp-pro/HEAD/README.md); [Runtime README](https://raw.githubusercontent.com/Erodenn/godot-mcp-runtime/HEAD/README.md); [Open Godot MCP thread](https://forum.godotengine.org/t/open-godot-mcp-ai-plays-tests-your-game-not-just-edits-files/141986)
- **Running tests, headless pitfalls** (forum post measured on Godot 4.5–4.7.2) **[snippet only]**:
  - GUT can print "All tests passed!" with exit 0 even though some of its own scripts failed to load.
  - gdUnit4 6.2.2 needs Godot 4.5+.
  - On 4.4.1 both frameworks' CLIs hang until killed.

  A Ziva guide (Godot 4.7.2) found Control clicks do not work under `--headless` and recommends `xvfb-run`. It also says gdUnit4 6.2.3 `runtest.sh --headless` exits 103 without `--ignoreHeadlessMode`. Other guides add: an `--import` pass is needed before tests, GUT needs `-gexit`, and config drift yields zero-test runs. — [forum: exit 0 headless](https://forum.godotengine.org/t/things-that-exit-0-in-godot-4-headless-even-though-they-failed-measured-reproducible/145990); [ziva.sh input testing](https://ziva.sh/blogs/godot-gut-gdunit4-simulate-input); [GUT issue 598](https://www.Github.com/bitwes/Gut/issues/598); [helpmetest](https://helpmetest.com/blog/godot-ci-cd-testing/); [bugnet](https://bugnet.io/blog/how-to-fix-godot-headless-test-run-fails-in-ci)
- **GDScript correctness:**
  - godot-ai parse-validates scripts; C# gets no compiler errors — [README](https://raw.githubusercontent.com/hi-godot/godot-ai/HEAD/README.md)
  - Runtime validates GDScript headless — [README](https://raw.githubusercontent.com/Erodenn/godot-mcp-runtime/HEAD/README.md)
  - GDAI reads open-script errors — [README](https://raw.githubusercontent.com/3ddelano/gdai-mcp-plugin-godot/HEAD/README.md)
  - Skill packs pin versions (awesome-gamedev-agent-skills: Godot 4.7.2; GodotPrompter: 4.8-beta callouts) to counter 3-vs-4 confusion — [awesome-gamedev README](https://raw.githubusercontent.com/gamedev-skills/awesome-gamedev-agent-skills/HEAD/README.md); [GodotPrompter README](https://raw.githubusercontent.com/jame581/GodotPrompter/HEAD/README.md)
- **Asset and scene editing:**
  - Coding-Solo edits scenes through headless Godot operations (create_scene, add_node, save_scene) — [README](https://raw.githubusercontent.com/Coding-Solo/godot-mcp/HEAD/README.md)
  - Godot MCP Pro goes through the editor UndoRedo system — [README](https://raw.githubusercontent.com/youichi-uda/godot-mcp-pro/HEAD/README.md)
  - godogen generates sprites, 3D, SFX and voice through paid APIs or local GPU — [README](https://raw.githubusercontent.com/htdt/godogen/HEAD/README.md)
  - awesome-gamedev-agent-skills "locks a visual target, builds families, normalizes outputs deterministically, and checks them inside the game" — [README](https://raw.githubusercontent.com/gamedev-skills/awesome-gamedev-agent-skills/HEAD/README.md)
- **Human-in-the-loop for art and feel:**
  - Runtime README: "doesn't catch the subtle feel issues that only a human notices, and it won't tell you if your game is fun" — [README](https://raw.githubusercontent.com/Erodenn/godot-mcp-runtime/HEAD/README.md)
  - Beckett: "AI proposes, the asserts verify, with a human staying in control" **[snippet only]** — [Beckett thread](https://forum.godotengine.org/t/beckett-zero-sidecar-mcp-server-for-godot-4-2-the-ai-sees-and-optionally-playtests-your-game/141177)
  - godogen leaves review to the user: "Ask for a screenshot or a video whenever you want to see where it stands" — [README](https://raw.githubusercontent.com/htdt/godogen/HEAD/README.md)

### Inferences
What practitioners still do by hand:
- judging feel, timing and art fidelity
- confirming that a screenshot matches an intended reference. compare_screenshots exists, but no surveyed tool documents tolerance-based reference diffs against an external source such as SWF frames.
- running GUI-click tests under Xvfb instead of headless
- reloading the editor after external .tscn writes
- verifying that test-runner exit codes reflect real failures

For a parity port like this project, no off-the-shelf tool reads a reference asset (e.g. SWF-derived positions or timings) and diffs the running game against it. That comparison loop has to be project-built. The runtime MCPs can supply the capture and input halves.

### Gaps
- No source quantified how reliable agent input injection is for timing-sensitive gameplay, or how deterministic it is across frames.
- LSP integration (Godot's built-in GDScript language server on port 6005) is mentioned only by Open Godot MCP **[snippet only]**. No mainstream server was confirmed to expose LSP diagnostics or docs lookup.
- Reddit and HN first-hand reports could not be retrieved.
