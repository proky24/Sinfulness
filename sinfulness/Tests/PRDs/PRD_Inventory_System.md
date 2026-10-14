# PRD: Inventory System for Sinfulness (Godot 4.7.2)

Owner: Proke. Status: ready for implementation. Language of this document: English. Language of the Notion progress callout: Czech.

## 1. Goal

Make the pause-menu book work as the game's inventory. The player opens one book menu, picks a tab, a page-turn animation plays, and the tab's page is filled from a shared player inventory, filtered by item category. From there the player can read item descriptions, drink potions, and change armor.

Out of scope for this PRD: crafting (alchemy), the Abilities, Save and Settings tab contents, talismans, the boss-fight system itself, world pickups and enemy drops (only the API they will call), and stat balancing.

## 2. Project context (verified, do not re-guess)

- Engine: Godot 4.7.2 stable, GDScript. Project root: `C:\Users\proke\Documents\GitHub\Sinfulness\sinfulness`.
- Existing scripts, in `res://GUI/PauseMenu/Invetory/Scripts/`:
  - `item_data.gd`: `class_name ItemData extends Resource` with `name: String`, `description` (multiline), `texture: Texture2D`.
  - `slot_data.gd`: `class_name SlotData extends Resource` with `item_data: ItemData`, `quantity: int = 0`.
  - `invetory_data.gd`: `class_name InvetoryData extends Resource` with `slots: Array[SlotData]`.
- Two test items exist in `res://GUI/PauseMenu/Invetory/Items/`, created from plain `ItemData`.
- Menu scene: `res://GUI/PauseMenu/PauseMenu.tscn`. Root `PauseMenu` (CanvasLayer, script `pause_menu.gd`, `process_mode` always) with children: `ColorRect`; `Control` containing `Book` (TextureRect) and `Tabs` (Control); `AnimationPlayer`.
  - `Tabs` contains `SettingsTab`, `SaveTab`, `LoadoutTab`, `InventoryTab`, `PotionsTab`, `AbilitiesTab` (each a TextureRect with one child TextureRect icon) and `ContentofTab` (Control with a `VBoxContainer`, which holds a `TextureRect`).
  - `pause_menu.gd` currently toggles the menu on the `pause_menu` action, sets `get_tree().paused`, and plays the `open_menu` animation at speed 1.3.
- Autoloads: `GlobalLevelManager`, `GlobalPlayerManager`, `PauseMenu`, `PlayerHud`, `MCPRuntimeServer` (tooling, do not touch).
- Existing input actions: attack, backwards, block, first_ability, forward, interact, left, pause_menu, right, second_ability, switch_stance, take_dmg, third_ability.
- Page-turn asset: `res://Assets/UI pack/Individual files/1x/Spellbook & Tabs/Spellbook_NextPage.png`.
- Design source: the Notion page "Sinfulness" (page id `379f4675-ea8f-808d-97a9-d3fa80343d85`, in Czech). Read the Controls, UI, Itemy and Mechaniky sections before starting.

## 3. Locked design decisions

1. One book menu, no other menu. `Tab` (keyboard) / Touch bar (controller) both opens and closes it, using the existing `pause_menu` action. Esc is not used. If the `pause_menu` action is still bound to Esc, rebind it to Tab.
2. One shared player inventory, held by a new autoload. Tabs only filter it by category.
3. Categories: `POTION`, `MATERIAL`, `ARMOR`, `LORE`, `KEY`. There is no weapon category: the player has one sword and damage comes from stats.
4. Tab to categories: Inventory tab shows `LORE` and `KEY`; Potions tab shows `POTION` and `MATERIAL`; Loadout tab shows `ARMOR`.
5. Armor is individual pieces in four slots: helmet, chestplate, gauntlets, boots. Two sets exist, sainted and decayed (see Notion).
6. Stacking limits: materials (mushrooms) 99; potions 5 per type (exported on the item, tunable); lore, key and armor items are unique (1, a second copy is refused). No overall slot limit.
7. Potions are temporary buffs with an exported duration of about 60 to 90 seconds. Re-drinking the same potion refreshes its timer and does not stack. A duration of 0 means an instant effect (for example Maturation, which lowers corruption).
8. Quick potion use: `1` drinks the selected potion, `2` cycles to the next potion type the player owns. Cooldown between potions: 3.0 seconds, exported and tunable.
9. Potion drinking from the Potions tab is allowed except during boss fights. The quick key is always allowed outside the paused menu.
10. Loadout can be changed any time through the menu except during boss fights. After the player dies in a boss fight, it is allowed again.
11. Unlimited items: no weight limit on the inventory. Equip load for armor is expressed through stance, dash distance and attack speed (see Notion).

## 4. Data model

All data classes live in `res://GUI/PauseMenu/Inventory/Scripts/` (after the rename in Phase 0).

- `ItemData` (base): add `id: StringName`, `category: Category` (enum above, set by each subclass in `_init`), `max_stack: int = 1`. Keep `name`, `description`, `texture`. Add an overridable `use(user) -> bool` returning whether the item was consumed.
- `PotionData extends ItemData`: `stat_changed` (enum: health, damage, durability, corruption_durability, luck, faith, disgrace, corruption), `amount: float`, `duration_seconds: float`, `max_stack = 5`. `use()` starts the buff, or applies the instant effect if duration is 0.
- `MaterialData extends ItemData`: no extra fields yet, `max_stack = 99`.
- `ArmorData extends ItemData`: `slot` (enum HELMET, CHESTPLATE, GAUNTLETS, BOOTS), `armor_set` (enum SAINTED, DECAYED), stat modifiers (health, damage, durability, corruption_durability, disgrace, corruption_gain), `stance`, `dash_distance_modifier`, `attack_speed_modifier`.
- `LoreData extends ItemData`: `text` (multiline), shown in full on selection.
- `KeyData extends ItemData`: `key_id: StringName`.
- `SlotData`: unchanged.
- `InventoryData` (renamed from `InvetoryData`): `slots: Array[SlotData]`, signal `changed_inventory`, and methods below.
- `EquippedData`: Dictionary of armor slot to `ArmorData` (or null), signal on change.

Autoload `GlobalInventory` (follows the existing `Global...` naming). It holds a runtime copy of the inventory made with `duplicate(true)` so playing never edits `.tres` files in the project. Public API:

- `add_item(item: ItemData, quantity: int = 1) -> int` returns how many did NOT fit (so a pickup can stay in the world).
- `remove_item(item: ItemData, quantity: int = 1) -> bool`
- `get_count(item: ItemData) -> int`
- `get_slots(categories: Array[ItemData.Category]) -> Array[SlotData]`
- `use_item(item: ItemData) -> bool`
- Potion quick use: `use_selected_potion()`, `cycle_potion()`, `get_selected_potion()`, signal `selected_potion_changed`, and a cooldown timer.
- Locks: `set_boss_fight_active(active: bool)`, `loadout_locked` (read-only), cleared by `notify_player_died()`.
- Signals: `inventory_changed`, `potion_used(potion)`, `equipment_changed`.

Applying buffs to player stats: first read `GlobalPlayerManager` and the player scripts to see whether a stats system exists. If it does, connect to it. If it does not, emit the `potion_used` signal and log it, and note this in the Notion callout. Do not invent a large stats system.

Buff and cooldown timers must pause when the tree is paused (do not use always-process).

## 5. Input

Add to the Input Map (names are fixed, bindings are easy to change later):

- `use_potion`: key `1`, controller D-pad down.
- `cycle_potion`: key `2`, controller D-pad right.
- `menu_back`: Backspace, controller ⭕ (circle). Goes back one level inside the menu (page to tab list). Tab closes the whole menu.

While `get_tree().paused` is true, `use_potion` and `cycle_potion` must be ignored (D-pad is also used for menu navigation).

## 6. Menu behavior

State machine in `pause_menu.gd`: `TAB_SELECT`, `PAGE_TURN`, `CONTENT`. Input only applies to the current state.

1. Tab pressed: menu opens (existing behavior), state `TAB_SELECT`, one tab highlighted.
2. Arrow keys / WASD / mouse move between the tabs. Confirm (left click, ❌ on controller, or `ui_accept`) chooses a tab.
3. State `PAGE_TURN`: play the page-turn animation using `Spellbook_NextPage`. Input is ignored while it plays.
4. On `animation_finished`, build the page for that tab from `GlobalInventory`, and move focus to its first slot. State `CONTENT`.
5. `menu_back` returns to `TAB_SELECT`. Tab always closes the menu.

Navigation uses Godot's built-in Control focus (focusable slot buttons, focus neighbors). Mouse hover calls `grab_focus()` so mouse and keyboard share one path. Whichever slot has focus updates the description panel (icon, name, description).

Reusable scenes: one `InventorySlotUI` (icon plus quantity label) and one description panel. Page layouts, built inside `ContentofTab` and sized to fit `Book.png`:

- Inventory tab: item grid on the left page, description on the right page (lore items show their full text).
- Potions tab: left page split vertically, potions on top and materials below; right page shows the description of the selected item, with an empty reserved area for the future alchemy UI (do not build crafting).
- Loadout tab: left page lists the four armor slots with the currently equipped piece (or an empty placeholder); choosing a slot shows the owned pieces for that slot on the right page; a stat panel shows before and after values for the highlighted piece. Equipping is blocked while `loadout_locked`, with a short message.
- Abilities, Save and Settings tabs: selectable but show no content yet, and must not error.

## 7. Phases and acceptance criteria

Work in order. After each phase run the game, verify, and update the Notion callout (section 9). Do not start a phase before the previous one passes.

### Phase 0: Housekeeping
- Rename folder `Invetory` to `Inventory` and class `InvetoryData` to `InventoryData`. Keep every file's UID working (do the rename in the Godot editor or with the MCP toolkit, not by moving files in Explorer).
- Convert the two test items to the correct subclasses once they exist (Phase 1).
- Acceptance: project opens without missing-resource errors, `editor_get_console` shows no errors.

### Phase 1: Data and logic
- Create the data classes, `EquippedData` and the `GlobalInventory` autoload with the full API.
- Create small test resources: two potions, two mushrooms, one lore item, one key, four armor pieces (one per slot, mixed sets). Placeholder textures are fine.
- Acceptance (verify with a small test script or MCP `execute_code`): stacking merges and respects `max_stack`; adding past the cap returns the leftover count; unique items refuse a second copy; `get_slots` filters by category; removing to zero deletes the slot; `inventory_changed` fires.

### Phase 2: Menu flow and pages
- Add the new input actions, the state machine, the slot and description scenes, and the three page layouts, filled with the Phase 1 test data.
- Acceptance: Tab opens and closes; choosing each tab plays the page-turn and then shows the right items; keyboard and mouse both work; focus is never lost; Abilities, Save and Settings tabs do not error; screenshots (`runtime_screenshot`) show nothing overlapping the book art.

### Phase 3: Using items
- Wire potion drinking from the Potions tab (blocked in boss fights), the `use_potion` and `cycle_potion` quick keys, cooldown, refresh-on-redrink, and `potion_used`.
- Acceptance: drinking removes one potion and shows the new count; at zero the slot disappears; the cooldown blocks a second drink; `1` and `2` do nothing while the menu is open; a boss-fight flag blocks menu drinking but not the quick key.

### Phase 4: Loadout
- Equip and unequip armor from the Loadout tab, before and after stat preview, `loadout_locked` via `set_boss_fight_active`, and unlock via `notify_player_died`.
- Acceptance: equipping moves the piece into the slot and the old piece returns to the owned list; stat preview matches the item data; while locked, equipping is refused with a message; after `notify_player_died` it works again.

### Phase 5: Persistence (data only)
- Save and load the inventory, equipped armor and selected potion with `ResourceSaver` to `user://`. Do not build the Save tab UI.
- Acceptance: save, restart the game, load, and the same inventory comes back.

## 8. Working rules for Claude Code

- Code is edited in VS Code, which is set as Godot's external editor. The user also has GitHub Copilot (Student plan) in VS Code. Claude Code cannot call Copilot, and Copilot suggestions may change files while you work, so re-read a file right before editing it.
- Write and edit `.gd` files directly. Create and change scenes and nodes through the Godot editor or the `godot-mcp-toolkit` tools. Do not hand-edit `.tscn` files or UIDs unless a tool cannot do it, and re-open the scene afterwards to check it loads.
- Follow the project conventions from the Notion "Project structure" callout: `class_name` in CamelCase, public functions `update_player_data()`, private functions `_update_player_data()`, constants in caps, typed variables, files under `res://<folder>/scripts`, `/sprites`, `/sfx`.
- Use static typing everywhere. Prefer signals over polling. No hard-coded node paths across scenes, use exports or groups.
- After each phase, run the project, read `editor_get_console` for errors and warnings, and take a `runtime_screenshot` of menu changes.
- Do not run Git commands (commit, push, reset). The user handles Git.
- Do not change anything outside this PRD's scope (combat, abilities, enemies, bosses, the Save and Settings tabs). If something outside scope blocks you, stop and ask.
- If the PRD and the Notion page disagree, ask the user.

## 9. Notion progress callout

In the Notion page "Sinfulness", create one new callout titled "Inventář – postup" (use a distinct icon and color). Keep it very short, in Czech, and update the same callout rather than adding new ones.

- "Hotovo": one line per finished phase.
- "Chyby a poučení": one short line per real mistake (what went wrong and what to do next time).
- Before starting each phase, read the "Chyby a poučení" lines and do not repeat those mistakes.

Do not write long explanations, code, or logs there. If you do not have Notion access, tell the user and ask them to enable the Notion connector for Claude Code, and keep the same notes in your replies until then.

## 10. Assumptions to confirm

- `menu_back` default (Esc and ⭕) was chosen because Esc is unused. The user may change it.
- Potion duration is stored as `duration_seconds` (about 60 to 90), not a minutes value.
- Controller defaults for potions: D-pad down to drink, D-pad right to cycle.
- If `GlobalPlayerManager` has no stats system, buff application is limited to the `potion_used` signal for now.
