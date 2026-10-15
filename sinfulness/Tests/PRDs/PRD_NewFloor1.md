# PRD 4: NewFloor1, a clean tile-only floor (Sinfulness, Godot 4.7.2)

Owner: Proke. Status: ready for implementation. Builds on the earlier PRDs (inventory, loadout, pickup). Notion page "Sinfulness" (id `379f4675-ea8f-808d-97a9-d3fa80343d85`) has the world design (section "Svět") and the project conventions.

## 1. Goal

Build a new, clean first floor in `res://Floors/Level1/Floor1/NewFloor1.tscn` (currently an empty `Node2D`). It contains **only the architecture**: floor, walls, shading, cracks, water, stairs, wall openings. It must be built with properly used `TileMapLayer` nodes from the existing tile scenes in `res://Floors/TilesSetsNodes/`, and it must look inspired by the reference image `res://Tests/PRDs/Floor1_reference.webp` (a top-down 16 px stone dungeon: dark brick walls showing their front faces, blue-grey floor with darker shadow patches along walls, raised platforms with borders, stairs, dark void around the map, irregular rooms, a water pool). Inspired by it, not a copy.

The old `res://Floors/Level1/Floor1/Floor1.tscn` is **not touched** and stays as a reference until the user decides what to do with it.

### Out of scope
- Objects. Do NOT place or create crates, barrels, chests, torches, fireplaces or braziers, pots, spikes, ladders, wooden doors, pickups, enemies, lights, or the player in `NewFloor1`. Those will be separate scenes later.
- New tileset art or new TileSet resources. No player spawn marker (the user will add spawning later).
- Random generation (undecided, see the Notion "Dungeon Gen / Design" callout). This floor is handmade.
- Changing the old Floor1 or its scripts.

## 2. Diagnosis of the old Floor1 (verified, do not repeat these mistakes)

1. `FloorWallTile` is used by eight layers (Floor, FloorDarker, Stairs, FloorWallShade, Walls, Windows, Walls2, Windows2) with no clear rule for which layer holds what.
2. Layers sit at different positions: Floor, FloorDarker, Stairs, FloorWallShade, Walls, Walls2 at `(48, 32)`; Windows, CrackedWalls, DecorativeFloor and the other decorative layers at `(0, 0)`. The same cell coordinate is a different place on different layers.
3. Leftover disabled duplicate layers (`Walls2`, `CrackedWalls2`, `Windows2`, `z_index = 100`) under a plain `Node` called `Behind`.
4. `FloorDarker` darkens with `modulate` instead of using shade tiles.
5. Test content (player, five crates, an enemy, four pickups) placed directly in the floor scene.
6. `res://Floors/TilesSetsNodes/Floor1_bounds.gd` (`class_name Floor1Bounds extends TileMapLayer`) computes the bounds as `used_rect.position * (rendering_quadrant_size / 10)` for the start and `used_rect.end * rendering_quadrant_size` for the end. The start is effectively not scaled by the tile size (integer division gives 1), the end is, `rendering_quadrant_size` is a rendering batch setting and not the tile size, and the layer's own position offset is ignored. It calls `GlobalLevelManager.change_tilemap_bounds(...)` in `_ready()`.
7. Suspected tileset physics problem: all three tile scenes use physics layer 0 with `collision_layer = 16` and `collision_mask = 0`. `DecorativeFloorTile` (the shade overlay, terrain named "WallShade") has thin 1 to 3 px collision strips on the tiles in rows 0 to 7. A decorative shade layer must not collide. In `FloorWallTile`, a few tiles in the lower rows have no collision polygon, and it is not known whether that is intended.

## 3. Conventions for the new scene (must follow)

- Root `NewFloor1` (Node2D). All `TileMapLayer` nodes at position `(0, 0)` and scale 1, so one cell coordinate means one place on every layer.
- Instance the existing tile scenes (`FloorWallTile.tscn`, `DecorativeFloorTile.tscn`, `DecorativeWallsTile.tscn`) for the layers, each with a clear job and a clear name. Suggested layers: `Floor`, `FloorShade`, `FloorDecoration`, `Walls`, `WallsDecoration`, `Water` (names may be adjusted if the audit suggests better ones). No layer is used for two jobs, and there are no disabled or duplicate layers.
- No `modulate` tricks for shading. Shadows and darker floor areas use shade tiles.
- Layer draw order and walls: a wall's upper part must be able to draw above the player so the player can walk behind it, and the lower part and floor draw below. Decide how after the audit (z-index per layer, y-sort, or tile `y_sort_origin`), choose the simplest option that works, and document it in a one-paragraph comment in the scene's script or in your report.
- Do not edit any existing tile scene or TileSet without the user's approval (they are shared with the old Floor1). The tilesets are embedded in each tile scene, so a change affects every user of that scene.
- Follow the Notion "Project structure" conventions (typed variables, `class_name` CamelCase, public and private function naming).

## 4. Layout requirements (handmade)

- About **64 by 48 tiles** (16 px tiles, 1024 by 768 px), **6 to 8 rooms** joined by corridors. The user can change the size later.
- Include: one entrance room, one large hall, one room with a **water pool**, one room with **stairs going down** (tiles only, no trigger yet), and a few dead-end side rooms. At least one loop in the layout so the player can walk in a circle.
- Corridors 2 to 3 tiles wide. Rooms with irregular shapes (not all rectangles), at least one raised platform with a border, and some 1-tile wall niches reserved for torches later (leave them empty).
- A dark void outside the outer walls, as in the reference.
- **Wall openings** (arches) for doors are built into the walls as tiles. The actual wooden doors will be objects later.
- Water tiles are used only if they exist in the atlas. Water is impassable for the player. If the water tiles have no collision, report that in the audit and propose a fix, but do not edit the tileset before the user approves.
- Rooms stay empty (no props). Use floor variety (cracks, different floor tiles) so they do not look flat.
- Use only tiles that exist in the three tile scenes. If something in the reference has no matching tile, leave it out and list it in your report.

## 5. Camera bounds

The camera needs the floor bounds through `GlobalLevelManager.change_tilemap_bounds(...)` (read how it is used and what format it expects, and how the camera uses it). Do not change `Floor1Bounds`, since the old Floor1 uses it. Create a new small script for `NewFloor1` (for example `NewFloorBounds` or a name fitting the conventions) that computes the bounds correctly: use the walls layer's used rect, the layer's tile size (`tile_set.tile_size`) and the layer's position, in pixels. Check the result against the real size of the built floor.

## 6. Phases and acceptance criteria

Stop and report after each phase and wait for the user's OK before the next one.

### Phase 0: audit (report only, change nothing)
- Read the three tile scenes and look at their atlas PNGs (`res://Assets/Dungeon TileSet/`, view the images) to inventory which tiles exist: floors, walls (and which part of a wall each tile is), shade, cracks, water, stairs, wall openings.
- Audit the physics for every group of tiles: floor tiles must not collide, wall tiles must collide matching their visual footprint, shade and decoration tiles must not collide, water must block. List every problem and whether it is certain or a guess.
- Check how `Player.tscn` collides (its `collision_mask`) and confirm it includes layer 5 (value 16), and whether the project has physics layer names.
- Read `GlobalLevelManager` and the camera code for how bounds are consumed.
- Report: the tile inventory, the physics problems, the proposed layer plan and draw-order approach, and the questions you have.

### Phase 1: skeleton
- Create the layer structure from section 3 in `NewFloor1.tscn`, the bounds script, and a throwaway test scene (for example `res://Tests/FloorTest.tscn`) that instances `NewFloor1` and the Player scene so the floor can be walked and screenshotted. `NewFloor1` itself contains no player.
- Acceptance: the scene opens without errors, all layers at `(0, 0)`, and the test scene runs.

### Phase 2: blockout
- Paint the floor area and the outer and inner walls for all rooms and corridors with plain tiles, no decoration yet.
- Acceptance: the layout matches section 4, the player can walk every corridor and room in the test scene, cannot walk through walls, cannot leave the map, and the camera stays inside the bounds. Screenshot of the full floor.

### Phase 3: walls and depth
- Walls with correct corners, fronts and tops, the openings for doors, and the walk-behind effect.
- Acceptance: no wrong or gap tiles at corners, the player visibly passes behind the upper wall parts, collisions still match.

### Phase 4: floor detail
- Floor variety, shade along walls, cracks, the water pool, the raised platform and the stairs.
- Acceptance: it looks like the reference in spirit, with no leftover `modulate` tricks, no empty cells where the floor should be, water blocks the player, and nothing in the excluded object list is present.

### Phase 5: verification
- Walk the entire floor in the test scene, take screenshots (full floor and a few close-ups), and check the editor console for errors and warnings.
- Report anything you could not do because the tiles do not exist, and the tileset fixes you recommend.

## 7. Working rules

- The user edits in VS Code (Godot's external editor) with GitHub Copilot active, so re-read a file right before editing it.
- Build tile layers with the godot-mcp-toolkit tile tools (cell queries, bulk fills, region operations). Do not hand-edit `.tscn` tile data. Reopen the scene after changes and check it loads.
- No Git commands. Do not change anything outside this PRD's scope. If something blocks you or the PRD disagrees with the code, ask.

## 8. Notion progress callout

Update the existing short Czech callout "Inventář – postup" in the Notion page, or add a similar short callout "Svět – postup" if you prefer, with one line per finished phase under "Hotovo" and one short line per real mistake under "Chyby a poučení". Read the existing mistake lines first. No long text and no code. If you have no Notion access, tell the user.

## 9. Assumptions to confirm

- The reference image is saved by the user as `docs/Floor1_reference.png`. If it is missing, ask for it before Phase 4.
- `Player.tscn` is assumed to use a collision mask that includes layer 5. The audit confirms it.
