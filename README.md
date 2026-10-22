# Project *Sebound*

A 2D adventure prototype built in **Godot 4.8**: a Cuphead-style overworld, Hollow Knight / Cuphead-style
platforming stages, and Super Smash Bros.-style battles, with a story told through NPC dialogue.

> The title is a placeholder. Change `TITLE` in `scripts/autoload/game.gd` and `config/name` in `project.godot`.

## Running it

1. Open the folder in Godot 4.8 (or newer) and press **F5**, or run `godot --path .` from a terminal.
2. Flow: splash → **loading screen** → **main menu** → New Game (optionally starting with the tutorial).

## Controls (keyboard + controller)

| Action | Keyboard | Controller |
|---|---|---|
| Move / climb | WASD / arrow keys | Left stick / D-pad |
| Jump (double jump in battle) | Space / Z | A |
| Sprint (hold) | Shift | B / RT |
| Crouch / crawl | S / ↓ | Down |
| Dash (needs Gale Boots) / Dodge / Shield | C | LB / LT |
| Talk / interact | E | Y |
| Light attack (Up + attack = up attack) | J / X | X |
| Heavy attack | K | Y |
| Special (Up + special = recovery leap) | L | RB |
| Inventory | Tab / I | Back |
| Pause | Esc / P | Start |
| Fullscreen · show hitboxes | F11 · F3 | — |

Bindings are registered in code (`scripts/autoload/controls.gd`). On-screen prompts change between keyboard and
controller labels depending on which device you last used.

## What the prototype covers

| Objective | Where |
|---|---|
| NPC interaction + story dialogue (typewriter, portraits, choices) | `scripts/autoload/dialogue.gd`, NPCs in `scripts/world/overworld.gd` |
| Adventure → combat transition like Pokémon (white flashes + sweeping bars) | `Transition.battle_cover()`, `Game.start_battle()` |
| Cuphead-style overworld with level entrances | `scripts/world/overworld.gd` |
| "3D illusion" | Overworld: y-sorting, perspective scaling (higher on the map = smaller), drop shadows, swaying trees, drifting cloud shadows. Stages and arena: multi-layer parallax, foreground silhouettes that move faster than the camera, floating leaves/motes. Plus an optional old-film filter (vignette + grain) |
| Sprint, crouch/crawl, climb, jump, dash | `scripts/platformer/platform_player.gd` |
| Health + inventory with upgrades | Hearts and items in `scripts/autoload/game.gd`; inventory UI in the pause menu |
| Platform obstacles | Tripping twigs, seed-spitting pods, falling acorns, thorns, pits, low crawl caves, vines, one-way planks |
| Smash-style combat | `scripts/combat/`. Damage % increases knockback, ring-outs, shields, rolls, air dodges, double jumps, hitstop and screen shake. HP bars Street Fighter-style |
| Demo boss with flash screen + intro scene | The Bramble King, at the end of Whispering Woods (`boss_fighter.gd`, `_boss_intro()` in `combat_arena.gd`) |
| Loading screen | `scripts/ui/loading_screen.gd` (threaded loading, progress bar, tips) |
| Tutorial | Training Grounds stage with hint zones, plus a combat-training checklist against a dummy |
| Menu, save + exit | Main menu, pause menu (save / settings / controls / quit / exit), benches heal and save. Save file: `user://savegame.json` |

### Demo route

Village (talk to Elder Moss) → **Training Grounds** (optional) → cross the bridge → **Whispering Woods**:
find the Berry Tonic, the Rusty Key at the top of the vines (bring it back to Little Fern for the Thorn Charm),
pick up the **Gale Boots** and dash across the wide gap, then rest and enter the gate to fight **the Bramble King**.
Touching a wandering Thornling on the map or in a stage starts a battle.

## How health works across modes

Adventure health is counted in hearts (5 to start). In battle each heart is 20 HP, so 5 hearts = 100 HP. Damage
taken in a fight carries back into the adventure. A ring-out costs one heart's worth of HP and resets your damage %.

## Project layout

```
assets/
  sprites/       placeholder pixel art (PNG sheets)
  backgrounds/   parallax layers
  shaders/       transitions, old-film filter, foliage sway, hit flash
scenes/          one small .tscn per screen (each script builds its scene in code)
scripts/
  autoload/      Game (state, save, routing), Controls, Transition, Dialogue, PauseMenu, PostFX
  core/          SpriteLib, UIKit theme, Interactable, ParallaxBG, Fx
  world/         overworld, overworld player, wandering encounters
  platformer/    level data (ASCII maps), level builder, player, hazards, pickups, enemies
  combat/        Fighter base class, player / AI / boss fighters, arena, HUD, hazards
  ui/            boot, loading screen, main menu, game over, HUD
  generated/     sprite_meta.gd (frame layout of every sheet, written by the art script)
tools/gen_assets.py   generates all placeholder art
tests/playtest.*      automated playtest (drives real scenes with simulated input)
```

## Editing content

- **Stages:** edit the ASCII maps in `scripts/platformer/level_data.gd`. There is a legend at the top of the file.
  Items, hints and signs are filled in left to right from the lists next to each map.
- **Overworld:** edit `MAP` and `NODES` at the top of `scripts/world/overworld.gd`. NPC dialogue is in `_talk()`.
- **Items:** `ITEMS` in `scripts/autoload/game.gd`.
- **Moves and balance:** the `MOVES` tables in `player_fighter.gd` and `ai_fighter.gd`, and the boss patterns in `boss_fighter.gd`.

## Replacing the placeholder art

All art is generated by `python3 tools/gen_assets.py` (requires Pillow). To swap in your own pixel art,
overwrite a PNG in `assets/sprites/` and keep the same frame size and frame order. The layout of each sheet
is listed in `scripts/generated/sprite_meta.gd`; edit that file instead if your animations differ. Once you
have custom art, stop re-running the generator, or delete that sprite's `build_*` call first, because the
generator overwrites the PNGs.

## Testing

```
godot --headless --fixed-fps 60 res://tests/playtest.tscn
```

This runs about 40 checks: movement, sprint, jump, crawl, climbing, tripping, pits, projectiles, inventory,
save, combat damage and %, the combat tutorial, the boss patterns and victory flow, the overworld, menus and
the loading screen. It exits with code 0 when everything passes.

## Sharing on GitHub

The folder is a git repository with Godot's `.gitignore` (the `.godot/` cache is not committed; `*.import`
files are). To publish it:

```
git add -A
git commit -m "Prototype: overworld, platforming, combat, boss, menus"
gh repo create project-bramble --private --source=. --push   # or add a remote and git push
```

## Not in the prototype yet

- Audio (no music or sound effects yet)
- Remapping controls from inside the game (they can be changed in `controls.gd`)
- More stages: Thornspire is shown on the map as locked
