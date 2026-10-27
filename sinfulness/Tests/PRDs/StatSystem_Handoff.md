# Stat system – session handoff (2026-10-27)

Context for the next Claude Code session. The task was `Tests/PRDs/PRD_StatSystem.md`: stats for the player and enemies, damage and crits, mana, orbs and leveling API, corruption, the HUD orbs, potions and armor. **All phases (0–5) are done.**

Working rules are the same as in `NewFloor1_Handoff.md` §1:
- phased work, with the report in the chat message;
- no Git;
- re-read files before editing;
- `.tres` / `.tscn` changes only through the editor or MCP tools;
- ask first;
- Czech Notion lines in the callout **"Staty – postup"** at the end of the page "Sinfulness".

## 1. Files

| File | What |
|---|---|
| `Entities/StatSystem/Scripts/stats.gd` | `class_name Stats extends Resource`. Base class: `Stat` enum, buffs, final values, health, hits. Replaces the tutorial sketch. |
| `Entities/StatSystem/Scripts/player_stats.gd` | `PlayerStats extends Stats`: points, level, orbs, mana, corruption, equipment. |
| `Entities/StatSystem/Scripts/enemy_stats.gd` | `EnemyStats extends Stats`: `orb_reward`, `corruption_per_hit`. |
| `Entities/StatSystem/Scripts/stat_buff.gd` | `StatBuff extends Resource`: `stat`, `buff_type` (ADD / MULTIPLY), `amount`, runtime `source`. |
| `Entities/StatSystem/Scripts/hit_data.gd` | `HitData extends RefCounted`: one hit (`amount`, `is_crit`, `corruption`, `source_position`, `applied`). |
| `Entities/Player/player_stats.tres` | PlayerStats template. All values equal the script defaults, so the file stores none; tune them in the Inspector. |
| `Entities/Enemies/Parent/enemy_stats.tres` | Skeleton test values (30 health, 8 damage, 0 durability, 2 orbs), assigned to `Enemy.tscn` → `stats`. |
| `Entities/GeneralNodes/Hurtbox/hurt_box.gd` | Deals damage: `damage_multiplier`, `source_stats`, new signal `hit_landed(target, hit)`. |
| `Entities/GeneralNodes/Hitbox/hit_box.gd` | Receives damage: `Damaged(hit: HitData)`, `take_damage(hit)`. |
| `Entities/GeneralNodes/Props/prop.gd` | Only `take_damage(_hit: HitData)` (the signature change). |
| `Entities/Player/Scripts/player.gd` | `stats` getter → `GlobalPlayerManager.player_stats`; hit wiring, mana on hit, potion keys, placeholder death. `hp` removed. |
| `Entities/Player/Scripts/States/state_attack.gd` | Exported `combo_damage_multipliers = [1.0, 1.1, 1.4]`, sets `hurt_box.damage_multiplier` per combo hit. |
| `Entities/Player/Scripts/States/state_idle.gd` | Debug `take_dmg` (↓) sends `HitData.new(15.0)`. |
| `Entities/Enemies/Parent/Scripts/enemy.gd` | `@export var stats: EnemyStats` (duplicated in `_ready()`), `_take_damage(hit)`, orbs on kill. `hp` removed. |
| `Entities/Enemies/Parent/Scripts/States/enemy_state_destroy.gd` | Fixed: callback takes the animation name, so the enemy is freed. The death push uses `knockback_speed` away from the player and slows down like the stun. |
| `Floors/00_Global/GlobalPlayerManager.gd` | `player_stats` (runtime copy of the template, set up before the Player exists), `reclaim_player()`. |
| `Floors/00_Global/GlobalInventory.gd` | Buff timeout removes the potion's buffs; every equipment change calls `apply_equipment()`. `_get_item_key()` moved to `ItemData.get_key()`. |
| `GUI/PlayerHUD/player_hud.gd`, `PlayerHUD.tscn` | `bind_stats()`; bars follow the stats; orbs are AtlasTextures (rows 5–42, offset 0, 5); one timer connection. |
| `GUI/PauseMenu/Inventory/Scripts/potion_data.gd` | `buffs`, `duration_seconds`, `heal_amount`, `mana_amount`, `corruption_amount`; `use()`. |
| `GUI/PauseMenu/Inventory/Scripts/item_data.gd` | New `get_key()`. |
| `GUI/PauseMenu/Inventory/UI/Scripts/items_page.gd` | Confirming a potion slot drinks it, refills the grid and moves focus. |
| `GUI/PauseMenu/Inventory/Items/*.tres` | 8 potions (see §4), `starting_inventory.tres` (+1 of each new potion, Decay 9 → 5). |
| `project.godot` | New actions `use_potion` (physical 1, D-pad down) and `cycle_potion` (physical 2, D-pad right). |
| `Tests/Scripts/Cases/test_stats.gd` | 21 tests: stat core and potions. |
| `Tests/Scripts/Cases/test_inventory.gd` | +2 tests (buff timer end, armor), starting-inventory counts updated. |
| `Tests/Scripts/Cases/test_torch_light.gd` | Path fixed to `Torch.tscn` (see §7). |
| `addons/sinfulness_mcp_tools/resource_tools.gd`, `input_tools.gd` | New editor MCP tools (see §8). |

## 2. Public API

**Stats** (base, use a runtime copy: `duplicate(true)` then `setup()`)
- Signals:
  - `health_changed(health, max_health)`
  - `health_depleted` (once per death)
  - `damaged(amount, is_crit)`
  - `stats_changed`
- Stats and buffs: `get_stat(Stats.Stat.X) -> float`, `add_buffs(buffs: Array[StatBuff], source)`, `remove_buffs(source)`, `has_buffs(source)`, `recalculate()`.
- Hits: `create_hit(multiplier, source_position) -> HitData`, `take_damage(hit) -> float` (sets `hit.applied`), `heal(amount)`, `is_dead()`, `get_crit_chance()`.
- Virtual: `get_stat_bonus(stat, points)`, `_get_base_value(stat)`, `_get_points(stat)`, `_get_hit_corruption()`, `_keep_missing_amounts(old_values)`.

**PlayerStats**
- Signals: `mana_changed`, `corruption_changed`, `orbs_changed`, `leveled_up(stat, new_level)`.
- Leveling: `get_level()`, `get_stat_level(stat)`, `get_level_up_cost()`, `can_level_up()`, `level_up(stat) -> bool` (only `LEVELABLE_STATS`), `add_orbs(n)`.
- Pools: `spend_mana(n) -> bool`, `restore_mana(n)`, `add_corruption(n)`, `restore_all()`.
- Equipment: `apply_equipment(pieces: Array[ArmorData])`, source `PlayerStats.EQUIPMENT_SOURCE` (`&"equipment"`).

**Other**
- `GlobalPlayerManager.player_stats`, `GlobalPlayerManager.reclaim_player()`.
- `PlayerHud.bind_stats(stats)`.
- `HurtBox.hit_landed(target, hit)`.
- `PotionData.use(user) -> bool` (needs `user.stats`), `ItemData.get_key()`.

## 3. How it works

- **Final value:** `(base + get_stat_bonus(points) + ADD buffs) × MULTIPLY buffs`, never below 0.
  - `recalculate()` always starts from the base values, so nothing compounds.
  - It runs immediately (never deferred).
- **Buff sources:** `add_buffs` stores copies under a source and replaces earlier buffs from the same source. Potions use `get_key()` (the item id); armor uses `&"equipment"`.
- **Max health / mana change:** the missing amount stays the same, and health never drops below 1 from a max change (`_keep_missing_amounts`). Vigor and armor therefore add their bonus to current health and take it back when removed, and equip / unequip never heals.
- **A hit:**
  1. The attack animation turns on the player's HurtBox `monitoring`.
  2. `HurtBox._area_entered` calls `source_stats.create_hit(damage_multiplier, pos)`; crit = `randf() < get_crit_chance()`, × `crit_multiplier`.
  3. `HitBox.take_damage(hit)` emits `Damaged(hit)`, and the owner calls `stats.take_damage(hit)`: `amount × durability_scale / (durability_scale + durability)`.
  4. If `hit.applied`, the HurtBox emits `hit_landed`, and the Player restores `mana_per_hit`.
- **Enemy:**
  - Hits are ignored while `invulnerable` (stun) or dead, so they give no mana.
  - The killing hit gives `orb_reward` once and emits `enemy_destroyed`.
  - The destroy state frees the enemy after the `destroy` animation.
- **Leveling** (API only, no screen yet): cost = `round(2 × level ^ 1.5)` (2, 6, 63 for levels 1, 2, 10). `level_up(stat)` spends orbs and adds one point, and player level = 1 + all points.
- **Corruption:** a positive amount is reduced like damage (by corruption durability), then × `(1 + CORRUPTION_GAIN)`. Negative amounts (Maturation) apply as they are. It is clamped to 0..`max_corruption`.
- **Potions:**
  - `use()` applies the heal, mana and corruption amounts.
  - A potion with `duration_seconds > 0` also adds its buffs.
  - GlobalInventory runs one timer per key (drinking again restarts it) and removes the buffs on timeout.
  - Potion buffs survive death.
- **Placeholder death** (`player.gd` `_die`, deferred from `health_depleted`): `notify_player_died()` → `reclaim_player()` → `restore_all()` → `player_spawned = false` → `reload_current_scene()`. Orbs, points, corruption, armor and potion buffs are kept.

## 4. Where to tune numbers

| What | Where | Now |
|---|---|---|
| Player base stats | `player_stats.tres` → Base stats | health 90, mana 100, damage 10, durability 5, corr. durability 5, luck / faith / disgrace 0 |
| Per level-up point | `player_stats.tres` → Per point | +6 health, +5 mana, +1 damage, +2 durability, +2 corr. durability, +1 luck / faith / disgrace |
| Crit | `player_stats.tres` → Crit; `crit_multiplier` | 0.05 + 0.01 × luck, ×1.5 |
| Mana per landed hit | `mana_per_hit` | 5 |
| Level cost | `level_cost_base`, `level_cost_exponent` | 2.0, 1.5 |
| Damage reduction | `durability_scale` (per Stats resource) | 100 (100 durability halves damage) |
| Max corruption | `max_corruption` | 100 |
| Enemy | `enemy_stats.tres` (or a new EnemyStats per enemy type) | 30 / 8 / 0, 2 orbs, crit 0 |
| Combo multipliers | Player.tscn → StateMachine/Attack → `combo_damage_multipliers` | 1.0, 1.1, 1.4 |
| Per-point growth formula | `PlayerStats.get_stat_bonus()` | linear; the one place for soft caps |
| HUD | `player_hud.gd` `dissapear_time`, `bar_tween_time` | 4.0 s, 0.5 s |

Potions (all max stack 5, placeholder values):

| Potion | File | Effect | Duration | Icon |
|---|---|---|---|---|
| Berserk | `potion.tres` | DAMAGE ×1.25 | 60 s | item_02 |
| Fortune-Teller | `fortune_teller_potion.tres` | LUCK +5 | 60 s | item_12 |
| Turtle | `turtle_potion.tres` | DURABILITY +25 | 60 s | item_34 |
| Vigor | `vigor_potion.tres` | MAX_HEALTH ×1.25 | 60 s | item_26 |
| Saint | `saint_potion.tres` | FAITH +5 | 60 s | item_13 |
| Decay | `decayed_potion.tres` | DISGRACE +5 | 60 s | item_08 |
| Maturation | `maturation_potion.tres` | corruption −10 | instant | item_19 |
| Mana | `mana_potion.tres` | mana +30 | instant | item_27 |

Armor fields map as ADD buffs: health → MAX_HEALTH, damage, durability, corruption_durability, disgrace, corruption_gain, stance, dash_distance_modifier → DASH_DISTANCE, attack_speed_modifier → ATTACK_SPEED.

## 5. Verified

- **TestRunner: 44 / 45.** The only failure is `test_torch_light_casts_shadows_and_keeps_its_look`; see §7.
- **Phase 5 play-through on Floor1, console without errors:**
  1. Berserk (key 1): damage 12.5.
  2. Three hits (30 → 17.5 → 5 → dead): skeleton freed after its animation, orbs +2, mana +5 per hit.
  3. Decayed chestplate through the Loadout page: damage (10 + 6) × 1.25 = 20, durability 8, corruption gain 0.15.
  4. Death with the ↓ key: floor reloaded, player at the spawn (566, 334), health 90 and mana 100. Orbs, the Berserk buff and the chestplate were kept, and the HP orb is full.
- **Checked in earlier phases:**
  - A hit during the stun gives nothing.
  - The debug key does 15 × 100 / 105.
  - HUD orbs at 0 / 1 / 50 / 99 / 100 and at real health 100 % / 52 % / 5 %; the HUD hides after its timer, with no "already connected" errors.
  - Keys 1 / 2 do nothing in the menu.
  - Drinking from the Potions page.
  - The Berserk buff ends after 60 s.
  - Mana Potion 50 → 80.
  - Helmet with Vigor: (90 + 10) × 1.25 = 125.

## 6. Known limits and open items

- **Not built (out of scope):**
  - level-up screen (API only);
  - abilities (nothing spends mana, faith or disgrace yet);
  - corruption visuals, tiers, passive gain and the 100 % death;
  - block, parry and stance;
  - dash and attack speed effects;
  - enemy attacks;
  - floor scaling;
  - save / load;
  - orb pickups in the world;
  - HUD for the selected potion or orbs;
  - real player stats in the Loadout page.
- **Negative armor modifiers become 0.**
  - The PRD rule "never below 0" also applies to ATTACK_SPEED and DASH_DISTANCE, so `attack_speed_modifier −0.05` ends as 0.
  - Before something uses these stats, allow negatives for the equipment-only stats (for example, clamp only in `recalculate()` for stats that can't go below 0).
- **Potion cooldown pauses with the menu.** It's a Timer under GlobalInventory, so after one drink in the menu the next one needs the game running for 3 s.
- **Respawn and physics interpolation.** `PlayerSpawn` sets the position without `player.reset_physics_interpolation()` (see `PlayerCamera_Handoff.md` §5), so after death the player can slide for one tick.
- **Combo hits 2 and 3 often land during the stun,** so 1.1 / 1.4 rarely matter against one enemy. Combo hit 2 was seen in game (multiplier 1.1); hit 3 (1.4) was not, because input timing kept missing the window.
- **Enemy fallback:** `Enemy` without `stats` warns and uses `EnemyStats` defaults (90 health, the base class defaults).
- `PlayerHud.player` is still set by the Player but no longer used by the HUD.

## 7. Torch light test

`test_torch_light.gd` loaded `TorchSmall.tscn`, which was renamed to `Torch.tscn`; the path is fixed. The test now fails on `energy`: it expects 3.5, and `Torch.tscn` has 3.0 after the campfire rework. **The user will check the torch energy; leave the test as it is.**

## 8. MCP notes from this session

- **The `resource_io` and `input_map` groups activate but never appear in this client** (like `tilemap` before). Use the eager project tools instead:
  - `sinres_write` (`file_path`, `script` for a new file, `properties`) creates or updates a `.tres` inside the editor. Values are JSON; a resource is a `res://` path; a new sub-resource is `{script, properties}`; a list replaces a whole array.
  - `sinres_read` shows what the editor sees.
  - `sininput_add_action` (`action`, `physical_keys`, `joy_buttons`, `replace`) saves real InputEvents with `ProjectSettings.save()`.
- **Editor-only resources:** a script without `@tool` can't be instantiated in the editor (`can_instantiate()` is false). The tool creates the base class and calls `set_script()` (a placeholder, as the Inspector does), so `_init()` doesn't run there. Values set only in `_init()` (for example `max_stack = 5`) must be written explicitly.
- **New `class_name` files:** rescan (`extensions_refresh`) after writing a new `class_name` file and before writing the scripts that use it. Otherwise they compile first and fail ("Could not find type").
- `script_check` reports false errors for `PlayerStats` (the inherited `Stat` enum). The game and console are the truth.
- **Hitting the wandering skeleton:** teleport the player to `enemy + (-2, -12)` (facing down) right before each attack key. To test the stun deterministically, call `HurtBox._area_entered(enemy HitBox)` twice in one `execute_code`.
- **`input_simulate` waits:** `delay_after_ms` above about 30 s hits the tool timeout, and its hint then lists old errors as if new. Wait in parts under 30 s.
- **Checking for unsaved scenes before `game_start`:** `execute_code` (editor channel) reading the titles of `EditorSceneTabs`' TabBar; unsaved tabs end with `(*)`.
- **HUD screenshots:** `appear()` sets `visible` only at the end of its tween, so check `visible` before taking a screenshot.
