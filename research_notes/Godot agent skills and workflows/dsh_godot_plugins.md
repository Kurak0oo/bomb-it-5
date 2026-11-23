# dsh Godot plugins: akira399/dsh-godot-skill and Smalldy/godot-bridge

Research date: 2026-11-23. Method: cloned both plugin repos (shallow, read-only) and read every
source and doc file; sparse-fetched the DeepSeek Harness repo docs; pulled repo metadata (stars,
dates) with `gh search repos`. **dsh-plugin.org itself could not be reached from this session**
(proxy 403 / DNS refusal), so nothing below is taken from the two plugin pages. Their content is
reconstructed from the GitHub repos the pages point to. If the pages carry extra metadata (download
counts, ratings), it is unverified.

## What is "dsh" and how does its plugin system compare to Claude Code skills/plugins and MCP?

### Takeaway
"dsh" is **DeepSeek Harness**, an open-source (MIT) agent harness from DeepSeek AI. It is built on
the Cordis plugin framework ("everything is a plugin"), and it is still a *developer preview* that
warns of breaking changes. Its skills use the same `SKILL.md` progressive-disclosure format as Claude
Code and Codex, and it ships an MCP *client*. A pure-skill dsh plugin therefore ports trivially to
other harnesses. A dsh *tool* plugin is a Node module that calls `ctx.tools.register` and does not
port directly, though godot-bridge is itself a re-implementation of an existing MCP server.

### Cited Findings
- "DeepSeek Harness (`dsh`) is an open-source agent harness developed by DeepSeek AI … built on an **everything-is-a-plugin** architecture and powered by Cordis." It is in "developer preview … THERE WILL BE COMPATIBILITY-BREAKING CHANGES." It runs as `npx @deepseek-ai/dsh web`, a Web UI on 127.0.0.1:3080. License: MIT. — [deepseek-ai/deepseek-harness README](https://github.com/deepseek-ai/deepseek-harness)
- Repo created 2026-08-13; ~285,950 stars, last push 2026-11-22 (gh search metadata, 2026-11-23). — [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness)
- Plugins are discovered through the GitHub `dsh-plugin` topic. Community directories include awesome-dsh-plugin, dsh.directory, and an "11,000+ plugins" hub (imsai-sh). dsh-plugin.org appears to be another directory of this kind (unverified, unreachable). — [DSH README](https://github.com/deepseek-ai/deepseek-harness); [awesome-dsh-plugin](https://github.com/awesome-dsh-plugin/awesome-dsh-plugin); [imsai-sh/awesome-deepseek-harness-plugins](https://github.com/imsai-sh/awesome-deepseek-harness-plugins)
- Install model: `dsh plugin --profile web add <npm|git|github:…>` forwards to pnpm. It installs the package into the profile's `node_modules`, and a package that declares `dsh.bundle.patch` (a `cordis.patch.yml`) gets a row inserted into the profile's plugin composition. A restart, or a reload from the Plugins page, activates it. — [godot-bridge README](https://github.com/Smalldy/godot-bridge); [dsh-godot-skill README](https://github.com/akira399/dsh-godot-skill)
- The DSH skill design note says the skill pattern is shared: "Codex, Claude Code, OpenCode, and Kimi Code differ in details, but all separate discovery metadata from complete instructions." DSH skills are `<name>/SKILL.md` with YAML frontmatter (`name` and `description` required; `whenToUse`, `metadata`, `disable-model-invocation`, `user-invocable` optional). They load on demand through a `skill({name})` tool, and the session only sees a name+description catalog. — [DSH agent note: skill system](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/archived/feature/2026-07-05-skill-system.md)
- The DSH local skill provider scans `<projectRoot>/.dsh/skills`, `<projectRoot>/.agents/skills`, custom dirs, then the user `.dsh` and `.agents` roots. It does **not** scan `.claude/skills` (no "claude" in the skills/MCP subsystem docs). Fields DSH defers include `allowed-tools`, `arguments`, and `context: fork`. — [docs/subsystems/skills.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/subsystems/skills.md); [skill-system note](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/archived/feature/2026-07-05-skill-system.md)
- DSH ships `@deepseek-ai/dsh-mcp-client`, which uses the official MCP TS SDK (stdio and streamable HTTP). Each MCP server is one plugin instance whose tools are registered as native tools. Client only: no MCP server side, no prompt templates. — [DSH agent note: MCP client plugin](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/archived/feature/2026-07-07-mcp-client-plugin.md)
- Native dsh tool plugins import `defineTool` from `@deepseek-ai/dsh-tools` and register through `ctx.tools.register`. They are harness-specific Node modules (named exports `name`/`inject`/`apply`). — [godot-bridge README](https://github.com/Smalldy/godot-bridge)

### Inferences
- Portability, skill side: dsh-godot-skill's `SKILL.md` can be dropped unchanged into `.claude/skills/<name>/SKILL.md` (Claude Code) or `.agents/skills/` (Codex/DSH). The JS wrapper only registers that file at runtime and adds nothing Claude Code needs.
- Portability, tool side: godot-bridge's 17 tools are not MCP, so Claude Code, Codex, and Cursor cannot load them. Its game-side protocol, however, is byte-identical to tugcantopaloglu/godot-mcp, which *is* an MCP server. The direct equivalent for Claude Code is therefore to run that MCP server, which uses the same autoload, same port 9090, and same commands.
- The ecosystem is new: DSH is about three months old, and both plugins appeared within one to two days of DSH's public launch.

### Gaps
- dsh-plugin.org page content (listing metadata, install counts, category, any curation or verification badge) was not reachable. Add `dsh-plugin.org` to the session network allowlist to verify.
- DSH's official docs site (deepseek-harness.github.io) was not fetched. The plugin-system description above comes from in-repo docs at master on 2026-11-23.

## What does akira399/dsh-godot-skill contain, how does it work, and how mature is it?

### Takeaway
It is a single static knowledge skill (`godot-4-development`, 444 lines, in **Chinese**) plus about
80 lines of JS that register it at runtime. The skill is a condensed tour of the Godot 4 feature
list, a generic "AI builds a game" workflow, code templates, and an error table. It has no tools, no
commands, no editor/runtime bridge, no screenshots, no linting, and no test runner. Maturity: v1.0.0,
six commits from 2026-08-14 to 2026-08-28, then dormant. 72 stars.

### Cited Findings
- Files: `lib/index.js` (host plugin), `.dsh/skills/godot-4-development/SKILL.md`, `cordis.patch.yml`, `scripts/verify.mjs`, README, LICENSE (MIT). — [repo](https://github.com/akira399/dsh-godot-skill)
- Mechanism: `inject = ["skills"]`. `apply(ctx)` reads SKILL.md, parses the `name`/`description`/`whenToUse` frontmatter with a hand-written parser, and calls `ctx.skills.register({...content: body, resourceBase: {kind:"directory"}})`, tied to the plugin lifecycle. It has zero npm dependencies. — [lib/index.js](https://github.com/akira399/dsh-godot-skill/blob/main/lib/index.js)
- Skill content: it is sourced from the official Chinese "List of features" page. Sections: core concepts (node/scene/resource/signal/group), standard project layout and a `project.godot` example, renderer choice (Forward+/Mobile/Compatibility), a 20-domain feature→API cheat sheet (2D/3D graphics and physics, shaders, scripting, audio, import, input, navigation, networking, i18n, GUI, animation, file formats, Movie Maker, headless/CI), a seven-stage workflow (design → scaffold → prototype → content → polish → test/debug → export), a node-selection table, code templates (player movement, camera, spawning, HTTP, scene change, pause, save, ENet), and a common-errors table. — [SKILL.md](https://github.com/akira399/dsh-godot-skill/blob/main/.dsh/skills/godot-4-development/SKILL.md)
- Its testing guidance amounts to running `godot --path . --debug`, adding `print()`/`push_error()`, and using the remote inspector. For headless use it notes that `godot --headless --path . --quit` should start cleanly and that importing, lightmap baking, and navmesh baking need the editor or an `--import` step. — [SKILL.md §4.2, §5](https://github.com/akira399/dsh-godot-skill/blob/main/.dsh/skills/godot-4-development/SKILL.md)
- Its sample `project.godot` uses `config/features=PackedStringArray("4.4", …)`. The skill targets "Godot 4.x" generically and pins no tested engine version. — [SKILL.md §2](https://github.com/akira399/dsh-godot-skill/blob/main/.dsh/skills/godot-4-development/SKILL.md)
- History: f4712dc 2026-08-14 (initial) → 5ff4084 2026-08-28 (install-path fixes). package.json is version 1.0.0. Repo created 2026-08-13, last push 2026-08-28, 72 stars (gh metadata 2026-11-23). The README documents pnpm/git+ssh install friction (SSH key, `allowBuilds`). — [repo history](https://github.com/akira399/dsh-godot-skill/commits/main)
- Verification is `pnpm verify`: plugin syntax, skill file integrity, and a registration check against a mock `ctx`. There are no Godot-level tests. — [README](https://github.com/akira399/dsh-godot-skill)

### Inferences
- The skill is general Godot knowledge that a frontier model already largely has. It adds no project-specific memory or verification discipline.
- Its whole philosophy ("AI independently plans, builds … exports") assumes that the agent's own checks are enough, which is the reverse of the user's rule that UI and art work stays open until the owner confirms it.

### Gaps
- No evidence of real-world use, issues, or evaluations of how much the skill helps.

## What does Smalldy/godot-bridge contain, how does it work, and how mature is it?

### Takeaway
godot-bridge is a native dsh **tool** plugin. It launches the game, talks to an in-game TCP
autoload (`McpInteractionServer`, 127.0.0.1:9090, newline-delimited JSON), and exposes 17
`godot_*` tools. With them an agent can capture screenshots, inject input (key, mouse, gamepad,
touch, InputMap actions), read the live scene tree and UI elements, get/set properties, call
methods, run `eval`, change `time_scale`, run headless static scene operations, compile-check
GDScript, and do bounded headless test runs. All the GDScript is vendored from
tugcantopaloglu/godot-mcp (MIT), so this is a port of that MCP server onto dsh. Maturity: active
and well-engineered for its age. v0.1.0 to v0.2.1 (11 tags) between 2026-08-14 and 2026-10-24, 80
commits, 60 stars, 3 forks, 2 open issues. It was measured on Godot 4.7.2.

### Cited Findings
- Tools (17): `godot_run_project`, `godot_stop_project`, `godot_get_debug_output`, `godot_command` (any interaction-server command), `godot_screenshot` (viewport PNG as base64), `godot_ping`, `godot_set_engine_path`, `godot_headless_op` (16 static ops: read_scene, modify/remove node, attach_script, create_resource, save/create scene, add_node, get_uid, signals…), `godot_run_headless` (`--headless [--quit-after N] [--script]`), `godot_validate_script` (`{valid, errors}` compile check), `godot_set_project_setting`, `godot_manage_autoloads`, `godot_manage_input_map` ("correct Godot 4 keycodes", fixing a Godot-3 keycode bug in godot-mcp), `godot_manage_export_presets`, `godot_create_script`, `godot_create_project`, `godot_export_project`. — [README](https://github.com/Smalldy/godot-bridge)
- `godot_command` commands, from the server's match statement, include: screenshot, click, key_press, key_hold/key_release, mouse_move, mouse_drag, scroll, gamepad, touch, input_state, input_action, get_scene_tree, get_ui_elements, get/set_property, call_method, get_node_info, eval, wait, pause, time_scale, process_mode, get_performance, serialize_state, await_signal/emit/connect/list_signals, play_animation, tween_property, change_scene, instantiate_scene, spawn_node, set_shader_param, camera get/set, viewport, debug_draw, tilemap, audio_*, ui_* (control/text/popup/tree/item_list/tabs/menu/range/theme), render_settings, plus many 3D/net commands. — [plugin/mcp_interaction_server.gd](https://github.com/Smalldy/godot-bridge/blob/main/plugin/mcp_interaction_server.gd); [COVERAGE.md](https://github.com/Smalldy/godot-bridge/blob/main/COVERAGE.md)
- Screenshot implementation: it waits one `process_frame`, then calls `get_viewport().get_texture().get_image().save_png_to_buffer()` and returns base64 with width and height. Click works through `Input.parse_input_event` press, one frame, then release. key_press works either through `Input.action_press/release` or a synthesized `InputEventKey`. — [mcp_interaction_server.gd L400–470](https://github.com/Smalldy/godot-bridge/blob/main/plugin/mcp_interaction_server.gd)
- Architecture: each command spawns a one-shot `node -e` bridge that connects to 9090, sends one line, prints one response line, and exits. The server is single-connection and single-command. Godot is spawned through DSH's raw `subprocess` service rather than the sandboxed shell, because the shell sandbox crashes Godot on `user://` log writes (signal 11). The plugin injects the port and an ownership token through env (`GODOT_BRIDGE_TOKEN`). `godot_run_project` auto-installs the autoload into `project.godot` if it is missing. — [README](https://github.com/Smalldy/godot-bridge); [ARCHITECTURE.md](https://github.com/Smalldy/godot-bridge/blob/main/ARCHITECTURE.md); [server source](https://github.com/Smalldy/godot-bridge/blob/main/plugin/mcp_interaction_server.gd)
- Headless pitfalls documented and handled: (1) an `eval` syntax error under `-d` drops into an interactive `debug>` prompt. Measured: 12,089 break lines (1.78 MB) in 3 s with stdin at EOF, so the default run is now non-debug, and `debug:true` is a "diagnostic mode" that refuses eval and returns a `debuggerTrace`. (2) Godot consumes `-d` before `OS.get_cmdline_args()`, so the flag is passed by env instead. (3) A headless scene without `--quit-after` or `get_tree().quit()` loops forever, and the tool kills it on timeout. (4) A version-manager shim orphans the real Godot process. — [CHANGELOG 0.2.1](https://github.com/Smalldy/godot-bridge/blob/main/CHANGELOG.md); [README Pitfalls](https://github.com/Smalldy/godot-bridge)
- Versions and dates: first commit 2026-08-14; v0.2.0 on 2026-10-01 (GUI config field, DSH 0.2 compatibility); v0.2.1 on 2026-10-24 (eval-debugger deadlock, issue #13); then docs and a landing site only (last commit 2026-11-09, push 2026-11-11). gh metadata as of 2026-11-23: 60 stars, 3 forks, 2 open issues. — [repo](https://github.com/Smalldy/godot-bridge); [CHANGELOG](https://github.com/Smalldy/godot-bridge/blob/main/CHANGELOG.md)
- Godot versions: the README says "Godot 4.x". Measurements cite "Godot 4.7.2-stable win64". No 4.5-specific testing is documented. The vendored upstream says "Tested with Godot 4.7". — [README](https://github.com/Smalldy/godot-bridge); [tugcantopaloglu/godot-mcp](https://github.com/tugcantopaloglu/godot-mcp)
- The repo also carries `.agents/skills/` meant for *developing* the plugin (dsh-plugin-workflow, dsh-plugin-compat-repair), not for game work. — [repo tree](https://github.com/Smalldy/godot-bridge/tree/main/.agents/skills)
- It checks for updates through a GitHub raw fetch at boot and adds a system-prompt notice when an update exists. — [README](https://github.com/Smalldy/godot-bridge)

### Inferences
- `godot_screenshot` returns a single frame as base64 PNG: a cheap, targeted look, not a recording. Together with `time_scale`, `pause`, `wait`, `serialize_state`, and `input_action`, it lets an agent step to a state and take one frame, which is the right primitive in place of huge recordings. There is no built-in deterministic frame stepping, though (no "advance N physics frames"), and no reference-image diffing.
- The server listens on loopback only and allows arbitrary `eval`. That suits local development but must never ship in an export build. The autoload is injected into `project.godot`, so a faithful-remake repo would need to keep it out of release presets or out of the committed config.

### Gaps
- Not run locally (Godot is not installed here). Behavior on Godot 4.5, Linux, and the Compatibility renderer is unverified.
- Contents of the two open issues not read (GitHub API not attached for this repo).

## Which of the user's problems does each plugin address?

### Takeaway
dsh-godot-skill addresses essentially none of the listed problems. godot-bridge addresses
"no visual feedback for the agent" well and "no live playground" partly (inspect and poke a running
game), helps with headless pitfalls, and makes slow pixel loops cheaper through single-frame capture.
Neither plugin helps with agents closing UI/art work on self-referential checks, doc bloat, or
cross-session memory. Those are process and harness problems that no Godot bridge solves.

### Cited Findings
- Problem-by-problem mapping (evidence in the sections above):

| Problem | dsh-godot-skill | godot-bridge |
| --- | --- | --- |
| Agents close UI/art work on self-referential checks | No. Its workflow tells the AI to finish independently, so it slightly *worsens* the problem | No. Screenshots let the agent self-judge more, but there is no human sign-off gate and no reference comparison |
| No visual feedback for the agent | No | **Yes**: `godot_screenshot` (viewport PNG), `get_scene_tree`, `get_ui_elements` (names/types/positions/sizes) |
| Slow pixel-comparison loops with huge recordings | No | **Partial**: single-frame on-demand capture plus `time_scale`/`pause`/`wait` replace recordings. No diffing or golden images, and no deterministic frame-advance |
| Doc bloat as cross-session memory | No (it is itself a 444-line doc, though loaded only on demand) | No |
| Agents losing context across sessions | No | No (`serialize_state` dumps game state, not agent memory) |
| No live playground to see art and in-game effect | No | **Partial**: live running game plus `set_property`, `set_shader_param`, `spawn_node`, `tween_property`, `eval`, so tweaks are visible on the next screenshot. Not an editor/Inspector loop, and changes are not written back |
| Headless test pitfalls | Minimal (only "make sure `--headless --quit` starts") | **Strong**: bounded `godot_run_headless --quit-after`, the eval/debugger deadlock fix, sandbox `user://` crash avoidance, shim warning, `godot_validate_script` |

### Inferences
- For the user's rule that "UI and art stay placeholders until the owner confirms" and that the comparison loop only marks a screen *ready for review*, godot-bridge is a fit as the agent's *eyes*. Closing the ticket still has to stay a human action.
- Layout data from `get_ui_elements` and `get_property` gives numeric parity checks against SWF-derived positions and scales without measuring screenshots, which matches the AGENTS.md rule to generate positions from SWF data rather than from screenshots.

### Gaps
- No published evaluation of how either plugin changes agent outcomes.

## Are there equivalents for Claude Code, Codex, and Cursor?

### Takeaway
Yes. The functionality is common and mostly MCP-based. godot-bridge's direct equivalent is its own
upstream, **tugcantopaloglu/godot-mcp** (157 MCP tools, same autoload and protocol), and many other
Godot MCP servers cover the same ground or more: editor bridges, deterministic playtesting, LSP/DAP.
dsh-godot-skill's SKILL.md ports to Claude Code as-is. Nothing here is dsh-exclusive.

### Cited Findings
- tugcantopaloglu/godot-mcp: "157 tools for AI-driven game development (GDScript and C#/.NET). Tested with Godot 4.7." 525 stars, last push 2026-10-09. It is godot-bridge's upstream for all three vendored `.gd` files. — [tugcantopaloglu/godot-mcp](https://github.com/tugcantopaloglu/godot-mcp); [godot-bridge README](https://github.com/Smalldy/godot-bridge)
- Coding-Solo/godot-mcp: launch the editor, run projects, capture debug output. 6,740 stars, last push 2026-04-16. — [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp)
- Erodenn/godot-mcp-runtime: "lightweight, zero-footprint TypeScript MCP server that lets AI assistants drive the Godot 4.x game engine". 103 stars, last push 2026-11-13. — [Erodenn/godot-mcp-runtime](https://github.com/Erodenn/godot-mcp-runtime)
- 3ddelano/gdai-mcp-plugin-godot (GDAI MCP): editor-plugin MCP for Claude/Cursor/Windsurf/VSCode (create scenes, resources, scripts, read errors). 103 stars, last push 2026-09-11. — [3ddelano/gdai-mcp-plugin-godot](https://github.com/3ddelano/gdai-mcp-plugin-godot)
- beckettlab/beckett-godot-mcp (Beckett): "Zero-sidecar MCP server inside the Godot editor. AI agents (Claude Code, Cursor) inspect, author, run and SEE your game … validate-before-write … Free Lite; Full adds autonomous playtesting." 52 stars. — [beckettlab/beckett-godot-mcp](https://github.com/beckettlab/beckett-godot-mcp)
- masteryee-labs/Open-Godot-MCP: "Deterministic playtesting, multiplayer testing, DAP debugging, LSP, token-efficient. 100% MIT." 15 stars. — [masteryee-labs/Open-Godot-MCP](https://github.com/masteryee-labs/Open-Godot-MCP)
- Other notable servers: satelliteoflove/godot-mcp ("input injection, deterministic playtesting, and live game state", 189 stars, push 2026-11-16); wgt19861219/godot-mcp-enhanced ("Godot 4.5-4.7 … headless + editor + game bridge … recording & fra[me]…", 106 stars); TomasLucasUTN/godot-mcp-bridge (231 tools, undo, DAP debugger, GDScript LSP, runtime play-testing); ryanmazzolini/minimal-godot-mcp (Godot LSP for GDScript validation, 46 stars, push 2026-11-17); youichi-uda/godot-mcp-pro (162 tools including input simulation, 649 stars); yurineko73/Godot-MCP-Native (882 stars). — [gh search "godot mcp"](https://github.com/search?q=godot+mcp&type=repositories), individual repos as named
- Other dsh-native Godot plugins exist: Fromlan/dsh-godot-tool (editor `agent_rpc` addon, 27 tools, 3 stars), gosomea/dsh-godot-ai (22 stars), jeffxuan/dsh-godot-game-studio (7 tools: "audit, test, simulate, validate, and release", 2 stars). — [Fromlan/dsh-godot-tool](https://github.com/Fromlan/dsh-godot-tool); [gosomea/dsh-godot-ai](https://github.com/gosomea/dsh-godot-ai); [jeffxuan/dsh-godot-game-studio](https://github.com/jeffxuan/dsh-godot-game-studio)

### Inferences
- For a Claude Code workflow: use tugcantopaloglu/godot-mcp (or Erodenn/godot-mcp-runtime) to get the same runtime eyes and hands as godot-bridge. Copy only godot-bridge's documented *lessons* (no `-d` by default, `--quit-after`, a real exe instead of a shim, refusing eval in debugger mode), because those fixes may not be upstreamed.
- The servers that advertise "deterministic playtesting" (satelliteoflove, Open-Godot-MCP, Beckett Full) and "recording & frame" capture (godot-mcp-enhanced) target the slow-pixel-loop problem more directly than godot-bridge does.

### Gaps
- Star counts and descriptions come from gh search metadata on 2026-11-23. READMEs of the comparable servers were not read in depth here, so their claims are self-descriptions and unverified.
- "Claude Code Godot skills": no dedicated search was done in this pass.
