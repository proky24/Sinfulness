# NewFloor1 – session handoff (2026-10-15)

Context for the next Claude Code session. The task was `Tests/PRDs/PRD_NewFloor1.md` (PRD 4): build a clean, tile-only first floor in `res://Floors/Level1/Floor1/NewFloor1.tscn`. **All five phases are done and verified.** This file records what exists, why it is built this way, how to change it, and what is still open.

## 1. How the user wants to work

- Work in phases. After each one, stop and give a short report with screenshots, then wait for the user's OK.
- **Write the report in the chat message itself.** Once a report was lost because it was put only in the end-of-turn summary box.
- The user edits in VS Code with Copilot, so **re-read a file right before editing it**.
- **No Git commands at all**, not even read-only ones like `git diff`.
- Ask instead of guessing. Don't touch `Floor1.tscn`, `Floor1_bounds.gd` or the shared tile scenes (`Floors/TilesSetsNodes/*.tscn`) without approval.
  - The user edits `FloorWallTile` themselves. This session they added a new arch at **4–5:24–25** and removed its collision triangles.
- Keep objects out of `NewFloor1`: no crates, torches, doors, enemies or player. They will be separate scenes later.
  - The user sometimes adds a Player to NewFloor1 for quick tests. Check the file on disk before testing, and ask before removing it.
- Code conventions (Notion "Project structure"): typed variables, `class_name` in CamelCase, public `func update_x()` / private `func _update_x()`.
- **Notion:** page "Sinfulness" (`379f4675-ea8f-808d-97a9-d3fa80343d85`), callout **"Svět – postup"** at the end of the page.
  - Add one short Czech line per finished step under *Hotovo* and one per real mistake under *Chyby a poučení*.
  - No long text and no code.

## 2. Files

| File | What |
|---|---|
| `Floors/Level1/Floor1/NewFloor1.tscn` | The floor. Root `NewFloor1` (Node2D, y-sort on, script `FloorBounds`, `bounds_layer` = WallTops) + 9 TileMapLayers. Tile data only, no objects. |
| `Floors/TilesSetsNodes/floor_bounds.gd` | `class_name FloorBounds extends Node2D`. Sends `[top-left, bottom-right]` in pixels from `bounds_layer` (used rect × `tile_set.tile_size` + layer position) to `GlobalLevelManager.change_tilemap_bounds()`. Warns and sends nothing if the layer is empty. The header comment documents the draw order. |
| `Floors/00_Global/GlobalLevelManager.gd` | Fixed: `tilemap_bounds_changed.emit(bounds)` (it used to emit without the argument). |
| `Entities/Player/Scripts/camera_2d.gd` | Fixed: `update_limits()` returns early if `bounds.size() < 2`. |
| `Tests/FloorTest.tscn` | Throwaway test scene: y-sorted root, NewFloor1 first, then Player at (136, 616) in the entrance room. NewFloor1 must come before Player so the bounds are set before the camera's `_ready`. |
| `Tests/Tools/newfloor1_maps.ps1` | **Single source of truth for the floor layout.** It generates every layer map (see §6). |
| `Tests/Tools/render_atlas.ps1`, `crop_atlas.ps1` | Render an atlas PNG at N× with a grid, defined tiles and collision polygons, or zoom into a tile range. Used to audit tilesets. |
| `addons/sinfulness_mcp_tools/tile_tools.gd` | Custom MCP tools (see §7). |
| `Floors/TilesSetsNodes/Floor1_bounds.gd` | **Untouched.** It still has the bounds bug from PRD §2.6; the old Floor1 uses it. |
| `Floors/Level1/Floor1/Floor1.tscn` | **Untouched by this session.** Its last write at 16:35 predates the session. |

## 3. Layers and draw order (most important design decision)

All layers are at (0, 0), scale 1. Tree order is as listed. The Player has z 0 and sorts by its origin, which is the **centre** of the sprite. Its collision circle has radius 6.5 px.

| Layer | Tile scene | z | y-sort / origin | Job |
|---|---|---|---|---|
| Water | WaterTile | -1 | – | water (pool) |
| Floor | FloorWallTile | -1 | – | floor (2:8 + cracked variants), raised platform, stairs, stairwell, pool strip |
| FloorDecoration | DecorativeFloorTile | -1 | – | cracked platform frame pieces |
| FloorShade | DecorativeFloorTile | -1 | – | dark shade (terrain set 0, terrain 0 "WallShade") |
| WallFaces | FloorWallTile | 0 | on / **8** | **bottom** row of every brick front, arch lower row, niche bottom, gate bottom |
| WallFacesUpper | FloorWallTile | 0 | on / **24** | **middle** row of brick fronts, arch upper row, niche middle, gate upper |
| WallFacesDecoration | DecorativeWallsTile | 0 | on / **24** | cracked middle bricks (0–3:0) |
| WallTops | FloorWallTile | **1** | – | wall tops, the **top** row of brick fronts, side walls, walls south of rooms, void, niche top row. It is the bounds layer. |
| ArchTops | FloorWallTile | **1** | – | **collision off.** The wall top above each door (rows r-4 = 2:1 and r-3 = 2:3), so the player walks under it. |

**Rules that came out of user feedback:**
1. **No per-cell y-sort for walls in general.** With the default cell-centre origin, the wall cell beside the player flipped between front and back every 8 px, and the sword appeared and vanished inside side walls.
2. **The user wants the sword hidden inside walls.** Walls are taller than the player, so side walls and wall tops draw *over* the player (z 1).
3. **Brick fronts of walls north of a room are behind the player** while the player stands in the room. All three rows of a front must sort from the **wall's bottom edge**, which is why the bottom row has origin 8 and the middle row origin 24, and why the top row sits on WallTops.
   - A player who walks into a door or niche is then covered by the bricks and arch. Before this fix the head showed over the arch; the user flagged it.
4. **Never duplicate an instanced layer node** (see §7). Add layers with `sintiles_add_layer`.

## 4. Layout (64 × 48 tiles, 16 px; camera bounds (0, 0)–(1024, 768))

| Room | Floor rect (x0, y0)–(x1, y1) | Notes |
|---|---|---|
| R1 entrance | (4,34)–(15,42), minus notch (12,34)–(15,37) | test player start (136, 616) |
| R2 large hall | (20,18)–(41,33), minus notches (20,18)–(24,21) and (37,30)–(41,33) | dark shade patches, decorative gate |
| R3 water room | (46,22)–(59,35) | pool x55–59 y22–35, platform strip x53–54 y22–35 |
| R4 stairs room | (46,5)–(59,14) | raised platform x53–59 y5–10, stairs at x56–57 (rows 9–10), stairwell (pit) x54–56 y6–8 |
| R5 west room (dead end) | (4,6)–(14,15), minus (11,6)–(14,9) | |
| R6 north room | (22,5)–(36,11) | |
| R7 SE room (dead end) | (46,40)–(57,45), minus (54,40)–(57,42) | |
| R8 closet (dead end) | (26,39)–(33,44) | |

**Corridors:**
- Side entries are 3 wide and open (no arch): R1→R2 (16,38)–(23,40) then (21,34)–(23,37) into R2 from the south; R2→R3 (42,26)–(45,28); R4→R6 (37,8)–(45,10).
- North entries are 2 wide and go through an **arch door**. The new arch is used for all five doors. Door cells (left column, rows r-4..r-1):

| Door | Door cells | Leads into |
|---|---|---|
| R6 → R2 | x28–29, y14–17 | R2 |
| R2 → R8 | x29–30, y35–38 | R8 |
| R3 → R7 | x50–51, y36–39 | R7 |
| R4 → R3 | x51–52, y18–21 | R3 |
| R5 → R1 | x8–9, y30–33 | R1 |

**Loop:** R2 → R3 → R4 → R6 → R2.

**Other features:**
- **Torch niches** (the walkable recess floor cell, empty for torches later): (5,33), (33,17), (48,21), (49,4), (56,4), (25,4), (33,4), (6,5).
- **Gate:** decorative portcullis at x37–38, y16–17 (tiles 14–15:26–27; the bars have a thin collision strip).
- **Walkable cells:** 1112, all reachable from the entrance. Last check was a full keyboard walkthrough, Phase 5.

**Wall thickness rules the layout relies on:**
- A wall north of a room needs ≥4 rows: r-1 bottom bricks, r-2 middle, r-3 top (dark + highlight), r-4 wall top.
- A niche needs a 5th solid row (r-5).
- Side walls must be ≥2 tiles wide. No 1-wide walls anywhere.

## 5. Tile reference (atlas coords `x:y`)

**FloorWallTile** (`walls_floor.png`):
- **Wall tops:** 2:2 interior / void; 2:1 rim along the top (floor north); 1:1 and 3:1 outer corners; 1:2 and 3:2 side rims (1:x = floor to the **west**).
- **Side rim beside a brick front:** 5:1, 5:2, 5:3 (front to the east; k = 3/2/1, where k is the row's distance above the floor) and 7:1, 7:2, 7:3 (front to the west).
- **Inner corners:** 5:4 (floor diagonally NE) and 7:4 (floor diagonally NW).
- **Brick front:** 2:3 top / 2:4 middle / 2:5 bottom. Ends: 1:3–1:5 (floor west), 3:3–3:5 (floor east).
- **Niche (recess) block:** 9–11:1–4. 10:4 is empty, so the floor shows.
- **New arch (user-made):** upper 4:24 5:24, lower 4:25 5:25, no collision. The old arches 4–15:25–27 are unused, except the gate 14–15:26–27.
- **Floor:** 2:8. Cracked light variants 7–8:13–14. Dark variants 9–10:13–14 and dark floor terrain 11–15:13–15 are unused.
- **Raised platform kit:** 1–3:7 top frame, 1–3:8 middle, 1–3:9 bottom frame, 1–3:10 brick front. The rims collide (thin strips).
- **Stairs set into a platform front:** 10:10 11:10 / 10:11 11:11. The opening is about 16 px wide for a 13 px player, and the rim sits about 3 px higher than the kit's.
- **Stairwell / pit:** 5–7:7–9, hole at 6:8, collision all around.
- **Unused:** narrow stairs 1:12–13.

**DecorativeFloorTile:**
- Rows 0–7 are opaque cracked platform pieces (1:1 left frame, 5:1 right frame, 2:0 top frame, 2:2 …). Their collision strips match the platform rims.
- Rows 8–14 are the shade terrain.

**DecorativeWallsTile:** cracked wall versions. 0–3:0 are cracked middle bricks, 4–7:0 cracked bottom bricks.

**WaterTile** (`Water_coasts_animation.png`):
- Row 30 is water: 11:30 plain, 7–10:30 patterned. 1–6:30 are "submerged bricks" with transparent edges, unused because they need another layer underneath.
- Rows 1–29 are foam/coast copies of walls and platforms standing in water: 6 animation frames, not configured, unused.
- **No physics layer.** The pool is impassable only because it is fully enclosed (walls plus the platform strip's rim).

## 6. How to change the floor (pipeline)

1. Edit the layout section of `Tests/Tools/newfloor1_maps.ps1`: `Rect` calls, `$doorStyle`, `$niches`, the gate, pool and platform coordinates, decoration cells.
2. Run it with `powershell -File Tests\Tools\newfloor1_maps.ps1`. It must print `problems: 0`. It flags 1-wide walls, missing legend characters, niches without solid wall above, and so on. The random choices use a fixed seed (4242), so a run with no changes reproduces the same maps.
3. It writes these files to `user://floor_maps/` (`%APPDATA%\Godot\app_userdata\Sinfulness\floor_maps`):
   - `walltops`, `wallfacesupper`, `wallfaces`, `archtops`, `floor`, `water`, `wallcracks`, `floordeco` (`.json`)
   - `shade_regions.json`
   - `layout.txt`
4. With NewFloor1 open in the editor, paint every layer from its file. **Never copy maps by hand.** Two cells were lost that way once.
   - Each map layer: `sintiles_paint {node_path: "<Layer>", clear_first: true, map_file: "user://floor_maps/<name>.json"}`.
   - FloorShade: `sintiles_paint {node_path: "FloorShade", clear_first: true}`, then `sintiles_terrain {node_path: "FloorShade", terrain_set: 0, terrain: 0, regions: <contents of shade_regions.json>}`.
5. `editor_save_scene`, then grep the `.tscn`. It must have **no `[sub_resource`** and **no `tile_set =` lines**: layers must use the TileSet from the instanced tile scene.
6. Run the game and verify (§8).

**Autotiler logic** (in the script):
- A wall cell with floor 1/2/3 rows below it is a brick front (k = 1/2/3).
- Otherwise it gets a 9-slice piece from its open neighbours (N/W/E), with face-adjacent rims (5:x / 7:x) and inner corners (5:4 / 7:4).
- Door, water and platform-strip cells count as "open" or "wall" as described in the script comments.

## 7. MCP tooling notes

- **Group tools don't reach the client.** Tools behind `discover_tools` groups (e.g. the toolkit's `tilemap`, `scene_advanced`) never appeared in Claude Code's tool list mid-session, even after the user reconnected and restarted Godot. **Eager (ungrouped) extension tools do appear right after `extensions_refresh`.** That's why the custom addon exists.
- **Custom tools** in `addons/sinfulness_mcp_tools/tile_tools.gd` (all eager, with editor undo):
  - `sintiles_paint`: cells / regions / ASCII `map` + `legend` + `origin`, or `map_file` (user:// JSON); `clear_first`; `source_id: -1` erases. It refuses tiles that don't exist in the TileSet.
  - `sintiles_read`: cells, or `as_map: true` for an ASCII map plus legend.
  - `sintiles_terrain`: `set_cells_terrain_connect` over cells or regions.
  - `sintiles_add_layer`: instance a tile scene as a proper layer node (shares the TileSet) with `index` and `z_index`.
  - `sintiles_reload_scene`: `EditorInterface.reload_scene_from_path`, for a scene changed on disk while open.
- Extension rules: `extends MCPToolkitExtension`, `@tool`; wire name `ns.action` becomes tool `ns_action`; reserved namespaces include `tilemap.*`, `scene.*`, `node.*`, …
- **Pitfalls hit this session:**
  - `scene_open` on a scene that is already open does **not** reload it from disk. Use `sintiles_reload_scene`.
  - `node_manage duplicate` of an instanced TileMapLayer **embedded a full TileSet copy** into the scene. It also renamed the shared TileSet's `resource_path` in editor memory. The fix was to strip the `[sub_resource]` blocks and `tile_set =` lines from the `.tscn`, then reload. Restarting Godot clears the leftover "Another resource is loaded from path" errors.
  - `execute_code` evaluates one expression only (no lambdas, no assignment; use `.set()`). The editor channel is relative to the edited scene root.
  - `input_simulate` keys need numeric codes: W 87, A 65, S 83, D 68. Hold durations are not precise, so read the position back after each leg and correct.
  - Godot's debug collision overlay is on. To hide it for screenshots at runtime, set `collision_visibility_mode = 2` on the layers.
  - In PowerShell, `@{}` hash tables are case-insensitive (`A` = `a`). Legends use an ordinal `Dictionary`.
- Files created outside the editor need `extensions_refresh` (a rescan) before running.

## 8. Verification recipe

- Run `Tests/FloorTest.tscn`, or NewFloor1 directly only if a Player was added to it.
- Wall stops for the 6.5 px player radius: west side rims stop at x = wall_x·16 + ~2.9 + 6.5; brick-front bottoms at row·16 + 8 + 5.83 + 6.5.
- **Phase 5 walkthrough** stop positions, useful as regression values:

| Stop | Position | Where |
|---|---|---|
| R5 | (136, 100.4) | north wall |
| R1 | y 614.8 | entrance room |
| corridor end | x 380 | R1 east corridor |
| R2 | y 356.4 | hall |
| R6 | y 84.4 | north wall |
| niche | y 70.6 | (33,4) |
| R4 platform edge | x 843.8 | blocks |
| stairs top | y 91.1 | platform back edge |
| R3 | y 569.4 | south wall |
| R7 | y 729.4 | south wall |
| R2 west wall | x 324.2 | loop closed |
| R8 | y 713.4 | south wall |

- The pool strip blocks at x 843.8, and the stairwell blocks at y 139.0.
- **Draw-order checks** at camera zoom 4:
  - Sword against the R1 west wall at y 611 and 621: the blade is hidden.
  - Doorway at x 464, y 281 / 266 / 250: the head shows only through the arch opening, then the arch stones cover it, then it is fully under the wall top.
  - In front of a wall at y 292: the player is drawn on top.
- Console: `debugger_get_log` (game) and `editor_get_console` (editor) must have no errors or warnings.

## 9. Physics audit (Phase 0) and recommended tileset fixes (not applied)

1. **WaterTile:** add physics layer 5 and full-tile collision to 1–11:30; rename the root node from `TileMapLayer` to `WaterTile`.
2. **Stairs 10:11 / 11:11:** narrow the collision by about 2 px each side so the ~16 px opening is easier to enter.
3. **Missing collision on unused tiles:**
   - FloorWallTile old arches 4–15:25–27 (stone sides);
   - FloorWallTile wall block 0–4:18–20 (most cells, none or a 1–2 px strip);
   - DecorativeWallsTile 0–3:14–16 (none or 0.5 px) and 7:11–12 (none);
   - FloorWallTile 5:12, which collides on its whole square although it is mostly floor.
4. **Not a bug, despite the PRD's suspicion:** DecorativeFloorTile rows 0–7 strips. Those tiles are cracked platform pieces whose strips match the platform rims. The shade rows 8–14 correctly have no collision.
5. **Optional:** per-tile `y_sort_origin` on the brick-front tiles would remove the need for WallFacesUpper.
6. **`Floor1_bounds.gd` bug:** it scales the start by `rendering_quadrant_size / 10` and ignores the layer position. It is still there; only the old Floor1 uses it.

## 10. Not possible with the existing tiles (reported to the user)

- A floor-to-water edge tile, so the pool is bordered by walls plus a raised platform strip.
- Stairs going down, so a stairwell shaft on the platform stands in for them.
- Foam lines: the coast tiles are not animated or configured.
- Rubble or pebble floor tiles, and the reference image's diagonal staircase in a wall.

## 11. Open items / next steps

- **Check visually:** in a Phase 5 close-up, the opening of the entrance-room door (x8–9, y32–33) looked dark. The painted map confirms the new arch (4–5:24–25) is there, as at the other doors. Find out why it looks dark (ArchTops above it? something drawn behind the opening?).
- The user still has to decide what to do with the old `Floor1.tscn`.
- Objects for later, as separate scenes: torches in the 8 niches, wooden doors in the 5 arches, a trigger on the stairwell or stairs, enemies, a player spawn marker.
- Recommended tileset fixes (§9) await the user's approval.
- Random generation is still undecided (Notion callout "Dungeon Gen / Design").
