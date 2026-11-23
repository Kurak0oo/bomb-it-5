# AI-agent game-development competitions, jams, benchmarks and viral events (2025 – Nov 2026)

Method note (2026-11-23): page fetches failed in this session because vibej.am, colyseus.io, arxiv.org, simonwillison.net and wccftech.com do not resolve under the session's network allowlist. Everything below comes from search-result snippets and summaries of the cited pages, not from full-text reads. Treat exact numbers as "reported by" the cited source. Where sources conflict, both are given. Items marked **[unverified]** rest on one secondary or vendor source.

## What were the events, when, on which engines, and with what rules?

### Takeaway
The flagship AI-built game event is Pieter Levels' (@levelsio) annual web-only Vibe Coding Game Jam: about 1,000+ entries in 2025 and 945 in 2026, with a $35–40k prize pool in 2026 sponsored by Cursor. Around it sit: (a) company-run "AI-feature" jams on itch.io in 2025 (Playful.AI, Player2, It's Alive! AI NPC); (b) Godot-specific vendor jams run by Ziva in 2026; (c) Unity's 24-hour AI Game Jam in Busan (Nov 2025); and (d) Epic's 2026 AI MegaJam on Unreal/UEFN (Nov 12–15 2026, 2,782 submissions, $65k). The largest community Godot jam, the Godot Wild Jam, bans AI outright.

### Cited Findings
**Vibe Coding Game Jam 2025 (levelsio, web)**
- Over 1,000 games entered ("1000+" on the official page); Indie Hackers reports 1,170 games. — [vibej.am/2025](https://vibej.am/2025); [Indie Hackers](https://www.indiehackers.com/post/Uz0wHG4pI3KBOiFhP5YR)
- Silver ($5,000) went to "Vibeware" by @mattgordonxyz. — [vibej.am/2025 (search snippet)](https://vibej.am/2025)
- First place is reported as "Great Taxi Assignment" (Ray Browser calls it "Great Taxi Assignment: Vibe City", an arcade game with a detailed city). **[unverified: aggregator sources only]** — [CO/AI](https://getcoai.com/video/the-best-ai-made-videogames-2025-vibe-coding-game-jam/); [Ray Browser blog](https://playonray.com/blog/levelsio-vibe-jam-winners-ray-vibe-awards)
- Judges included Andrej Karpathy, levelsio and a panel of game developers. Habr reported five judges, including an OpenAI co-founder and a former Tesla AI director. — [Vibe Jam 2026 press page](https://vibej.am/2026/press); [Habr](https://habr.com/ru/articles/895918)
- Sponsors are disputed. Indie Hackers names Bolt.new, CodeRabbit and Lambda API; a vibecoding.app recap says there was "no company sponsor". — [Indie Hackers](https://www.indiehackers.com/post/Uz0wHG4pI3KBOiFhP5YR); contradicted by [vibecoding.app recap](https://vibecoding.app/events/recap/pieter-levels-vibe-code-game-jam-2025)
- From training memory, not re-verified this session: the 2025 rules required at least 80% AI-written code, a free browser game playable without login or downloads, and the jam ran in March 2025 with a 1 April 2025 deadline. **[unverified]** The 2026 rule below (90%+) is sourced.

**Cursor Vibe Jam 2026 (levelsio, web)**
- Ran 1 April to 1 May 2026 (closing 13:37 UTC). Summer Engine reports 945 games submitted, more than 242,000 players, and calls it "the largest AI game jam to date". Sponsors were Cursor, Bolt.new, Glif and Tripo AI. — [Summer Engine guide (vendor)](https://www.summerengine.com/blog/cursor-vibe-jam-2026-guide)
- The prize pool is disputed. The press page (updated 8 May 2026) lists $40,000 ($25k Gold / $10k Silver / $5k Bronze), "more than doubled from 2025"; the jam page lists $35,000 ($20k / $10k / $5k). — [vibej.am/2026/press](https://vibej.am/2026/press); contradicted by [jam.pieter.com/2026](https://jam.pieter.com/2026/)
- The rules required 90%+ AI-written code and rewarded native multiplayer. Colyseus counted 48 entries using its server, which it framed as about 15% ("1 in 7") of online multiplayer entries. — [Colyseus blog](https://colyseus.io/blog/vibe-jam-2026/)
- The winner was an iOS developer's capybara food-delivery game, which won $25,000. **[game title not captured]** — [Wccftech](https://wccftech.com/ios-developer-made-capybara-game-using-vibe-coding-and-won-25000/)

**Company-run "AI feature" jams on itch.io (2025, any engine)**
- Playful.AI Jam #1 (9–18 Aug 2025, 72 entries, $7,000 pool). Champion: "Make it Weirder" ($4k). Excellence Awards: "Galactic Marbles" and "Off the Menu". People's Choice: "Xenomerge". AI features were "must have". — [itch.io](https://itch.io/jam/playfulai-jam-1); [PocketGamer.biz](https://www.pocketgamer.biz/playfulai-kicks-off-first-game-jam-with-a-7000-prize-pool-where-ai-features-are-must-have)
- Playful.AI Jam #2 (19–27 Oct 2025). Champion: "Hungry Blob" ($4,000). — [itch.io](https://itch.io/post/14647900/view-in-topic)
- Player2 AI NPC Jam (21 Jul–7 Aug 2025, any engine, free Player2 API). Winner: "Escape Protocol" ($5,000). — [itch.io](https://itch.io/jam/ai-npc-jam)
- It's Alive! AI NPC Jam (29 Aug–19 Sep 2025, $20,000 in prizes). Winner: "The Daily Ledger" ($5,000). — [itch.io](https://itch.io/jam/its-alive-ai-npc)
- These jams are about AI inside the game (LLM NPCs), not AI building the game. Keep them separate from agent-built game jams.

**Unity AI Game Jam (Busan, Nov 2025)**
- A 24-hour in-person jam hosted by Unity and K-GAMES with OpenAI and Meshy. Top honor: "Swing & Swing" by Team Byeolkkot. — [Inven Global](https://www.invenglobal.com/articles/28843/three-winners-selected-for-unity-ai-game-jam-joined-by-unity-openai-and-meshy)

**Godot-specific**
- Ziva Game Jam (itch.io, 27–30 Mar 2026; voting ended 6 Apr). Entrants had to use only Ziva (an AI agent plugin for Godot) and the Godot engine, and received $1,000 in Ziva credits. Ziva says it is "a tool to assist development, not replace creativity". No winners page found. — [itch.io/jam/ziva-game-jam](https://itch.io/jam/ziva-game-jam)
- Ziva bracket in Micro Jam (from Micro Jam 056 onward). Across jams 056–063, 81 entries declared Ziva and 30 took prize money ($30/$25/$20 podium per jam). Named winners: "Melting Hero" (MJ 058) and "SpaceRat" (MJ 060). **[vendor self-report]** — [Ziva blog](https://ziva.sh/blogs/godot-game-jam-winners)
- The Godot Wild Jam (monthly; e.g. #90, 13–22 Feb 2026) bans "vibe code, AI-generated art, AI-composed music, AI-written dialogue, AI assets of any kind". — [itch.io GWJ 90](https://itch.io/jam/godot-wild-jam-90)

**Epic 2026 AI MegaJam (Unreal Engine / UEFN)**
- Theme reveal 11 Nov 2026; build window 12–15 Nov 2026. Teams of up to five humans "plus unlimited AI agents". Prizes total $65,000 (first place per category $7,500), with continuation grants up to $50,000. — [Unreal Engine news](https://unrealengine.com/news/2026-epic-ai-megajam); [TweakTown](https://www.tweaktown.com/news/114250/epic-games-2026-ai-megajam-offers-65-000-in-prizes-but-the-ai-requirements-are-confusing/index.html)
- Epic first said AI use was mandatory, then reversed: "Our FAQ originally said you had to use AI for the MegaJam. That's our mistake." AI is now optional. — [PC Gamer](https://www.pcgamer.com/software/ai/epic-announces-game-jam-where-you-have-to-use-ai/?type=Games)
- 2,782 submissions by close on 16 Nov 2026. An AI-free game ("fih-aura farming") topped the itch.io popularity ranking, which does not decide winners. Official winners were not found as of 2026-11-23. — [Automaton](https://automaton-media.com/en/news/ai-free-fih-aura-farming-game-tops-popularity-ranking-in-epic-games-major-ai-game-jam/)
- For comparison, the non-AI 2025 Epic MegaJam (16–25 Oct 2025) had 491 entries. — [itch.io](https://itch.io/jam/2025-epic-megajam)

**Other**
- YGG's VibeBlitz game jam crowned "Idle Tactics" as its first winner (Web3/blockchain-game context; date not captured). — [IT Brief](https://itbrief.news/story/vibeblitz-game-jam-crowns-idle-tactics-as-first-winner); [BlockchainGamer](https://www.blockchaingamer.biz/?p=42769)
- Summer Engine (an AI game-engine vendor) runs its own "Summer Games Jam: New Beginnings"; details not captured. — [summerengine.com/jam](https://www.summerengine.com/jam)

### Inferences
- The agent-built game jams that grew big (levelsio's) are web-only. Browser play removes download friction for judges and players, and the AI-percentage rules are honor-system.
- Engine vendors split. Epic and Unity ran AI jams in Nov 2025 and Nov 2026; the Godot community jam (GWJ) bans AI. Godot agent jams come only from third-party plugin vendors (Ziva), so they are small and vendor-run.
- Epic's 2,782 MegaJam entries, against 491 for the 2025 MegaJam, may partly reflect bigger prizes and the AI framing, not AI-built output alone. Popularity went to an AI-free game.

### Gaps
- Full podium for Vibe Jam 2025 (Gold and Bronze) and Vibe Jam 2026 (title of the capybara game, Silver, Bronze) could not be confirmed; vibej.am was unreachable.
- Ziva Game Jam entry count and winners were not found.
- Epic AI MegaJam winners were not yet announced, or not indexed, as of 2026-11-23.
- No Unity- or Godot-official AI jam was found for 2026.

## What did winning/top entries do differently (workflow, tools, human involvement)?

### Takeaway
There is little first-hand winner workflow evidence. What exists points to three things: tight scope in web tech (three.js, PIXI.js), a human steering and play-testing iteratively rather than one-shot prompting, and distribution and build-in-public counting as much as the code.

### Cited Findings
- Hugging Face's VibeGame post argues that one-shot "make me a game" prompting fails. It built a high-level declarative engine on three.js + rapier + bitecs because a raw web stack gave good AI performance but was "too low-level", while Roblox had good abstraction but less openness. — [Hugging Face blog](https://huggingface.co/blog/vibegame)
- Simon Willison (28 Oct 2026) called October 2026 "a new inflection point… for vibe coding computer games", credited Claude Opus 5.5, and said he vibe-coded four games he enjoyed. He reported that telling models to use three.js works well, and he used a WebSockets relay for 2–4 player modes. — [Simon Willison](https://simonwillison.net/2026/Oct/28/vibe-game-development/)
- Indie Hackers on five viral vibe-coded games: a high-quality game or the occasional high-engagement tweet is not enough; creators also built in public. — [Indie Hackers](https://www.indiehackers.com/post/starting-up/how-5-vibe-coded-ai-games-went-viral-despite-their-creators-having-tiny-audiences-VKa1DsSICLniUWvWlsAg)
- Codex Mortis (Steam demo, Dec 2025 – Jan 2026 coverage) was built with Claude Code ("mostly Opus 4.1 and 4.5") in TypeScript + PIXI.js + bitECS inside Electron, with no traditional engine. ChatGPT made the art. Development took about three months. Reception was divided, with near-unanimous rejection reported by Xataka. — [TweakTown](https://www.tweaktown.com/news/109355/codex-mortis-is-a-100-ai-made-roguelite-bullet-hell-and-its-proving-divisive-as-hell-too/index.html); [PC Gamer](https://www.pcgamer.com/games/roguelike/this-roguelite-claims-to-have-the-dubious-honor-of-being-the-worlds-first-fully-playable-game-created-100-percent-through-ai-in-a-milestone-for-slop-everywhere/); [Xataka](https://www.xataka.com/videojuegos/primer-videojuego-hecho-integramente-ia-llega-a-steam-rechazo-jugadores-ha-sido-casi-unanime)
- In a solo three.js jam write-up, the AI pair-programmer switched to instanced rendering for about a 150x performance gain over separate draw calls. — [DEV](https://dev.to/furic/building-unmask-the-city-a-solo-game-jam-journey-with-ai-pair-programming-44b4)
- Vibe Jam 2026 multiplayer entries leaned on off-the-shelf networking (Colyseus in about 1 in 7 online-multiplayer entries; Peer.js P2P in others). — [Colyseus](https://colyseus.io/blog/vibe-jam-2026/); [three.js forum](https://discourse.threejs.org/t/vibe-weavers-a-vibecode-open-playground-p2p-colaborative-game-project/85381)
- Viral web game "Color" by designer Geoff Teehan (reported June 2026) reached about half a million plays in days. — [search snippet, source list in Simon Willison / Indie Hackers results]; **[unverified: primary source not opened]**
- A father-and-son AI game suite, "Dialed", reportedly reached 26 million plays. **[unverified]** — [Complete AI Training](https://completeaitraining.com/news/father-and-son-build-ai-game-suite-dialed-with-26-million/); [Let's Data Science](https://letsdatascience.com/news/father-son-duo-build-viral-ai-game-suite-c181fab0)

### Inferences
- The pattern that works: small scope, a browser runtime the agent can run and the human can test instantly, mature JS libraries for physics and networking (rapier, Colyseus), and a human acting as designer and play-tester.

### Gaps
- No winner-authored post-mortem of a Vibe Jam Gold game was found.
- No breakdown of how much human versus AI code was in winning entries, beyond the rule thresholds.

## What common failure modes did organizers or participants report?

### Takeaway
The reported failures are engine-state errors (scene, node and signal files), visual and graphics work the agent cannot see, scaling past small scope, performance, and reception: "slop" backlash, clones of clones, and organizers stumbling over AI rules.

### Cited Findings
- Ziva (a vendor) says general agents "hallucinate node paths, misread signal connections, and produce scene files that crash on load" in Godot or Unity. — [DEV / Ziva](https://dev.to/ziva/vibe-coding-works-for-web-apps-it-breaks-on-game-engines-heres-why-446g)
- A Godot asset-library tool warns that .tscn, .tres and project.godot "break silently when AI agents edit them as plain text" (UIDs, sub-resource IDs, signal connection blocks). — [Godot Asset Library](https://godotengine.org/asset-library/asset/5482)
- A Godot forum post-mortem of a failed vibe-coded metroidvania concluded that current agents "aren't capable of building systems as complex as a metroidvania". — [Godot Forum](https://forum.godotengine.org/t/post-mortem-of-my-failed-attempt-to-vibe-code-a-metroidvania-game/137567)
- In GameDevBench, success drops from about 51% on gameplay tasks to about 33% on 2D graphics tasks. Visual or video feedback helps (GPT-5.4 from 41.1% to 52.0%; Claude Sonnet 4.5 from 34.4% to 44.7% in an earlier version). — [ICML 2026](https://icml.cc/virtual/2026/poster/64919); [arXiv](https://arxiv.org/html/2602.11103)
- In GameCraft-Bench, the best agent scored core mechanics at 55.34% but content depth at 39.48% and art/presentation at 36.86%. A project that does not launch in the Godot runtime scores zero. — [arXiv 2606.17861](https://arxiv.org/abs/2606.17861); [project site](https://tongxuluo.github.io/gamecraft-bench-website)
- Clones: developers of a viral haystack-game clone complained that their clone was in turn cloned by a vibe coder. — [Kotaku](https://kotaku.com/devs-behind-needle-in-a-haystack-clone-complain-their-clone-has-been-cloned-by-vibe-coder-2000747284)
- "Slop" backlash and contested "first 100% AI game" claims (Codex Mortis). — [PC Gamer](https://www.pcgamer.com/games/roguelike/this-roguelite-claims-to-have-the-dubious-honor-of-being-the-worlds-first-fully-playable-game-created-100-percent-through-ai-in-a-milestone-for-slop-everywhere/)
- Rule confusion at Epic: mandatory AI was announced, then walked back after criticism. An AI-free entry topped popularity. — [PC Gamer](https://www.pcgamer.com/software/ai/epic-announces-game-jam-where-you-have-to-use-ai/?type=Games); [Automaton](https://automaton-media.com/en/news/ai-free-fih-aura-farming-game-tops-popularity-ranking-in-epic-games-major-ai-game-jam/)

### Inferences
- The two biggest technical failure classes, structured engine files and visual correctness, are the ones a text-only agent cannot check without a run-and-look loop. Tools that add a headless run, screenshots or video, or scene parsers target exactly these.

### Gaps
- No organizer-published statistics on broken or unplayable submissions (e.g. the share of Vibe Jam entries that failed to load).

## Are there leaderboards/benchmarks measuring agents' game-building ability (and Godot-specific ones)?

### Takeaway
Yes, and the main ones use Godot. GameDevBench (Feb 2026, ICML 2026) and GameCraft-Bench (Jun 2026) both run in Godot; the best agents solve only about 41–54%. Further 2026 papers (CEGame-Bench, GameLogicBench, WebGameBench, RSIGame, Recursive Game Creator) were seen but not verified.

### Cited Findings
- **GameDevBench** (arXiv 2602.11103, Feb 2026; ICML 2026; PMLR v306). Tasks come from web and video tutorials and run in Godot. Task counts differ by version: 132 tasks (v1, best 47.0%), 358 tasks (best baseline 49.0%), and 333 tasks (camera-ready, best agent plus method 53.8%). The 333-task mix is 33.3% 2D graphics/animation, 26.7% 3D, 20.1% UI and 19.8% gameplay. Multimodal feedback (screenshots and video) is the main lever. The repo README claims a GPT run of 229/333 (68.8%). **[unverified]** — [arXiv](https://arxiv.org/html/2602.11103); [ICML](https://icml.cc/virtual/2026/poster/64919); [PMLR](https://proceedings.mlr.press/v306/chi26a.html); [Gitee mirror](https://gitee.com/ccran/gamedevbench); [DEV summary](https://dev.to/yujia_zhang_0328/gamedevbench-shows-where-multimodal-coding-agents-still-break-4c5h)
- **GameCraft-Bench** (arXiv 2606.17861, Jun 2026). 140 Godot tasks across 15 game families, judged end to end as playable games. A GPT-5.5-based judge scores sampled frames and videos against a rubric. Best: Claude Code with Opus 4.7 at 41.46%; GPT-5.5 via Codex at 39.49% **[secondary]**. Also tested: Kimi-K2.6 and MiMo-2.5-Pro. — [arXiv](https://arxiv.org/abs/2606.17861); [project site](https://tongxuluo.github.io/gamecraft-bench-website); [AI Weekly](https://aiweekly.co/alerts/claude-code-tops-ai-game-building-benchmark-at-41)
- A follow-up evaluates the same tasks in Godot and Phaser with a Qwen-based judge, so its scores are not comparable. — [search summary of related arXiv work](https://arxiv.org/pdf/2609.39045) **[unverified]**
- Seen only as titles or refs and **[unverified]**: CEGame-Bench (arXiv 2610.26098, long-horizon game creation), GameLogicBench (arXiv 2609.21562, tick-level state assertions for runtime game logic), WebGameBench (arXiv 2605.17637), RSIGame (2609.39045), Recursive Game Creator (2610.08621). A Phaser-based "VibeGame" multi-agent framework is reported to top general harnesses on a 2D benchmark. — [arXiv CEGame-Bench](https://arxiv.org/pdf/2610.26098); [arXiv GameLogicBench](https://arxiv.org/pdf/2609.21562); [AI Weekly](https://aiweekly.co/alerts/vibegame-tops-general-llm-harnesses-on-2d-game-benchmark)

### Engines: where agents do best and why
- Web/JS (three.js, PIXI, Phaser) dominates successful agent-built games. Simon Willison says three.js works well with models; Codex Mortis skipped an engine entirely; the HF VibeGame post rates the raw web stack strong for AI performance but low-level. — [Simon Willison](https://simonwillison.net/2026/Oct/28/vibe-game-development/); [Hugging Face](https://huggingface.co/blog/vibegame)
- Godot is argued to suit agents: plain-text .tscn and project.godot, headless build and web export from one command (ABA Games). The counter-view is that those text formats are fragile when agents edit them (asset-library tool, Ziva). Note: C# Godot 4 projects cannot export to web, so web targets need GDScript. — [DEV / ABA Games](https://dev.to/abagames/godot-is-well-suited-for-game-development-with-ai-coding-agents-2lcm); [DEV / Ziva](https://dev.to/ziva/why-godots-architecture-makes-it-the-best-engine-for-ai-assisted-development-5e8f)
- Unity and Unreal are covered by vendor jams (Unity Busan 2025, Epic MegaJam 2026), but no public benchmark of agents in those engines was found.

### Why the topic went viral in late 2026
- Simon Willison's 28 Oct 2026 "inflection point for vibe coding games" post, crediting Claude Opus 5.5, plus his 20 Oct 2026 "battledrones" game post. — [Simon Willison](https://simonwillison.net/2026/Oct/28/vibe-game-development/); [Battledrones](https://simonwillison.net/2026/Oct/20/battledrones/)
- Epic's AI MegaJam controversy (Oct 2026 announcement and walk-back), then 2,782 submissions closing 16 Nov 2026. — [PC Gamer](https://www.pcgamer.com/software/ai/epic-announces-game-jam-where-you-have-to-use-ai/?type=Games); [Automaton](https://automaton-media.com/en/news/ai-free-fih-aura-farming-game-tops-popularity-ranking-in-epic-games-major-ai-game-jam/)
- A run of benchmark papers (GameCraft-Bench in Jun 2026, more in Sep–Oct 2026), GameDevBench at ICML 2026 (Jul 2026), and media coverage ("Claude Code tops AI game-building benchmark at 41%"). — [AI Weekly](https://aiweekly.co/node/3103)

### Inferences
- Benchmarks converge on Godot because it is open source, scriptable headless and text-serialized, which makes it automatically gradable. Viral, shipped, agent-built games converge on web/JS because the agent and the player share one fast-feedback runtime. Godot's agent weakness, as the benchmarks measure it, is visual and scene correctness, which multimodal feedback partly fixes (about +10 points in GameDevBench).
- The late-2026 virality comes from three things at once: a model step (Opus 5.5, as Simon Willison names it), Epic putting AI jam framing on a major engine, and benchmark headlines.

### Gaps
- No public, continuously updated leaderboard (in the style of LMArena) for game-building agents was found; the benchmarks are paper snapshots.
- No Unity- or Unreal-specific agent benchmark was found.
- November 2026 coverage beyond the Epic MegaJam close was sparse in search results.
