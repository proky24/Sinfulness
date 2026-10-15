# PRD 3: Item pickup fix and pickup message (Sinfulness, Godot 4.7.2)

Owner: Proke. Status: ready for implementation. Builds on `C:\Users\proke\Documents\GitHub\Sinfulness\sinfulness\Tests\PRDs\PRD_Inventory_System.md` and `C:\Users\proke\Documents\GitHub\Sinfulness\sinfulness\Tests\PRDs\PRD_Loadout_And_PageFlip.md` (both implemented).

## 1. Goals

1. Items lying on the ground are picked up automatically when the player touches them, and they really end up in the player's inventory (today they do not show up in the pause menu).
2. Fix the inconsistent meaning of `add_item()`.
3. Show a small world-space message when something is picked up: item name and quantity, with a short upward slide.

Out of scope: remembering which pickups were collected (comes with the saving system, so items respawn when a level reloads for now), the interaction key (F) for chests and doors, a "no room" message, drop tables and spawning, new sound assets, anything outside the files named here.

## 2. Diagnosis (verified by reading the code)

### Bug 1: the pickup writes to the wrong inventory
`res://GUI/PauseMenu/Inventory/Items/Item_Pick_up/item_pick_up.gd` calls `GlobalPlayerManager.INVENTORY_DATA.add_item(item_data)`. In `res://Floors/00_Global/GlobalPlayerManager.gd`, `INVENTORY_DATA` is a constant that preloads `res://GUI/PauseMenu/Inventory/starting_inventory.tres`, the project template file. The pause menu reads the autoload `GlobalInventory` (`res://Floors/00_Global/GlobalInventory.gd`, scene `GlobalInventory.tscn`), which keeps its own runtime copy of that template (`_inventory`, made with `duplicate(true)`). So items go into a different object that no menu reads, and the shared template resource is modified in memory.

### Bug 2: `add_item()` has two meanings
- `GlobalInventory.add_item()` is documented as "returns how many did NOT fit", and its already-equipped-armor branch (`return maxi(quantity, 0)`) follows that.
- `InventoryData.add_item()` was changed by the user to return how many were **added**, and a stray `## return quantity - added` comment is left after the return.
- Cause of the change: the pickup checked `add_item(...) > 0`. With the "did not fit" meaning that is the wrong test (0 means everything fit), which made the pickup succeed only when the stack was already full. The function was changed instead of the check.

Decision: **`add_item()` always returns how many did NOT fit** (0 = everything fit), in both classes. Pickups test for `== 0` or use the difference.

### Other findings
- `item_pick_up.gd` waits for `audio_player.finished` before `queue_free()`. If no sound is assigned the signal never fires and the pickup is never freed.
- The pickup has no quantity setting.
- Misspelled method `_uptade_sprite`.
- `starting_inventory.tres` has an 11th slot (`Resource_vr32y`) that is unnamed while the others are named (`Slot_berserk`, ...). Check what it is. If it is an accidental empty entry, remove it and tell the user.

## 3. Requirements

### Part A: plumbing
1. **Semantics.** Make `InventoryData.add_item()` return `quantity - added` (how many did not fit), remove the stray comment, and fix its doc comment. Keep `GlobalInventory.add_item()` consistent with it (including the already-equipped armor branch, which means "nothing fit"). Search the whole project for every caller of `add_item` (`GlobalInventory`, `InventoryData`, `_inventory`) and fix any check that assumed the old meaning, including `equip_armor` and `unequip_armor`.
2. **Pickup target.** The pickup calls `GlobalInventory.add_item(item_data, quantity)`.
3. **Remove the old path.** Delete `INVENTORY_DATA` from `GlobalPlayerManager.gd`. If anything else uses it, move that code to `GlobalInventory` first.
4. **Quantity.** Add `@export_range(1, 99) var quantity: int = 1` to the pickup.
5. **Result handling** in the pickup's body-entered handler (only reacts to `Player`, as now):
   - `leftover = GlobalInventory.add_item(item_data, quantity)`, `picked = quantity - leftover`.
   - `leftover == 0`: the pickup is consumed (existing behavior: stop listening, play the sound, hide, free).
   - `0 < leftover < quantity`: the pickup stays in the world and its `quantity` becomes `leftover`.
   - `picked == 0` (nothing fit, a unique item already owned, armor already equipped): nothing changes and no message is shown.
   - Guard with a flag so two bodies entering in the same frame cannot add the item twice.
6. **Sound.** If `audio_player.stream` is null, free the pickup immediately instead of awaiting `finished`.
7. **Cleanup.** Rename `_uptade_sprite` to `_update_sprite`, and handle the unnamed slot in `starting_inventory.tres` (see above). Keep the `@tool` editor sprite preview working.

Acceptance (Part A):
- A pickup of a mushroom touched in a test level appears in the Potions tab (materials) with the right count.
- Stack cap: an item with max_stack 5, player owns 4, pickup quantity 3: 1 is added, the pickup stays with quantity 2.
- A unique item (lore, key, armor) that the player already has: the pickup stays and nothing is added. Same for an armor piece that is currently equipped.
- A pickup with no sound assigned is freed.
- `starting_inventory.tres` is not modified by playing (check slot count and quantities after a run, and that its modified time did not change).
- Regression: pause menu pages, equip and unequip, and potion use still behave as before. No errors in the editor console.

### Part B: pickup message
1. New small scene, for example `PickupMessage.tscn` next to the pickup scene, with a script. It shows one Label with the text `"{name} x{picked}"` (for example `Aspen mushroom x3`), using the item's `name` and the amount that was actually added. Always show the quantity, including `x1`.
2. It is created at the moment of a successful (picked > 0) pickup, starts exactly at the pickup's global position, and is added to the **pickup's parent** (not to the pickup itself, which may be freed). Give it a high `z_index` so it draws above sprites.
3. Animation: tween the position **up by 12 px** (y minus 12) while the text fades out, then `queue_free()`. Total time about 0.8 s, with the duration and distance exported so they are easy to tune. Use a short ease-out.
4. Reuse the font and styling used by the pause-menu pages so it matches the game. Keep it readable at the game's resolution and keep pixel positions crisp.
5. Several pickups at once produce independent messages, each starting at its own pickup's position (no stacking logic).
6. The message follows the normal pause behavior (it freezes while the tree is paused).

Acceptance (Part B):
- Picking up a 3-stack of Aspen mushrooms shows "Aspen mushroom x3" at the pickup's position, sliding up 12 px while fading out, then disappearing.
- A partial pickup shows only the amount that was added.
- Two nearby pickups touched together show two messages.
- Verify with screenshots taken at the start and end of the animation, and check the console for errors.

## 4. Order of work

Part A, stop and report, then Part B, stop and report. Before changing anything, read the files in section 2, search for all `add_item` callers and all uses of `INVENTORY_DATA`, and tell the user what you found.

## 5. Working rules

- The code is edited in VS Code (Godot's external editor) with GitHub Copilot active, so re-read a file right before editing it.
- Edit `.gd` files directly. Change scenes and nodes with the Godot editor or the `godot-mcp-toolkit` tools. Do not hand-edit `.tscn` files or UIDs unless a tool cannot do it, and reopen the scene afterwards.
- Follow the Notion "Project structure" conventions and the rules in the earlier PRDs. Static typing everywhere. No Git commands.
- Do not change anything outside this PRD's scope. If something blocks you or the PRD disagrees with the code, ask.

## 6. Notion progress callout

Update the existing short Czech callout "Inventář – postup" in the Notion page "Sinfulness" (id `379f4675-ea8f-808d-97a9-d3fa80343d85`). One line per finished part under "Hotovo". Under "Chyby a poučení" add these two lessons, shortened: (1) the pickup wrote to `GlobalPlayerManager.INVENTORY_DATA` (a copy of the template) and not to `GlobalInventory`; (2) changing a function's return meaning to patch a wrong check created two different meanings, fix the check instead. No long text, no code. If you have no Notion access, tell the user.

## 7. Assumptions to confirm

- No message is shown when nothing fits. A "no room" message may come later.
- A partially picked-up item is picked up again only when the player leaves and touches it again.
- The message goes in the pickup's parent node, which is assumed to use the same coordinate space as the pickup.
