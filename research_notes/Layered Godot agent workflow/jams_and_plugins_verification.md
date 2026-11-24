# Verification of AI game-jam figures and dsh Godot plugin details

Research date: 2026-11-24. Checks the claims marked unverified or conflicting in
`research_notes/Godot agent skills and workflows/ai_gamedev_competitions.md` and
`dsh_godot_plugins.md` against primary pages.

Method: pages fetched with curl through the session proxy (TLS on, `-L`) into a scratch directory
and read as data. `vibej.am` now redirects to `vibejam.com`, and `jam.pieter.com/2026/` redirects
to `vibejam.com/`. The jam site publishes machine-readable data: `https://vibejam.com/api` (all
games, per-year counts) and a games cache script on the 2026 page that carries `final_rank` and
`award` for every 2026 entry. The two plugin repos were shallow-cloned read-only from GitHub
because the GitHub API is not enabled for them in this session.

Not reachable: itch.io returned HTTP 429 (rate limit) for the Ziva jam and Epic MegaJam pages;
`unrealengine.com` and `dev.epicgames.com` returned HTTP 403 behind a Cloudflare JavaScript
challenge. A retry against itch.io with a browser user agent was blocked by the session's
permission system and was not attempted again. Claims that depend on those pages stay unverified.

Labels: **Verified** = a primary page states it. **Corrected** = a primary page states something
different; the corrected value is given. **Still unverified** = no primary page reached.

## Vibe Coding Game Jam 2025 (levelsio): entries, rules, sponsors, judges, podium, prizes

### Takeaway
The 2025 archive page confirms the full podium (Gold "The Great Taxi Assignment" by @tomasbencko,
$10,000; Silver "Vibeware" by @mattgordonxyz, $5,000; Bronze "Vector Tango" by @scobelverse,
$2,500; $17.5K total), the 80% AI rule, five judges led by Andrej Karpathy, and three sponsors
(Bolt.new, CodeRabbit, Lambda Labs). The page says "1000+ games entered"; the site's own API
counts 1,083 games for 2025. The Indie Hackers figure of 1,170 does not match the primary data.

### Cited Findings
- **Corrected (entry count).** The archive page says "1000+ games entered!". The site's games API
  reports `"2025":{"games":1083,"still_up":632}`. The Indie Hackers figure of 1,170 is not
  supported by either primary. — [vibejam.com/2025](https://vibejam.com/2025/);
  [vibejam.com/api](https://vibejam.com/api); contradicted by
  [Indie Hackers](https://www.indiehackers.com/post/Uz0wHG4pI3KBOiFhP5YR)
- **Verified (official name).** The archive page title is "Bolt Vibe Coding Game Jam 2025", "by
  @levelsio", "April 2025 - $17.5K in prize money". — [vibejam.com/2025](https://vibejam.com/2025/)
- **Verified with a nuance (80% rule).** Rules as listed: "Game must be at least 80% written by AI
  (code, assets, etc)"; "Game must be instantly playable on web - no logins, signups or loading
  screens"; "Game must be free-to-play and hosted on its own domain/subdomain"; "Game can be single
  or multiplayer, using any engine (ThreeJS recommended)"; "Add the code to your game to show
  you're a participant". The 80% covers code *and* assets, not code alone. —
  [vibejam.com/2025](https://vibejam.com/2025/)
- Note: the site-wide `llms.txt` and `/api` describe the jam generically as "at least 90%
  AI-coded". That is the 2026 rule; the 2025 page itself states 80%. —
  [vibejam.com/llms.txt](https://vibejam.com/llms.txt); [vibejam.com/2025](https://vibejam.com/2025/)
- **Verified (podium and prizes).** "#1 Gold $10,000 The Great Taxi Assignment by @tomasbencko";
  "#2 Silver $5,000 Vibeware by @mattgordonxyz"; "#3 Bronze $2,500 Vector Tango by @scobelverse".
  The 2026 press release repeats the 2025 split ($10,000 / $5,000 / $2,500; $17,500 total). The
  earlier aggregator title "Great Taxi Assignment: Vibe City" is not the official title; "Vibe City"
  is the in-game city named in the entry's pitch. — [vibejam.com/2025](https://vibejam.com/2025/);
  [vibejam.com/2026/press](https://vibejam.com/2026/press); [vibejam.com/api](https://vibejam.com/api)
- **Corrected (sponsors).** The page meta description reads "Sponsored generously by Bolt.new,
  Coderabbit AI, and Lambda Labs", and the sponsors module lists `BoltDotNew`, `CodeRabbitAI`,
  `Lambda Labs`. The page footer credits "@levelsio @boltdotnew and coderabbitai". Indie Hackers'
  list (Bolt.new, CodeRabbit, Lambda) is right; the vibecoding.app "no company sponsor" claim is
  wrong. — [vibejam.com/2025](https://vibejam.com/2025/);
  [vibejam.com/2025/js/sponsors.js](https://vibejam.com/2025/js/sponsors.js)
- **Verified (judges, now named).** The jury module lists five judges: Andrej Karpathy
  (@karpathy), Ricardo Cabello / Mr.doob (@mrdoob), s13k (@s13k), Tim Soret (@timsoret), and Pieter
  Levels (@levelsio). Habr's "five judges" count is right. Its "OpenAI co-founder" and "former
  Tesla AI director" both describe Karpathy, as the press release does ("former Director of AI at
  Tesla, co-founder of OpenAI"). — [vibejam.com/2025/js/juryMembers.js](https://vibejam.com/2025/js/juryMembers.js);
  [vibejam.com/2026/press](https://vibejam.com/2026/press)
- **Corrected (dates).** No deadline is printed on the archive page beyond "April 2025". The API's
  2025 submission timestamps run from 2025-03-17T14:09:57Z to 2025-04-02T08:23:29Z, so the window
  was mid-March to about 1-2 April 2025. — [vibejam.com/api](https://vibejam.com/api)
- **Verified.** The 2026 press release says 2025 entries came from "more than 50 countries". —
  [vibejam.com/2026/press](https://vibejam.com/2026/press)

### Inferences
- The 2025 rule was looser than "80% AI code": the threshold explicitly included assets, and the
  FAQ said "No! You can use no-code tools".
- The 1,083 count is a live database figure that may include late or test submissions; "1000+" is
  the organizer's headline. Either is defensible; 1,170 is not.

### Gaps
- An exact official 2025 deadline timestamp was not found on the archive page.

## Cursor Vibe Jam 2026: dates, entries, players, rules, prize pool, full podium

### Takeaway
The current jam site confirms 1 April – 1 May 2026 (13:37 UTC), 945 games, the 90% AI rule, and a
$40,000 podium ($25k / $10k / $5k) plus 12 special prizes of $1,000 each, which is why the
homepage headline reads "$50,000+". The $35,000 ($20k / $10k / $5k) figure could not be found on
any current primary page. The full podium: Gold "A Game About Capybaras Delivering Food" by
@leocooout, Silver "Fanto's Mega-Mart" by @e_c_t_o, Bronze "WenWare" by @underpaid_mom.

### Cited Findings
- **Verified (dates).** "Runs April 1 – May 1, 2026. Deadline 1 May 2026 @ 13:37 UTC." Timeline:
  jam starts 1 Apr 2026, submissions close 1 May 2026 13:37 UTC, judging May 2026, winners
  announced (the page's countdown now renders "WINNERS ANNOUNCED"). Last API submission timestamp
  is 2026-05-01T13:42:13Z. — [vibejam.com/2026/press](https://vibejam.com/2026/press);
  [vibejam.com](https://vibejam.com/); [vibejam.com/api](https://vibejam.com/api)
- **Verified (entry count).** API: `"2026":{"games":945,"still_up":826}`. The press release says
  "945 games already submitted as of this release" and notes the count "reads straight from the jam
  database". — [vibejam.com/api](https://vibejam.com/api);
  [vibejam.com/2026/press](https://vibejam.com/2026/press)
- **Still unverified (242,000+ players; "largest AI game jam to date").** The homepage player
  counter is filled in by script and reads 0 in the static HTML; no primary figure was captured.
  The homepage shows "21,419,339 impressions" for #vibejam on X. Note that by the site's own API,
  2025 had more entries (1,083) than 2026 (945), so "largest" can only refer to prizes or players,
  not entry count. — [vibejam.com](https://vibejam.com/); [vibejam.com/api](https://vibejam.com/api);
  unverified source [Summer Engine](https://www.summerengine.com/blog/cursor-vibe-jam-2026-guide)
- **Verified (rules).** "At least 90% of the code has to be written by AI." Other rules: the
  vibejam widget JS snippet is required ("games without it are disqualified"); only new games made
  on or after 1 April 2026; web, no login or signup, free-to-play, preferably own domain; any
  engine, Three.js recommended; no loading screens or heavy downloads; one entry per person;
  multiplayer preferred but not required. — [vibejam.com](https://vibejam.com/);
  [vibejam.com/2026/press](https://vibejam.com/2026/press)
- **Verified (sponsors).** Cursor (Diamond), Bolt.new (Gold), Glif (Silver), Tripo AI (Silver). —
  [vibejam.com/2026/press](https://vibejam.com/2026/press); [vibejam.com](https://vibejam.com/)
- **Corrected (prize pool).** The FAQ says "Gold ($25,000), Silver ($10,000), and Bronze ($5,000)
  … $40,000 total! Last year we gave out $17,500." The prize block adds "+ 12 Special Prizes —
  $1,000 each" and the header says "$50,000+ in prize money" ($40k + $12k = $52k). The earlier
  "$35,000 ($20k/$10k/$5k)" reading of jam.pieter.com/2026 is not reproduced: that URL now
  redirects to vibejam.com and shows the $25k Gold figure. — [vibejam.com](https://vibejam.com/);
  [vibejam.com/2026/press](https://vibejam.com/2026/press)
- **Verified (jury).** Homepage jury: @levelsio (organizer), @s13k_ (lead judge, "Vibe Jam co-host
  and vibe code consultant"), Tim Soret (@timsoret, Odd Tales, The Last Night), Nicola Manzini
  (@nicolamanzini, Vibesail), Eric Zakariasson (@ericzakariasson, designer at Cursor), Alessandro
  Schiassi (@overjumprally, Over Jump Rally). The press release still reads "to be announced"
  beyond levelsio and s13k_. — [vibejam.com](https://vibejam.com/);
  [vibejam.com/2026/press](https://vibejam.com/2026/press)
- **Verified (podium, from the page's games data, `final_rank` 1-3 = podium per the page script).**
  - Gold, $25,000: "A Game About Capybaras Delivering Food" by @leocooout
    (capybara-vibejam26.leocoout.dev), ThreeJS, made with "Claude Code, Tripo3d, Suno, ElevenLabs".
    Pitch: "A cozy open world game about capybaras delivering food…".
  - Silver, $10,000: "Fanto's Mega-Mart" by @e_c_t_o (fantos-megamart.vercel.app), ThreeJS, Codex.
  - Bronze, $5,000: "WenWare" by @underpaid_mom (wen-ware.com), ThreeJS, Codex; it also took the
    "@boltdotnew's MOST PLAYED" special prize.
  — [vibejam.com](https://vibejam.com/) (games cache script
  `https://vibejam.com/2026/cache/games-5288ad4b37b007e7f970f150f68f2d1d.js` and
  [vibejam.com/2026/scripts.js](https://vibejam.com/2026/scripts.js): "final_rank 1-3 = the podium;
  every 🌿 special award is $1,000 on top")
- **Verified (12 special prizes, $1,000 each).** @cursor_ai's BEST ART DIRECTION: Null Range
  (@taylor_sntx); @cursor_ai's MOST ORIGINAL: HALDANE-4 (@denisbondare, custom TypeScript engine);
  @heyglif's MOST ZEN: Kanso (@mrsukeruton); @boltdotnew's MOST PLAYED: WenWare (@underpaid_mom);
  MOST ATMOSPHERIC: Eyrie (@slowchaz); MOST POLISHED: Tiny Skies (@dannylimanseta); UNIQUE CONCEPT:
  Undersphere (@_NoahWhiteson); MOST UNHINGED: Swingers (@_offmylawn); MOST PORTAL TRANSFERS: FULL
  SEND (@dvassallo); RAGE-QUIT AWARD: BeetleJump (@assentorp); FUNNIEST GAME: KÖTTBULLAR METAL
  (@MichalPastier); MOST CURSED: Almost Surgery (@RagimMusakaev), **built in Godot**. —
  [vibejam.com](https://vibejam.com/) (games cache script, as above)
- **Verified (engines).** Of 945 entries: ThreeJS 608, Phaser 60, PixiJS 23, Godot 21, Unity 11,
  Babylon.js 11 (self-reported engine field). 943 entries declare `ai_written: "Yes"`. 2025 had 5
  Godot entries in the API. — [vibejam.com](https://vibejam.com/) (games cache);
  [vibejam.com/api](https://vibejam.com/api)
- **Still unverified.** Wccftech's description of the winner as an "iOS developer"; Colyseus's
  count of 48 entries using its server. Neither page was fetched in this pass. —
  [Wccftech](https://wccftech.com/ios-developer-made-capybara-game-using-vibe-coding-and-won-25000/);
  [Colyseus blog](https://colyseus.io/blog/vibe-jam-2026/)

### Inferences
- The "$35k vs $40k" conflict was most likely an older page state; the current primary pages
  agree on $40k for the podium and $52k with special prizes. Cite "$40,000 podium, $50,000+
  including 12 × $1,000 special prizes".
- All three podium games are Three.js; two of three were made with Codex and one with Claude Code.
  A Godot web export won one special prize (Most Cursed), so Godot entries can compete in this jam
  but are a small minority (21 of 945).

### Gaps
- No primary player count. The homepage counter is client-rendered.
- The `final_rank` beyond 3 is the site's ordering, not an announced ranking; only 1-3 carry prizes.

## Epic 2026 AI MegaJam: rules history, 2,782 submissions, prizes, winners

### Takeaway
No primary page could be read. unrealengine.com and dev.epicgames.com return a Cloudflare
challenge (HTTP 403), and itch.io rate-limited the jam page (HTTP 429). Every MegaJam figure in
the earlier notes remains secondary-sourced, and whether winners were announced by 2026-11-24 is
unknown.

### Cited Findings
- **Still unverified.** Theme reveal 11 Nov 2026; jam 12–15 Nov 2026; teams of up to five humans
  "plus unlimited AI agents"; $65,000 total prizes; first place per category $7,500; continuation
  grants up to $50,000. The primary page returned "Enable JavaScript and cookies to continue". —
  [Unreal Engine news](https://www.unrealengine.com/news/2026-epic-ai-megajam) (HTTP 403);
  secondary [TweakTown](https://www.tweaktown.com/news/114250/epic-games-2026-ai-megajam-offers-65-000-in-prizes-but-the-ai-requirements-are-confusing/index.html)
- **Still unverified.** Rules reversal (AI first mandatory, then optional; "Our FAQ originally said
  you had to use AI for the MegaJam. That's our mistake.") rests on PC Gamer's quote. —
  [PC Gamer](https://www.pcgamer.com/software/ai/epic-announces-game-jam-where-you-have-to-use-ai/?type=Games)
- **Still unverified.** 2,782 submissions and the popularity lead of "fih-aura farming" rest on
  Automaton; the itch.io jam page returned HTTP 429. —
  [Automaton](https://automaton-media.com/en/news/ai-free-fih-aura-farming-game-tops-popularity-ranking-in-epic-games-major-ai-game-jam/);
  [itch.io/jam/2026-epic-ai-megajam](https://itch.io/jam/2026-epic-ai-megajam) (HTTP 429)

### Inferences
- With the jam closing 16 Nov 2026, a winners announcement within eight days would be fast for a
  2,782-entry jam with category judging; absence of evidence here is not evidence of absence.

### Gaps
- Winners, official prize table and official submission count need a browser session or a later
  fetch of the itch.io results page once the rate limit clears.

## Ziva Game Jam, Ziva Micro Jam bracket, Godot Wild Jam AI ban, other Godot AI jams

### Takeaway
Ziva's own blog (26 Aug 2026) confirms the Micro Jam bracket numbers (81 Ziva entries, 30 paid
prizes across jams 056–063) but corrects the payout: jams 056–060 paid three places ($30/$25/$20)
and jams 061–063 paid five ($30/$22/$18/$15/$15), $675 in total. The blog does not mention the
March 2026 Ziva Game Jam at all, and its itch.io page was rate-limited, so that jam's results stay
unverified. The Godot Wild Jam #90 page confirms the AI ban.

### Cited Findings
- **Verified with a correction (Micro Jam bracket).** "Across jams 056 to 063, 81 entries declared
  Ziva and 30 took prize money." "30 cash prizes across 8 jams, 27 different teams, $675 total."
  "81 of 500 ranked entries declared Ziva: 16% of the field, second to GameMaker at 91." Payout
  table: jams 056–060, 3 paid places, $30 / $25 / $20, 7 to 9 Ziva entries per jam; jams 061–063,
  5 paid places, $30 / $22 / $18 / $15 / $15, 12 to 16 Ziva entries per jam. (5 × $75 + 3 × $100 =
  $675.) Counts come from the tool question on each itch.io submission page. —
  [Ziva blog](https://ziva.sh/blogs/godot-game-jam-winners)
- **Corrected (named winners).** "Melting Hero" (Neonfire Studio and cam-ul) was **first in the Ziva
  bracket** of Micro Jam 058 and #7 of 56 overall; the team placed in the bracket in four jams
  (057, 058, 062, 063). "SpaceRat" (DahMaus) was #9 of 57 overall in Micro Jam 060. The blog's
  headline results are "Fire keeper" (StarXgames), which won Micro Jam 063 outright (#1 of 65), and
  "Follow the Wheat" (LazyGnome), #2 of 53 in Micro Jam 059 with the highest score of any Ziva entry
  (4.060). — [Ziva blog](https://ziva.sh/blogs/godot-game-jam-winners)
- **Verified (a counterpoint in the vendor's own post).** "Ziva entries averaged an adjusted score
  of 2.50 against 2.56 for the rest of the field. The tool did not lift the median entry." —
  [Ziva blog](https://ziva.sh/blogs/godot-game-jam-winners)
- **Verified.** Micro Jam is a 48-hour jam every two weeks on itch.io with "3,500+ members", paying
  "$400 or more per event, funded by GameMaker, Ziva, and CraftPix". — [Ziva blog](https://ziva.sh/blogs/godot-game-jam-winners)
- **Still unverified (Ziva Game Jam, 27–30 Mar 2026).** Results, entry count and winners: the
  itch.io jam and results pages returned HTTP 429. The Ziva winners blog does not mention this jam.
  — [itch.io/jam/ziva-game-jam](https://itch.io/jam/ziva-game-jam) (HTTP 429)
- **Verified (Godot Wild Jam AI ban).** GWJ #90 "ran from 2026-02-13 21:00:00 to 2026-02-22
  21:00:00"; "This monthly jam starts on the second Friday of every month, and lasts for 9 days."
  Rules: "Do NOT use AI-generated content. No vibe code, no AI-generated art, no AI-composed music,
  no AI-written dialogue, no AI assets of any kind." FAQ: "Can I use generative AI? No." —
  [itch.io/jam/godot-wild-jam-90](https://itch.io/jam/godot-wild-jam-90)
- **Still unverified (other Godot-specific AI jams 2025–2026).** itch.io searches could not be
  run (HTTP 429). The only Godot-specific AI-tool jam activity found on primary pages is Ziva's
  Micro Jam bracket. Godot entries also appear in the Cursor Vibe Jam 2026 (21 entries; one
  special prize). — [Ziva blog](https://ziva.sh/blogs/godot-game-jam-winners);
  [vibejam.com](https://vibejam.com/)

### Inferences
- Ziva's data supports a "top of the field, not the median" reading: AI tooling did not raise the
  average Micro Jam score in its own bracket.
- Godot's community jam bans AI outright while the engine project restricts AI-authored code (next
  section); Godot-plus-AI jam activity is vendor-funded brackets, not community or official jams.

### Gaps
- Ziva Game Jam (Mar 2026) results and entry count.
- A complete list of Godot-specific AI jams on itch.io for 2025–2026.

## dsh plugin pages vs GitHub repos (akira399/dsh-godot-skill, Smalldy/godot-bridge)

### Takeaway
dsh-plugin.org is a third-party directory ("DSH Plugin Hub", claiming 27,000+ indexed plugins), not
DeepSeek's site. Both plugin pages mark the plugins "Verified", show the install command and repo
metadata, and say they are "an independent rewrite of the plugin's official README". Neither page
shows download counts. The godot-bridge page has two discrepancies with the repo: it says
"sixteen native tools" (the repo has seventeen), and it says `godot_run_project` launches in debug
mode with `godot -d`, which v0.2.1 changed to non-debug by default.

### Cited Findings
- **Verified (what the site is).** "The DSH Plugin Hub is a dsh plugin market curating 27000+
  DeepSeek Harness (DSH) plugins, updated daily … 7000+ of them shipping an npm package"; listings
  are "reviewed by our professional technical team, which checks the install command, compatibility
  status (verified / unconfirmed) and DSH target version (dshTarget)". Its install FAQ matches the
  DSH README (`npx @deepseek-ai/dsh web`, Web UI at 127.0.0.1:3080, `dsh plugin --profile web add
  <package>`). — [dsh-plugin.org](https://dsh-plugin.org/)
- **akira399/dsh-godot-skill page.** Category "Skills & Agents", badge "Verified", "Listed on
  2026-08-14", "Page last updated 2026-11-21". Install: `dsh plugin --profile web add
  github:akira399/dsh-godot-skill`. Language JavaScript, MIT, repo created "2026-08-14 04:14:13",
  last push "2026-08-28 15:54:54". No version (`softwareVersion` is empty). Star, fork and issue
  fields are empty in the static HTML (client-rendered). No download or install counts. —
  [dsh-plugin.org/plugins/akira399/dsh-godot-skill](https://dsh-plugin.org/plugins/akira399/dsh-godot-skill)
  - **Consistent with repo.** First commit `2026-08-14T04:14:06+08:00`, last commit `5ff4084`
    `2026-08-28T15:54:51+08:00`; `package.json` version 1.0.0; no tags. The page times are in
    UTC+8, which explains the earlier note's "created 2026-08-13" (UTC). The README documents three
    install forms (npm name, `git+https://…`, `github:akira399/dsh-godot-skill`); the page shows
    only the `github:` form. The page's FAQ on the git+ssh failure and verify script matches the
    README. — [akira399/dsh-godot-skill](https://github.com/akira399/dsh-godot-skill)
  - Minor: the page omits that the skill text is in Chinese and omits the version 1.0.0.
- **Smalldy/godot-bridge page.** URL canonicalises to lowercase `smalldy/godot-bridge`. Category
  "Development & Operations", "Verified", "Listed on 2026-08-18", "Page last updated 2026-11-19".
  Version "v0.2.1". Install: `dsh plugin --profile web add github:smalldy/godot-bridge`. Language
  GDScript, MIT, repo created "2026-08-14 23:09:28", last push "2026-11-12 00:10:43". Topics
  include `mcp`. No download counts. —
  [dsh-plugin.org/plugins/smalldy/godot-bridge](https://dsh-plugin.org/plugins/smalldy/godot-bridge)
  - **Consistent.** Version v0.2.1 matches `package.json` "0.2.1" and the latest tag `v0.2.1`
    (then v0.2.0, v0.1.8). Last commit `e9c34db` `2026-11-09T02:21:35+08:00` ("docs: remove demo
    data tag from hero"); the page's last push (2026-11-12 00:10 UTC+8 = 2026-11-11 UTC) matches the
    earlier note's push date. The README's install command uses `github:Smalldy/godot-bridge`;
    GitHub resolves the case-insensitive owner either way. —
    [Smalldy/godot-bridge](https://github.com/Smalldy/godot-bridge)
  - **Discrepancy 1 (tool count).** The page says "offering sixteen native tools". The README's
    tool table lists 17 `godot_*` tools and the README text says "the seventeen `godot_*` tools"
    several times. The "16" likely conflates the 16 `godot_headless_op` static operations. —
    [page](https://dsh-plugin.org/plugins/smalldy/godot-bridge);
    [README](https://github.com/Smalldy/godot-bridge/blob/main/README.md)
  - **Discrepancy 2 (debug mode).** The page FAQ says `godot_run_project` launches "in debug mode
    (internally runs godot -d --path …)". CHANGELOG 0.2.1: "`godot_run_project` now starts
    **without** `-d` by default … `debug:true` is now explicitly **diagnostic mode**" (issue #13).
    The repo's own README still shows `subprocess.spawn(Godot -d --path <project>)` in its
    architecture diagram, so the page copied a stale part of the README. —
    [CHANGELOG](https://github.com/Smalldy/godot-bridge/blob/main/CHANGELOG.md);
    [README](https://github.com/Smalldy/godot-bridge/blob/main/README.md)
  - The page's "about 130 game_* commands" for `godot_command` was not cross-checked against
    COVERAGE.md. **Still unverified.**
  - The page's "no MCP protocol, Python server, or editor addon" copies the README line "No MCP
    protocol, no Python server, no editor addon."; consistent with the repo.

### Inferences
- The "Verified" badge is the directory's own install-command and compatibility check, not a
  security review; the page itself says the plugin "is third-party code that runs on your machine
  once installed".
- For decisions, use the repos as the source of truth. The directory pages are machine rewrites
  that can lag the CHANGELOG.

### Gaps
- Star, fork and open-issue numbers are client-rendered on the pages and could not be compared.
- No download or install counts exist on either page, so the earlier "downloads unverified" gap is
  closed as "not published".

## Godot's contribution policy on AI-authored code

### Takeaway
The official contributing docs carry an "AI-assisted contributions" policy: AI must not author
substantial code, agents must not submit PRs on a contributor's behalf, no AI-generated text in
human-to-human communication and no AI-generated user-facing media; AI code completion is allowed
if it produces what the contributor would have written. Changes of 15 lines or fewer are presumed
trivial. Maintainers need not review AI-assisted PRs, and every PR needs human approval.

### Cited Findings
- **Verified (scope).** "'AI' in this page refers to any LLM/generative AI model like ChatGPT,
  Claude, Grok, etc." Translation software used only for communication is exempt; the policy does
  not apply to third-party libraries. —
  [Contribution rules: AI-assisted contributions](https://contributing.godotengine.org/en/latest/development/contribution_rules.html#ai-assisted-contributions)
- **Verified (contributor rules, headings verbatim).** "Do not use AI-generated text in
  human-to-human communication"; "Do not allow an AI agent to submit PRs on your behalf"; "Do not
  use AI to generate substantial pieces of code"; "Do not use AI to generate user-facing media
  (e.g. documentation, images and audio)". — [same page](https://contributing.godotengine.org/en/latest/development/contribution_rules.html#ai-assisted-contributions)
- **Verified (code rule detail).** "AI should not be used to author code. Code authoring is more
  than typing … All those decisions need to be made by a human. For example using AI for code
  completion is permissible … If you do not have the knowledge/ability to write the code yourself,
  you are not allowed to use AI to write it. You must understand and take responsibility for
  everything that you submit." Repeated low-effort submissions "may result in limits or bans". —
  [same page](https://contributing.godotengine.org/en/latest/development/contribution_rules.html#ai-assisted-contributions)
- **Verified (maintainer rules).** "Maintainers are not obliged to review AI-assisted PRs"; they
  "must pay special attention to quality and maintainability"; "All PRs must be reviewed and
  approved by a human before merging". — [same page](https://contributing.godotengine.org/en/latest/development/contribution_rules.html#for-maintainers)
- **Verified ("substantial code").** Measured by amount, complexity, contributor experience, code
  area and merge risk; "code changes of 15 lines or less are generally trivial … we presume that
  anything under 15 lines should be considered trivial unless otherwise shown." —
  [same page](https://contributing.godotengine.org/en/latest/development/contribution_rules.html#substantial-code-definition)
- The policy is linked from the godotengine.org homepage's contributing links via
  contributing.godotengine.org. — [godotengine.org](https://godotengine.org/);
  [contributing.godotengine.org](https://contributing.godotengine.org/en/latest/index.html)

### Inferences
- The policy governs contributions to the engine, not games made with Godot; it does not restrict
  using agents on a game project such as this repo.
- Any upstream fix this project might send to Godot (for example a bug found while porting) would
  have to be human-authored beyond trivial size, and could not be opened by an agent.

### Gaps
- The adoption date of the policy is not on the page (footer: "© Copyright 2025-present"), and the
  GitHub commit history of the docs repo was not reachable (API 403). Whether it is "the 2026
  policy" or an earlier one is **still unverified**.
