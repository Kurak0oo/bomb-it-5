# Install the replica on your iPhone (#87)

This is a private build for your own iPhone, installed from Xcode with a free Apple ID. It
involves no App Store, TestFlight or Douyin upload. The original pack is added only to
your local copy; nothing SWF-derived goes into git.

Platform claims were checked on 2026-10-29 against:

- Godot 4.5-stable's source and class reference;
- Godot's [iOS export page](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_ios.html);
- Apple's [membership comparison](https://developer.apple.com/support/compare-memberships/)
  and [Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)
  pages.

## What the project already sets

| Requirement | Setting | Source |
| --- | --- | --- |
| Landscape only, both directions | `display/window/handheld/orientation=4` (sensor landscape). The iOS exporter writes `UIInterfaceOrientationLandscapeLeft` and `…Right` | `editor_export_platform_apple_embedded.cpp` |
| Compatibility renderer | `rendering_method.mobile="gl_compatibility"` | `project.godot` |
| Silent switch respected, other apps' audio mixed in | `audio/general/ios/session_category=0` (Ambient). Ambient follows the silent switch, and Godot notes it always mixes with others | ProjectSettings reference; `app_delegate_service.mm` |
| 120 fps on ProMotion, 60 elsewhere | `display/window/ios/allow_high_refresh_rate` (default true) asks `CADisplayLink` for 120. The 4.5 Info.plist template already has `CADisableMinimumFrameDurationOnPhone` | `godot_view_apple_embedded.mm`; `godot_ios-Info.plist` |
| Game speed independent of refresh rate | The replica steps at the original 35 Hz, at most one step per drawn frame (#79), and draws between steps | `tick_scheduler.gd` |
| Backgrounding pauses on the original pause screen | `Game` pauses at once on `NOTIFICATION_APPLICATION_FOCUS_OUT` and `…PAUSED` and shows the pause page | `scripts/game.gd` |
| Original sound and music switches | Main menu and pause screen; saved in `user://` | #75 |

Godot 4.5's iOS minimum deployment target defaults to 14.0. Set it to 16.0 below.

## One-time setup on the Mac

1. Install Xcode from the Mac App Store and open it once to accept the licence. If export
   later complains about `xcode-select`, run:

   ```bash
   sudo xcode-select -switch /Applications/Xcode.app
   ```

2. In Xcode, open **Settings › Accounts** and add your Apple ID. With no paid membership,
   Xcode shows it as a *Personal Team*.
3. Install Godot 4.5-stable (standard, not .NET). Open this project, then use **Editor ›
   Manage Export Templates › Download and Install** for 4.5-stable.
4. Connect the iPhone by USB and trust the Mac. On iOS 16 or later, turn on
   **Settings › Privacy & Security › Developer Mode** and restart when asked. The switch
   appears only after the phone has been connected to Xcode once.

## Build the original pack (local only)

Put your SWF at `.scratch/edition-5-research/agame-bomb-it-5-zh-fix.swf`. Then build the art
and audio packs (Python 3.11+, Java, and the art pipeline's packages; see
`tools/art_pipeline/README.md`):

```bash
python3 tools/art_pipeline/original_pack.py --resume
```

```bash
python3 tools/art_pipeline/original_audio.py
```

```bash
git checkout tools/art_pipeline/manifest.csv
```

This writes `original/`, which git ignores. The game reads these files directly, so the
export must include them as plain files (next section). Without `original/` the build
still runs, with native drawing and no sound.

## Export from Godot

**Project › Export… › Add… › iOS**, then:

- **Application › App Store Team ID:** your Personal Team's 10-character Team ID. In Xcode,
  select the team under **Settings › Accounts**; the ID also appears in the Signing &
  Capabilities tab once a project is signed.
- **Application › Bundle Identifier:** something unique to you, for example
  `com.<yourname>.bombit5replica` (letters, digits, hyphens and periods only).
- **Application › Min iOS Version:** `16.0`.
- **Application › Targeted Device Family:** iPhone.
- **Resources › Filters to export non-resource files/folders:** `original/*`. This is
  required for the pack.
- Leave the provisioning profile fields empty, so that Xcode creates the profile.

Choose an empty folder outside the project and a file name without spaces (for example
`BombIt5`), then **Export Project**. `export_presets.cfg` is ignored by git, so your Team ID
stays local.

## Install from Xcode

1. Open the exported `.xcodeproj`.
2. Select the app target. Under **Signing & Capabilities**, tick *Automatically manage
   signing* and choose your Personal Team.
3. Pick your iPhone as the run destination and press **Run**.
4. The first launch of a free-account app may be blocked until you trust the developer on
   the phone. On current iOS this is under **Settings › General › VPN & Device Management**.

## The weekly reinstall

Apple's free-account profiles expire 7 days after they are issued. The app then stops
launching until you build and install it again from Xcode. Re-run **Run** from the same
Xcode project; there is no need to re-export unless the game changed. A free account can
also register at most 3 devices and 10 App IDs, and install at most 3 apps per device.

## Checking the build on the phone

- **Orientation:** rotate between both landscape directions. The page re-fits each time,
  and portrait is never offered.
- **Silent switch:** with the switch on, the game is silent. Music from another app keeps
  playing under the game.
- **Original switches:** the sound and music switches on the main menu and pause screen
  still work, and stay set after relaunch.
- **Backgrounding:** during play, swipe home and come back. The original pause screen is
  showing and the round has not moved.
- **Frame rate:** on a ProMotion iPhone, motion is smooth at 120 Hz and the round runs at
  the same speed as on a 60 Hz phone. Slow-downs should only come from the original
  engine's own rules (#79).
