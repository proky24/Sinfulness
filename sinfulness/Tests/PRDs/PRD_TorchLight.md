# PRD 7: Torch light blocked by walls, dark doorways (Sinfulness, Godot 4.7.2)

Owner: Proke. Status: ready for implementation. Builds on PRD 4 / PRD 5 and their handoff (`Tests/PRDs/NewFloor1_Handoff.md`). **Read the handoff first:** §1 (working rules), §3 (layers and draw order), §4 (doors and niches), §5 (tile reference), §7 (MCP pitfalls) and §8 (verification recipe) all still apply. Notion page "Sinfulness" (`379f4675-ea8f-808d-97a9-d3fa80343d85`) has the project conventions.

## 1. Goal

The torch light (`PointLight2D` in `TorchSmall`) currently ignores the tilemap. Next to a door, it lights the inside of the arch opening, which should read as the dark space beyond the door. The door looks lit from behind.

Fix it so that:
- **Doorway openings stay dark.** No torch light inside the opening of any arch door, from either side.
- **Walls block light in general,** not just doors. Light must not reach places it physically couldn't (over a wall top or through a side wall into the next room).
- **The door frame and the torch's own wall stay lit.** The arch stones and the brick front the torch hangs on keep their glow.
- **It's data-driven.** The fix lives in the shared TileSet and in `TorchSmall.tscn`, so every existing and future torch, door and floor gets it automatically. No per-level occluder nodes.
- **The look is unchanged:** same color, energy, flicker (`torch_lit`) and size.

### Out of scope
- Shadows from the player, enemies or props (light hitting the player itself stays as it is, see §3.4).
- `CanvasModulate`, `WorldEnvironment`, particles, other light types.
- Other TileSets (Water, DecorativeFloor, DecorativeWalls), unless one turns out to be needed. Ask first.
- Floor layout, collisions, draw order and the behind/in-front logic (`Floors/Behind_Infront/`).
- Torches in the niches and wooden doors (later PRDs). The occluders must not get in their way, though (§3.3).

## 2. Current state (verified)

- **`res://Entities/GeneralNodes/Props/Torches/TorchSmall.tscn`:**
  - `TorchSmall` (Node2D, y-sort) → `Sprite2D` (`torch_small_sheet.png`, `hframes = 6`, 32×48 frames) → `PointLight2D`, plus an `AnimationPlayer` (autoplay `torch_lit`: frames 0–5 over 0.5 s, `energy` 3.0/3.5/2.5/3.0/3.5/3.0).
  - Light: color `(0.98, 0.97, 0.34)`, energy 3.5, texture `GradientTexture2D` (default 64×64, radial, `fill_from (0.5, 0.5)` → `fill_to (0.9, 0.5)`, white→black).
    - The light reaches black about **26 px** from the centre (0.4 × 64), not 32.
  - `shadow_enabled = false`. All masks are at the default (layer 1).
- **`res://Floors/TilesSetsNodes/FloorWallTile.tscn`:** a TileMapLayer scene whose TileSet (atlas `walls_floor.png`, 16×16) has **no occlusion layer**.
  - Floor, WallFaces, WallFacesUpper, WallTops and ArchTops in the floor all instance this scene and share the TileSet. No instance overrides `tile_set`, so one TileSet change reaches all of them.
  - The user edits this file themselves (handoff §1). **This PRD approves edits to it for the occlusion layer only.** Don't touch collisions, terrains or tiles.
- **`res://Floors/Level1/Floor1/Floor1.tscn`** (root node `NewFloor1`) has two torches under `Props/Torches`, both `z_index = 1`:
  - `TorchSmall` at (488, 263), map cell ≈ (30, 16);
  - `TorchSmall2` at (439, 263), map cell ≈ (27, 16).
  - They flank the door **R6 → R2** (cells x28–29, y14–17, handoff §4). The torches hang on the brick front, row 16 (middle row), **not** in niches.
  - `CanvasModulate` color `(0.80, 0.78, 0.93)`. Project: Forward+, `viewport/hdr_2d = true`.
- **Arch door tiles (handoff §5):**
  - upper `4:24 5:24` (WallFacesUpper, row r-2);
  - lower `4:25 5:25` (WallFaces, row r-1);
  - wall top above the door `2:1` / `2:3` on ArchTops (rows r-4 / r-3).
  - All five doors use this arch. The opening is the transparent part of 4–5:24–25.
- **Layer note:** WallTops holds the true wall tops **and** the top brick row (2:3). ArchTops holds 2:1 and 2:3 above doors. Occlusion is set **per atlas tile**, not per layer.
- **Tests:** `res://Tests/FloorTest.tscn` = Floor1 (as `NewFloor1`) + Player at (136, 616) in the entrance room R1, far from the torches. Automated cases live in `Tests/Scripts/Cases/test_*.gd` and run through `Tests/TestRunner.tscn`.

## 3. Requirements

### 3.1 Occlusion layer
- Add one occlusion layer to the TileSet in `FloorWallTile.tscn`, with `light_mask = 1`. Leave `sdf_collision` off unless needed.
- Check, but don't change, that `occlusion_enabled` is on (the default) for the layers in Floor1. If it isn't, ask.
- Edit the TileSet without duplicating or re-embedding it (handoff §7: the duplicate pitfall). Afterwards, confirm that `Floor1.tscn` still has **no** `tile_set =` lines or embedded TileSet sub-resources.

### 3.2 Doorway occluders
- Tiles 4:24, 5:24, 4:25 and 5:25 get occluder polygons that cover **only the transparent opening**, never the arch stones.
  - Trace the polygons from the tile alpha. Use `Tests/Tools/crop_atlas.ps1` / `render_atlas.ps1` to look at the tiles. Within about 1 px is fine.
  - The polygon pieces of the four tiles must meet seamlessly, with no gap where light gets in.
- The gate (14–15:26–27) is not a door opening. Leave it alone unless the user asks.

### 3.3 Wall occluders
- Solid wall mass blocks light: true wall tops (2:2, 2:1, 1:1, 3:1, 1:2, 3:2), side rims (5:1–5:3, 7:1–7:3) and inner corners (5:4, 7:4).
  - Confirm the list in Phase 0 against the atlas render. Add anything that is clearly solid wall.
- **No occluders on brick fronts** (2:3, 2:4, 2:5, ends 1:3–1:5 / 3:3–3:5). Torches hang on these. A light inside or right next to a closed occluder polygon darkens its whole surroundings, and the torch's own wall must stay lit.
- **Niche tiles (9–11:1–4):** torches go into the 8 niches later. The niche must not enclose a torch in a closed polygon. Propose shapes in Phase 0, or leave the niche tiles out.
- Shapes can be full-tile squares where that works. Explain any tile where you chose something else.

### 3.4 Torch light settings (`TorchSmall.tscn`)
- Set `shadow_enabled = true` on `Sprite2D/PointLight2D`.
- Start with `shadow_filter = None` (hard edges suit the pixel art). Only try PCF5 if the edges look broken, and show the user both.
- `shadow_item_cull_mask` stays 1, so the player also gets darkened when standing inside a dark doorway. That's probably right (the doorway is dark). **Show it to the user in Phase 2 and let them decide.** If they don't want it, split the masks and document how.
- Don't change `color`, `energy`, `texture`, `texture_scale`, the node tree or the animation tracks.

### 3.5 Known side effects to check
- **Shadow cast by an opening:** each doorway occluder also throws a short shadow away from the torch.
  - The far jamb of the door is now shadowed from the torch on the other side. The torch on its own side still lights it.
  - The floor just south of the opening can also get a little darker.
  - At a radius of about 26 px this should be small. Check it at zoom 4.
- **Wall tops near a torch:** row 14 (wall top above the door and torch) used to get some light and will now be shadowed. Show it to the user.
- **Leaking through walls:** at a 26 px radius the light barely reaches another room. To check that walls block light, temporarily set `texture_scale` to 4 **at runtime only**, never saved.

### 3.6 Automated test
- Add `Tests/Scripts/Cases/test_torch_light.gd` (`extends TestCase`), following the existing cases. It checks that:
  - the TileSet from `FloorWallTile.tscn` has at least one occlusion layer with `light_mask & 1`;
  - tiles 4:24, 5:24, 4:25 and 5:25 each have an occluder polygon on that layer;
  - brick fronts 2:3, 2:4 and 2:5 have **no** occluder;
  - `TorchSmall.tscn`'s PointLight2D has `shadow_enabled == true` and its original color and energy.
- All existing tests must still pass (`[TEST] SUMMARY … failed=0`).

## 4. Phases and acceptance

Stop after each phase, report **in the chat message itself** (not only in the end-of-turn summary), and wait for the user's OK.

### Phase 0: audit (report only, change nothing)
- Re-read `TorchSmall.tscn`, `FloorWallTile.tscn`, the floor layers around door R6→R2, and the handoff.
- Render the arch tiles (4–5:24–25), the wall-top and rim tiles, and the niche block at 8× with the atlas tools, and show the user.
- Propose the occluder shape for each tile (doorway polygons, which wall tiles, the niche decision).
- **Before screenshots:**
  - Run `Tests/FloorTest.tscn` and move the player next to door R6→R2. Either walk there or set `Player.global_position` at runtime with `execute_code` + `.set()`. If physics interpolation is on, call `reset_physics_interpolation()`.
  - A good spot is about (464, 300) in R2, just south of the door. Check that it is walkable.
  - Take a `runtime_screenshot` at the normal zoom and at camera zoom 4.
  - Also take one with both torch lights disabled at runtime, as the "dark doorway" reference.
  - If you can, sample a few pixel colors (opening centre, near jamb, wall beside each torch). For example, use `get_viewport().get_texture().get_image().get_pixel()` in the game channel, or a small test helper. These are the "before" values.
- Report the plan and any questions.

### Phase 1: occlusion and light
- Implement §3.1–§3.4 and §3.6.
- **Acceptance:**
  - `FloorWallTile.tscn` has the occlusion layer and the agreed polygons. No collision, terrain or tile changes; diff the file by reading it, **no Git**.
  - `Floor1.tscn` has no embedded TileSet or `tile_set` override.
  - `TorchSmall.tscn` only has `shadow_enabled` (and the filter, if changed) as new values.
  - The test runner passes, including `test_torch_light`.
  - The game runs from `Tests/FloorTest.tscn` with no errors or warnings in `debugger_get_log` or `editor_get_console`.

### Phase 2: visual verification
- Repeat the Phase 0 screenshots and pixel samples.
- **Acceptance:**
  - The opening of door R6→R2 looks as dark as in the lights-off reference. Its sampled color is about the same as lights-off.
  - The near jamb of each torch and the brick front around each torch look as before. The samples are within about 10%.
  - Color, flicker and size of the torches are unchanged. Compare a few frames.
  - The §3.5 side effects are shown at zoom 4: far jamb, floor below the opening, wall top above, player standing in the doorway (handoff §8 positions x 464, y 281 / 266 / 250).
  - Leak test: with `texture_scale = 4` at runtime, the light stops at walls and doesn't show in the neighbouring room or corridor. Restore it and confirm it isn't saved.
  - Move one torch next to another door (e.g. R4→R3, x51–52) **at runtime only** and show that the opening there is also dark with no extra setup.
  - Note the frame time before and after (it should be about the same).

### Phase 3: tuning with the user
- The user looks at it and decides on the open points: player darkened in doorways, shadow filter, wall-top darkening, niche shapes. Adjust from their feedback.
- **Acceptance:** the user says it looks right.

## 5. Working rules

- The user edits in VS Code with Copilot active, and edits `FloorWallTile` themselves. **Re-read every file right before editing it.** If `scene_open` shows a scene was changed on disk while open, use `sintiles_reload_scene` (handoff §7).
- **No Git commands at all**, not even read-only ones.
- Ask instead of guessing. If the PRD disagrees with the code or the handoff, ask.
- Don't change anything outside this PRD's scope (§1). Only these files change: `FloorWallTile.tscn`, `TorchSmall.tscn` and the new test case. Anything else, ask first.
- Test through `res://Tests/FloorTest.tscn`. Don't add a Player to floor scenes. Check that `FloorTest` still has NewFloor1 before the Player. Runtime-only changes (teleports, `texture_scale`, moved torches, disabled lights) must never be saved.
- Use the godot-mcp-toolkit tools: `game_start`/`game_stop`, `input_simulate`, `runtime_screenshot`, `execute_code`, `debugger_get_log`, `editor_get_console`. Mind the handoff §7 pitfalls: eager vs group tools, `execute_code` is one expression only, numeric key codes (W 87, A 65, S 83, D 68), imprecise hold durations, `collision_visibility_mode = 2` for clean screenshots.
- Notion: in the page "Sinfulness", add a short Czech callout **"Světlo – postup"** (or update an existing one):
  - one line per finished phase under *Hotovo*;
  - one line per real mistake under *Chyby a poučení*;
  - read the existing mistake lines in the other callouts first. No long text, no code.
- At the end, add a short section to `Tests/PRDs/NewFloor1_Handoff.md` (§5 tile reference and §11 open items), or write a new `Tests/PRDs/TorchLight_Handoff.md`, whichever the user prefers. Include:
  - which tiles have occluders and why;
  - the light settings;
  - the decisions from Phase 3;
  - open items (niche torches, wooden doors, the dark-looking entrance door from handoff §11).
