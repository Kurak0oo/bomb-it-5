# Industry-wide usage of AI models for game art (2025 – November 2026, beyond jams)

Researched 2026-11-24. Fetch notes: WebFetch could not resolve most hosts in this session
(gamedeveloper.com, techspot.com, tomshardware.com); pages marked "read in full" were
fetched with curl through the session proxy and read as text. Figures marked
"(snippet only)" come from search-result summaries and were not read at the source.
"Vendor" marks numbers produced by a company that sells the tool or platform.

## Which art models are most used by game developers by share, per survey/data source?

### Takeaway
No large independent survey published in 2025–2026 breaks out image, 3D, sprite or audio
models by name, with one exception: GDC's January 2026 State of the Game Industry
(n ≈ 2,300) found Midjourney the most-used text-to-image/video tool at 17% of
genAI-using respondents, ahead of Adobe Generative Fill (13%) and Sora (8%). Everything
else is either category-level (image generation 22%, concept art 22%, final assets 8% in
GDC's November 2026 edition) or a disclosure count. Steam disclosures rarely name tools
(about 4–6% do). In our own count of the 1,500 most recent Steam releases (15–24 Nov 2026),
82 of 834 disclosures (9.8%) name any product; among those naming a visual tool, Google
Gemini/Nano Banana (8 games), PixelLab (7), Meshy (7) and OpenAI image generation (6) lead,
Tripo has 4, and Midjourney only 2. Among 360 current top-seller/popular-new games, 35
disclose AI and none names an image or 3D model.

### Cited Findings

**GDC State of the Game Industry, January 2026 edition (fieldwork late 2025, n ≈ 2,300; read in full via Game Developer)**
- 36% of game-industry professionals use generative AI tools as part of their job; 30% at game studios vs 58% at publishing, support, marketing/PR firms; 21% use internal genAI tools (30% at AAA) — [Game Developer](https://www.gamedeveloper.com/business/one-third-of-game-workers-use-generative-ai-but-half-think-it-s-bad-for-the-industry)
- Tools named (share of AI users): ChatGPT 74%, Google Gemini 37%, Microsoft Copilot 22%; "As for text-to-image or video tools, Midjourney was the most used (17 percent), with Adobe Generative Fill (13 percent) and Sora AI (8 percent) following behind." Claude was written in by several respondents but was not a listed option — [Game Developer](https://www.gamedeveloper.com/business/one-third-of-game-workers-use-generative-ai-but-half-think-it-s-bad-for-the-industry)
- Use cases: research/brainstorming 81%, daily tasks (email, code assistance) 47%, asset generation 19%, procedural generation 10%, player-facing features 5% — [Game Developer](https://www.gamedeveloper.com/business/one-third-of-game-workers-use-generative-ai-but-half-think-it-s-bad-for-the-industry)
- 52% say genAI is harming the industry (30% the year before, 18% two years before); 7% positive — [GDC press/BusinessWire](https://www.businesswire.com/news/home/20260129438528/en/2026-State-of-the-Game-Industry-Report-Reveals-Widening-Effect-of-Layoffs-Broader-Perspectives-on-Generative-AI-Unionization-Tariffs-and-More) (snippet only); [TechSpot](https://www.techspot.com/news/111128-more-than-50-game-developers-generative-ai-harming.html) (snippet only)
- Note: Stable Diffusion, Flux, gpt-image, Nano Banana, Leonardo, Scenario, any 3D or audio generator were not reported in the published summaries; the survey's answer list is not public in what I could read.

**GDC State of the Game Industry, November 2026 edition (GDC moved the report from January to November; n > 2,600 from 69 countries; 63% US; AAA share up to 36%; read in full)**
- 40% use genAI at work (up from 36%); 57% of adopters use it daily; 55% negative, 35% mixed, 8% positive — [GDC](https://gdconf.com/state-of-the-game-industry-november-2026/)
- Tool categories (share of AI users): text generation 72%, code generation 62%, AI in productivity software 35%, **image generation 22%**, video generation 7% — [GameDev Reports summary, 19 Nov 2026](https://gamedevreports.substack.com/p/gdc-the-state-of-the-game-industry-52b)
- Use cases: research/brainstorming 73%, data analysis/summaries 62%, code/debugging 56%, **concept art 22%, final in-game assets 8%** — [GameDev Reports summary](https://gamedevreports.substack.com/p/gdc-the-state-of-the-game-industry-52b)
- Caveat stated by the summariser: sample shifted toward US and AAA, so year-on-year comparisons are weak — [GameDev Reports](https://gamedevreports.substack.com/p/gdc-the-state-of-the-game-industry-52b)
- No named image/3D/audio model shares found in the public preview or summary for this edition.

**Unity 2026 Game Development Report (vendor; Cint survey of 300 developers in 2025 plus Unity telemetry; read in full)**
- Back-end AI tools mostly used for coding assistance (62%) and writing/narrative (44%); Unity describes studios as avoiding "controversial front-end generative workflows"; 50% use MCP servers. No art-model breakdown in the public blog — [Unity blog](https://unity.com/blog/2026-unity-game-development-report-trends)
- Only 5% said "I do not use AI" — [Wccftech](https://wccftech.com/unity-2026-game-development-report-points-to-smaller-teams-making-games-in-less-time-with-ai/) (snippet only)

**CESA (Japan) Game Industry Report 2026 preview (17 Sep 2026; read in full)**
- First CESA survey on genAI: 85.8% of game developers use genAI at work (survey "ゲーム開発者の就業とキャリア形成 2026", internet survey, n = 1,349, May–Aug 2026, includes some educators and students); member-company survey n = 48 of 220 firms, June–July 2026. Most common governance practice: human review/correction; many firms designate or restrict which tools may be used. No per-model breakdown in the preview; full report (≈460 pp, ¥55,000) due early December 2026 — [CESA press release PDF](https://www.cesa.or.jp/uploads/cesa_report_preview_0914.pdf)
- 63.0% use it daily — [@DIME](https://dime.jp/genre/2157293/) (snippet only)

**China — 伽马数据 (Gamma Data / CNG) 中国游戏产业AI发展报告, July 2026 (read in full via PEdaily reprint)**
- Of AI tools used in the games industry, **art and design tools account for 57.4% of traffic and 49.4% of tool count** (traffic = May 2026 monthly visits; count = functional-tag share). Tools are not named in the reprint — [PEdaily](https://news.pedaily.cn/20260730/135291.shtml)
- 80% of China's top-50 game companies by revenue publicly disclose AI initiatives; 56% have an AI lab or team; ~36% build own models/tools/engines; of those with AI plans, 57.6% integrate mainstream (external) models and 72.7% buy cloud/compute — [PEdaily](https://news.pedaily.cn/20260730/135291.shtml)
- An earlier Gamma Data 「新质生产力」 report (July 2025) said AI participation in art-asset use/management exceeded 70% — [Gamma Data PDF](https://pdf.dfcfw.com/pdf/H3_AP202507181711204583_1.pdf?1752858662000.pdf=) (snippet only)
- A secondary finance article attributes to 游戏工委 (CADPA game committee) a survey showing 86.36% AI adoption in development and >84% penetration in art design; source report not found — [Eastmoney](https://caifuhao.eastmoney.com/news/1748043591) (snippet only; unverified)
- Company disclosures of specific models: miHoYo reportedly uses its own Glossa model and an AIGC tool "AJI" for art; NetEase Fuxi runs its own art platform (有灵天工). These are press/self-media reports, not disclosures of which third-party image models are used — [Eastmoney](https://finance.eastmoney.com/a/202604033694820123.html), [smzdm](https://post.smzdm.com/p/arz090oz/) (snippets only; unverified)
- Tencent says its Hunyuan3D/PolyGen runs in its own game pipelines with ">70%" efficiency gains (vendor claim); MoguraVR reports >3 million open-source downloads and >150 adopting companies in mainland China (unverified) — [AI News](https://www.artificialintelligence-news.com/news/tencent-hunyuan3d-polygen-a-model-for-art-grade-3d-assets/), [MoguraVR](https://www.moguravr.com/?p=284649) (snippets only)

**Steam AI-content disclosures (counts)**
- Totally Human Media (Ichiro Lambe), July 2025: 7,818 Steam titles disclosed genAI (~7% of library), ~20% of 2025 releases; ~1,000 in April 2024; visuals cited in ~60% of disclosures — [Totally Human](https://www.totallyhuman.io/blog/the-surprising-number-of-steam-games-that-use-genai), [Tom's Hardware](https://www.tomshardware.com/video-games/pc-gaming/1-in-5-steam-games-released-in-2025-use-generative-ai-up-nearly-700-percent-year-on-year-7-818-titles-disclose-genai-asset-usage-7-percent-of-entire-steam-library) (snippets only)
- Totally Human, Nov 2025 (read in full): 10,258 titles (8% of Steam); combined Boxleiter gross ≈ $660M; 12 games at 8 figures, 33 at 7, 170 at 6, 487 at 5, 9,556 below — [Totally Human](https://www.totallyhuman.io/blog/games-with-ai-disclosures-have-grossed-an-estimated-660m-on-steam)
- Sulka Haro census (read in full; 65,287 Steam "Games" released Jul 2023–2 Nov 2026): October 2026 — 1,982 of 3,897 new games (51%) carried the disclosure; u/ploz counted 49.9% for the same month; AI games were 42% of launches in Q3 2026 but ~12% of sales; Haro states his data "can't tell which tools anyone used" — [Haro, 4 Nov 2026](https://fragwyz.substack.com/p/half-of-new-steam-games-now-disclose)
- Steam Next Fest October 2026: 2,502 of 7,240 demos (34.6%) disclosed AI; of those, 75.7% mentioned art, 0.3% "substantially AI-built" (Chris Zukowski's count). Share was 21% in Feb 2026 and 26% in June (GameDiscoverCo) — [Haro](https://fragwyz.substack.com/p/half-of-new-steam-games-now-disclose); [tech-insider](https://tech-insider.org/steam-ai-disclosure-2026/) (snippet only). GamingOnLinux counted only ≥1,054 of 7,164 (15%) and PC Guide 2,593 (36%) — counts differ by method (snippet only).
- Steam Page Analyzer (read in full; random sample of 1,592 unreleased pages, 23 Oct 2026): 29% flagged (465 pages); 80% of disclosures mention visuals, 32% music/SFX, 32% text, 27% localisation, 23% store/marketing, 22% code, 12% voice; **"only about 4 to 5% name a product"** — [Steam Page Analyzer](https://www.steampageanalyzer.com/blog/steam-ai-disclosure-what-developers-wrote)
- Zhang (2025) BERTopic study of 584 disclosures from 2024 games: most common areas voice generation, visual assets, translation/localisation, workflow support (tool counts not reported in the citing paper) — cited in [Bazzaz & Cooper, arXiv 2608.11539](https://arxiv.org/html/2608.11539v1)

**itch.io tags (own count, 24 Nov 2026)**
- itch.io browse pages: `tag-ai-generated` 5,466 games of 1,849,197 total; user tags `chatgpt` 88, `stable-diffusion` 15, `midjourney` 9, `dall-e` 5, `flux` 4 — [itch.io tag-ai-generated](https://itch.io/games/tag-ai-generated), [itch.io games](https://itch.io/games). These are free-form creator tags, not itch.io's AI disclosure field (the disclosure is optional for games, mandatory for assets since Nov 2024 — [PC Gamer](https://www.pcgamer.com/software/platforms/indie-distribution-platform-itch-io-now-requires-asset-creators-to-disclose-the-use-of-generative-ai-in-their-work)); Dot Esports put games carrying the AI Generated disclosure tag at ~132,000 (snippet only, undated) — [Dot Esports](https://dotesports.com/general/news/itch-io-deletes-ai-slop)

**Own Steam sample: tools named in disclosure text (24 Nov 2026)**
Method: on 24 Nov 2026 I fetched English Steam store pages (curl/urllib through the session
proxy) for (a) the 1,500 most recent releases in Steam search sorted by release date, category
Games (all released 15–24 Nov 2026), and (b) the first 297 "Top Sellers" and 300 "Popular New
Releases" (360 unique games). I extracted the "AI Generated Content Disclosure" text and matched
product names with regexes, then read every image/3D hit by hand. Search URLs:
[recent](https://store.steampowered.com/search/?sort_by=Released_DESC&category1=998),
[top sellers](https://store.steampowered.com/search/?filter=topsellers&category1=998),
[popular new](https://store.steampowered.com/search/?filter=popularnew&category1=998).
Limits: one week of releases, mostly tiny games (only 84 of the 834 disclosing games had ≥10
reviews at fetch time); keyword matching; a disclosure that names no tool says nothing about
which tool was used; single run, not re-checked.

- (a) Recent releases: 834 of 1,500 (55.6%) carry a disclosure (consistent with Haro's 51% for
  October). Keyword share of the 834: visuals 712 (85%), text/translation 437, audio/music 310,
  code 236, voice 112. **82 of 834 (9.8%) name at least one product.**
- Products named (games, regex count): Claude 25, Suno 25, OpenAI/ChatGPT/DALL-E/GPT Image 13
  (any use), ElevenLabs 12, Google Gemini/Nano Banana/Imagen 10 (any use), PixelLab 7, Meshy 7,
  Adobe Firefly/Photoshop 6 (mostly manual Photoshop editing), Tripo 4, Midjourney 2, Stable
  Diffusion/ComfyUI 1, Flux 1, Leonardo 1, Retro Diffusion 1, Trellis 1, Kling 1, DeepL 1,
  Copilot 1, Grok 1. Also seen by hand: Seedream, Seedance 2.0, PixVerse, WAN, Google Lyria,
  VOICEVOX, Kokoro TTS, Irodori-TTS, "Claude Design".
- Hand classification of **visual-asset** uses only: Gemini/Nano Banana 8 games (concept art,
  textures, icons, sprites, backgrounds; one via ElevenLabs' image UI); PixelLab 7 (pixel
  characters, tiles, icons); Meshy 7 (3D characters/props); OpenAI image generation / GPT Image
  2.0 6 clear (+2 ambiguous "ChatGPT/GPT for assets"); Tripo 4 (3D characters/heads, incl.
  rigging); Midjourney 2 (Steam profile backgrounds; one other); Adobe Firefly / Photoshop
  generative fill 2; Leonardo 1 (pixel art); Flux 1; ComfyUI 1; Retro Diffusion 1; Kling 1;
  Microsoft Copilot images 1; Trellis 1 (image-to-3D); Seedream 1.
  3D generators combined (Meshy + Tripo + Trellis) = 12 games, more than any single 2D model.
- (b) Top sellers / popular new (360 unique games): 35 (9.7%) disclose AI; only 2 name a
  product, both audio: One More Lawn (ElevenLabs SFX, Suno radio songs; 1,284 reviews) and Train
  Sim World 7 (ElevenLabs TTS). Disclosing big titles (PUBG, Call of Duty, ARC Raiders, THE
  FINALS, Stellaris, Crimson Desert, World of Warships/Tanks, AION 2, EA Sports FC 27/Madden
  27/F1 25, inZOI, MapleStory, Where Winds Meet, Blue Archive) all describe use without naming a
  model.

**Vendor user counts (3D) — vendor claims, not usage shares among game developers**
- Meshy: >12M registered users and >100M models generated (July 2026 Series B); ~10M users at GDC March 2026; ARR passed $100M (30 Sep 2026) — [Unite.AI](https://unite.ai/ai-3d-firm-meshy-reports-100-fold-arr-jump-in-two-years), [aiidelist](https://aiidelist.com/blog/meshy-100m-arr-ai-3d.md) (snippets only; vendor)
- Tripo (VAST): claims 10M users and 90,000 studio/developer clients incl. Sony and NetEase; a Chinese report says 6.5M creators as of March 2026 (conflicting); earlier SCMP: >85% of users outside China — [woshipm](https://www.woshipm.com/share/6399237.html), [SCMP](https://www.scmp.com/tech/tech-trends/article/3338202/china-founded-tripo-ai-updates-3d-content-creation-platform-users-more-double) (snippets only; vendor)

### Inferences
- Among surveys, only GDC Jan 2026 gives a named-model ranking for images: Midjourney 17% > Adobe Generative Fill 13% > Sora 8% of AI users. Multiplying by the 36% usage rate, roughly 6% of all respondents used Midjourney (my arithmetic; GDC did not publish this).
- Image generation is a minority use inside the industry (22% of AI users; 8% for final assets), while art is the majority use in *shipped-content* disclosures (60–80% of Steam disclosures). Both are true because surveys count all AI use (mostly code/text) and disclosures count only player-facing content.
- Disclosure text is a poor source for model shares: 90–96% of disclosures name no product (Steam Page Analyzer 4–5% naming; our Nov 2026 count 9.8%). Tool-naming disclosers are self-selected, mostly solo developers who over-share.

### Gaps
- No 2025–2026 survey found that reports shares for Stable Diffusion/Flux, gpt-image, Nano Banana, Leonardo, Scenario, Meshy/Tripo/Rodin/Hunyuan3D, PixelLab/Retro Diffusion, Suno or ElevenLabs among game developers. Statista has a 2025 chart of genAI tool use by content area (paywalled, not read) — [Statista](https://www.statista.com/statistics/1608004/gen-ai-tool-usage-game-dev-areas-content-creation/).
- The November 2026 GDC full report (gated download) may contain a named-tool table; not read.
- CESA full report (Dec 2026) may break down tool types; not yet published.
- No a16z games survey with named art tools found in this pass.
- Game Developer Collective / Omdia and Gamesindustry.biz surveys with named art tools were not found.

## Any evidence on which tools appear in commercially or critically successful games vs failures?

### Takeaway
There is no tool-level success analysis. Evidence exists only at the disclosure level: AI-disclosing games are under-represented among sellers and reviewed worse, and the most successful games that disclose describe small, peripheral uses (paintings, posters, store capsules, voices) and seldom name a tool. Among Totally Human's 12 eight-figure disclosing games, one (Infection Free Zone) names a tool: Midjourney.

### Cited Findings
- Of 45 AI-disclosing Steam games estimated at ≥$1M gross, uses cited: in-game art 49%, voiceover/dialogue 27%, preproduction/concept 13%, marketing 11%, localisation 9%, upscaling <5%, runtime generation <5% — [Totally Human](https://www.totallyhuman.io/blog/games-with-ai-disclosures-have-grossed-an-estimated-660m-on-steam)
- Totally Human's public spreadsheet of the 12 eight-figure disclosing games (Stellaris, The Outlast Trials, Supermarket Simulator, My Summer Car, inZOI, The Long Drive, Call of Duty: Black Ops 6, X4: Foundations, VTOL VR, Infection Free Zone, …): only Infection Free Zone names a model ("Some artworks have been made with the help of the Midjourney AI tool"); Stellaris and X4 cite AI voices; inZOI uses runtime text-to-texture/image-to-3D — [Totally Human spreadsheet](https://docs.google.com/spreadsheets/d/1ZHfowAfdR84daeoSZlvXQK5Nm7zM2Kpevf5klURViNE/edit?gid=0#gid=0) (downloaded as CSV)
- Arc Raiders launched with >30,000 reviews, >90% positive, while citing limited genAI use — [Totally Human](https://www.totallyhuman.io/blog/games-with-ai-disclosures-have-grossed-an-estimated-660m-on-steam)
- In each mature quarter the two biggest AI-disclosed titles take 83–92% of estimated AI-game revenue; revenue per AI game outside the top two fell from ~$13,700 (Q2 2026) to ~$7,200 (Q3 2026) while AI launches rose from 2,059 to 3,391 — [Haro](https://fragwyz.substack.com/p/half-of-new-steam-games-now-disclose)
- AI-disclosed games average 76.4% positive vs 81.5% for others; half cost under $5; AI share lowest in metroidvanias (8.5%), hand-drawn (12%) and platformers (12%), highest in trading/card/management; AI games appear in the top-100 most-reviewed monthly releases at about half the rate their launch share predicts (12% in June → 20–22% Aug–Oct 2026) — [Haro](https://fragwyz.substack.com/p/half-of-new-steam-games-now-disclose)
- Successful games remove labels: Jul–Oct 2026, 105 games removed disclosures (2.5% of AI games with ≥100 reviews vs 0.7% with <10) — [Haro](https://fragwyz.substack.com/p/half-of-new-steam-games-now-disclose)
- Of Next Fest Oct 2026's 25 most-played demos, 2 disclosed AI (8% of top 25 vs 35% of the rest) — [Haro](https://fragwyz.substack.com/p/half-of-new-steam-games-now-disclose); [tech-insider](https://tech-insider.org/steam-ai-disclosure-2026/) (snippet only)
- Haro: flops (<50 reviews after ≥9 months) had a median 13-word disclosure vs 22 words for games with ≥1,000 reviews; 35% of flops used ≤10 words vs 13% — reported in [Steam Page Analyzer](https://www.steampageanalyzer.com/blog/steam-ai-disclosure-what-developers-wrote)
- Game Oracle (9,879 games, Jan–Oct 2025): comparable games with an AI disclosure got ~52.6% fewer reviews — [Steam Page Analyzer citing Notebookcheck](https://www.steampageanalyzer.com/blog/steam-ai-disclosure-what-developers-wrote); [PC Gamer](https://www.pcgamer.com/software/ai/data-analyst-finds-ai-stigma-on-steam-can-reduce-the-number-of-reviews-a-game-gets-by-around-53-percent-and-the-reviews-it-does-get-are-more-negative/) (snippet only)
- Bazzaz & Cooper (Northeastern, 2026; 508,192 English Steam reviews): AI-disclosing games recommended 68.4% vs 86.3% for procedural-generation games — [arXiv 2608.11539](https://arxiv.org/html/2608.11539v1); figures as reported by [Haro](https://fragwyz.substack.com/p/half-of-new-steam-games-now-disclose)
- Wiesinger, Pirker & Helic (arXiv, 19 Oct 2026): AI-disclosed games draw more AI-related criticism in negative reviews; they used "midjourney"/"stable diffusion" as review keywords but report no tool-level outcome split — [arXiv 2610.30178](https://arxiv.org/html/2610.30178v1)
- Case notes: Everplay's Warhounds disclosed AI placeholder portraits and drew AI complaints in "nearly every second negative review" until it removed them — [Llama & Griffin Next Fest June 2026 report](https://www.llamagriffin.com/Data/SteamNextFestJune2026/part-2.html)

### Inferences
- With ≤6% of disclosures naming a product, any "which tool do hits use" claim is based on a handful of games and is not statistically meaningful. In Totally Human's top-12, one hit names Midjourney; in our 360-game top-seller sample, no hit names an image or 3D model at all, and the only named tools are ElevenLabs and Suno (audio). Large publishers disclose generically, so model choice in commercially successful games is effectively undisclosed.
- Commercial outcome tracks scope of use, not tool: hits disclose narrow, peripheral or voice/localisation uses; flops tend to give terse disclosures and cluster in cheap, high-volume genres.

### Gaps
- No study links specific models (Midjourney vs SD vs gpt-image vs Nano Banana, or Meshy vs Tripo) to sales or review scores.
- Haro's dataset (65k games with disclosure text) could answer this, but it is not public.

## Trends over 2025–2026

### Takeaway
Measured trends are about volume, not model mix: Steam disclosures went from ~1,000 titles (Apr 2024) to 7,818 (Jul 2025) to 10,258 (Nov 2025) and to about half of new releases by October 2026; GDC usage rose 31% → 36% → 40% while sentiment worsened. A shift from Midjourney/SD to gpt-image/Nano Banana, or a rise of 3D generators, is not measured by any survey found; the only signals are vendor user counts (Meshy >12M users; Tripo claims 10M) and tool-name counts in disclosures.

### Cited Findings
- GDC personal genAI use: 31% (2025 report) → 36% (Jan 2026) → 40% (Nov 2026); negative sentiment 18% → 30% → 52/54% → 55% — [PC Gamer](https://pcgamer.com/31-of-game-developers-already-use-generative-ai) (snippet only); [Game Developer](https://www.gamedeveloper.com/business/one-third-of-game-workers-use-generative-ai-but-half-think-it-s-bad-for-the-industry); [GDC](https://gdconf.com/state-of-the-game-industry-november-2026/)
- Steam disclosure share of new releases rose ~1.3 points/month in the year to June 2026 and ~2.5 points/month in the year to October 2026; Q3 2026 ~44% of debut developers disclosed AI (34% in Q2); October 2026 was the first month AI-disclosing first-timers (1,466) outnumbered others (1,326) — [Haro](https://fragwyz.substack.com/p/half-of-new-steam-games-now-disclose)
- Since January 2026 Valve's form excludes efficiency tools (code assistants) from disclosure — [Steam Page Analyzer](https://www.steampageanalyzer.com/blog/steam-ai-disclosure-what-developers-wrote)
- itch.io: new game pages per day doubled in two months (autumn 2026), mostly first-time uploaders; 2–3 Nov 2026 itch.io deleted "a couple terabytes of ai slop" and added a filter to hide AI-noticed pages — [Haro](https://fragwyz.substack.com/p/half-of-new-steam-games-now-disclose)
- 3D generators: Meshy ~10M users (Mar 2026) → >12M (Jul 2026), ARR >$100M (Sep 2026) (vendor) — [Unite.AI](https://unite.ai/ai-3d-firm-meshy-reports-100-fold-arr-jump-in-two-years) (snippet only); Tencent launched Hunyuan 3D engine globally (Nov 2025) — [Tencent](https://www.tencent.com/en-us/articles/2202235.html) (snippet only)
- Survey-level image-tool trend: Midjourney was the top image tool in GDC's Jan 2026 report; the Nov 2026 edition summaries report only "image generation 22%" with no model names, so a Midjourney→gpt-image/Nano Banana shift cannot be read from GDC — [Game Developer](https://www.gamedeveloper.com/business/one-third-of-game-workers-use-generative-ai-but-half-think-it-s-bad-for-the-industry); [GameDev Reports](https://gamedevreports.substack.com/p/gdc-the-state-of-the-game-industry-52b)
- Own Steam count, releases 15–24 Nov 2026 (see Q1): where a visual tool is named, Google Gemini/Nano Banana (8), PixelLab (7), Meshy (7), OpenAI image (6) and Tripo (4) outnumber Midjourney (2) and Stable Diffusion/ComfyUI/Flux (1 each); among all named products, Suno (25) and ElevenLabs (12) lead audio and Claude (25) leads text/code — [Steam search, recent releases](https://store.steampowered.com/search/?sort_by=Released_DESC&category1=998) (own count; one week; n = 82 tool-naming disclosures)
- Contrast with GDC's Jan 2026 survey, where Midjourney was the top image tool (17% of AI users) — [Game Developer](https://www.gamedeveloper.com/business/one-third-of-game-workers-use-generative-ai-but-half-think-it-s-bad-for-the-industry). The two sources measure different populations (studio professionals vs tiny new Steam releases), so this is suggestive of a shift, not proof.

### Inferences
- Weak evidence of a shift: in late-2025 survey data Midjourney led image tools; in a November 2026 sample of new Steam releases, Gemini/Nano Banana, OpenAI image generation, PixelLab and 3D generators (Meshy, Tripo) are named far more often than Midjourney or Stable Diffusion. Different populations and tiny counts; flag as unverified trend.
- The disclosure surge in 2026 comes mostly from first-time, low-price developers; it reflects cheaper image/text generation and AI coding tools making solo releases possible, not a measured change in which model studios prefer.
- Blog "best tool" rankings for 2026 (Midjourney for look, GPT Image 2 as default, Nano Banana 2 for volume; Meshy/Tripo/Rodin for 3D) are opinion and vendor content, not usage data — e.g. [devtoollab](https://devtoollab.com/blog/best-ai-image-generators), [Meshy blog](https://www.meshy.ai/blog/best-ai-tools-for-3d-game-assets).

### Gaps
- No longitudinal named-model data for image tools among game developers; no survey shares for 3D generators, PixelLab/Retro Diffusion, Suno or ElevenLabs.
- Japanese and Chinese reports give category shares (art tools ~half of tool traffic in China) but not model names.
- a16z games and Gamesindustry.biz surveys with tool breakdowns were not found in this pass.
