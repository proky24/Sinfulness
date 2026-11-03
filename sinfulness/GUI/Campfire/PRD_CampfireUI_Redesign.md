# PRD: CampfireUI level-up screen. Layout, hierarchy and theme pass

- **Project:** Sinfulness (Godot 4, 640×360 viewport, `canvas_items` stretch, integer scale, nearest filtering)
- **Scene:** `res://GUI/Campfire/CampfireUI.tscn` (script: `res://GUI/Campfire/campfire_ui.gd`)
- **Date:** 2026-11-03
- **Type:** UI restructure and styling only. **No gameplay or logic code.**

---

## 0. How to use this document (Claude Code)

1. Read `CLAUDE.md` first. This PRD follows it: state assumptions, make surgical changes, verify each step.
2. The scene is a **hand-placed sketch** that is correct in content and rough layout but unusable as a UI. Your job is to turn it into a properly structured, themed Control tree that looks right and survives edits.
3. Do not invent features. If something here is ambiguous or contradicts what you find in the project, stop and ask before building on it.
4. Prefer the Godot MCP node tools and the editor over hand-editing the `.tscn`. The scene may be open in the editor, and external edits to an open scene cause reload conflicts. Save with `editor_save_scene`.
5. Everything in section 3 and section 5 marked *measured* was measured from the actual PNG and TTF files. Everything marked *verify* must be confirmed by you in a screenshot. Nobody has seen a rendered screenshot of the current scene yet, so take a baseline first.

---

## 1. Goal and non-goals

### Goal
Make the Campfire level-up screen **usable and consistent with the pause menu**. It should sit on the same open-spellbook art, use the same two fonts and the same parchment colour logic, and be built from containers, with no hard-coded offsets and no scaled controls.

The player sees:
- a banner at the top with the current level
- on the **left page**, their True Orbs, the orb cost for the next level, and one `< n >` spinner per stat to spend points on
- on the **right page**, a read-out of the current stat values in three groups
- a Confirm button

### Non-goals (do **not** do these)
- No GDScript for spinners, costs, orb maths, confirm behaviour, signals, or data binding. Placeholder text stays placeholder text.
- No changes to `inventory_theme.tres` or anything under `GUI/PauseMenu/`. The pause menu shares that theme.
- No new animations, SFX, controller or keyboard focus navigation (see section 9).
- No changes to `campfire_ui.gd` unless section 6 says a change is required (it should not be).
- No renaming, moving or restyling of other scenes.

---

## 2. Current state (findings)

From `scene_get_tree`, `scene_spatial_map` and the `.tscn` source. **No rendered screenshot was available**, so these are structural findings.

| # | Problem | Evidence |
|---|---|---|
| 1 | Groups are plain `Node`s, not `Control`s. They cannot lay out or anchor anything. | `Control/Node`, `Labels`, `BaseStats`, `AbilityStats`, `CorruptionStats`, `Header`, `Upgrades`, `Confirm` are all class `Node`. |
| 2 | Every element is absolutely positioned with offsets. A container exists only to cancel offsets. | `Labels/Control` sits at (-40, 72) and its children are at x=96. |
| 3 | Stat rows are one Label with runs of spaces for alignment. | `"Health                                  100"` |
| 4 | Art is stretched with `scale`, which distorts pixel art and makes sizes unreliable. | Dividers (3, 1.5) and (3.36, 1.5), banner (2.5, 2), Confirm button (2.56, 1.92). |
| 5 | Confirm is an icon-only Button with a separate Label floating on top of it. | `Confirm/Button` has `icon = Button_06A_Normal.png` and no text. `Confirm/Label` is a sibling. |
| 6 | **Colours clash.** The shared theme's text colours are dark brown `(0.29,0.16,0.12)` and dark red `(0.5,0.13,0.1)`, made for parchment. The scene background is near-black navy `(0.035,0.027,0.09)` and has no parchment on it. | Dark text on a dark background. |
| 7 | **Fonts are inconsistent.** The 8 left labels override font to `FantasyRPGtitle` size 10 (native is 11). The right-hand rows override size to 10 on the 8 px text font (native is 8). Orbs, spinner count and Confirm labels have no theme at all, so they use the engine default font. | Per-node `theme_override_*`. |
| 8 | **Overlaps.** Ability grid overlaps the Corruption header and divider. Corruption grid overlaps the Confirm button. `<` and `>` buttons overlap the count label. | `scene_spatial_map` overlaps. |
| 9 | **Data mismatch.** The left list has 8 stats. The right read-out shows 7. **Durability is missing on the right.** | Left: Health, Mana, Damage, Durability, Corruption durability, Luck, Faith, Disgrace. Right: Base (Health, Mana, Damage, Luck), Ability (Faith, Disgrace), Corruption (Corruption Durability). |
| 10 | A single `< 0 >` spinner sits in the middle of the screen, but the left list has eight stats. Intent is one spinner per stat. | `Upgrades/Button`, `Button2`, `Label` |
| 11 | Misleading names. The full-screen background is a `ColorRect` named `CanvasModulate`. Most labels are `Label`, `Label2`, `Label8`. | |

---

## 3. Target design

### 3.1 Visual direction (decided)
**Parchment panel on dark.** The dark background stays (`#09071A`, existing colour). The content sits on the **open Spellbook** art from the UI pack, the same family the pause menu uses, so the existing brown and red text colours work as intended.

### 3.2 Wireframe (640×360 viewport; not to scale)

```
                 ┌──────────── HeaderBanner (LEVEL 9) ────────────┐
        ┌────────┴──────────┬───────────┬──────────────────────────┴───┐
        │ LEFT PAGE         │  (spine)  │ RIGHT PAGE                   │
        │ True Orbs     999 │           │ Base Stats                   │
        │ Needed for lvl 67 │           │ ─── divider ───              │
        │ ─── divider ───   │           │ Health ............ 100      │
        │ Health   < 0 >    │           │ Mana .............. 100      │
        │ Mana     < 0 >    │           │ Damage ............ 100      │
        │ Damage   < 0 >    │           │ Durability ........ 100      │
        │ Durability < 0 >  │           │ Luck .............. 100      │
        │ Luck     < 0 >    │           │ Ability Stats                │
        │ Faith    < 0 >    │           │ ─── divider ───              │
        │ Disgrace < 0 >    │           │ Faith / Disgrace             │
        │ Corr. Dur. < 0 >  │           │ Corruption Stats             │
        │                   │           │ ─── divider ───              │
        │                   │           │ Durability ........ 100      │
        │                   │           │        [ Confirm ]           │
        └───────────────────┴───────────┴──────────────────────────────┘
```

This keeps the sketch's arrangement: orbs info top-left, stat names with their spinners on the left, grouped read-outs on the right, Confirm bottom-right, level banner top-centre.

### 3.3 Art scale: integer only, never `scale`
- The Spellbook (`Spellbook & Tabs/Spellbook.png`, **256×160**) is drawn at **2×: 512×320**, centred, using the TextureRect's **size** (`expand_mode = Ignore Size`, `stretch_mode = Scale`, nearest filter), **not** the `scale` property.
- **No node in the scene may have a non-default `scale`.** Panels and buttons that need to be a custom size use 9-slice (`NinePatchRect` / `StyleBoxTexture` with margins), so borders stay pixel-exact.
- Book on screen: position (64, 20) to (576, 340) in the 640×360 viewport. Keep it centred via anchors, not typed offsets.

### 3.4 Page content areas (measured from the Spellbook PNG)
Parchment safe area at 1×:

| | x | y | size |
|---|---|---|---|
| Left page | 26 to 117 | 10 to 127 | 92×118 |
| Right page | 138 to 229 | 10 to 127 | 92×118 |
| Spine gap | 118 to 137 | | 20 px |

At the 2× book that is, in **book-local** pixels, each page **≈ 184 × 236** at x=52 and x=276, y=20, with a **40 px** spine gap between them. Add **6 px inner padding** on each page. Tolerance ±2 px; confirm on screen.

Implementation hint: a single `HBoxContainer` (`Pages`) inside the book, with left offset 52, right offset −52, top 20, bottom −64 and separation 40. Both pages are `size_flags_horizontal = Expand|Fill`, which gives equal 184 px widths.

### 3.5 Typography and colour (measured widths)
Both fonts already exist in the project and in `inventory_theme.tres`:
- Title font: `res://Assets/UI pack/Fonts/FantasyRPGtitle (size 11).ttf` → use at **11** only.
- Body font: `res://Assets/UI pack/Fonts/FantasyRPGtext (size 8).ttf` → use at **8** only.

Both are pixel fonts. **No other sizes. No per-node font overrides.**

| Role | Font / size | Colour |
|---|---|---|
| Section titles (Base Stats, Ability Stats, Corruption Stats) | Title 11 | accent red `#80211A` (= existing `Color(0.5, 0.13, 0.1)`) |
| Banner text (`LEVEL 9`) | Title 11 | dark brown `#4A291F`, or cream if brown is hard to read on the banner (*verify*) |
| Stat names, orbs labels | Body 8 | dark brown `#4A291F` (= existing `Color(0.29, 0.16, 0.12)`) |
| Stat values, spinner values, orbs numbers | Body 8 | accent red `#80211A` |
| Button text (Confirm, `<`, `>`) | Body 8 | cream, e.g. `#F3E2BF` (*verify* contrast on the red button art) |
| Screen background | n/a | `#09071A` (existing) |

**Why the left names must be Body, not Title:** measured at native size, `"Corruption durability"` is **74 px** in the Body font and **172 px** in the Title font. A page is 184 px wide and also needs about 56 px for the spinner, so only the Body font fits. Other widths (Body 8): Health 22, Mana 18, Damage 26, Durability 34, Luck 16, Faith 18, Disgrace 30, "Needed for level" 57, "True Orbs" 35. Section titles (Title 11): "Corruption Stats" 129, "Ability Stats" 102, "Base Stats" 77, all of which fit.

### 3.6 Art assets to use (all existing, `res://Assets/UI pack/Individual files/1x/`)

| Element | Asset | Notes |
|---|---|---|
| Book | `Spellbook & Tabs/Spellbook.png` (256×160) | Same family as the pause menu |
| Banner | `Title banners/BannerMedium_02C.png` (48×32) | Already used by the sketch. Use a **NinePatchRect**: stretch **horizontally only** (left/right margins to protect the end curls, about 10–12 px, *verify* against the art; top/bottom 0) to about 96×32. Place it so its bottom edge stays above the page content (y < 40 on screen). |
| Dividers | `Dividers/Divider_10.png` (48×16) | The ornament is centred, so it will distort if stretched. Use a TextureRect with `stretch_mode = Keep Centered` at native 1× (48×16), centred in the section. If you choose another divider from the pack to get a stretchable line, say so in your report. |
| Spinner `<` `>` and Confirm buttons | `Buttons/Button_06A_Normal.png`, `_Pressed.png`, `_Selected.png` (each 48×16) | Use as `StyleBoxTexture` (9-slice, margins about 4 px, *verify*) for normal / pressed / hover+focus. `Button_04A_Normal.png` (grey) is a candidate for `disabled`. Keep the `<` and `>` as button **text**. |
| Banner text, labels | n/a | Real Labels. No icon-only buttons with floating labels. |

---

## 4. Target node hierarchy

Rules: every grouping node is a **Control or Container**. No `Node` used as a group. Names describe purpose. Nodes the future logic will need are marked `%` (**Unique Name in Owner**).

```
CampfireUI                         CanvasLayer   (existing script + process_mode ALWAYS, keep as is)
├─ Background                      ColorRect     full rect, color #09071A        ← must be child index 0
└─ Root                            Control       full rect, theme = campfire_theme.tres   ← child index 1
   ├─ Book                         TextureRect   Spellbook.png, 512×320, centred (anchors, not offsets)
   │  └─ Pages                     HBoxContainer offsets L52 R-52 T20 B-64, separation 40
   │     ├─ LeftPage               MarginContainer (6 px)
   │     │  └─ LeftColumn          VBoxContainer
   │     │     ├─ OrbsSummary      VBoxContainer
   │     │     │  ├─ TrueOrbsRow       HBoxContainer: Name "True Orbs" | %TrueOrbsValue "999"
   │     │     │  └─ OrbsNeededRow     HBoxContainer: Name "Needed for level" | %OrbsNeededValue "67"
   │     │     ├─ OrbsDivider      TextureRect   Divider_10, Keep Centered
   │     │     └─ UpgradeRows      VBoxContainer (separation ≈ 4–5)
   │     │        ├─ %Row_Health          HBoxContainer: Name | Minus "<" | Value "0" | Plus ">"
   │     │        ├─ %Row_Mana
   │     │        ├─ %Row_Damage
   │     │        ├─ %Row_Durability
   │     │        ├─ %Row_Luck
   │     │        ├─ %Row_Faith
   │     │        ├─ %Row_Disgrace
   │     │        └─ %Row_CorruptionDurability
   │     └─ RightPage              MarginContainer (6 px)
   │        └─ RightColumn         VBoxContainer
   │           ├─ BaseStatsSection        VBoxContainer
   │           │  ├─ Title        Label ("Base Stats", SectionTitle)
   │           │  ├─ Divider      TextureRect
   │           │  ├─ %Stat_Health ... HBoxContainer: Name | Value (100)
   │           │  ├─ %Stat_Mana
   │           │  ├─ %Stat_Damage
   │           │  ├─ %Stat_Durability    ← NEW (was missing)
   │           │  └─ %Stat_Luck
   │           ├─ AbilityStatsSection     (Title, Divider, %Stat_Faith, %Stat_Disgrace)
   │           ├─ CorruptionStatsSection  (Title, Divider, %Stat_CorruptionDurability)
   │           ├─ Spacer                  Control, size_flags_vertical = Expand
   │           └─ %ConfirmButton          Button, text "Confirm", horizontally centred
   └─ HeaderBanner                 NinePatchRect  BannerMedium_02C, about 96×32, top-centre
      └─ %LevelLabel               Label  "LEVEL 9", centred on the ribbon (full-rect anchors)
```

Left-list order now mirrors the right-hand grouping (Health, Mana, Damage, Durability, Luck | Faith, Disgrace | Corruption Durability). The sketch had Corruption Durability fifth and Luck sixth. See decision D3.

Row internals: in left rows, `Name` is `Expand|Fill`. `Minus` and `Plus` have a minimum size of about 16×16. `Value` has a minimum width of about 20–24 and is centred. In read-out rows, `Name` is `Expand|Fill` and `Value` is right-aligned.

All static Labels: `mouse_filter = Ignore`.

### Old → new mapping (so nothing is lost)

| Old | New |
|---|---|
| `CanvasModulate` (ColorRect) | `Background` |
| `Control/Node/Label` "True Orbs 999" | `TrueOrbsRow` (name + `%TrueOrbsValue`) |
| `Control/Node/Label2` "Needed for level 67" | `OrbsNeededRow` (name + `%OrbsNeededValue`) |
| `Control/Node/divider2` | `OrbsDivider` |
| `Control/Labels/Control/Label…Label8` (8 stat names) | `Row_*` → `Name` |
| `Control/Upgrades/Button`, `Button2`, `Label` (one shared spinner) | **Replaced** by a `Minus` / `Value` / `Plus` per row |
| `Control/BaseStats`, `AbilityStats`, `CorruptionStats` | `*Section` VBoxes |
| `Control/Header/TextureRect` + `Label` | `HeaderBanner` + `%LevelLabel` |
| `Control/Confirm/Button` + `Label` | `%ConfirmButton` (text button) |

Placeholder values stay as they are: `LEVEL 9`, `999`, `67`, `0` per spinner, `100` per read-out stat.

---

## 5. Theme spec

Create **`res://GUI/Campfire/campfire_theme.tres`**. Do **not** edit `inventory_theme.tres`. Godot themes do not inherit, so copy only the entries this scene needs. Assign it **once, on `Root`**. Remove every `theme =` and every `theme_override_*` from child nodes, and remove the scene's reference to `inventory_theme.tres`.

Contents:
- **Defaults:** `default_font` = body font, `default_font_size` = 8, `Label/colors/font_color` = `#4A291F`.
- **Variation `SectionTitle`** (base `Label`): title font, size 11, colour `#80211A`.
- **Variation `StatValue`** (base `Label`): colour `#80211A`.
- **Variation `BannerTitle`** (base `Label`): title font, size 11, colour per 3.5.
- **Button:** `StyleBoxTexture` for `normal`, `pressed`, `hover`, `focus` from the Button_06A set and `disabled` from a grey one, margins about 4 px. Font colours cream, per 3.5. Set the minimum size on the nodes, not in the theme.

Existing names to reuse: the shared theme already defines `PageTitle` (title font 11, red). If you can reuse that name in the new theme for section titles, do, so a future search finds one concept. Otherwise use `SectionTitle`. Pick one and say which.

---

## 6. Constraints and compatibility

- **`campfire_ui.gd` iterates `get_children()` of the CanvasLayer** to fade nodes in, and `_show_child` sets `get_children()[0].modulate.a = 0.95`. Therefore:
  - `CampfireUI` must keep **exactly two direct children**: the background **first** (`Background`), then `Root`.
  - Do not add other direct children. Fading `Root` fades the whole book.
  - If you find the script does need a change to keep working, stop and report instead of editing it.
- **Closing the screen** (`interact` action → `queue_free()`, unpause) must still work.
- **Before renaming anything,** find what instantiates `CampfireUI` and whether any other script reaches into its children by path. Use `graphify query` first, as `CLAUDE.md` requires. The only script known to touch this scene is `campfire_ui.gd`, which uses no child paths.
- Keep `process_mode = 3` (Always) on the root.
- **No new project settings, autoloads, or addons.**
- `CLAUDE.md` rules apply: minimum change that solves the problem; every changed line traces to this PRD.

---

## 7. Execution plan (verify each step)

1. **Preflight.** Run `graphify query` for who instantiates `CampfireUI` and any path references. Take a baseline screenshot of the current scene running. → *verify:* the reference list exists and the baseline screenshot is saved. Report if anything outside `campfire_ui.gd` depends on the child layout.
2. **Create `campfire_theme.tres`** (section 5). → *verify:* it loads with no console errors and `inventory_theme.tres` is unchanged.
3. **Rebuild the hierarchy** (section 4). Keep the existing placeholder texts. → *verify:* `scene_get_tree` matches section 4, with Background at index 0 and Root at index 1, and `scene_query` shows no node with a non-default `scale`.
4. **Assign the theme at `Root`; strip all per-node `theme` and `theme_override_*`.** → *verify:* `scene_query` for those properties returns nothing on children, and no label uses a font size other than 8 or 11.
5. **Fit pass.** Place the banner, divider and button art per 3.6, then adjust separations until everything fits inside each page's safe area with ≥ 4 px of padding. If a page overflows, reduce **row separation first**, then divider height or the Confirm button's height. **Do not shrink fonts or scale art.** If the longest left-list name plus spinner does not fit, shorten the display text of that one row (e.g. `Corr. Durability`) and report it. → *verify:* `scene_spatial_map` shows no overlaps other than parent and child, and all text lies inside its page.
6. **Look at it.** Run the scene (or temporarily instance it from a throwaway scene) and capture a screenshot at 1920×1080. Check: text is crisp (no blur or fractional-pixel offsets), the banner label sits on the ribbon, and the `<` `>` buttons look pressable. Fix what you see. → *verify:* screenshot attached to your report.
7. **Behaviour check.** Fade-in still plays; the `interact` action still closes it and unpauses. → *verify:* observed in a run.
8. **Cleanup.** Remove any temporary test scene or scaffolding. Run `graphify update .` per `CLAUDE.md`. Save the scene.

---

## 8. Acceptance criteria

- [ ] `CampfireUI` has exactly two direct children, `Background` then `Root`, and the existing script runs unchanged.
- [ ] No node is a plain `Node` used as a group. No node has a non-default `scale`. No absolute offsets except the book's centring anchors, the page offsets, and the banner placement.
- [ ] Every stat row has separate name and value Labels. There are no space-padded strings.
- [ ] 8 left rows, each with its own `<  n  >`. 8 right read-out rows, grouped Base (5), Ability (2), Corruption (1). Durability appears in both.
- [ ] Only the two project fonts are used, at 8 and 11 only. All styling comes from `campfire_theme.tres` on `Root`. No per-node overrides.
- [ ] Text is readable on parchment (brown and red) and on the banner, in the 1080p screenshot.
- [ ] No overlaps and no clipped text; ≥ 4 px padding inside each page.
- [ ] `inventory_theme.tres`, `GUI/PauseMenu/*` and `campfire_ui.gd` have no diff.
- [ ] Report lists: files changed, any deviation from this PRD and why, and the screenshot.

---

## 9. Out of scope, but design with it in mind

- **Logic.** The `%` names (`%Row_*`, `%Stat_*`, `%TrueOrbsValue`, `%OrbsNeededValue`, `%LevelLabel`, `%ConfirmButton`) are the hooks a later task will bind to. Keep them stable.
- **Gamepad and keyboard navigation.** The `<` and `>` buttons will need focus neighbours later. Do not remove focus from buttons. Do not wire neighbours now.
- **Pending-change display** (e.g. showing `+3` next to a read-out value) is not designed here.

---

## 10. Decisions made, and open questions

| # | Decision (default taken) | Why | Open? |
|---|---|---|---|
| D1 | Visual style: parchment Spellbook on the dark background | Chosen by the designer. Makes the existing brown/red theme colours legible. | No |
| D2 | One `< n >` spinner per stat row | Chosen by the designer. The left list has 8 stats; the old design had one shared spinner. | No |
| D3 | Durability added to Base Stats (right page) | Chosen by the designer. | No |
| D4 | Book at **2×** (512×320), not the pause menu's 1.2× | 8 rows and a spinner need about 184 px per page. At 1.2× each page would be about 110 px. | **Yes.** Say if you prefer to match the pause menu's scale and shorten the content instead. |
| D5 | Fonts at native 8 and 11 only | Pixel fonts are crisp only at native or integer-multiple sizes. This is also what the pause menu does. | **Yes.** If the text feels too small against the 2× book, the integer step is 16 / 22, which needs a re-fit. |
| D6 | Left list reordered to mirror the right read-out grouping | Easier to scan. | **Yes.** Easy to revert to the sketch's order. |
| D7 | Banner widened as a horizontal 9-slice instead of scaled | Keeps the pixel art undistorted. | No |
