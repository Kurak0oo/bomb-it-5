# Vibe Jam write-ups: winners' and top entrants' workflows, 2025 and 2026

Scope: the Vibe Coding Game Jam 2025 (Bolt-sponsored, organised by @levelsio) and the Cursor Vibe Jam 2026. Research date: 2026-11-24.

Labels: **[1st]** means a first-hand account by the entrant or organiser. **[2nd]** means secondary (news, aggregator, curated list). Every item carries its publication date.

Retrieval notes:
- vibej.am redirects to vibejam.com. WebFetch could not resolve it, but curl through the proxy worked.
- The site exposes a games API at `vibejam.com/api` (engine, genre, multiplayer and is_up for all 2,028 entries) and an MCP server, per [llms.txt](https://vibejam.com/llms.txt).
- X posts were read as JSON through the api.fxtwitter.com mirror. The tweet URLs below are the canonical x.com links.
- Two first-hand sources were blocked by Cloudflare and could not be read: the 2026 winner's Medium article and Reddit. They are reported here only through secondary quotes.

## Key question 1: How did the winning workflows differ from typical entries? (per-entrant profiles, organiser/judge commentary, failure rates)

### Takeaway
The winners were experienced developers. Each spent about 2 to 4 weeks of sustained, directed work (60 to 65 hours in 2025; 15 intense days and about 27k LOC in 2026). They ran a multi-tool AI pipeline: a coding agent plus separate image, 3D, music and SFX generators. They put unusual effort into polish, audio and "details", and several built their own level or map editors instead of prompting geometry. Judges rewarded finished-feeling games with strong atmosphere. Typical entries were first-time game makers, often submitted in the final days. Many have since gone offline: 42% of 2025 entries and 13% of 2026 entries.

### Results and judging (organiser, first-hand)
- **2025 results** ([1st] levelsio, 2025-04-23, [levels.io](https://levels.io/winners-of-the-2025-vibe-code-game-jam); [vibejam.com/2025](https://vibejam.com/2025/)):
  - Gold, $10,000: *The Great Taxi Assignment* by @TomasBencko
  - Silver, $5,000: *Vibeware* by @mattgordonxyz
  - Bronze, $2,500: *Vector Tango* by @scobelverse
  - Judges: @karpathy, @timsoret, @mrdoob, @s13k_ and levelsio. More than 1,000 games entered.
  - The 2025 rule was "at least 80% written by AI (code, assets, etc)". ThreeJS was recommended.
- **2025 jury quotes on the winners** ([1st] levelsio post, 2025-04-23, [levels.io](https://levels.io/winners-of-the-2025-vibe-code-game-jam)):
  - Taxi: "I love it, it's funny, cute, well executed, cool music"; "Crazy taxi, cool vibes, great car physics, feels good, instant fun, level design a bit flat"; "A little bit too easy."
  - Vibeware: "Super fun concept… original idea and looks relatively polished"; "Fun concept, but janky."
  - Vector Tango: "Looks pretty clean/polished, air traffic control simulator"; "elevation control (A/Z) is unconvenient."
- **2025 organiser comment** ([1st] levelsio, 2025-04-23, [levels.io](https://levels.io/winners-of-the-2025-vibe-code-game-jam)): "Vibe coding still has its limitations… the vast majority of people participating never made a game before!"
- **2026 results** ([1st] levelsio, 2026-06-17, [X](https://x.com/levelsio/status/2067364066193203333); [levels.io](https://levels.io/vibe-jam-2026-winners-quality)):
  - 1st, $25,000: *A Game About Capybaras Delivering Food* by @leocooout
  - 2nd, $10,000: *Fanto's Mega-Mart* by @e_c_t_o
  - 3rd, $5,000: *WenWare* by @underpaid_mom
  - Special awards: HALDANE-4 (Most Original), Null Range (Best Art Direction), WenWare (Most Played), Kanso (Most Zen), Swingers (Most Unhinged), FULL SEND (Most Portal Transfers), Köttbullar Metal (Funniest), Tiny Skies (Most Polished), Undersphere (Unique Concept), Eyrie (Most Atmospheric), BeetleJump (Rage-Quit), Almost Surgery (Most Cursed).
- **2026 rules** ([1st] [vibejam.com](https://vibejam.com/); press release updated 2026-11-24, [press](https://vibejam.com/2026/press)):
  - At least 90% of the *code* written by AI.
  - New games only. Web, no login, "almost instantly in the game" with no loading screens.
  - Multiplayer preferred. Any engine, ThreeJS recommended. One entry per person.
  - A required JS tracking widget, plus optional portal "webring" links between games.
- **2026 judging process** ([1st] levelsio, 2026-05-01, 2026-05-11 and 2026-06-04, X posts [1](https://x.com/levelsio/status/2050213288609235424), [2](https://x.com/levelsio/status/2053941166085693647), [3](https://x.com/levelsio/status/2062644166849622066)):
  - 945 games submitted, 242,212 players, about 12M views on X.
  - Pre-vetting used "some help from AI (like if the games load at all)".
  - Round 1: a game advanced if either levelsio or @s13k_ liked it.
  - Round 2: the top 100+ were rated 0 to 10, "trying the games extensively".
  - Round 3: the top 25 went to the external judges Tim Soret (Odd Tales), Eric Zakariasson (Cursor), Nicola Manzini (VibeSail) and Alessandro Schiassi (Over Jump Rally).
- **What separated the 2026 winner, in the organiser's words** ([1st] levelsio, 2026-06-18, [X](https://x.com/levelsio/status/2067437528320512144)):
  - @s13k_ confirmed it "really is the highest rated game by the judges".
  - Levelsio's reasons: "it's just well made, has Playstation style retro graphics, a great AI-generated soundtrack and just all around there's so much effort gone into the details".
  - The details include an in-game phone with "Capy Maps", a music player and "Capy Tok".
- **Year-over-year quality**:
  - Levelsio ([1st], 2026-05-01, [X](https://x.com/levelsio/status/2050213288609235424)): "last year's games looked clunky and basic, this year's games are starting to look like stuff you could find on Steam".
  - Tim Soret ([1st] quoted by levelsio, 2026-06-17, [levels.io](https://levels.io/vibe-jam-2026-winners-quality)): "Some of them are getting close to be genuine games… next year (or maybe 6 months at the given rate), it will match many game devs. Not the top 20%, but a 3rd year student yes!"
  - Levelsio, day 3 ([1st], 2026-04-05, [X](https://x.com/levelsio/status/2040936355375788137)): "it's easier to build something that looks good and is playable! But you still need creativity".
- **Submission timing** ([1st] levelsio daily threads, [2026-04-23](https://x.com/levelsio/status/2047445128827047972), [2026-04-27](https://x.com/levelsio/status/2048773325401305214), [2026-04-30](https://x.com/levelsio/status/2049986812299612460), [2026-05-01](https://x.com/levelsio/status/2050182736673911136)):
  - Submission counts were 296 with a week left, 403 with 3 days left, 674 on the last day, and 945 final. About 200 arrived in the last 24 hours.
  - Levelsio (2026-04-16, [X](https://x.com/levelsio/status/2044886250289598965)): "I guess you need 2 weeks to really get going."

### Failure and attrition rates
- **Link rot from the jam API** ([2nd] analysis by Michael Scheiwiller, data as of 2026-09-24, [blog](https://www.michaelscheiwiller.com/blog/vibe-jam-link-rot)):
  - 42% of 2025's 1,083 games and 13% of 2026's 945 games are offline.
  - Half of the 2025 custom-domain games are offline.
  - 12 of 14 Railway-hosted 2026 games died within five months. Static hosts lost 0 to 20%.
  - My own check of the API on 2026-11-24 confirms the totals: 2025 had 1,083 games with 632 up; 2026 had 945 with 826 up ([vibejam.com/api](https://vibejam.com/api)).
- No organiser figure exists for the share of games that did not load or were unfinished. Levelsio only says AI pre-vetting checked "if the games load at all" ([X](https://x.com/levelsio/status/2050213288609235424)).

### Per-entrant profiles

**1. The Great Taxi Assignment: 2025 Gold** ([1st] Tomáš Bencko, Cassovia Code blog, 2025-04-11, [article](https://cassoviacode.com/i-tried-vibe-coding-how-i-created-gta-with-artificial-intelligence/))
- **Genre and engine**: GTA: Vice City tribute scoped down to taxi missions. Three.js for rendering, Cannon-es for physics, Vite for builds. "Modular, object-oriented" code. Client-only, hosted on Netlify, music streamed from SoundCloud.
- **Harness and model**: Cursor with Claude Sonnet 3.7, with Gemini 2.5 Pro mentioned. A secondary list also says Cursor + Claude 3.7 Sonnet ([2nd] [awesome-ai-built-games](https://github.com/lappemic/awesome-ai-built-games)).
- **Other tools**: GPT-4o image generation for billboards (it replaced a Stable Diffusion plan mid-jam), Suno for music, ElevenLabs for SFX with "a bit of manual tweaking".
- **Human role**:
  - Design and map authoring: the map blueprint was drawn by hand in Adobe Illustrator and imported as SVG. Buildings were placed as primitives in the Three.js online editor.
  - The human had AI write two-way converters between the editor format and the game format.
  - He paused coding "for several days" to produce the music.
- **Time and cost**: 65 hours over about 2 weeks, €72 in AI services.
- **Failures and recoveries**:
  - The physics car model failed repeatedly: wheels rotated 90°, rocking the car could launch it "into space", the chassis lagged the wheels, and it flipped on turns.
  - "I finally landed on a satisfying driving model… on my fourth attempt. That meant restarting the project from scratch—empty repo and all—four times."
  - "LLMs… struggle with grasping the physical world, spatial orientation, axes, and directions."
- **What he says was decisive**:
  - His prior game-dev experience: "huge added value when experienced developers use these tools".
  - Audio for atmosphere: "music sometimes accounts for as much as 50%".
  - His warning: without planning and code oversight, models "layer patch upon patch".

**2. A Game About Capybaras Delivering Food: 2026 1st place**
- **Sources**: [1st] @leocooout X posts dated 2026-04-29 ([X](https://x.com/leocooout/status/2049610251381756307)) and 2026-06-18 ([X](https://x.com/leocooout/status/2067423255770857709)). The [Medium write-up](https://leocoout.medium.com/how-i-made-25k-in-15-days-with-a-game-built-entirely-by-claude-code-94b3b817f0ce) was not readable (Cloudflare). Reddit quotes come via [2nd] [Wccftech](https://wccftech.com/ios-developer-made-capybara-game-using-vibe-coding-and-won-25000/) and [2nd] [Admix](https://admix.software/blog/ai-game-won-25k-vibejam-2026), dated 2026-07-12.
- **Genre and engine**: cozy open-world delivery sim with optional multiplayer, set in Rio. Three.js. The API lists it as ThreeJS, Adventure/Simulation/Racing, multiplayer Yes ([API](https://vibejam.com/api?q=capybara)).
- **Harness and model**:
  - Claude Code. Admix says Opus 4.7. Wccftech says he upgraded from the 5x to the 20x plan.
  - Plan mode before each feature ([2nd] search snippet of the Medium post).
  - In his 2026-06-18 post he also credits Cursor and "gpt".
- **Other tools**: Tripo (image-to-3D for all models), Suno for music, ElevenLabs for audio. Admix adds GPT Images-2 and Grok for textures. Multiplayer is a single global lobby over a Cloudflare WebSocket relaying position and item stack, about 10 Hz per Admix ([2nd] Wccftech quoting Reddit).
- **Workflow** ([2nd] Wccftech quoting his Reddit post):
  - "I spent most of my time brainstorming, planning, and playing rather than generating code."
  - "I ran 2–3 Claude Code sessions at once, each working on a different part of the code to avoid conflicts."
  - "New features always used a fresh session with no context; I kept one long-running session for bugs that needed more context."
- **Built in advance vs. improvised**: AI could not generate a 3D map, so he used an editor to build the city by hand, which took several hours. Admix lists AI-built in-game tools: a map, terrain and road editor, a cutscene editor, a PS1-style texture pipeline, and localization ([2nd]).
- **Scale and time**: 15 days ([1st] 2026-06-18). About 27,000 LOC across 188 commits ([2nd] Wccftech and Admix). He is an iOS engineer ([2nd]).
- **What he says was hardest or decisive** ([1st] 2026-06-18, translated from Portuguese):
  - "I didn't write a line of code, all visual assets were generated and the 3D models all made image-to-3D. The hardest part was and still is the polish of the game and the artistic part, human to human."
  - He credits levelsio's early public feedback while the game was "still raw" as motivating.

**3. Fanto's Mega-Mart: 2026 2nd place** (@e_c_t_o)
- **Genre and engine**: "Rocket-speed shopping in a haunted grocery store", multiplayer with ghost replays. ThreeJS, Action/Racing ([API](https://vibejam.com/api?q=Fanto); [2nd] [awesome-ai-built-games](https://github.com/lappemic/awesome-ai-built-games)).
- **Harness**: listed as Codex ([2nd] curated list). Another directory says the tooling is unpublished, so this is unconfirmed.
- **First-hand account**: none found.

**4. WenWare: 2026 3rd place and Most Played** (@underpaid_mom)
- **Genre and engine**: "time travel geoguessr". Players explore 360° historical scenes and guess place and year. Three.js, multiplayer Yes ([API](https://vibejam.com/api?q=WenWare)).
- **First-hand** ([1st] 2026-04-26, [X](https://x.com/underpaid_mom/status/2048286883080224877)): "Time travel is now possible with gpt-image 2 and codex 5.5."
- **Secondary** ([2nd] @venturetwins, a16z, 2026-04-26, [X](https://x.com/venturetwins/status/2048453326694646124)): "The creator batch generated [panoramas] and then used Codex to make an app."
- The core idea depends on an asset generator's new capability (panoramas) more than on code complexity.

**5. Tiny Skies: 2026 Most Polished** (@DannyLimanseta)
- **First-hand posts**: 2026-04-05 ([X](https://x.com/DannyLimanseta/status/2040791667868070273)), 2026-04-09 ([X](https://x.com/DannyLimanseta/status/2042244467458199644)), 2026-04-28 ([X](https://x.com/DannyLimanseta/status/2049130261204644208)).
- **Genre and engine**: cozy multiplayer flying game ("Animal Crossing" vibes) in Three.js. He was featured by Cursor before the jam as a Cursor game-maker ([1st] Cursor's @edwinarbus, 2026-04-03, [X](https://x.com/edwinarbus/status/2040096305624838400)). [2nd] lists credit Cursor, Suno, ElevenLabs and Tripo3D.
- **Time**: "almost 4 weeks of dev". He had "never launched a multiplayer game before".
- **Decisive, in his words**: shaders. "I highly recommend anyone building a 3D game to add some shaders": noise water, Fresnel rim light, post-processing colour grading, VHS effects, and vertex sway on foliage.
- **Improvised**: he settled on the concept only on day 9 after prototyping.

**6. FULL SEND: 2026 Most Portal Transfers** (@dvassallo with two collaborators)
- **First-hand** ([1st] 2026-04-26, [X](https://x.com/dvassallo/status/2048530791190364374)): "GPT 5.5 helped us get track scenery data from OpenStreetMap."
- **Engine and harness**: HTML5 Canvas top-down racer with multiplayer rooms, leaderboards and a track editor. Cursor + Claude per [2nd] lists. It is the most-played game in the site's analytics: about 58k on the 24h/all-time counters in the page JSON ([vibejam.com](https://vibejam.com/)).

**7. Other first-hand entrant notes (2026)**
- @jasperdeboer, Sky Critters ([1st] 2026-04-16, [X](https://x.com/jasperdeboer/status/2044682969030267101)): "a lot of people are creating their own game editor: Instead of prompting to get the perfect 3d model or map, just let ai create an editor so you have full control." His map, enemies, waves, sounds and shop are all editor-driven.
- @andreeliasdev, Hollowlands, the top Colyseus game ([1st] 2026-04-21, [X](https://x.com/andreeliasdev/status/2046670471760949553)): "My previous game development experience + AI is a powerful combination… What used to take weeks… now is being done in days, allowing me to focus more on the creative part." Multiplayer via Colyseus was added late.
- @taylor_sntx, Null Range, Best Art Direction ([1st] 2026-04-08, [X](https://x.com/taylor_sntx/status/2041917312186429576)): planned order was "1. SOUND (this is so intimidating) 2. Ship upgrades 3. UI/gameplay/performance".
- @davidbmadsen, Mafia City ([1st] 2026-04-08, [X](https://x.com/davidbmadsen/status/2041986240606568762)): Three.js, "all assets generated with MeshyAI".
- @VibeCreAI ([1st] 2026-04-09, [X](https://x.com/VibeCreAI/status/2042116018072346755)): Three.js + R3F, enemies animated via PixelLab, "Built with just Claude Code + Codex"; "Game dev doesn't need a traditional engine anymore!"
- @kiddowdev ([1st] 2026-04-11, [X](https://x.com/kiddowdev/status/2042957949505528237)): used the jam to learn multiplayer with Claude and Glif visuals.
- @rnschiehll ([1st] 2026-04-29, [X](https://x.com/rnschiehll/status/2049491193789071650)): "~3 weeks of sleepless nights"; speed from Tripo and Scenario.
- @MyMoonEnt ([1st] 2026-04-14, [X](https://x.com/MyMoonEnt/status/2044159401678819483)): "A lil' bit of refactoring and a whole lotta playtesting today". Stack: Three.js, SpacetimeDB, Svelte.
- Florian Isikci, Geobeat ([1st] blog 2026-05-28, [dmnshd.gg](https://dmnshd.gg/blog/vibe-jam-2026-geobeat)):
  - About 2 days from concept to finished game, built on Meta's Immersive Web SDK (WebXR).
  - "Testing becomes much more streamlined, as the models can control a whole browser window via MCP tooling."
  - He deliberately chose a minimal concept that needed little development.
- Levelsio's own entry, Voxel Derby ([1st] 2026-04-08/09, [X](https://x.com/levelsio/status/2042015845866447278), [X](https://x.com/levelsio/status/2042322844734923098)): in Bolt, "updates… are immediately visible on the right side as a browser… you skip the whole deployment step". About "a few hours" to a deployed, improved version.

**8. Vibeware (2025 Silver) and Vector Tango (2025 Bronze)**
- Vibeware: the API lists the engine as "Just react.js and webapis", a WarioWare-style microgame collection ([API](https://vibejam.com/api?q=Vibeware)).
- No first-hand write-ups were found for either game.

### Ecosystem and tooling stats
- **Engines** (my count from [vibejam.com/api](https://vibejam.com/api), 2026-11-24):
  - 2025: ThreeJS 642 of 1,083, Godot 5.
  - 2026: ThreeJS 608 of 945, Phaser 60 (plus variants), PixiJS 23, Godot 21, Babylon 11, Unity 11.
  - Multiplayer: 413 games in 2025, 410 in 2026.
  - Scheiwiller reports Three.js at 60% and 65% and Godot rising from 5 to 21 ([2nd] [blog](https://www.michaelscheiwiller.com/blog/vibe-jam-link-rot)).
- **Colyseus** ([2nd, vendor] Colyseus blog, 2026-05-08, [colyseus.io](https://colyseus.io/blog/vibe-jam-2026/)): 48 games, about 5% of all entries and about 15% of online multiplayer entries. "Entries are more polished, the multiplayer integrations feel less like proofs-of-concept, and many submissions ship with progression, persistence, and full game loops."
- **Sponsor framing** ([1st, sponsor] Cursor's @edwinarbus):
  - 2026-04-03 ([X](https://x.com/edwinarbus/status/2040096305624838400)): Cursor 3 has "a built-in browser, image generation, and cloud agents that can playtest".
  - 2026-04-06 ([X](https://x.com/edwinarbus/status/2041275178748117424)): in a same-prompt Three.js test, "Composer 2 finished first… Opus 4.6 felt most game-like. GPT-5.4 had the most detailed UFO and terrain but took the longest."
- **Prepared in advance by the community**:
  - Starter packs with agent skills, e.g. @chongdashu's "8 battle-tested agent skills" with Phaser and Three.js starters ([1st] [GitHub README](https://github.com/chongdashu/vibejam-starter-pack)).
  - A Three.js WebGPU skill because "models have a lot of outdated info on WebGPU" ([1st] @dangreenheck, 2026-04-10, [X](https://x.com/dangreenheck/status/2042464551979876428)).
  - The organiser shipped copy-paste portal sample code ([vibejam.com](https://vibejam.com/)).

### Inferences
- The winners differed from typical entries in five ways:
  - prior dev or game-dev skill (Bencko, Leo, Elias)
  - sustained effort over 2 to 4 weeks, against a field that piled up in the last days
  - a multi-generator asset pipeline with a deliberate art direction (PS1 look, 80s synth, shaders)
  - audio treated as first-class
  - human-built or editor-built levels instead of prompted geometry
- Judges rewarded polish, atmosphere and "details" over technical ambition. The 2025 jury criticised "flat" levels, "too easy" difficulty and jank, so feel and tuning mattered.
- The recurring failure is spatial and physical reasoning: car physics, axes, map generation. The fixes were restarts (Bencko restarted four times) or moving the work into an editor or tool the human controls.

### Gaps
- Leo's Medium article and Reddit thread could not be read directly because of Cloudflare and blocking. Details such as Opus 4.7, 27k LOC, 188 commits and the editor list are secondary.
- There are no first-hand workflow write-ups for Fanto's Mega-Mart, Vibeware or Vector Tango. Codex for Fanto's comes only from curated lists.
- No published Karpathy or mrdoob judging comments were found beyond the anonymous jury quotes in levelsio's 2025 post.
- No organiser statistic on unfinished or non-loading submissions exists. Link rot is the only failure-rate proxy.

## Key question 2: Which parts did humans keep?

### Takeaway
Across accounts, humans kept six things: concept and scope, planning and task decomposition, level and map layout (often in a hand-used editor), art direction and the choice of generated assets, playtesting and feel tuning, and marketing and community feedback. Code was almost entirely delegated. Asset *creation* was delegated to generators, but asset *selection* and polish stayed human.

### Cited Findings
- **Planning and playing over coding**: "I spent most of my time brainstorming, planning, and playing rather than generating code." Leo also orchestrated parallel sessions himself ([2nd] Wccftech quoting Reddit, [link](https://wccftech.com/ios-developer-made-capybara-game-using-vibe-coding-and-won-25000/)).
- **Polish and art stayed human**: "The hardest part was and still is the polish of the game and the artistic part, human to human" ([1st] Leo, 2026-06-18, [X](https://x.com/leocooout/status/2067423255770857709)). He prompted every asset but wrote no code ([2nd] [Wccftech](https://wccftech.com/ios-developer-made-capybara-game-using-vibe-coding-and-won-25000/)).
- **Map and level authoring was manual**:
  - Bencko drew the map in Illustrator and placed blocks in the Three.js editor ([1st] [Cassovia](https://cassoviacode.com/i-tried-vibe-coding-how-i-created-gta-with-artificial-intelligence/)).
  - Leo built his city in an editor by hand ([2nd] [Wccftech](https://wccftech.com/ios-developer-made-capybara-game-using-vibe-coding-and-won-25000/)).
  - de Boer's AI-built editor gave "full control" ([1st] [X](https://x.com/jasperdeboer/status/2044682969030267101)).
- **Music curation was human time**: Bencko paused development for days to make music in Suno and hand-tweaked the SFX ([1st] [Cassovia](https://cassoviacode.com/i-tried-vibe-coding-how-i-created-gta-with-artificial-intelligence/)).
- **Responsibility and review stayed human**: "AI is willing to listen, but it needs someone beside it who understands the big picture… what AI still doesn't take over… is responsibility for the result" ([1st] Bencko).
- **Playtesting**: "a whole lotta playtesting today" ([1st] @MyMoonEnt, [X](https://x.com/MyMoonEnt/status/2044159401678819483)). Judges also played extensively ([1st] levelsio, [X](https://x.com/levelsio/status/2062644166849622066)). Cursor is pitching cloud agents "that can playtest" ([1st, sponsor] [X](https://x.com/edwinarbus/status/2040096305624838400)), but no winner reported using them.
- **Marketing and building in public**:
  - Levelsio reposted progress daily and featured Leo's game from day 14 ([1st] [X](https://x.com/levelsio/status/2044886250289598965)).
  - Leo credits that early feedback ([1st] [X](https://x.com/leocooout/status/2067423255770857709)).
  - Glif sponsored trailer-making because "building the game is only half the battle" ([1st] @fabianstelzer, 2026-04-07, [X](https://x.com/fabianstelzer/status/2041444644475588731)).
  - The Bolt "Most Played" prize and the portal traffic make distribution part of the jam.
- **The "AI-coded" rule covers code, not design**: the 2026 FAQ says "you describe what you want, the AI writes the code, and you guide the creative direction" ([1st] [vibejam.com](https://vibejam.com/)).

### Inferences
- In a Godot-based workflow, the human-kept layer maps naturally onto scene, level and art direction inside the editor, plus playtesting. That matches what the winners did by building or using editors. The agent owns scripts and tooling, including editor tools.
- "Polish" is the bottleneck the winners named. No account reports automated checks covering it.

### Gaps
- No winner published a time breakdown between coding, prompting, asset work and playtesting, beyond Bencko's "several days" on music.
- No evidence was found of automated or agent playtesting by any winner.

## Key question 3: Which lessons transfer to engine-based (Godot) development, and which depend on web/JS (one runtime, instant reload)?

### Takeaway
These lessons transfer: plan-then-execute with fresh agent sessions per feature, parallel sessions on disjoint code areas, editor-driven content instead of prompted geometry, a multi-tool asset pipeline, shaders and audio as cheap polish, restarting when the physics foundation is wrong, and keeping multiplayer optional and static builds durable. These depend on the web/JS setting: the rule set itself (browser-only, instant load), Three.js's dominance in model training data, the one-runtime instant-reload loop (Bolt's live preview, agents driving a browser via MCP), and zero-friction distribution (URLs, portals, X virality). Godot did appear in the jam: 21 entries in 2026, up from 5 ([API](https://vibejam.com/api)). No Godot entry placed.

### Cited Findings
**Transferable**
- **Session hygiene**: a fresh session per feature, one long-lived bug-fix session, and 2 to 3 parallel sessions on separate code areas ([2nd] Wccftech quoting Leo). A plan step before each feature ([2nd] [Admix](https://admix.software/blog/ai-game-won-25k-vibejam-2026)).
- **Tools over prompts for content**: "just let ai create an editor so you have full control" ([1st] [de Boer](https://x.com/jasperdeboer/status/2044682969030267101)). Bencko had AI write converters between the editor and game formats ([1st] [Cassovia](https://cassoviacode.com/i-tried-vibe-coding-how-i-created-gta-with-artificial-intelligence/)). In Godot the editor already exists, so this cost largely goes away.
- **Spatial and physics weakness**: "LLMs… struggle with… spatial orientation, axes, and directions." He restarted four times to get the driving right ([1st] Bencko). This is engine-independent. An engine's built-in physics such as VehicleBody may reduce it, but that is untested here.
- **Asset pipeline**:
  - Tripo image-to-3D, Suno and ElevenLabs ([1st] [Leo](https://x.com/leocooout/status/2049610251381756307)).
  - GPT-4o, Suno and ElevenLabs ([1st] Bencko).
  - Meshy ([1st] [davidbmadsen](https://x.com/davidbmadsen/status/2041986240606568762)), PixelLab ([1st] [VibeCreAI](https://x.com/VibeCreAI/status/2042116018072346755)), Scenario ([1st] [rnschiehll](https://x.com/rnschiehll/status/2049491193789071650)).
  - All of these produce engine-agnostic files.
- **Polish levers**: shader recipes for water noise, Fresnel and post-processing ([1st] [Limanseta](https://x.com/DannyLimanseta/status/2040791667868070273)). Audio counts for atmosphere ([1st] Bencko). Godot has the same shader categories.
- **Agent skills to correct stale model knowledge**: a WebGPU skill exists because models hold outdated info ([1st] [dangreenheck](https://x.com/dangreenheck/status/2042464551979876428)). Starter skill packs exist too ([1st] [chongdashu](https://github.com/chongdashu/vibejam-starter-pack)). The same pattern applies to Godot 4 API drift.
- **Durability**: deploy static, keep multiplayer optional, and publish the source ([2nd] [Scheiwiller](https://www.michaelscheiwiller.com/blog/vibe-jam-link-rot)).

**Web/JS-dependent**
- **Rules force the web**: browser, no login, "almost instantly in the game", ThreeJS recommended ([1st] [vibejam.com](https://vibejam.com/)). Godot web exports carry a large wasm download, which conflicts with the no-loading-screen rule. This is my inference, not tested here.
- **Instant feedback loop**: Bolt shows updates "immediately visible… as a browser" and skips deployment ([1st] levelsio, [X](https://x.com/levelsio/status/2042015845866447278)). Agents "control a whole browser window via MCP tooling" for testing ([1st] [Geobeat blog](https://dmnshd.gg/blog/vibe-jam-2026-geobeat)). Cursor 3 has a built-in browser and playtesting cloud agents ([1st, sponsor] [X](https://x.com/edwinarbus/status/2040096305624838400)).
- **Model familiarity**: "All the models are solid at @threejs in Cursor" ([1st, sponsor] [X](https://x.com/edwinarbus/status/2041275178748117424)). Three.js is 60 to 65% of entries ([2nd] [Scheiwiller](https://www.michaelscheiwiller.com/blog/vibe-jam-link-rot)). @VibeCreAI claims "Game dev doesn't need a traditional engine anymore!" ([1st] [X](https://x.com/VibeCreAI/status/2042116018072346755)).
- **Distribution**: portals, URL sharing and the daily X amplification from levelsio ([1st] [vibejam.com](https://vibejam.com/); [X](https://x.com/levelsio/status/2050216691380969945)). Multiplayer through a Cloudflare WebSocket or Colyseus is lightweight in JS ([2nd] [Wccftech](https://wccftech.com/ios-developer-made-capybara-game-using-vibe-coding-and-won-25000/); [2nd] [Colyseus](https://colyseus.io/blog/vibe-jam-2026/)).

### Inferences
- The JS advantage rests mostly on iteration latency and agent observability: the agent can reload and inspect the running game itself. A Godot workflow should rebuild these with headless runs, scripted scene tests, and screenshot capture via the CLI.
- Single-file or monolithic JS games ("Technical Masterpiece in a Single File", a 2026 entry pitch in the [API](https://vibejam.com/api)) trade structure for speed. That approach does not carry over to a multi-scene Godot project, which benefits more from the planning and per-feature-session discipline.
- Winners leaned on editors for spatial content. That suggests Godot's editor is an asset for the human-kept layer, not a handicap. The handicap lies in the agent's run-and-see loop.

### Gaps
- No first-hand account was found from a Godot-based Vibe Jam entrant, and no comparison of Godot and Three.js agent productivity in this jam.
- No measured data was found on how long reloads take or how often agents iterate in winning workflows.
