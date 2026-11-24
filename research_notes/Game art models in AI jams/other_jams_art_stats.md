# Game art models in AI-permitting jams other than Vibe Jam (2025 to Nov 2026)

Scope and method. Collected 2026-11-24. Pages were fetched with curl through the proxy and read
as untrusted data. WebFetch could not resolve most hosts, itch.io included. itch.io returned
HTTP 429 on most requests, so I paced requests at 6 s apart and backed off 45 to 225 s on each
429. At that rate a full crawl was not possible.

**Coverage.** The per-entry data comes from the two Slapjam jams. These are the only
non-Vibe-Jam AI jams where I could get a public ranked list and also read the entry pages.
- **Slapjam #1:** 59 of 141 rated entries. That is ranks 1–19 (21 of the 22 entries tied into
  those ranks; Folded Keep is missing) plus a systematic sample of every third entry from rank 23
  to 141.
- **Slapjam #2:** 38 of the top 40 by Overall (ranks 29 and 40 are missing), out of 211 rated
  entries.

**How each entry was coded.** I read each page's credits or "AI tools used" block and coded it
by hand. Regex was only used for a first pass, because it confuses "ChatGPT used for code" with
"ChatGPT used for images". Each entry got these fields:
- **primary in-game art source:** generated image / generated 3D / art from a platform tool /
  procedural or code-drawn / licensed or human-made / not stated;
- **image models used in the game itself;**
- **image models used only for cover, promo or reference art;**
- **3D generators;**
- **audio generators.**

The other jams (Epic AI MegaJam, Unity AI Game Jam Busan, Ziva Micro Jam bracket, Rosebud No
Slop, Shanghai AIGC game track, VibeBlitz, Tripo Portal Pass, Supercell) have rules and
placement facts only. None gave per-entry art-model data I could reach. The scripts, the coded
table (`coded.py`) and the raw pages are in
`/tmp/claude-0/-home-user-bomb-it-5/52544bf5-a639-5dc5-82f2-0623abd835f5/scratchpad/artstats_scripts`
and `.../scratchpad/artstats_other`. These are temporary files.

## Per-jam rules, entry counts, how tools are declared, and art models of placed entries

### Takeaway
Slapjam is the only non-Vibe AI jam with public placements and per-entry tool credits.
- **Image model:** among placed entries the one named image model is OpenAI's GPT image (via
  ChatGPT or Codex). It is the in-game art source in 2 of Slapjam #1's 5 cash winners and in 1
  of Slapjam #2's top 5.
- **Most winners used no image model in the game.** They drew art in code with Claude or Codex,
  used licensed asset packs, or did not say.
- **Other jams:** the Epic AI MegaJam (2,782 entries) has no results until January 2027. The
  Unity Busan jam winners do not name their art tools, although Meshy sponsored it.

### Cited Findings

**Slapjam #1 (itch.io, theme Castles, Sept 28–30 2026)**
- **Rules.** "AI everything. Use any AI tools you like for code, art, audio and design. Tell us
  what you used on your submission page." Entries must be a mobile-portrait HTML5 game. —
  [Slapjam: Is AI allowed in game jams?](https://slapjam.ai/news/is-ai-allowed-in-game-jams/)
- **Field and prizes.** "141 rated entries · 650 ratings · 1 disqualified entry excluded".
  Judges rated Fun, Visual Appeal and Theme Following. Cash winners:
  - 1st: Keep It Crispy, $250
  - 2nd: ECHOES OF CAER VEYR, $100
  - 3rd (tie): ASHEN RAMPART and Castle Courier, $50 each
  - 5th: Crown Snatcher, $50

  — [Slapjam #1 results](https://slapjam.ai/jams/slapjam-1/)
- **How tools are declared.** There are three channels:
  1. Free-text credits on the itch page.
  2. itch.io's AI Disclosure field. 34 of the 36 pages I checked with regex had ticked
     "Graphics".
  3. An optional tools checklist in the submission form. The organizer says it is optional and
     public, and "Blank means unreported, not non-use". I could not read this checklist
     (itch.io 429).

  — [Slapjam FAQ](https://slapjam.ai/)
- **Cash winners and their art sources (entry pages):**
  - **#1 Keep It Crispy (Godot).** Concept art, loading screen, title art, logo, interface and
    attack icons came from "Codex (OpenAI) image generation". All 3D models were "built in
    Blender by script" by Claude Code. Audio is CC0 from Freesound and Kenney. —
    [page](https://juslangit.itch.io/keep-it-crispy)
  - **#2 ECHOES OF CAER VEYR.** "ChatGPT / GPT image generation" was used for "selected visual
    artwork, including illustrated lore material and promotional artwork". The 3D is
    licensed/source assets processed in Blender. ElevenLabs did voices and some SFX. —
    [page](https://aj-insanity.itch.io/echoes-of-caer-veyr)
  - **#3 ASHEN RAMPART.** "Sound, art and voice are AI-assisted; see credits in game". No model
    is named on the page. — [page](https://haruka-apps-games.itch.io/ashen-rampart)
  - **#3 Castle Courier.** "All models, castles, terrain, effects and shaders are generated in
    code. No external art assets." The Suno music did not ship. —
    [page](https://cfrog25.itch.io/castle-courier)
  - **#5 Crown Snatcher.** No tools are named on the page. —
    [page](https://fitzyyxd.itch.io/crown-snatcher)
- **Other top-20 entries that name an image model:**
  - **#13 Castle War.** The castle map came from ChatGPT image generation. The sprites are
    human-made LPC art. — [page](https://yanfroes.itch.io/castle-war)
  - **#19 Castle Dominion** (built with Pixelfork). Character and scene art came from ChatGPT.
    Voices and SFX came from ElevenLabs. Music came from Stable-audio-open-1.0. —
    [page](https://haruka-apps-games.itch.io/castle-dominion)
- **Top-20 entries that used an image model only outside the game:**
  - #10 Hold the Gate: Gemini for the cover only.
  - #14 Sixfold Castle: ChatGPT images as "visual references" only; the in-game art is
    procedural.
  - #15 HAUNT YOUR CASTLE: "Higgsfield (GPT Image 2.5): cover image" only.
  - #15 Keep Shift: ChatGPT for promotional art only; the game uses KayKit 3D and Kenney audio.

  — entry pages linked from [Slapjam #1 results](https://slapjam.ai/jams/slapjam-1/)
- **Sponsored art tools are rare among entrants.** Slapjam #1's art sponsors were AutoSprite and
  PixelLab (both part of the first prize), plus Rosebud and Ziva.
  - In my 59-entry sample AutoSprite appears once (#90 Castlekeep, Raider sprite sheets) and
    PixelLab once (#43 Castle Squads, sprite animations).
  - Rosebud appears as the build platform in 3 entries (#17, #80, #114) and Ziva in 2 (#23
    Siege & Stack "Ziva: Game art", #68 The Torch Bearer).

  — [Slapjam #1 results](https://slapjam.ai/jams/slapjam-1/);
  [guide listing sponsors](https://slapjam.ai/docs/);
  [Castlekeep](https://smahalgavaiya.itch.io/castlekeep-one-more-floor); [Siege & Stack](https://aripolar.itch.io/siege-stack)
- **Other named art models in the lower-ranked sample:**
  - #36 Siege Labyrinth: "OpenArt with Nano Banana 2 and GPT Image 2.5 made the concept art,
    key art, logo, UI ... textures", and "Tripo (image to 3D) turned the 2D art into" the
    models.
  - #58 Vault of Embers: Tripo3D for 3D generation and rigging.
  - #75 Sneaky Kingslayer: "Qwern [Qwen] image edit".
  - #83 The Castle Roll: "GPT Image 2".

  — [Slapjam #1 results](https://slapjam.ai/jams/slapjam-1/) and linked entry pages

**Slapjam #2 (itch.io slug slapjam-ai-2, theme Speed, Oct 29–31 2026)**
- **Field and prizes.** "217 submissions · 211 rated entries · 792 ratings", with a $1,000 cash
  pool. Rosebud (Gold sponsor) paid a $100 "Best Game Hosted on Rosebud" award. —
  [Slapjam #2](https://slapjam.ai/jams/slapjam-2/)
- **Top 5.**

  | Rank | Game | Overall |
  |---|---|---|
  | 1 | Speed Slash | 4.000 |
  | 2 | Escape Velocity | 3.917 |
  | 3 | Shrinestone | 3.750 |
  | 4 | Snailracer | 3.667 |
  | 5 | DragonRacers | 3.667 |

  — [Slapjam #2](https://slapjam.ai/jams/slapjam-2/);
  [itch results](https://itch.io/jam/slapjam-ai-2/results)
- **Top-5 art sources:**
  - **#1 Speed Slash (Godot).** "the code, the music engine and the art were all built together
    with Claude". No image model is named. — [page](https://megumih.itch.io/speed-slash)
  - **#2 Escape Velocity (Phaser).** "All art is drawn in code at runtime (no image files)". —
    [page](https://behlulakdag.itch.io/escape-velocity)
  - **#3 Shrinestone (Godot).** "The 3D model textures, the stone UI ... and the sand-wind/dust
    effects are GPT-generated images". The texture routes are documented in a public
    ART_LOG.md. — [page](https://innollia.itch.io/shrinestone)
  - **#4 Snailracer.** No tools are named. —
    [page](https://oskariolli.itch.io/snailracer-fast-as-shell)
  - **#5 DragonRacers (Three.js).** "Dragon model generated with Meshy". —
    [page](https://jeremieagee.itch.io/dragonracers)
- **Ranks 6–39, named art models:**
  - #6 TRAILBLADE: "some of the art made with ChatGPT".
  - #13 Doorbell Dash: "Google Gemini (Nano Banana): all 16 characters ... the porch, the
    hallway and the door", with Lyria for music.
  - #23 Don't Shake Us!: "Art ... OpenAI Codex".
  - #34 Rush Time: "ChatGPT image generation".
  - #9 Inkerial: cover only, "AI image model (via ElevenLabs Creative)".
  - #10 Live fast: cover only, Gemini.
  - #28 JOUST!: OpenAI image only as "concept art used as the look target"; no AI images ship.
    Music came from "TapTap Maker (AI music generation)".
  - #8 Turbo Sloth and #11 Breakfast Rush: built with the Hark agent ("code, art, music and
    sound").
  - Four entries (#12, #14, #30, #31) have identical "Made with ... Cline" credits and no art
    tool.

  — [itch results](https://itch.io/jam/slapjam-ai-2/results) and linked entry pages

**Ziva Micro Jam bracket (Micro Jam 056–063, itch.io)**
- Micro Jam is a 48-hour jam held every two weeks.
  - 81 of 500 ranked entries in 056–063 declared Ziva, a Godot AI agent, in a submission
    question. 30 of them won bracket prizes ($675 in total).
  - Ziva's own blog says Ziva entries averaged 2.50 against 2.56 for the rest of the field.
  - The blog names no art models.

  — [Ziva blog (vendor)](https://ziva.sh/blogs/godot-game-jam-winners)
- **AI rule change.** Micro Jam 069 (Nov 14–16 2026) says "Micro Jam has banned generative AI
  for art and audio" and allows AI only for code. The page for 070 still says "Yes, AI is
  allowed". This is per Slapjam's survey; I did not fetch the Micro Jam pages, so it is
  second-hand. — [Slapjam AI game jams 2026](https://slapjam.ai/news/ai-game-jams-2026/)

**2026 Epic AI MegaJam (Unreal Engine / UEFN, itch.io)**
- **Dates and rules.** The jam ran Nov 12–16 2026 with the theme "Director's Cut".
  - Rules encouraged "asset generation and coding agents", but the FAQ says "Do I have to use
    AI? No". AI usage does not affect eligibility or score.
  - Sponsors include Anthropic, Google, OpenAI and SpaceXSI.
  - 2,782 submissions were received.

  — [Automaton](https://automaton-media.com/en/news/ai-free-fih-aura-farming-game-tops-popularity-ranking-in-epic-games-major-ai-game-jam/);
  [UE forum FAQ](https://forums.unrealengine.com/t/vibe-your-way-to-50k-the-2026-epic-ai-megajam-is-coming/2843983)
- **Declaration.** Entrants must "Declare any prompts, scripts, or assets you made before the
  jam". Teams can have up to 5 humans plus unlimited agents. The in-person venue had teams from
  "Anthropic, Google, Meshy, OpenAI, SpaceXSI". —
  [UE forum](https://forums.unrealengine.com/t/vibe-your-way-to-50k-the-2026-epic-ai-megajam-is-coming/2843983)
- **No results yet.** Winners are due by Jan 29 2027. The itch "Popular" leader is PolyCube's
  LSD:FIH, which says "no AI was used to make this game". Popularity does not decide
  placement. — [Kotaku](https://kotaku.com/epic-ai-megajam-game-jam-slop-lsd-fih-aura-farming-tim-sweeney-2000758352);
  [Automaton](https://automaton-media.com/en/news/ai-free-fih-aura-farming-game-tops-popularity-ranking-in-epic-games-major-ai-game-jam/)
- **Prizes.** About $65,000 in total, plus continuation grants of up to $50,000. —
  [TweakTown](https://www.tweaktown.com/news/114250/epic-games-2026-ai-megajam-offers-65-000-in-prizes-but-the-ai-requirements-are-confusing/index.html)

**Unity AI Game Jam (BEXCO Busan, Nov 18–19 2026, 24 h, before G-STAR)**
- **Format and sponsors.** Creators were selected by document screening, with tools including
  Unity CLI and the Codex plugin. Sponsors were OpenAI (credits and on-site engineers) and
  Meshy ("credits to generate 3D assets from text and images"); every participant also got $50
  of Unity AI credit.
- **Winners:**
  - Swing & Swing (Team Byeolkkot) won the popularity vote.
  - Colla-Zoo won the Unity CLI prize.
  - Dungeon Tycoon won the OpenAI prize; it used only $0.26 of its $500 API credit.
- **No art tools are named for any winner.**

  — [Inven Global, results](https://www.invenglobal.com/articles/28843/three-winners-selected-for-unity-ai-game-jam-joined-by-unity-openai-and-meshy)
- **Participant count conflicts.** The results article says 54 creators; the day-1 article says
  55. The day-1 photo caption reads: "Generating concept art and running it through Meshy AI
  to inspect the 3D model takes just a few minutes". —
  [Inven Global, day 1](https://www.invenglobal.com/articles/28782/unity-openai-and-meshyai-gather-for-unity-ai-game-jam)

**Other jams (rules and podiums only, no per-entry art data)**
- **Shanghai International AIGC Innovation Contest, game track (Tencent-backed; awards Sept 30
  2026).**
  - 186 entries, 18 finalists, 9 awards.
  - Ecosystem partners were V2Fun (3D generation) and Meowa.ai (an AI game platform that
    exports Godot projects). Tencent Cloud supplied its multimodal models, text through 3D.
  - Winners include 《GAZE IN SHADOWS 摩登迷城》, 《磁带侦探》 and 《崇祯模拟器》. No tools are named
    per winner.

  — [gcores](https://www.gcores.com/articles/220684)
- **VibeBlitz (vibecode.game with Minds/Animoca, Aug 2026).** More than 250 participants and 72
  games. Entrants built with a "Game Designer Mind" on the platform. The winner was Idle
  Tactics: Ascension. No art models are named. —
  [IT Brief](https://itbrief.news/story/vibeblitz-game-jam-crowns-idle-tactics-as-first-winner)
- **Rosebud No Slop Hackathon (date not stated).**
  - Winners were Echo Seeker, then Shadowfall, then Floppy Capybara.
  - The text calls the 2nd-place game "Solar Rush" in one place, which is an internal
    inconsistency.
  - Builders used "models from Freepik, ElevenLabs, and Rosebud". Freepik, Fal and ElevenLabs
    sponsored the event.

  — [Rosebud blog](https://lab.rosebud.ai/blog/no-slop-hackathon-ai-games-rosebud)
- **Sponsor-locked AI jams.**
  - Tripo 3D Game Jam "Portal Pass" (Jan 2026): "The primary 3D assets used in the game scenes
    must be generated by Tripo". Results moved to Tripo's Game Hub, an SPA I could not read.
  - Jabali AI Game Jam and GDC 2026 AI Game Jam: these required Jabali Studio.
  - Supercell Global AI Game Hack (Feb 6–8 2026): AI required; no winners list found.

  — [Slapjam rules survey](https://slapjam.ai/news/is-ai-allowed-in-game-jams/);
  [Tripo GameHub](https://gamehub.tripo3d.ai/games)
- **Jams with mandatory disclosure.**
  - Official 2026 Unity Game Jam: "Generative AI may be used for any part of a submission,
    provided it is disclosed on the submission page". 3,779 had joined by Nov 10.
  - All Tools Allowed: "No disclosure means no entry".
  - AI Browser Game Jam (Focaccai): AI required and an "AI Usage" rating category; it grew to
    320 entries in round 5.

  — [Slapjam AI game jams 2026](https://slapjam.ai/news/ai-game-jams-2026/)
- **Jams that ban AI art (context only).** GMTK bans AI art and audio. Brackeys, Pirate
  Software, Kenney, Godot Wild Jam, Mini Jam and Scream Jam ban AI wholly or for assets. —
  [Slapjam rules survey](https://slapjam.ai/news/is-ai-allowed-in-game-jams/)

### Inferences
- **What winners actually used for art.** The modal top-placed Slapjam entry did not ship
  generated raster art. It either had an agent draw everything in code or used CC0/licensed
  packs.
  - Where an image model did ship in a placed entry, it was OpenAI's GPT image.
  - Keep It Crispy and Shrinestone used it for UI, icons and textures over code- or
    Blender-built 3D, not as the whole look.
- **For a 2D sprite game like bomb-it-5,** the placed pattern is: an image model for flat UI and
  texture assets, with structure built by script.

### Gaps
- **Unread tools checklists.** I could not read the Slapjam submission-form checklists
  (itch.io 429), so tools left out of page credits are invisible.
- **Coverage holes.**
  - Slapjam #1 rank 19 (Folded Keep) and Slapjam #2 ranks 29 and 40 were not fetched.
  - Slapjam #2 ranks 41–211 were not sampled.
- **Missing results:**
  - Epic AI MegaJam: no results until Jan 2027.
  - Tripo Portal Pass: results are behind a JS app.
  - Supercell, Unity Busan and Shanghai AIGC: no per-entry tool data.
  - Japanese AI jams: I found no qualifying public results.
- **Ziva's ART_LOG.** Ziva's art usage inside Micro Jam is unknown; only the Ziva yes/no
  question was published.
- **Jams not reached.** AI Browser Game Jam, Ultimate AI-Powered Game Jam and All Tools Allowed
  have public itch results and disclosures. I did not crawl them because of itch.io rate
  limits; they are the best next targets.

## Aggregate: which art and audio models appear among winners versus all entries, and sponsor bias

### Takeaway
Across 97 hand-coded Slapjam entries, OpenAI GPT image is by far the most common image model: 20
entries ship it in-game and 7 more use it only for covers or references. Gemini/Nano Banana is a
distant second (2 in-game).

Top-placed entries lean less on generated images and more on procedural, code-drawn art:
- **Top 10 of both jams (n=21):** 4 of 21 (19%) ship a generated image in-game; 10 of 21 (48%)
  are mainly procedural.
- **Rest of the sample (n=76):** 20 of 76 (26%) ship a generated image in-game; 16 of 76 (21%)
  are mainly procedural.

The 3D generators named are Tripo (2) and Meshy (1). For audio, ElevenLabs (9) and Suno (7 used,
plus 1 entry where the Suno music did not ship) lead. Sponsored art tools barely register.

### Cited Findings
(All counts are from my hand coding of the entry pages linked from
[Slapjam #1 results](https://slapjam.ai/jams/slapjam-1/) and
[Slapjam #2 itch results](https://itch.io/jam/slapjam-ai-2/results). The coding table is
`coded.py` in the scratchpad.)

**Primary in-game art source:**

| Group | n | Gen image | Gen 3D | Platform agent | Procedural / code | Licensed / human | Not stated |
|---|---|---|---|---|---|---|---|
| SJ1 cash winners (#1–#5) | 5 | 1 | 0 | 0 | 1 | 1 | 2 |
| SJ1 ranks 1–19 | 21 | 3 | 0 | 1 | 8 | 3 | 6 |
| SJ1 sample, ranks 23–141 | 38 | 14 | 1 | 4 | 8 | 1 | 10 |
| SJ2 top 5 | 5 | 1 | 1 | 0 | 2 | 0 | 1 |
| SJ2 top 10 | 10 | 2 | 1 | 1 | 4 | 0 | 2 |
| SJ2 ranks 11–39 | 28 | 3 | 0 | 1 | 6 | 1 | 17 |
| **Pooled top-10, both jams** | 21 | 3 | 1 | 1 | 10 | 2 | 4 |
| **Pooled rest** | 76 | 19 | 1 | 6 | 16 | 3 | 31 |
| All coded | 97 | 22 | 2 | 7 | 26 | 5 | 35 |

**Entries naming each model or tool (an entry may name several):**

| Model / tool | Pooled top-10 (n=21) | Rest (n=76) | All (n=97) |
|---|---|---|---|
| OpenAI GPT image (ChatGPT, Codex, "GPT Image 2/2.5"), in game | 4 | 16 | 20 |
| OpenAI GPT image, cover or reference only | 0 | 7 | 7 |
| Google Gemini / Nano Banana, in game | 0 | 2 | 2 |
| Gemini, cover only | 2 | 0 | 2 |
| PixelLab (sponsor) | 0 | 1 | 1 |
| AutoSprite (sponsor) | 0 | 1 | 1 |
| Qwen-Image-Edit | 0 | 1 | 1 |
| Sprite Fusion | 0 | 1 | 1 |
| ElevenLabs image (cover) | 1 | 0 | 1 |
| Tripo (3D) | 0 | 2 | 2 |
| Meshy (3D) | 1 (SJ2 #5) | 0 | 1 |
| Blender by script (procedural 3D) | 2 (SJ1 #1, SJ2 #3) | ≥2 | ≥4 |
| Platform agents: Rosebud / Hark / Pixelfork / Ziva | 1 (Hark) | 3 / 1 / 2 / 2 | 3 / 2 / 2 / 2 |
| ElevenLabs (voice, SFX, music) | 2 | 7 | 9 |
| Suno | 1 (did not ship) | 7 | 8 |
| Others, one entry each: Stable Audio Open, Lyria, Mureka, MiniMax, TapTap Maker, Gemini SFX | 0 | 6 | 6 |

**Models never named in any coded entry:** Midjourney, Stable Diffusion/SDXL, Flux, Leonardo,
Scenario, Recraft, Retro Diffusion, Layer, Hunyuan3D and Rodin. Slapjam's own guide recommends
several of them. — [Slapjam guide](https://slapjam.ai/docs/)

**Visual Appeal by art source.** These are Slapjam #1 means for the 59 coded entries.
- Generated image 3.07 (n=17); procedural 3.02 (n=16); licensed/human 3.62 (n=4); platform
  agent 2.66 (n=5); not stated 2.90 (n=16).
- The average over all 141 rated entries is 2.81.
- The sample over-weights the top 20, so these means are biased upward.

— [Slapjam #1 results](https://slapjam.ai/jams/slapjam-1/)

**Sponsor bias.**
- **Slapjam:** sponsored art tools barely appear. AutoSprite and PixelLab (first-prize perks)
  have 1 use each. Ziva and Rosebud appear only as build platforms. No placed entry used a
  sponsored art tool, although Speed Slash (Slapjam #2 #1) also ranks in the Ziva and Godot
  ecosystem.
- **Other jams:** OpenAI and Meshy sponsored the Unity Busan jam, and the Epic MegaJam sponsors
  include OpenAI and Google with Meshy on site. Neither has per-entry tool data, so bias cannot
  be measured there.
- **Tripo Portal Pass** mandated Tripo outright.

— [Slapjam guide](https://slapjam.ai/docs/);
[Inven Global](https://www.invenglobal.com/articles/28843/three-winners-selected-for-unity-ai-game-jam-joined-by-unity-openai-and-meshy);
[UE forum](https://forums.unrealengine.com/t/vibe-your-way-to-50k-the-2026-epic-ai-megajam-is-coming/2843983);
[Slapjam rules survey](https://slapjam.ai/news/is-ai-allowed-in-game-jams/)

### Inferences
- **GPT image dominance probably reflects tool access, not winning.** Entrants who code with
  Codex or ChatGPT get the image tool in the same subscription. That matches the overlap: most
  GPT-image entries also name Codex or ChatGPT for code.
- **Procedural art is over-represented at the top** (48% vs 21%). One likely reason is the
  mobile-browser constraint: small builds and a consistent look are easier when the agent draws
  everything. Another is that strong agent users (Claude Code, Codex) both place well and prefer
  code-drawn art. The samples are too small to separate these effects.
- **Licensed and human packs (KayKit, Quaternius, Kenney, LPC) score the highest mean Visual
  Appeal,** but n=4.

### Gaps
- **Small samples.** n=21 placed entries; there are no confidence intervals and no test of
  significance.
- **"Not stated" is large** (35 of 97). Many entries tick "Graphics" in itch's AI disclosure
  without naming a model, so true model shares could differ.
- **Cover-only versus in-game was judged from wording.** Some cases are ambiguous: ECHOES
  "lore material", Shellter "concept art", and Falling Castle, coded in-game from a general
  statement.
- **No comparable per-entry data** for the Epic MegaJam, Unity Busan, Shanghai AIGC, Supercell
  or Chinese and Japanese platform jams.

## Organizer and judge remarks on AI art quality

### Takeaway
Organizers' guidance stresses a consistent style: "pick one image model and one style prompt and
reuse it". Weekly-judged AI jams say raw AI art and clashing styles score low. In the biggest
AI jam (Epic), visible anti-"slop" sentiment pushed an AI-free game to the top of the popularity
chart. I found no published judge write-ups that break down Slapjam's Visual Appeal scores.

### Cited Findings
- **Slapjam's guide:**
  - "Consistent assets. Pick one image model and one style prompt and reuse it for everything."
  - On Retro Diffusion: "The fastest path to a consistent 2D look."
  - On PixelLab: it "Generates pixel-art characters, animations and tiles in one consistent
    style".

  — [Slapjam guide](https://slapjam.ai/docs/)
- **ctrl ai jam rules (per a search snippet; page not fetched).** Looks are scored, "raw,
  unedited AI art scores low", and clashing styles "will hurt your rating". —
  [ctrl ai jam (itch)](https://itch.io/jam/ctrl-ai-jam) (secondary: search-result summary)
- **One judge's comment, quoted in a search snippet:** generated visuals "end up feeling
  inconsistent and lifeless compared to entries with even simple hand-made assets". This is a
  single comment, and the itch post was not identified or fetched. Treat it as unverified.
- **Epic AI MegaJam:**
  - PolyCube's LSD:FIH page parodies "I'm Joining the War on AI SLOP on the Side of LSD:FIH".
  - Kotaku framed the field as "a small, AI-slop filled pond".
  - Forum replies to the announcement called the theme "insane" and "tone deaf", citing "AI
    slops" elsewhere.

  — [Automaton](https://automaton-media.com/en/news/ai-free-fih-aura-farming-game-tops-popularity-ranking-in-epic-games-major-ai-game-jam/);
  [Kotaku](https://kotaku.com/epic-ai-megajam-game-jam-slop-lsd-fih-aura-farming-tim-sweeney-2000758352);
  [UE forum](https://forums.unrealengine.com/t/vibe-your-way-to-50k-the-2026-epic-ai-megajam-is-coming/2843983)
- **Rosebud named its hackathon "No Slop".** The aim was "to generate with intention, design
  with taste". The 2nd place game was praised for "high production polish" from auto-generated
  cutscenes and level art. — [Rosebud blog](https://lab.rosebud.ai/blog/no-slop-hackathon-ai-games-rosebud)
- **Entrants disclose AI art defensively.**
  - Keep Shift: "Promotional illustrations are AI-generated concept artwork and may differ from
    the final game." — [page](https://ballaii.itch.io/keep-shift)
  - Brake for Cake (Slapjam #2 #17): "no AI image generation was used for these promotional
    images". — [page](https://jason-jung.itch.io/brake-for-cake)
- **Unity Busan.** A day-1 caption reads "You can't leave everything to AI", and some
  participants "brought their own gear to handle art assets directly". —
  [Inven Global, day 1](https://www.invenglobal.com/articles/28782/unity-openai-and-meshyai-gather-for-unity-ai-game-jam)
- **Micro Jam's move to ban generative AI for art and audio (from 069)** is a policy signal; no
  reason was given in what I read. —
  [Slapjam AI game jams 2026](https://slapjam.ai/news/ai-game-jams-2026/)

### Inferences
- **What seems to cost points** is style inconsistency (mixed models, raw output) and the "slop"
  stigma. Placed entries avoided both by drawing in code or by limiting generated images to UI
  and textures under one look.

### Gaps
- **No per-criterion judge feedback** was found for any placed entry in these jams. Slapjam
  publishes scores but not comments.
- **itch rating comments were not crawled** (rate limits).
- **Unverified items.** The ctrl ai jam rule text and the "inconsistent and lifeless" judge
  quote come from search snippets only.
