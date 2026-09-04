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
- `assets/art/`: actual PNG character/background/map artwork and static SVG terrain/props.
- `assets/art/ui/`: bundled SVG arrows, pause, and sound icons, independent of system font availability in web exports.
- `assets/audio/`: 17 original pre-rendered WAVs, including three looping tracks and a victory fanfare.
- `assets/fonts/`: bundled Rubik fonts with their SIL Open Font License.
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
```

Gameplay tests exercise real physics: acceleration, sprint, jump height, coyote time, buffering, landing, stomps, power-ups, damage immunity, death, and respawn. Flow tests isolate save data and exercise screen transitions and stale-timer regression cases. The traversal test uses actual input actions to complete the level.

## Assets and attribution

Character sprites, title landscape, and overworld map were made with the built-in image-generation tool; prompts are in **assets/art/PROMPTS.md**. Artwork is stored locally and the transparent atlas is consumed directly. The SVG environment assets were authored offline. This game does not use Nintendo sprites, levels, music, branding, or sounds.

Original audio provenance and reproduction instructions are in **assets/audio/README.md**. Rubik copyright notices and licensing are in **assets/fonts/OFL.txt**. No affiliation or endorsement by Dario Amodei, Sam Altman, Anthropic, or OpenAI is implied.
