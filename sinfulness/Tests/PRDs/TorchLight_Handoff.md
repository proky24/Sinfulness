# Torch light – session handoff (2026-10-21)

Context for the next Claude Code session. The task was `Tests/PRDs/PRD_TorchLight.md` (PRD 7): torch light blocked by walls, dark doorways. **All four phases are done and verified; the user accepted the result.** The rules in `NewFloor1_Handoff.md` §1 still apply.

## 1. Files

| File | Change |
|---|---|
| `Floors/TilesSetsNodes/FloorWallTile.tscn` | Occlusion layer 0 (`light_mask = 1`, `sdf_collision` off) + 7 `OccluderPolygon2D` sub-resources used by 19 tiles (§2). No collision, terrain or tile changes. |
| `Entities/GeneralNodes/Props/Torches/TorchSmall.tscn` | Only `shadow_enabled = true` on `Sprite2D/PointLight2D`. |
| `Tests/Scripts/Cases/test_torch_light.gd` | New, 5 tests (§5). |

Not changed: `Floor1.tscn` (still no `tile_set =` lines or embedded TileSet; every layer keeps `occlusion_enabled` on, the default), the other TileSets, `CanvasModulate`, the light's color / energy / texture / `texture_scale` / animation.

## 2. Occluders (FloorWallTile, occlusion layer 0)

Coordinates are tile-local (centre = 0, ±8).

| Tiles | Shape | Why |
|---|---|---|
| `2:1`, `2:2`, `5:1–5:4`, `7:1–7:4`, `11:16` | full tile | Solid wall mass: wall tops, rims beside brick fronts, inner corners. `11:16` is the wall-top rim with the pipe joint at (18, 41). `5:x` / `7:x` show 2–3 px of a brick edge; covered anyway to avoid gaps. |
| `1:1`, `1:2` | x −5…8 | Outer rims with floor showing on the west; matches the collision edge. |
| `3:1`, `3:2` | x −8…6 | Same, floor on the east. |
| `4:24` | (0,8) (0,3) (2,0) (5,−2) (8,−3) (8,8) | Arch opening, upper left. Traced from the alpha. |
| `5:24` | (−8,−3) (−7,−3) (−4,−2) (−1,0) (1,3) (1,8) (−8,8) | Upper right. |
| `4:25` | (0,−8) (8,−8) (8,8) (0,8) | Lower left, down to the tile bottom (includes the dithered threshold). |
| `5:25` | (−8,−8) (1,−8) (1,8) (−8,8) | Lower right. |

The four arch pieces share edges exactly. The opening is 17 px wide (combined x 8–25), crown at y 5; the polygon cuts at most 1 px of crown stone.

**Deliberately without occluders:**
- Brick fronts and ends (`2:3–2:5`, `1:3–1:5`, `3:3–3:5`): torches hang on them, and a light in or next to a closed polygon darkens its surroundings.
- Niche tiles `9–11:1–4` (user decision): the solid r-5 wall-top row above each niche already blocks light, and a future niche torch must not sit inside a polygon.
- Gate `14–15:26–27`, thin pillars / pipes `2:15`, `2:17`, `2:23` (decorative, a few px wide).
- Unused wall-looking tiles (`6:1–6:4`, `12–15:1–4`, old arches, wall block `0–4:18–20` …). **If a future layout uses one of them as solid wall, add an occluder.**
- Other TileSets (Water, DecorativeFloor, DecorativeWalls): no occlusion layer. Cracked bricks on WallFacesDecoration are brick fronts anyway.

**How to add an occluder by hand** (the editor works too): add an `[sub_resource type="OccluderPolygon2D" id="…"]` with `polygon = PackedVector2Array(…)` before the atlas source, then the line `X:Y/0/occlusion_layer_0/polygon_0/polygon = SubResource("…")` after `X:Y/0 = 0`. Reload the open tab (`sintiles_reload_scene`) and run the tests.

## 3. Light settings (TorchSmall)

- `shadow_enabled = true`, `shadow_filter = None` (default, hard edges suit the pixel art), `shadow_item_cull_mask = 1` (default).
- Color `(0.98, 0.97, 0.34)`, energy 3.5 with the `torch_lit` flicker 3.0/3.5/2.5/3.0/3.5/3.0, 64×64 radial gradient (black at ~26 px): unchanged.

## 4. Decisions (Phase 0 / Phase 3)

- **"Dark doorway" = the lights-off look.** Through the opening you see ordinary floor under the CanvasModulate, so the occluders can only bring it down to room-floor brightness. The user accepted that. A darker-than-floor doorway would need shade / a dark tile / an overlay in the door cells.
- **Shadow filter None.** PCF5 was not needed.
- **The player is darkened in doorways** (`shadow_item_cull_mask` stays 1). Measured about 13 % darker at y 266. To change it later: move the player (and anything else that should never be shadowed) to its own light-mask bit, e.g. player `light_mask = 2`, torch `range_item_cull_mask = 3` (still lights bit 2) and `shadow_item_cull_mask = 1` (bit 2 is never shadowed). Not done.
- **Niches left out** (§2).

## 5. Verification

- `test_torch_light` (5/5): occlusion layer with `light_mask & 1`; occluders on the four arch tiles; none on `2:3–2:5`; the layer survives a save + reload (it has only default values, and the user edits this file in the editor); torch `shadow_enabled`, original color and energy.
- Full runner at the end of Phase 1: passed 20, failed 1. The failure is `test_inventory:test_get_slots_filters_by_category` (§6), not related to light.
- **Same-frame comparison** (animation frozen at runtime with `speed_scale = 0` + `seek()`, shots with shadows on and off), player (464, 300), zoom 4, averaged sRGB sums:

| Region | Shadows off | Shadows on | Lights off |
|---|---|---|---|
| Opening centre | 63.4 | 61.0 | 61.0 |
| Opening by left jamb | 90.8 | 61.0 | 61.0 |
| Jamb stones L / R | 50.2 / 54.4 | 50.2 / 54.4 | 21.0 / 20.6 |
| Wall beside torches | 43.5 / 44.5 | 43.5 / 44.5 | 15.8 / 16.8 |
| Torch areas 20×16 | 147.4 / 150.2 | 147.4 / 149.3 | 41.0 / 41.3 |

- Wall top above the door (row 14) was already near-black (≈3–5) before; no visible change.
- Floor below the opening: no measurable change at normal size. At `texture_scale = 4` the opening throws a visible V-shaped shadow onto the R2 floor.
- Leak test (`texture_scale = 4`, runtime only): the light stops at the wall mass and at the wall top above the door; R6 and the door corridor stay dark.
- Torch moved at runtime to (856, 327) beside door R4→R3: opening by the jamb 107.0 → 61.0 with no extra setup.
- Frame time 16.67 ms (vsync cap) before and after. `Engine` / `Performance` aren't reachable from `execute_code`; use the editor's Monitors for finer numbers.
- Console clean (`debugger_get_log`, `editor_get_console`).

## 6. Things found on disk (not changed by this session, reported to the user)

The editor's **save-on-run** wrote unsaved editor state when `game_start` launched a scene:
- 11:01 — `Floor1.tscn` (its Player node removed), `GUI/PauseMenu/Inventory/starting_inventory.tres` (now 11 slots: extra Berserk ×2, Decayed potion instead of Maturation), `Items/potion.tres`, `Items/mushroom.tres`. This makes `test_get_slots_filters_by_category` fail (expects 4 / 10, gets 5 / 11).
- 11:18 — `Tests/FloorTest.tscn`: Player start is now (448, 431) instead of (136, 616). NewFloor1 is still before the Player.

## 7. Open items

- **Torches in niches:** decide niche occluders then (option: `9:1`, `11:1` full + top 6 px of `10:1`).
- **Wooden doors:** a door sprite in the arch sits inside the opening occluder, so with `shadow_item_cull_mask = 1` the torches won't light it. Either give the door a light-mask bit that isn't in the torch's `shadow_item_cull_mask`, or accept a dark closed door.
- **Dark-looking entrance door** (NewFloor1 handoff §11, x8–9 y32–33): not investigated here.
- Inventory test failure and the FloorTest start position (§6): waiting for the user.
- Other light sources added later need `shadow_enabled` themselves; the TileSet part is already shared.

## 8. MCP notes from this session

- `game_start` saves modified open scenes/resources (editor save-on-run). Check for unsaved tabs before launching.
- A scene open in the editor keeps its old copy after an on-disk edit: compare the in-memory values, then `sintiles_reload_scene`.
- The player camera rewrites `zoom` every tick: set `base_zoom`, `attack_zoom` and `_zoom_value` at runtime instead.
- World → screenshot pixel: `3 × (zoom × world + canvas_origin)` (final transform ×3 at 1920×1080); read the origin with `get_viewport().get_canvas_transform()`.
- PowerShell scripts need `-ExecutionPolicy Bypass` on this machine; `python` is only the Store stub, use `node` for quick parsing (e.g. decoding `tile_map_data`).
