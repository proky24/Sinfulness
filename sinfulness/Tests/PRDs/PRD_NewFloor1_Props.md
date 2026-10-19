# PRD 5: NewFloor1 props, decorating the floor (Sinfulness, Godot 4.7.2)

Owner: Proke. Status: ready for implementation. Builds on PRD 4 (`Tests/PRDs/PRD_NewFloor1.md`) and its handoff (`Tests/PRDs/NewFloor1_Handoff.md`). **Read both first.** The handoff has the layout (rooms, doors, niches), the layer and draw-order rules, the MCP tooling notes and pitfalls, and the verification recipe. All of that still applies unless this PRD says otherwise.

## 1. Goal

Decorate and finish `res://Floors/Level1/Floor1/NewFloor1.tscn` with props, in the spirit of the reference image `res://Tests/PRDs/Floor1_reference.webp`:
- crates, barrels and vases scattered around and grouped in the rooms;
- shields hung on the walls;
- a few gold piles on the floor.

All props are instances of the reusable scene `res://Entities/GeneralNodes/Props/Prop.tscn` (script `prop.gd`, `class_name Prop`). Each instance gets a different texture cut from `res://Assets/Dungeon TileSet/Objects.png`.

The rooms must **not look empty**. The target density is close to the reference, a little lighter is fine (see §6).

### Out of scope (do NOT add)
- Torches, braziers, fireplaces and lights. Torches come later, into the 8 niches.
- Ladders, the floor hatch or grate (Objects.png around x 20, y 85), and the wall staircase (Objects.png left part, rows 1 to 4).
- Chests. They will be interactive objects later. Keys and the lever. Spikes, doors, enemies, pickups.
- The Player in NewFloor1. The user removed it. Test only through `res://Tests/FloorTest.tscn`.
- Any change to tiles or tile layers of NewFloor1, to the shared tile scenes in `Floors/TilesSetsNodes/`, to `Floor1.tscn` or to `Floor1_bounds.gd`.
- Breaking props. Nothing breaks for now, but the switch for it is prepared (see §3).

## 2. Current state (verified)

**`Prop.tscn`:**
- Root `Create` (Node2D, `y_sort_enabled`, script `prop.gd`) has three children:
  - `Sprite2D`: texture `Create.png`, 16×32, centred on the origin;
  - `StaticBody2D`: `collision_layer = 16`, `mask = 0`, with a `RectangleShape2D` of 11×7 at (0.5, -0.5);
  - `HitBox`: an instance of `HitBox.tscn` (Area2D, `collision_layer = 256`, monitoring off), with a shape of 11×6 at (0.5, 0).

**`prop.gd`:**
- `@tool`, `@export var texture: Texture2D`.
- `_ready()` copies the texture to the sprite and, at runtime, connects `hit_box.Damaged` to `take_damage()`, which calls `queue_free()`.

**Problems:**
1. The sprite and the collision are centred on the origin. NewFloor1 y-sorts by origin, so the player would swap in front of or behind a prop at its middle, not at its base.
2. One fixed collision size does not fit all variants (a tall crate, a small vase).
3. The sprite only updates in `_ready`, so changing `texture` in the inspector does not show until the scene reloads.
4. Every prop breaks when hit.
5. The root name `Create` is a typo for "Crate", and the scene is generic anyway.

**`Objects.png`** is 384×144 px. **Its objects are not on a 16 px grid.** Many are offset by half a tile, and several touch each other or their neighbours' shadows. Each sprite has a baked purple, semi-transparent drop shadow.

## 3. Prop scene changes (approved by the user)

Re-read `prop.gd` and `Prop.tscn` right before editing them (the user edits in VS Code with Copilot).

1. **Rename the root node** to `Prop`. Check that nothing references the old name. `Prop.tscn` is not instanced anywhere yet, but grep to be sure.
2. **Origin at the base.** The node origin is the object's foot, meaning the bottom of the object without its shadow. Do this with `Sprite2D.centered = false` plus an `offset` computed from the texture size, or with `centered` and an offset of `-height/2`, so that the visible base sits at y = 0. Then y-sort compares the player's origin (the centre of their sprite) with the prop's base.
   - Choose the exact rule and document it in a short comment at the top of `prop.gd`.
   - Check visually that the player standing just above or just below a barrel is drawn behind or in front of it correctly.
3. **Collision per variant.** The collision box is a thin footprint at the base, not the whole sprite:
   - roughly the object's width minus 2 to 4 px;
   - roughly 5 to 8 px tall;
   - ending at the base.
   - Either compute it automatically from the texture (preferred, with an exported override `collision_size: Vector2`, where `Vector2.ZERO` means automatic), or set it per variant. **Shapes must be unique per instance**: use `resource_local_to_scene` or create the shape in code. Otherwise every prop shares and resizes the same shape.
   - Clusters (crate stacks and so on) get a footprint covering their whole base.
4. **Exported switches** (typed, with defaults):
   - `solid: bool = true`. When false, the StaticBody2D is disabled or removed: no collision.
   - `breakable: bool = false`. When false, the HitBox does not register hits (disable its shape or set `collision_layer = 0`), and `take_damage` is not connected. When true, it behaves as now (`queue_free`). Nothing in this PRD sets it to true.
   - `flat: bool = false`. For floor decals like gold piles: draw under the player always (`z_index = -1`, like the floor layers), not solid.
   - Wall-hung props (shields) use `solid = false`, `breakable = false` and the wall rule in §5.
5. **Live editor update:** add a setter on `texture` (and on the switches) that updates the sprite and collision, guarded with `is_node_ready()`, so changes show in the editor at once.
6. Follow the Notion "Project structure" conventions: typed variables, public `func update_x()`, private `func _update_x()`, `class_name` in CamelCase.
7. **Acceptance:**
   - Prop.tscn opens without errors.
   - Changing `texture` in the inspector updates the sprite and the collision immediately.
   - The defaults give a solid, non-breakable prop.
   - The player cannot be damaged by props and cannot break them.

## 4. Prop textures (variants)

Create one `AtlasTexture` `.tres` per variant: `atlas = Objects.png`, `region` = the exact pixel rect including the baked shadow, and no `filter_clip` issues (check for bleeding from neighbours).
- Save them in `res://Entities/GeneralNodes/Props/Textures/`, named `snake_case` by what they are, e.g. `crate_tall_light.tres`, `barrel_dark.tres`, `vase_blue_small.tres`, `shield_a.tres`, `cluster_crates_3.tres`, `gold_pile_small.tres`.
- The `texture` export takes them as they are. Do not edit `Objects.png`.

Measure each region exactly from the PNG: alpha bounding boxes, then split the merged blobs by hand by looking at zoomed crops. A first rough connected-component pass found these. They are **approximate starting points only** (x, y, w, h in px, shadow included):

| Group | Variant | Approx. region |
|---|---|---|
| Crates (light wood) | tall double crate | x 56, y 80, w 17, h 30 (merged with the vase cluster below; split it) |
| | small crate | 82, 83, 13, 18 |
| | medium crate | 96, 80, ~15, 24 (merged with the barrel to its right) |
| Crates (dark wood) | tall double crate | x 136, y 80, w 17, h 30 (split from the lever below) |
| | small crate | 162, 83, 13, 18 |
| | medium crate | 176, 80, ~15, 24 (merged with the barrel) |
| Barrels | light | ~112, 80, 16, 24 |
| | dark | ~192, 80, 16, 24 |
| Vases blue | large / medium / small | 209, 80, 14, 19 / 226, 83, 11, 16 / 244, 86, 9, 12 |
| Vases brown | large / medium / small | 257, 80, 14, 19 / 274, 83, 11, 16 / 292, 86, 9, 12 |
| Vase clusters | 3 groups | bottom row, x ≈ 20 to 80, y ≈ 112 to 136 |
| Crate / barrel clusters | ~5 groups | top right, x ≈ 274 to 365, y ≈ 16 to 109 (crate pair, crate stack, barrel+crate, barrel+crate+vase, …) |
| Shields | 2 variants | ~97, 112, 15, 20 and ~112, 112, 15, 15 (bottom row; measure) |
| Gold piles | 4 sizes | bottom row, x ≈ 177 to 237, y ≈ 113 to 126 |
| **Excluded** | chests, gold-filled chests, keys, lever, ladders, hatch, wall staircase | do not create textures for these |

**Acceptance:** before placing anything, render a labelled preview sheet of all variants (each region cut out at 4×, with its file name), show it to the user and wait for an OK. No variant may contain pixels of a neighbour.

## 5. Placement rules

**Scene structure:**
- Add a `Props` Node2D (`y_sort_enabled = true`, position (0, 0)) to NewFloor1, **after** all tile layers.
- Under it, one Node2D group per room (`R1_Props` … `R8_Props`, `y_sort_enabled = true`), and `Shields` for the wall-hung ones.
- Only Prop instances go there. This relaxes the PRD 4 rule "no objects in NewFloor1", **for props only**.
- Instance `Prop.tscn` properly. Do not duplicate tile layers or embed resources: the pitfall from handoff §7. After saving, grep the `.tscn`. It must contain no `[sub_resource` TileSet blocks and no `tile_set =` lines. A `[sub_resource]` is acceptable only for the props' own shapes if they are created that way.

**Floor props** (crates, barrels, vases, clusters):
- Position = base in pixels, on the floor of a room. Snap to whole pixels, not necessarily to the 16 px grid. Small offsets look more natural, as in the reference.
- Style from the reference:
  - groups of 2 to 5 pieces against walls and in corners, with mixed sizes (a tall crate with a barrel and a small vase, a vase cluster beside a crate);
  - some single props along walls;
  - a couple of free-standing props in big rooms;
  - mix light and dark wood and blue and brown vases.
  - Do not repeat the same group in the same room.
- **Keep clear:**
  - the 5 arch doors and the 2 tiles right in front of each door, on both sides (door cells in handoff §4);
  - the 8 torch niches, plus the tile below each niche and one tile to each side, for the torch light later;
  - the 3-wide side entries and all corridors (corridors get no props at all);
  - the R4 stairs, stairwell and platform edges;
  - the gate at x 37 to 38, y 16 to 17, and the tile below it;
  - the R3 pool strip.
- **Walkability:** every walkable area stays reachable from the entrance room R1. The player's radius is 6.5 px, so leave at least about 16 px of free floor between a prop footprint and a wall or another prop wherever the player is meant to pass. Gaps narrower than about 14 px are not allowed, unless the gap is a fully closed nook (e.g. behind a cluster in a corner).
  - Check this with a script: flood fill over the walkable cells (or a pixel grid) minus the prop footprints, grown by the player's radius. Also check by walking.
- No prop may overlap a wall's collision, another prop's footprint, or the dark void.

**Shields:**
- About 6 to 8, on the brick fronts of walls **north of a room** (walls where the room's top floor row is r and the wall's front rows are r-3 to r-1). The shield sits visually on the **middle row (r-2)**.
- Not on side walls, not within 2 tiles of an arch, niche or the gate, and not on the cracked bricks if they hide the crack art badly (your judgment; screenshot).
- Draw order: the brick fronts sort at the wall's bottom edge, y = (r-1)·16 + 8 (handoff §3). Set the shield's origin 1 px below that, at (r-1)·16 + 9, with the sprite drawn upward onto row r-2.
  - Then the shield is drawn over the bricks and behind the player while the player stands in the room. Verify this, and fix the rule if Godot's tie-breaking says otherwise.
- `solid = false`, `breakable = false`.

**Gold piles:**
- 4 to 8 total, in 2 or 3 rooms, near storage groups or in a dead end. `flat = true`, `solid = false`.

## 6. Density targets (rooms from handoff §4)

The rooms are big. **No room may look empty.** Use these as targets ("piece" = one Prop instance; a cluster counts as one):

| Room | Character | Target |
|---|---|---|
| R1 entrance (12×9) | lived-in, near the entrance | 6–9 pieces, 2 groups + singles |
| R2 large hall (22×16) | main hall: groups along all walls, a couple of free-standing | 14–20 pieces |
| R3 water room (14×14) | vases and barrels on the dry side, one group near the pool | 8–12 pieces |
| R4 stairs room (14×10) | keep the platform and stairs clear; groups on the west side | 6–9 pieces |
| R5 west room, dead end (11×10) | storage | 8–12 pieces, dense corners |
| R6 north room (15×7) | narrow: props along the north wall only, path stays clear | 6–9 pieces |
| R7 SE room, dead end (12×6) | storage room, densest | 8–12 pieces + gold |
| R8 closet, dead end (8×6) | cluttered closet | 5–8 pieces + gold |
| Walls | shields | 6–8 total |

Total: roughly 65 to 95 Prop instances. It is fine to go a bit lighter than the reference if a room still feels furnished.

## 7. Phases and acceptance

Stop after each phase, report **in the chat message itself** (not only in the end-of-turn summary) with screenshots, and wait for the user's OK.

### Phase 1: Prop scene + textures
- Apply §3. Create all variant textures from §4. Render the preview sheet.
- **Acceptance:**
  - the §3 criteria;
  - the preview sheet is approved;
  - a test instance of each variant type in `Tests/FloorTest.tscn` (temporary, removed afterwards) shows the correct sorting and collision at runtime, with a screenshot.

### Phase 2: placement plan
- Make the placement reproducible: one source-of-truth file (for example `Tests/Tools/newfloor1_props.json`, or a section in a new `Tests/Tools/newfloor1_props.ps1` next to `newfloor1_maps.ps1`). It lists, per room: variant, position in px, and flags.
- Write a checker that reads it together with `layout.txt` and the layer maps (handoff §6) and reports problems. It must print `problems: 0`. Checks:
  - props on non-floor cells;
  - overlaps;
  - keep-clear zones from §5;
  - reachability (flood fill with the player radius);
  - density counts per room.
- Render a **top-down plan image** of the floor (layout plus prop footprints and labels) and show it to the user **before** instancing anything.
- **Acceptance:** the checker reports 0 problems, and the user approves the plan.

### Phase 3: instancing
- Instance the props into NewFloor1 from the source-of-truth file. Use editor tools with undo, or extend `addons/sinfulness_mcp_tools/` with a small eager tool, e.g. `sinprops_place` with `clear_first`. Note: group tools don't reach the client; only eager tools work after `extensions_refresh` (handoff §7).
- Do not place props by hand one by one without the file, and **do not hand-edit `.tscn`**.
- Save, grep the `.tscn` (§5), and reopen the scene with `sintiles_reload_scene`.
- **Acceptance:**
  - the scene loads without errors;
  - the counts match the plan;
  - the editor screenshot of the full floor matches the plan image.

### Phase 4: verification
- Run `Tests/FloorTest.tscn`. Walk every room and corridor (recipe in handoff §8, using numeric key codes; read the position back after each leg).
- Take screenshots of the full floor and close-ups of R2, R7 and a shielded wall.
- **Check:**
  - every room is reachable, and the handoff's Phase 5 stop positions still hold where no prop is in the way;
  - props block the player at their footprint;
  - the player draws behind a prop when above its base and in front when below it;
  - shields are behind the player and over the wall;
  - gold is always under the player;
  - attacking a prop does nothing;
  - no torches, ladders, hatches, chests, keys or lever are present;
  - `debugger_get_log` and `editor_get_console` show no errors or warnings.
- Report anything that could not be done, and any suggested tweaks.

## 8. Working rules

- Re-read every file right before editing it (VS Code + Copilot).
- **No Git commands at all**, not even read-only ones.
- Ask instead of guessing. If the PRD disagrees with the code, ask.
- Don't touch anything outside this PRD's scope (§1).
- Keep NewFloor1's tile layers untouched. If a layout problem blocks a good placement, report it and don't change tiles.
- Notion: in the page "Sinfulness" (`379f4675-ea8f-808d-97a9-d3fa80343d85`), callout **"Svět – postup"**:
  - add one short Czech line per finished phase under *Hotovo*;
  - add one line per real mistake under *Chyby a poučení*;
  - read the existing lines first. No long text, no code.
- At the end, update `Tests/PRDs/NewFloor1_Handoff.md` with:
  - a short "Props" section: the scene structure, the variants list, the pipeline (file → checker → instancing) and the draw-order rules;
  - the open items: torches into the niches, wooden doors, interactive chests, turning on `breakable`.
