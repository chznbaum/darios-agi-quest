# Dario’s AGI Quest

A small, original Godot platform adventure: big hair, little hero, and a very elusive AGI. Created by an AI agent for this request; the finished build has not received a formal human review. This is an unofficial, affectionate parody with fictional dialogue and events.

## Play on this Mac

Double-click **Dario’s AGI Quest.app** in this folder. It launches the game using the installed Godot engine; keep the app inside the project folder. Alternatively, double-click **Play Dario's AGI Quest.command**.

To edit or run through Godot, import **project.godot** and press **F5**. Built and tested with Godot **4.7.2**, using the Compatibility renderer. No account, API key, network connection, or asset generation is needed to play.

## Controls

| Key | Action |
| --- | --- |
| A / D or Left / Right | Move; select a location on the map |
| W / Space / Up | Jump; hold for a higher jump |
| Shift | Run |
| S / Down | Fall faster while descending |
| Enter | Confirm menus |
| Esc | Pause / resume; back from map |
| M | Toggle all sound |
| F11 | Toggle fullscreen |

Stomp enemies from above. Holding jump during a stomp produces a higher bounce. Health is shown as three hearts. There are unlimited retries; flags preserve your position during the current run.

## Mobile web

Open the hosted game on a phone or tablet and turn it sideways. Touch controls appear automatically. Hold the left/right arrows with one thumb and **JUMP** with the other; holding jump gives higher leaps and stomp bounces. Running starts enabled. Tap **RUN ON** to switch to **WALK**, or hold **DROP** to fall faster. Pause and sound buttons are at the top right.

Showing the portrait prompt or actually hiding the page pauses the level and releases held controls. Return to landscape and tap **KEEP GOING** to resume. Browser focus changes and address-bar resizing do not pause the level or block resume. Browser menus and phone notches have space around the game, and the canvas prevents scrolling during play. Desktop keyboard controls remain available.

The Web export preset includes `web/mobile_shell.html`, both desktop and mobile texture formats, and PWA support with standalone display and a landscape preference. Export **Web** with **Export With Debug** unchecked, keep all generated files together (including the manifest, service worker, offline page, and icons), and replace the files on your static HTTPS host. Thread support and cross-origin isolation headers stay off; no backend is needed. The custom shell is part of the project, so future exports retain mobile support. For desktop layout previews, append `?touch=1` to the game URL, or launch the native project with `-- --touch-controls`.

To play without browser chrome, install the hosted game and launch its home-screen icon:

- **iPhone/iPad:** in Safari, use **Share → Add to Home Screen**, enable **Open as Web App** if offered, then **Add**. [Apple instructions](https://support.apple.com/guide/iphone/open-as-web-app-iphea86e5236/ios)
- **Android:** in Chrome, open the menu and choose **Install** / **Add to Home screen**. [Google instructions](https://support.google.com/chrome/answer/9658361?co=GENIE.Platform%3DAndroid&hl=en)

Opening the ordinary browser URL still shows the browser interface. After updating an installed version, close existing game tabs/app windows and reopen; a service-worker update can require another reopen after downloading. Deploy the complete export together and avoid long-lived immutable caching for the HTML, manifest, and service worker. Clearing site data also clears saved progress, so it should not be a routine update step. Offline availability depends on the browser retaining the cached game files; an online reopen after installation lets the worker cache the full game.

The current BunnyCDN deployment was observed serving the game HTML with `Cache-Control: public, max-age=2592000` (30 days). Purge `/darios-agi-quest/` after replacing the export and refresh Safari. Configure HTML, manifest, and service-worker responses to revalidate (`Cache-Control: no-cache`) so future releases are picked up promptly.

The enabled `addons/web_pwa_fix` editor plugin works around a Godot 4.7.2 export bug: apostrophes in the project name otherwise create an invalid service-worker string. It safely quotes that string after export, preserving the game name and saved-progress identity. Reopen the Godot project once if it was already open when the plugin was added; subsequent GUI and CLI exports apply the fix automatically.

Mobile behavior is covered by automated tests and Chrome touch emulation. Physical iPhone/iPad Safari and Android Chrome testing is still needed to assess device performance and how the controls feel.

## Chapter 01

The title screen leads to an illustrated world map and **1–1 Token Meadow**, a complete 6,100-pixel level with an optional upper route, three hidden insight crystals, token trails, supply blocks, computer bugs, hallucination clouds, and a three-stomp Sam boss encounter. Reach the castle after the boss for the ending. Compute Peaks is visibly marked as a future chapter.

- **Safety Shield:** absorbs one hit, expires after 12 seconds.
- **Overclock Coffee:** 10 seconds of faster running and stronger jumps.
- **Heart:** restores one health point.
- **Supply blocks:** jump into their underside to activate a power-up.

The game saves cleared status, best token/insight totals, and sound preference in Godot’s local user-data directory. Checkpoint positions last for the current run. Quitting or restarting starts the level again.

## Project layout

- `scenes/main.tscn` / `scripts/main.gd`: title, map, HUD, level population, pause, progression, and ending.
- `scenes/meadow_layout.tscn`: authored terrain, one-way platforms, scenery, and castle.
- `scripts/player.gd`, `enemy.gd`, `boss.gd`: actor physics and animation.
- `scripts/pickup.gd`: collectibles and power-up pickup behavior.
- `scripts/art.gd`: regions of the original transparent character atlas.
- `scripts/touch_controls.gd`: multi-touch input, thumb controls, and run/walk toggle.
- `assets/art/`: actual PNG character/background/map artwork and static SVG terrain/props.
- `assets/art/ui/`: bundled SVG arrows, pause, and sound icons, independent of system font availability in web exports.
- `assets/audio/`: 17 original pre-rendered WAVs, including three looping tracks and a victory fanfare.
- `assets/fonts/`: bundled Rubik fonts with their SIL Open Font License.
- `web/mobile_shell.html`: safe-area layout, portrait prompt, and browser interruption handling.
- `addons/web_pwa_fix/`: editor-only compatibility fix for PWA exports with apostrophes in the game name.
- `tools/`: optional offline asset authoring sources. These do not run during gameplay.
- `tests/`: headless movement and game-flow regression tests.

## Validation

Verified in Godot 4.7.2: **26 movement checks, 57 game-flow checks, and 24 full-level traversal checks pass**. The traversal uses actual input to cross all gaps, recover from a boss death, stomp Sam three times, reach the ending, and collect all three insights on a second continuous run. Six rendered screenshots are in **screenshots/**.

Run from this project directory:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/gameplay_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/flow_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script res://tests/traversal_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/touch_controls_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/mobile_flow_test.gd
node --test tests/mobile_shell_test.cjs
```

Gameplay tests exercise real physics: acceleration, sprint, jump height, coyote time, buffering, landing, stomps, power-ups, damage immunity, death, and respawn. Flow tests isolate save data and exercise screen transitions and stale-timer regression cases. The traversal test uses actual input actions to complete the level.

Mobile validation adds **34 touch-input checks and 68 controller integration checks** for simultaneous fingers, jump height, sliding directions, run/walk, canceled touches, keyboard coexistence, pausing, rotation, background interruptions, and scene cleanup. Eight shell regression scenarios execute the actual HTML bridge, including visible-but-unfocused startup and portrait-to-landscape rotation without a focus event. Browser QA screenshots are in `output/playwright/`, excluded from game imports.

## Assets and attribution

Character sprites, title landscape, and overworld map were made with the built-in image-generation tool; prompts are in **assets/art/PROMPTS.md**. Artwork is stored locally and the transparent atlas is consumed directly. The SVG environment assets were authored offline. This game does not use Nintendo sprites, levels, music, branding, or sounds.

Original audio provenance and reproduction instructions are in **assets/audio/README.md**. Rubik copyright notices and licensing are in **assets/fonts/OFL.txt**. No affiliation or endorsement by Dario Amodei, Sam Altman, Anthropic, or OpenAI is implied.
