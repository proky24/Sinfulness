# PRD 2: Loadout tab stage 2, two-way page flip, last-used tab (Sinfulness, Godot 4.7.2)

Owner: Proke. Status: ready for implementation. This PRD builds on `docs/PRD_Inventory_System.md` (PRD 1, already implemented). Where the two disagree, this one wins (see section 2).

## 1. Goals

1. Rework the Loadout tab so that after the player picks an armor slot, the left page lists every owned piece for that slot and the right page shows the highlighted piece's details.
2. Make the page-turn animation work in both directions, driven by the `tab_page` number on each tab.
3. Reopen the menu on the last-used tab.

Out of scope: anything about boss fights (the game has no bosses yet, do not add or change boss-fight behavior; if a loadout-lock check already exists, leave it as it is), crafting, Abilities, Save and Settings page contents, balancing.

## 2. Changes to earlier decisions (supersede PRD 1)

- The menu **opens on the last-used tab** (PRD 1 said the first tab). The very first opening in a game session uses Loadout.
- Armor can be **unequipped** (the player may go without a piece).

## 3. Current state (verified, read these files first)

- `res://GUI/PauseMenu/pause_menu.gd`: CanvasLayer controller with states `CLOSED, OPENING, TAB_SELECT, PAGE_TURN, CONTENT`. Tab nodes are collected into `_tabs` in scene-tree order. `show_pause_menu()` currently sets `_active_tab = _tabs[0]` and after `open_menu` finishes it calls `_enter_tab_select(_tabs[0])` then `_show_page()`. `hide_pause_menu()` clears the active tab. `_on_tab_chosen()` clears the page and plays the code-built `page_turn` animation. `_go_back()` asks `_page.go_back()` first (returns true if the page consumed it) and otherwise returns to the tab list.
- The `page_turn` animation is built in `_add_page_turn_animation()`: it shows the `Control/PageTurn` TextureRect and steps its AtlasTexture region through 8 frames of `Spellbook_NextPage.png` (256x176 each). The AtlasTexture margin aligns the frames with the 240 px tall opened book. The `Book` texture is never touched.
- `res://GUI/PauseMenu/Scripts/book_tab.gd` (`class_name BookTab extends TextureRect`): exports `selected_texture`, `page_scene`, `tab_page: int`; emits `tab_chosen`.
- Loadout page scene: `res://GUI/PauseMenu/Inventory/UI/LoadoutPage.tscn` (script location: find it from the scene). Pages derive from `BookPage` (methods used by the controller: `build()`, `set_interactive()`, `get_first_focus()`, `go_back() -> bool`).
- Tab scene-tree order is Loadout, Inventory, Potions, Abilities, Save, Settings.

## 4. Part A: two-way page flip and last-used tab

### Requirements
1. `tab_page` values (set in the editor by the user, verify and fix if wrong): LoadoutTab 0, InventoryTab 1, PotionsTab 2, AbilitiesTab 3, SaveTab 4, SettingsTab 5.
2. `pause_menu.gd` tracks the number of the page currently shown (`_current_tab_page`). When a tab is chosen:
   - chosen `tab_page` > current: play the existing forward flip.
   - chosen `tab_page` < current: play the backward flip.
   - chosen `tab_page` == current (this includes re-choosing the open tab): no flip; rebuild or refocus the page immediately and go to `CONTENT`.
3. Backward flip, in this order:
   1. Mirror: set `page_turn.flip_h = true` for backward flips (false for forward) and play the same animation. Check alignment against the book with `runtime_screenshot` at several frames in both directions. Always reset `flip_h` afterwards.
   2. If the mirrored frames do not line up with the book (the AtlasTexture margin may assume the book is centered in the overlay), fall back to playing the same animation in reverse (`play_backwards`), and check for a visible first-frame jump. Report which one you chose and why.
   The forward flip must look exactly as it does now. Do not touch the `Book` texture.
4. Last-used tab: remember the last chosen tab for the whole game session (not saved to disk). `show_pause_menu()` opens on it: the book opens, that tab is highlighted, its page is shown with no flip, and `_current_tab_page` is set from it. First time in a session it is LoadoutTab. `hide_pause_menu()` must not forget it.
5. Input stays ignored while `OPENING` and `PAGE_TURN` (existing behavior).

### Acceptance criteria (Part A)
- Going Loadout → Potions flips forward, Potions → Inventory flips backward, Inventory → Settings forward, Settings → Loadout backward. Choosing the open tab again does not flip.
- Both directions look aligned with the book in screenshots.
- Close the menu on Potions, reopen: Potions is shown and highlighted, no flip. Fresh game start: Loadout.
- No errors or warnings in `editor_get_console`.

## 5. Part B: Loadout tab, stage 2

### Stage 1 (unchanged)
The left page shows the four slots (helmet, chestplate, gauntlets, boots) and the right page behaves as it does now. Do not change stage 1.

### Stage 2 (new)
Entered by confirming a slot (left click, ❌, or `ui_accept`).

1. **Empty slot category:** if the player owns no pieces for that slot, do not enter stage 2. The right page shows a short "nothing for this slot" message and focus stays on stage 1.
2. **Left page:** replaced by a list or grid of all owned pieces for that slot, using the same slot UI and layout as the Inventory page. The currently equipped piece (if any) is included and clearly marked as equipped. The cursor starts on the equipped piece, or on the first piece if nothing is equipped.
3. **Right page:** name and description of the highlighted piece, plus the stat comparison (current value and the value after equipping, as in PRD 1 / Notion). When nothing is equipped in that slot, "current" is the value without the piece. Focus and mouse hover both update it, the same way as on the Inventory page.
4. **Confirm on a piece that is not equipped:** equip it. The previously equipped piece stays in the owned list (unmarked). Stay in stage 2, the mark and the comparison update.
5. **Confirm on the equipped piece:** unequip it. The slot becomes empty, the mark disappears, stay in stage 2.
6. **Esc (`menu_back`):** `go_back()` returns true and the page returns to stage 1, with focus on the slot that was just edited. The stage-1 view shows the updated equipped piece. Esc in stage 1 returns false, so the controller goes back to the tab list. Tab always closes the whole menu.
7. Keep the existing data model (inventory plus equipped data) and the existing equip logic, signals and boss-lock check. Change the data classes only if you truly must, and explain why.

### Acceptance criteria (Part B)
- Slot → stage 2 shows only pieces of that slot; right page updates on every highlight change with keyboard and mouse.
- Equip, swap and unequip all work and the changes show in stage 1 afterwards and in the stat panel.
- An empty slot category shows the message and does not open stage 2.
- Esc from stage 2 goes to stage 1 (cursor on the edited slot); Esc from stage 1 goes to the tab list; Tab closes the menu from every state.
- Focus is never lost, no overlap with the book art in screenshots, no errors in the console.

## 6. Order of work

1. Part A, then stop and report.
2. Part B, then stop and report.
After each part, verify with the game running (`game_start`, `input_simulate`, `runtime_screenshot`) and read `editor_get_console`.

## 7. Working rules

- Code is edited in VS Code (Godot's external editor) with GitHub Copilot active, so re-read a file right before editing it.
- Edit `.gd` files directly. Change scenes and nodes with the Godot editor or the `godot-mcp-toolkit` tools. Do not hand-edit `.tscn` or UIDs unless a tool cannot do it, and reopen the scene afterwards.
- Follow the Notion "Project structure" conventions and the rules in section 8 of PRD 1. Static typing everywhere. No Git commands.
- Do not change anything outside this PRD's scope. If something blocks you, stop and ask. If this PRD and the code disagree, ask.

## 8. Notion progress callout

Update the existing short Czech callout "Inventář – postup" in the Notion page "Sinfulness" (id `379f4675-ea8f-808d-97a9-d3fa80343d85`): one line per finished part under "Hotovo", and one short line per real mistake under "Chyby a poučení". Read the existing mistake lines before you start. No long text, no code. If you have no Notion access, tell the user and keep the notes in your replies.
