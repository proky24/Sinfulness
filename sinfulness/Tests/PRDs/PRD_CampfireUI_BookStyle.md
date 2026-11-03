# PRD: Campfire level-up screen in the pause-menu book style (Sinfulness, Godot 4.7.2)

Owner: Proke. Status: ready for implementation. This PRD builds on `Tests/PRDs/PRD_CampfireUI_Redesign.md` (already implemented). Where the two disagree, this one wins (see section 2).

## 1. Goals

1. Make `res://GUI/Campfire/CampfireUI.tscn` look **exactly like the PauseMenu book**: the same book art, the same size and position, the same 1.2 scale, the same translucent background.
2. Give it the **same open and close animation** as the pause menu (including the book open and close sounds), without the tabs.
3. Fit the existing level-up content on the pause menu's smaller pages: orbs summary and 8 `< n >` rows on the left page, three grouped read-outs on the right page, level banner above the book, Confirm button below it.

This is **design only**. The pause menu's functionality (state machine, tab selection, page turns, inventory pages, focus handling) is deliberately **not** copied.

### Out of scope (do not do these)

- Any change to the pause menu: `GUI/PauseMenu/*` and `inventory_theme.tres` stay as they are. Read them for reference only. Do not open `PauseMenu.tscn` for editing.
- Tabs, page turns, `BookPage`, focus or WASD navigation, controller support.
- Leveling logic: spinner increments, orb costs, stat changes, Confirm behaviour, signals, data binding. Placeholder texts stay placeholder texts.
- `torch.gd` and anything outside `GUI/Campfire/` except the read-only references listed in section 3. (One thing noticed there is in section 9.)

## 2. Changes to earlier decisions (supersede PRD_CampfireUI_Redesign)

| Earlier decision | Now |
|---|---|
| Book is `Spellbook.png` at 2× (512×320), centred, pages 184×236 | Book is the pause menu's `Spellbook_Opening.png` atlas frame (256×240) at scale **1.2**, same offsets as the pause menu. Pages are **86×118**. |
| Level banner and Confirm inside the pages | Both **outside the pages**, on the dark space above and below the book. |
| Section dividers and Title-font section titles | **No dividers.** Section titles use the **Body font** in red (Title font is too wide, see section 4.3). |
| Opaque dark navy background | Translucent pause-menu tint (the scene already has this colour; keep and verify). |
| Fade-in tween, instant close | Book open animation, book close animation (with sounds). |
| Close with F only | F (`interact`) **and** Esc (`menu_back`). |

Still valid: `campfire_theme.tres`, only the two project fonts at sizes 8 and 11, no per-node font overrides, the `%` unique names and node names listed in section 5.4, and `CampfireUI` having `Background` first and `Root` second.

## 3. Current state (verified, read these files first)

- `res://GUI/PauseMenu/PauseMenu.tscn` (**reference, read only**):
  - `Control/Book` is a `TextureRect`: `anchors_preset 5` (top-centre), `anchor_left` and `anchor_right` 0.5, `offset_left -156`, `offset_right 100`, `offset_bottom 240`, `grow_horizontal 2`, **`scale (1.2, 1.2)`**, `stretch_mode 3`, texture = `AtlasTexture` of `Spellbook_Opening.png`, `region (0,0,256,240)`, `filter_clip` on.
  - `Control/Tabs/ContentofTab` is the page content holder: same anchors and offsets as the Book, `scale (1.2, 1.2)`, `mouse_filter` Ignore.
  - `AnimationPlayer` (root node `../Control`) with library `RESET`, `open_menu`, `close_menu`. Sub-resources `Animation_38l0w` (open) and `Animation_ak32l` (close). Open and close are **0.6 s** long and are played at `speed_scale` **1.3** (`MENU_SPEED` in `pause_menu.gd`).
  - **`open_menu`:** the `Book:texture:region` track is discrete, with keys at t = 0, 0.0667, 0.1333, 0.2, 0.2667, 0.3333, 0.4, 0.4667 and `Rect2(x, 0, 256, 240)` for x = 0, 256, 512, … 1792 (frame 0 is the closed book, frame 7 the fully open book). `Tabs:visible` turns true at 0.4667 and the tabs slide in until 0.6. An audio track starts the opening sound at t = 0.
  - **`close_menu`:** the same frames in reverse (x = 1792 down to 0, with the same 0.0667 step; one key is at 0.40350556 instead of 0.4, copy it as it is). An audio track starts the closing sound at 0.2667.
  - There is a separate `AudioStreamPlayer2D` under `AnimationPlayer` that those audio tracks play on.
  - Sounds: `res://Assets/UI SFX/PauseMenuSFX/book-opening.wav` and `book-closing.wav`.
  - Read the exact keys, audio clips and values from `Animation_38l0w` and `Animation_ak32l` in the file, not from this summary.
- `res://GUI/PauseMenu/pause_menu.gd`: `MENU_SPEED = 1.3`; the controller hides the page content before `close_menu` and shows it after `open_menu` finishes; input is ignored while the book opens or turns.
- `Spellbook_Opening.png` is 2048×240: **8 frames of 256×240**. The art occupies only the lower part of each frame (fully open frame: y 81 to 239, x 11 to 245), so a free band of about 97 px on screen is above the open book, and about 72 px below it (book art ends at screen y ≈ 287).
- Page areas of the pause menu, **measured** from the open frame: parchment x 26 to 116 (left) and 139 to 229 (right), y 88 to 207. The existing pause-menu pages (`LoadoutPage.tscn`) use `LeftPage` offsets (28, 92) to (114, 210) and `RightPage` (142, 92) to (228, 210) in the 256×240 content space, i.e. **86×118 each**. Use exactly these rectangles.
- `res://GUI/Campfire/CampfireUI.tscn` today: `CampfireUI` (CanvasLayer, `process_mode` Always) → `Background` (ColorRect, already tinted `Color(0.467, 0.412, 0.722, 0.078)` = the pause menu tint) and `Root` (Control, `campfire_theme.tres`) → `Book` (512×320 `Spellbook.png`, `Pages` HBox, left and right page columns, 8 `Row_*`, 8 `Stat_*`, `ConfirmButton`) and `HeaderBanner` (NinePatchRect 96×32) with `%LevelLabel`.
- `res://GUI/Campfire/campfire_ui.gd` today: `visible = false`, sets `modulate.a = 0` on every direct child, tweens them back in (`appear`); `_unhandled_input` on `interact` does `queue_free()`, `PauseMenu.process_mode = PROCESS_MODE_ALWAYS`, `get_tree().paused = false`. **It loops over `get_children()` and sets `modulate`, which fails on a non-CanvasItem child such as an AnimationPlayer, so this script must change** (see 5.5).
- `res://Entities/GeneralNodes/Props/Torches/torch.gd` opens it: instantiates `CampfireUI.tscn`, adds it to `current_scene`, sets `PauseMenu.process_mode = PROCESS_MODE_INHERIT` and `get_tree().paused = true`. It uses no child paths. **Do not change `torch.gd`.**
- `res://GUI/Campfire/campfire_theme.tres`: fonts 8 and 11, brown `Color(0.29, 0.16, 0.12)` labels, red `Color(0.5, 0.13, 0.1)` for `PageTitle` and `StatValue`, `BannerTitle`, Button_06A 9-slice styles (content margins 4 / 2, texture margins 5 / 4), and the layout variations `BookPages`, `PageMargin`, `UpgradeList` (which this PRD makes unused).

## 4. Design

### 4.1 Screen layout (640×360 viewport; approximate screen coordinates)

```
                  y≈53–91     [ LEVEL 9 ]            banner, above the book
        ┌───────────────────────────┬───────────────────────────┐   y≈97 book art starts
        │ LEFT PAGE (x≈198–301)     │ RIGHT PAGE (x≈334–438)    │
        │ True Orbs ......... 999   │ Base Stats                │
        │ Needed for level ..  67   │  Health / Mana / Damage / │
        │ Health      < 0 >         │  Durability / Luck  (100) │
        │ Mana        < 0 >         │ Ability Stats             │
        │ Damage      < 0 >         │  Faith / Disgrace         │
        │ Durability  < 0 >         │ Corruption Stats          │
        │ Luck        < 0 >         │  Durability               │
        │ Faith       < 0 >         │                           │
        │ Disgrace    < 0 >         │                           │
        │ Corr. Durab. < 0 >        │                           │
        └───────────────────────────┴───────────────────────────┘   y≈287 book art ends
                  y≈295–319   [ Confirm ]            below the book
```

Page rectangles are in the Content holder's 256×240 space (scaled 1.2 on screen), see 5.2. The banner and Confirm sit in the same space but outside the pages. Positions above are targets to confirm by screenshot, ±3 px.

### 4.2 Scale and pixels

Everything (book, pages, banner, Confirm) lives under one scaled holder, exactly like the pause menu, so all art has the same 1.2 pixel size. **1.2 is not an integer, and that is intended: it is what the pause menu does. Do not "fix" it** and do not add any other `scale`, `Window` stretch change or filter change. Because it is non-integer, verify positions at runtime with `global_position`, not in the editor (the previous pass found a 5 px overflow that put everything on half pixels).

### 4.3 Space budgets (measured; all in content-space px, before the 1.2 scale)

Fonts: Body 8 has ascent 7 and descent 2, so a text line is about 9 px. Title 11 does not fit the pages.

| Text | Body 8 width | Title 11 width | Page width |
|---|---|---|---|
| Base Stats / Ability Stats / Corruption Stats | 38 / 44 / 60 | 77 / **102** / **129** | 86 |
| Corruption durability | 74 | 172 | 86 |
| Corr. Durab. / Corr. Dur. / Durability | 44 / 36 / 34 | | |
| Needed for level + `67` | 57 + 8 | | 86 |
| True Orbs + `999` | 35 + 12 | | 86 |

Consequences, already decided:
1. **Section titles use the Body font in red** (a new variation, e.g. `PageSection`). The Title font is wider than the page for two of the three titles.
2. **Left-list label of the last row is shortened to `Corr. Durab.`.** A left row is name + `<` + value + `>`; with 10 px buttons and a 14 px value that leaves about 52 px for the name, and "Corruption durability" is 74. The right page keeps the full meaning through its header: under `Corruption Stats` the row says `Durability`. The node is still `Row_CorruptionDurability`.
3. Vertical budget, left page 118 px: two orbs rows (≈ 10 each) + 2 px gap + 8 rows at a pitch of 11 px = **110 px**, 8 px spare. Right page 118 px: 3 section titles (≈ 10) + 8 stat rows (≈ 10) + two 2 px gaps = **≈ 114 px**, 4 px spare. This is tight, so:
   - the spinner `<` and `>` buttons must be **≤ 11 px high**: the current theme buttons (16×16, content margins 2) are too big. Add a `SpinButton` variation in `campfire_theme.tres` with content margins of 1 px top and bottom and a minimum size of about 10×10.
   - the value label between the buttons has a minimum width of about 14, not 22.
   - no dividers. If you find spare room after cropping a divider texture to its non-transparent rows, you may add one under the orbs summary on the left page, but only if everything else still fits.
4. If something still does not fit, apply in this order and report which you used: row separation to 0 → body-font section titles to 9 px line height with no gap → move `TrueOrbsRow` and `OrbsNeededRow` out of the left page into the free band above the book (on the dark background they then need a light text colour, e.g. `#F3E2BF` as the Button text uses). **Do not shrink fonts and do not add a second scale.**

## 5. Requirements

### 5.1 Part A: the book shell and animation

1. Remove the old 512×320 `Book` and its `Pages` tree from `Root` once Part B has re-homed the rows (do Part A on an empty shell first, see section 6).
2. Add to `Root` a `Book` (`TextureRect`) that is a **copy of `PauseMenu/Control/Book`**: same anchors, offsets, `grow_horizontal`, `scale (1.2, 1.2)`, `stretch_mode`, texture region and `filter_clip`. Its `AtlasTexture` must be **its own sub-resource inside `CampfireUI.tscn`** (not a shared `.tres`, not the one from the pause menu), so animating `Book:texture:region` can never touch the pause-menu book. The atlas image is `res://Assets/UI pack/Individual files/1x/Spellbook & Tabs/Spellbook_Opening.png`. `mouse_filter` Ignore.
3. Add to `Root` a `Content` (`Control`) with the **same anchors, offsets, grow flags, `scale (1.2, 1.2)` and `mouse_filter` Ignore as `ContentofTab`**. It starts `visible = false`.
4. Add `AnimationPlayer` as a child of `CampfireUI` with `root_node = ../Root`, and an `AudioStreamPlayer2D` under it, as in the pause menu. Add the animations:
   - `open_menu` (0.6 s): the same 8 discrete region keys as the pause menu; `Content:visible` → true at 0.4667; the opening sound starting at t = 0 on the same player, with the same clip.
   - `close_menu` (0.6 s): the same reversed region keys; `Content:visible` false at t = 0; the closing sound at the same time and with the same clip as the pause menu.
   - `RESET`: region `(0,0,256,240)`, `Content:visible` false.
   - **No tab tracks.** Keep the lengths at 0.6 s so the timing feels identical.
   Create them with the animation tools or in the editor. If you build them in code instead (as `_add_page_turn_animation` does in the pause menu), the keys and times must still be identical.
5. Do not add an autoplay: the script starts the animation (5.5).

Acceptance (Part A):
- At runtime the Campfire `Book` has the same `global_position`, `size`, `scale` and region as `/root/PauseMenu/Control/Book` when both are at the same frame, and `Content` matches `ContentofTab` in `global_position` and `scale`.
- Frame-by-frame screenshots of the open animation (≈ t = 0.07, 0.2, 0.4 and the final frame) and of the close animation look identical to the pause menu's book at the same frames (allow differences only in the content and the background).
- The opening and closing sounds play at the same moments as in the pause menu.
- No errors in `editor_get_console` and no warnings in the debugger log.

### 5.2 Page holders (Part B)

Inside `Content`:
- `LeftPage` (`Control`): offsets (28, 92) to (114, 210). `RightPage` (`Control`): offsets (142, 92) to (228, 210). `mouse_filter` Ignore. Each has one `VBoxContainer` column filling it (`LeftColumn`, `RightColumn`), separation 0 or 1 as the budget needs. Use no extra margin container; the rectangles already sit inside the parchment.
- Outside the pages but inside `Content`: `HeaderBanner` and `ConfirmButton` (see 5.3).

### 5.3 Contents (Part B)

Keep the placeholder texts exactly as they are now: `LEVEL 9`, `999`, `67`, `0` per spinner, `100` per read-out row.

- **`LeftColumn`:** `OrbsSummary` (`TrueOrbsRow`: name `True Orbs`, `%TrueOrbsValue`; `OrbsNeededRow`: name `Needed for level`, `%OrbsNeededValue`) then `UpgradeRows` with the eight rows in the current order (Health, Mana, Damage, Durability, Luck, Faith, Disgrace, Corruption Durability). Each row stays an `HBoxContainer` `Name | Minus | Value | Plus` with `Name` expanding. The last row's Name text is `Corr. Durab.`. Values right-aligned in the orbs rows.
- **`RightColumn`:** `BaseStatsSection` (title `Base Stats`, rows Health, Mana, Damage, Durability, Luck), `AbilityStatsSection` (title `Ability Stats`, rows Faith, Disgrace), `CorruptionStatsSection` (title `Corruption Stats`, one row named `Durability`). Titles use the new body-font red variation. Rows are `HBoxContainer` `Name | Value`, value right-aligned.
- **`HeaderBanner`** (`NinePatchRect`, same texture and patch margins as now, about 96×32) with `%LevelLabel` (`BannerTitle`) centred on the ribbon. Place it above the book in content space, roughly y 44 to 76 (screen ≈ 53 to 91), horizontally centred on the book (x = 128 in content space). It must not touch the page rectangles (pages start at y = 92).
- **`%ConfirmButton`** below the book, in content space roughly y 246 to 266 (screen ≈ 295 to 319), horizontally centred, text `Confirm`, minimum size about (64, 16) as now.

### 5.4 Names to keep

All of these must exist with these exact names and `unique_name_in_owner` on: `%LevelLabel`, `%TrueOrbsValue`, `%OrbsNeededValue`, `%ConfirmButton`, `%Row_Health`, `%Row_Mana`, `%Row_Damage`, `%Row_Durability`, `%Row_Luck`, `%Row_Faith`, `%Row_Disgrace`, `%Row_CorruptionDurability`, `%Stat_Health`, `%Stat_Mana`, `%Stat_Damage`, `%Stat_Durability`, `%Stat_Luck`, `%Stat_Faith`, `%Stat_Disgrace`, `%Stat_CorruptionDurability`. Inside rows: `Name`, `Minus`, `Value`, `Plus` / `Name`, `Value`. They are the hooks a later leveling task will bind to. If you move existing nodes instead of rebuilding them, check afterwards (by reading the saved `.tscn`) that each has its owner and its unique-name flag.

### 5.5 `campfire_ui.gd` (Part A)

Rewrite the script (static typing; `_private` helpers; constants in `UPPER_CASE`). It is the only script change allowed. Behaviour:

- States: `OPENING`, `OPEN`, `CLOSING`.
- `_ready()`: hide `Content`, set `animation_player.speed_scale` to 1.3 (same constant value as `MENU_SPEED` in `pause_menu.gd`; do not import it from the pause menu), play `open_menu`, state `OPENING`. When it finishes, state `OPEN`.
- Input (`_unhandled_input` is fine): while `OPEN`, `interact` (F) **or** `menu_back` (Esc, ⭕) starts closing: mark the event handled, state `CLOSING`, hide `Content`, play `close_menu`. While `OPENING` or `CLOSING`, consume those two actions and do nothing.
- When `close_menu` finishes: `PauseMenu.process_mode = Node.PROCESS_MODE_ALWAYS`, `get_tree().paused = false`, `queue_free()`. These three side effects are the same ones the old close did, now after the animation.
- Remove the old `appear()` tween, `_show_child()` and the `get_children()` fade loop.
- `CampfireUI` keeps `process_mode` Always, so the animation runs while the tree is paused.
- Mouse: only the Buttons should react. Book, Content, pages and labels are Ignore.
- No other behaviour. The spinner buttons and Confirm do nothing yet.

### 5.6 Theme changes (Part B)

Edit `campfire_theme.tres` **only with the theme tool or in the Inspector, never by hand while the editor has it loaded** (a hand edit was overwritten by the editor last time).
- Add `SpinButton` (base `Button`, same styleboxes and colours as `Button`, content margins 1 px top and bottom, about 2 px left and right) and `PageSection` (base `Label`, Body font, red `Color(0.5, 0.13, 0.1)`).
- Remove `BookPages`, `PageMargin` and `UpgradeList` if nothing uses them after your change, and remove the old `Spellbook.png` and divider ext_resources from `CampfireUI.tscn` if unused. Do not remove anything else.
- Keep `PageTitle` and `StatValue`.

Acceptance (Part B):
- Every Label's `global_rect` lies inside its page's `global_rect`, with no overlap between rows and no clipped text, checked at runtime with `global_position` and `size`. The two pages' column heights fit with no overflow.
- Left page: 8 rows with `< n >`, each fully visible; right page: 3 groups, 8 read-out rows; banner above the book and Confirm below it, neither touching a page; nothing outside the 640×360 viewport.
- Names and `%` handles from 5.4 all present; no node other than `Book` and `Content` has a non-default `scale`; no `theme_override_*` on any child.
- A 1920×1080 screenshot of the final open state, converted from linear to sRGB before judging colours (the game uses `hdr_2d`, so raw screenshots look darker than the game).

## 6. Order of work

1. **Part A** (shell and animation): do it first on the shell, with the page area empty. Move or leave the old content out of the way (hide it, do not delete yet). Then stop and report, with the comparison screenshots.
2. **Part B** (content): rebuild the pages per 5.2 to 5.4, apply the theme changes, delete the old `Book/Pages` tree, then stop and report with the budget numbers (actual used height per page, spare pixels, which fallback if any).
3. Finish: `graphify update .`, close and reopen the scene to confirm it is saved, and check the Campfire opens from the real campfire in `FloorTest` or `NewFloor1`.

## 7. Working rules

- Use the graphify skill: run `graphify query` before your first search or read of project code, as `CLAUDE.md` requires, and `graphify update .` at the end.
- Code is edited in VS Code (Godot's external editor) with GitHub Copilot active, so re-read a file right before editing it.
- Edit `.gd` files directly. Change scenes, nodes, animations and themes with the Godot editor or the `godot-mcp-toolkit` tools. Do not hand-edit `.tscn` or `.tres` files that the editor has open. `scene_open` does not reload a scene that changed on disk while it is open, so close that tab without saving first. After creating files outside MCP, call `extensions_refresh` before running the game. Before `game_start`, check for unsaved tabs (it saves them).
- Moves and renames only with `project_fs_move` (dry run first), never through Explorer.
- Tool pitfalls already hit in this project: `node_manage duplicate` leaves the children without an owner (they would not be saved), so create rows separately or check owners afterwards; `scene_create_node` with a texture overwrites the offsets, so set offsets afterwards; `input_simulate` needs numeric keycode and physical_keycode, mouse positions in window pixels (×3), and `Rect2` in MCP uses `w`/`h`; keep one `input_simulate` call under 30 s.
- Static typing everywhere. Naming and structure follow the Notion "Project structure" conventions.
- **No Git commands, not even read-only ones** (`git diff` included). Find out what changed by reading files. To confirm the pause menu is untouched, compare modification times of `GUI/PauseMenu/*` before and after.
- Write each report in the message itself, not only in the wrap-up box. At the end, add a short "Hotovo" and "Chyby a poučení" entry (Czech) for the "Táborák – postup" section of the Sinfulness Notion page, as for the previous Campfire PRD.

## 8. Acceptance criteria (summary)

- [ ] Campfire book, content holder, animation, speed and sounds match the pause menu (numeric and screenshot comparison, Part A).
- [ ] No tabs, no page turns, no pause-menu logic in the Campfire; `GUI/PauseMenu/*` unchanged (modification times).
- [ ] Left page: orbs summary and 8 `< n >` rows. Right page: 3 grouped read-outs. Banner above the book, Confirm below it. Nothing overflows, nothing is clipped.
- [ ] Both F and Esc close it with the close animation; input is ignored while it opens and closes; after closing, the game is unpaused, `PauseMenu.process_mode` is Always and the node is freed.
- [ ] Only the two project fonts at sizes 8 and 11 (11 only on the banner), no per-node overrides, all styling from `campfire_theme.tres`.
- [ ] All names and `%` handles in 5.4 exist.
- [ ] Console and debugger log clean; reopening the Campfire from the world works (apart from the existing issue in section 9).

## 9. Noticed, not part of this task

- `torch.gd` never resets `campfire_ui_shown` when the Campfire closes itself: after closing the screen with F, the **next** press of F at the campfire only flips the flag back (`else` branch) and shows nothing, and the one after that opens it. Do not change it here. Report whether you can reproduce it, so it can be handled separately.
- `Tests/PRDs/PRD_CampfireUI_Redesign.md` and a leftover copy `GUI/Campfire/PRD_CampfireUI_Redesign.md` both exist. Leave them; the user will clean up.

## 10. Decisions made, and open questions

| # | Decision (default taken) | Open? |
|---|---|---|
| D1 | Layout: lists on the pages, banner above and Confirm below the book (chosen by the user from two options) | No |
| D2 | Background: same translucent tint as the pause menu (the scene already has it) | No |
| D3 | Close with F and Esc, both with the close animation (chosen by the user) | No |
| D4 | Left label `Corr. Durab.` for the last row (74 px does not fit in about 52 px) | **Yes.** Easy to rename; the right page shows `Durability` under `Corruption Stats`. |
| D5 | Section titles in the Body font, red, no dividers (Title font 102 and 129 px do not fit an 86 px page) | **Yes.** If it feels flat, it can be revisited with cropped dividers. |
| D6 | Book scale 1.2 (non-integer), same as the pause menu | No. Do not "fix" it. |
| D7 | Open and close sounds reused from the pause menu | No |
| D8 | Banner position and Confirm position are targets, final values by screenshot | No |
