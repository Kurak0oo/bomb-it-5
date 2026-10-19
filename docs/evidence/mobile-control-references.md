# Mobile-control design references

Checked 2026-10-19 following the user's request to reference mature mobile games such as PUBG Mobile and Honor of Kings. These references inform control presentation, not edition 5 gameplay authority. The user has already chosen a fixed, always-visible stick, eight phone directions and a normal-speed request outside the deadzone.

| Official reference | Supported observation | Limit |
| --- | --- | --- |
| [PUBG MOBILE controls help](https://pubgmobile.helpshift.com/hc/en/3-pubg-mobile/faq/37-what-are-the-controls/) | Left-side movement control, touch/drag interaction, separate action buttons and customizable controls | Does not document stationary versus floating base, thumb animation, easing or response timing; its running behavior is outside this game's accepted input model |
| [PUBG MOBILE control-key positioning](https://pubgmobile.helpshift.com/hc/en/3-pubg-mobile/faq/280-i-want-to-change-the-location-of-the-control-key/) | Players can position controls through the customization interface and save their layout | Supports layout customization, not animation timings or input-latency measurements |
| [Riot Wild Rift patch 2.2, Move Stick](https://wildrift.leagueoflegends.com/en-gb/news/game-updates/wild-rift-patch-notes-2-2/) | Explains a historical joystick-center change intended to prevent initial drag from causing unexpected opposite-direction movement near screen edges | A 2021 design rationale, not a current-default claim or this game's fixed-base specification; ability-button dead zones on that page are not movement dead-zone measurements |

Honor of Kings remains a user-selected visual inspiration. This lookup did not establish an official numeric animation or state-transition specification for its joystick; do not attribute invented settings to it.

The project's own accepted feedback requirement is that the fixed stick remains visible and its demonstration/animation responds clearly to input. An implementation can express this with idle/pressed/dragged/released states, a thumb indicator following input and a centered released state. Exact art, easing and numeric timing are implementation/tuning choices, not measured facts from these sources. The reference request does not authorize sprinting, variable-speed deflection, unrelated action buttons or copying game assets.

The user rejected an early phone prototype. Build the main Godot game to publication readiness first, then perform physical phone/iOS testing. Desktop tests and input simulation can verify implementation during development; physical-device validation is a later stage and does not block the initial Godot implementation. The named control references are not evidence that this game's phone feel has already been validated.
