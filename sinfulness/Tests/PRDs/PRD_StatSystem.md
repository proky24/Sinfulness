# PRD: Stat System for Sinfulness (Godot 4.7.2)

Owner: Proke. Status: ready for implementation. Language of this document: English. Language of the Notion progress callout: Czech.

## 1. Goal

Replace the tutorial sketch in `res://Entities/StatSystem/Scripts/` with a working stat system for the player and enemies:

- Elden Ring style leveling: the player spends "True energy" orbs to raise one stat they choose; every point raises the player level by 1.
- Damage flows through the existing HurtBox / HitBox nodes, but the numbers come from stats (damage, crits, durability).
- The HUD shows health and mana from the stats instead of keeping its own HP.
- Potions and armor change stats through buffs.

In scope: stat core (player and enemy), damage and crits, mana gained by hitting enemies, orbs from killed enemies and the level-up API, the corruption value and its API, the HP and mana orbs in the HUD, potions (data, drinking, buffs), armor bonuses, a placeholder player death, and the enemy death fix.

Out of scope: the level-up screen (only the API), abilities (faith, disgrace and mana are stored but nothing spends them yet), corruption visuals, tiers, passive gain and the 100 % corruption death, block / parry / stance mechanics, dash, attack-speed effects, enemy attacks and AI, enemy scaling per floor, save / load, orb pickups in the world (orbs go straight to the player), HUD for the selected potion or orb count, real player stats in the Loadout page, stat curves.

## 2. Project context (verified on 2026-10-27, do not re-guess)

- Engine: Godot 4.7.2 stable, GDScript. Project root: `C:\Users\proke\Documents\GitHub\Sinfulness\sinfulness`.
- `res://Entities/StatSystem/Scripts/stats.gd` and `stat_buff.gd` are a sketch from a YouTube tutorial: level is derived from total XP, an `entity_type` enum tries to separate player and enemy, `recalculate_stats()` never resets stats to base (buffs compound on every recalculation), the curve code is commented out, `health` starts at a hardcoded 90. Nothing else in the project uses these scripts yet. Replace them. `res://Entities/StatSystem/Curves/` is empty: leave it.
- Hit detection naming in this project (from the AARPG tutorial): **HurtBox deals damage, HitBox receives it.** Do not rename them.
  - `hurt_box.gd`: `@export var damage: int = 1`; on `area_entered` with a `HitBox` it calls `a.take_damage(damage)`.
  - `hit_box.gd`: `signal Damaged(damage: int)`, `take_damage(damage)` emits it.
  - Layers: Player HitBox layer 2 (PlayerHurt); Player HurtBox mask 256 (Enemy), `monitoring` switched on by tracks in the attack animations; Enemy HitBox layer 256; Enemy HurtBox mask 2 with `monitoring` always false (enemies cannot attack yet).
- `res://Entities/Player/Scripts/player.gd`: `hp` clamped to 10..90 (a workaround for the HUD sprite, see below), empty `take_damage()`, `@onready hit_box` and `hurt_box`. In `_ready()` it sets `PlayerHud.player = self` and calls `PlayerHud.player_damaged()`.
- `res://GUI/PlayerHUD/player_hud.gd` (autoload `PlayerHud`) currently owns the player's HP: it connects to `player.hit_box.Damaged`, subtracts from `HPBar.value`, and reloads the scene at 10 or less. `inactive()` connects `timer.timeout` on every call, so a second call before the timer ends gives "already connected" errors.
- HUD sprite: `Orb_HP.png` and `Orb_MP.png` are 48×48 px but the liquid only fills rows 5 to 42. With `fill_mode` bottom-to-top, values 0–10 and 90–100 draw only transparent rows. This is why the player HP was clamped to 10..90. `HPBar` and `ManaBar` use default min 0 / max 100.
- `res://Entities/Enemies/Parent/Scripts/enemy.gd`: `@export var hp: int = 3`, `_take_damage(int)`, ignores hits while `invulnerable` (set during the stun state), emits `enemy_damaged` / `enemy_destroyed`.
- `enemy_state_destroy.gd`: `_on_animation_finished()` takes no argument, but `AnimationPlayer.animation_finished` sends the animation name, so the call errors and the enemy is never freed. The death push uses `decelerate_speed` instead of `knockback_speed`, points toward the player, and `process()` multiplies by delta so the enemy barely moves.
- `state_attack.gd`: three-hit combo in `attack_combo` (1..3). `state_idle.gd`: debug action `take_dmg` calls `player.hit_box.take_damage(15)`.
- `GlobalPlayerManager.gd` (script autoload, not a scene) creates the Player as its own child in `_ready()`. `level.gd` moves the player into the level with `set_as_parent()`. `player_spawn.gd` only positions the player while `player_spawned` is false. Because the player sits inside the level, `reload_current_scene()` frees the player too, so the current death (HUD reload) breaks `GlobalPlayerManager.player`.
- Autoload order: GlobalLevelManager, PlayerHud, GlobalPlayerManager, PauseMenu, MCPRuntimeServer, GlobalInventory. GlobalInventory becomes ready after GlobalPlayerManager.
- `GlobalInventory.gd`: potion cooldown, one buff Timer per potion keyed by `_get_item_key()` (the item id), re-drinking refreshes the timer (no stacking), signals `potion_used`, `potion_effect_ended`, `equipment_changed`. `set_equipped()` in `_ready()` emits `equipment_changed` directly. No `starting_equipment` is set.
- `potion_data.gd`: `stat_changed` (own enum) and `amount` are placeholders made before the stat system existed. Replace them. Existing potions: `potion.tres` (id `berserk_potion`), `decayed_potion.tres` (wrong data, max_stack 7), `maturation_potion.tres`. Icons: `res://Assets/Potions/items/item_01.png` … `item_20.png`; 02, 08 and 19 are used.
- `armor_data.gd` fields: `health`, `damage`, `durability`, `corruption_durability`, `disgrace`, `corruption_gain`, `stance`, `dash_distance_modifier`, `attack_speed_modifier` (the last three and `corruption_gain` are fractions, 0.05 = 5 %). `loadout_page.gd` reads these field names: keep them.
- Input map has no `use_potion` / `cycle_potion` (planned in `PRD_Inventory_System.md`, never added). `ItemGrid` emits `slot_chosen`, but `ItemsPage` does not connect it, so potions cannot be drunk in game.
- Tests: `res://Tests/TestRunner.tscn` runs every `res://Tests/Scripts/Cases/test_*.gd` (extends `TestCase`: `assert_true`, `assert_false`, `assert_eq`, `assert_not_null`, `get_autoload`, `wait_seconds`). `test_inventory.gd` uses `PotionData.is_instant()` and `duration_seconds`.
- Design source: Notion page "Sinfulness" (page id `379f4675-ea8f-808d-97a9-d3fa80343d85`, Czech). Read "Mechaniky" (stats, leveling, abilities), "Corruption" and "Itemy" before starting.

## 3. Locked design decisions

1. **Leveling (Elden Ring style).** The player owns `orbs` (a currency). Leveling up spends orbs and adds 1 point to one chosen stat. Player level = 1 + total points spent. A stat's shown level = 1 + its points. Level is never derived from orbs.
2. **Level-up cost** = `round(level_cost_base × level ^ level_cost_exponent)` with `level` = current player level, defaults 2.0 and 1.5 (1→2 costs 2, 2→3 costs 6, 10→11 costs 63). Both exported.
3. **Levelable stats (8):** max health, max mana, damage, durability, corruption durability, luck, faith, disgrace. **Equipment-only stats (4):** stance, dash distance, attack speed, corruption gain (base 0, changed only by armor and buffs, nothing uses them yet).
4. **Growth per point is linear** and lives in one function, `get_stat_bonus(stat, points) -> float` (= points × per-point value). No curves. This function is the only place to change if soft caps are added later.
5. **Final stat value** = `(base + get_stat_bonus + sum of ADD buffs) × product of MULTIPLY buffs`, never below 0. Add first, then multiply. Two MULTIPLY buffs multiply together (1.25 × 1.25 = 1.5625).
6. **Buffs have a source** (`StringName`, for example the potion id or `&"equipment"`). Adding buffs with a source replaces all earlier buffs from that source. Removing by source removes them all.
7. **Outgoing damage** = attacker damage × attack multiplier × (crit ? `crit_multiplier` : 1). Combo multipliers for the player's three hits: 1.0, 1.1, 1.4 (exported). `crit_multiplier` = 1.5.
8. **Crit chance (player)** = 0.05 + luck × 0.01, clamped only to 0..1 (no other cap). Enemies have an exported crit chance, default 0.
9. **Incoming damage** = raw × `durability_scale` / (`durability_scale` + durability), `durability_scale` = 100 exported. 100 durability halves damage; damage never reaches 0.
10. **When max health or max mana changes,** the missing amount stays the same: raising max by 20 also adds 20 to current (so Vigor heals by its bonus), lowering max by 20 also removes 20, but a max change never takes health below 1. This keeps equip / unequip from healing the player for free.
11. **Mana:** base 100. Only two ways to refill: landing a hit on an enemy that actually takes damage (`mana_per_hit` = 5, exported) and the Mana Potion. `spend_mana(amount) -> bool` refuses when there is not enough. Starts full.
12. **Corruption:** a value 0..100 in PlayerStats with a `corruption_changed` signal. No progress bar (it will drive the game's visuals later). Positive gain is reduced by corruption durability with the same formula as damage and then multiplied by `(1 + corruption gain)`. Negative amounts (Maturation) are applied as they are.
13. **Player vs enemy:** a shared base class `Stats` and two subclasses. Level, orbs, mana, corruption, luck, faith and disgrace exist only in `PlayerStats`. Enemies can still hold buffs (needed later for floor scaling and bosses). There is no `entity_type` enum.
14. **Player stats live in `GlobalPlayerManager`** (`player_stats`), as one runtime copy of a template `.tres`, like `GlobalInventory` holds the inventory. They survive scene reloads and are ready for a save system. The Player node only reads them.
15. **Each enemy duplicates its stats** in `_ready()`, so enemies sharing one `.tres` do not share a health pool.
16. **Faith and disgrace** are stored and levelable but have no effect until abilities exist (they will scale Purified and Corrupted abilities).
17. **Recalculation is immediate**, never `call_deferred`, so the HUD never reads stale values.

## 4. Data model and API

All scripts in `res://Entities/StatSystem/Scripts/`. Static typing everywhere.

**`HitData extends RefCounted`** (new, `hit_data.gd`): `amount: float`, `is_crit: bool`, `corruption: float`, `source_position: Vector2`, `applied: bool = false` (set to true by the receiver when damage was actually taken).

**`StatBuff extends Resource`** (rewrite `stat_buff.gd`): `@export stat: Stats.Stat`, `@export buff_type: BuffType` (`ADD`, `MULTIPLY`), `@export amount: float` (MULTIPLY 1.25 = +25 %), `source: StringName` (not exported, set by `Stats`). `_init` keeps defaults on every parameter so `.tres` sub-resources load.

**`Stats extends Resource`** (rewrite `stats.gd`, base class):
- `enum Stat { MAX_HEALTH, MAX_MANA, DAMAGE, DURABILITY, CORRUPTION_DURABILITY, LUCK, FAITH, DISGRACE, STANCE, DASH_DISTANCE, ATTACK_SPEED, CORRUPTION_GAIN }`.
- Exports: `base_max_health`, `base_damage`, `base_durability`, `durability_scale = 100.0`, `crit_chance = 0.0`, `crit_multiplier = 1.5`.
- Runtime: `health: float`, internal buff list, internal dictionary of final values per `Stat`.
- Signals: `health_changed(health: float, max_health: float)`, `health_depleted` (emitted once), `damaged(amount: float, is_crit: bool)`, `stats_changed`.
- Methods: `setup()` (compute everything, fill health), `get_stat(stat) -> float`, `add_buffs(buffs: Array[StatBuff], source: StringName)`, `remove_buffs(source)`, `has_buffs(source) -> bool`, `recalculate()`, `create_hit(multiplier: float, source_position: Vector2) -> HitData`, `take_damage(hit: HitData) -> float` (returns damage taken, sets `hit.applied`), `heal(amount)`, `is_dead() -> bool`.
- Virtual hooks the subclasses override: base value and per-point bonus per stat (stats a class does not have return 0), crit chance.
- `add_buffs` stores its own copies, so it never edits a potion's or armor's resources.

**`PlayerStats extends Stats`** (new, `player_stats.gd`):
- Exports: `base_max_mana`, `base_corruption_durability`, `base_luck`, `base_faith`, `base_disgrace`; one per-point value for each of the 8 levelable stats; `base_crit_chance = 0.05`, `crit_chance_per_luck = 0.01`; `mana_per_hit = 5.0`; `level_cost_base = 2.0`, `level_cost_exponent = 1.5`; `max_corruption = 100.0`.
- Runtime: `points: Dictionary[Stat, int]`, `orbs: int`, `mana: float`, `corruption: float`.
- Signals: `mana_changed(mana, max_mana)`, `corruption_changed(corruption, max_corruption)`, `orbs_changed(orbs)`, `leveled_up(stat, new_level)`.
- Methods: `get_stat_bonus(stat, points) -> float`, `get_level() -> int`, `get_stat_level(stat) -> int`, `get_level_up_cost() -> int`, `can_level_up() -> bool`, `level_up(stat) -> bool` (only levelable stats), `add_orbs(amount)`, `spend_mana(amount) -> bool`, `restore_mana(amount)`, `add_corruption(amount)`, `restore_all()` (full health and mana, used by the placeholder death), `apply_equipment(pieces: Array[ArmorData])` (rebuilds the `&"equipment"` ADD buffs).

**`EnemyStats extends Stats`** (new, `enemy_stats.gd`): exports `orb_reward: int = 2`, `corruption_per_hit: float = 0.0` (copied into outgoing hits, for later enemy attacks).

**Order of work:** write `Stats` first, rescan (`extensions_refresh`), then `PlayerStats` and `EnemyStats` (see the Notion lessons: base class and subclasses written at once compiled in the wrong order).

**Data files** (create through the editor or MCP tools, set values in the Inspector):
- `res://Entities/Player/player_stats.tres` (PlayerStats template).
- `res://Entities/Enemies/Parent/enemy_stats.tres` (EnemyStats, test skeleton), assigned to Enemy.tscn.

## 5. Integration

**GlobalPlayerManager**
- Holds `player_stats: PlayerStats`: a `duplicate(true)` of the template, `setup()` called before the Player is created.
- New `reclaim_player()`: moves the player from the level back under GlobalPlayerManager (counterpart of `set_as_parent()`).

**HurtBox / HitBox**
- HurtBox: replace `damage: int` with `@export var damage_multiplier: float = 1.0` and `var source_stats: Stats` (set by the owner in `_ready()`). On hit: `hit = source_stats.create_hit(damage_multiplier, global_position)`, `a.take_damage(hit)`, then if `hit.applied` emit new signal `hit_landed(target: HitBox, hit: HitData)`. Without `source_stats`, push a warning and do nothing.
- HitBox: `signal Damaged(hit: HitData)`, `take_damage(hit: HitData)`.

**Player**
- `stats` returns `GlobalPlayerManager.player_stats`. Remove `hp` and its 10..90 clamp.
- Sets `hurt_box.source_stats`, connects `hit_box.Damaged` (passes the hit to `stats.take_damage`) and `hurt_box.hit_landed` (calls `stats.restore_mana(stats.mana_per_hit)`).
- `state_attack.gd` sets `hurt_box.damage_multiplier` from an exported array `[1.0, 1.1, 1.4]` by `attack_combo`.
- `state_idle.gd` debug `take_dmg`: build a `HitData` with amount 15 and call `player.hit_box.take_damage(hit)`.
- New input `use_potion` (key 1, D-pad down) and `cycle_potion` (key 2, D-pad right), handled by the Player (pausable, so ignored while the menu pauses the tree), calling `GlobalInventory.use_selected_potion()` / `cycle_potion()`.

**Placeholder death** (only until the death state exists): on `health_depleted` the Player, deferred: calls `GlobalInventory.notify_player_died()`, `GlobalPlayerManager.reclaim_player()`, `player_stats.restore_all()`, sets `GlobalPlayerManager.player_spawned = false` so PlayerSpawn places the player again, then `reload_current_scene()`. Orbs, points, corruption and potion buffs are kept.

**Enemy**
- `@export var stats: EnemyStats`; in `_ready()`: `stats = stats.duplicate(true)`, `stats.setup()`, set `hurt_box.source_stats`. Remove `hp`.
- `_take_damage(hit: HitData)`: ignore while `invulnerable` or dead (leave `hit.applied` false); otherwise `stats.take_damage(hit)`; if dead, give `orb_reward` to `GlobalPlayerManager.player_stats` exactly once and emit `enemy_destroyed`, else `enemy_damaged`.
- `enemy_state_destroy.gd`: `_on_animation_finished(_anim_name: StringName)`; the death push uses `knockback_speed` away from the player and slows down with `decelerate_speed` (like the stun state).

**HUD** (`player_hud.gd`, `PlayerHUD.tscn`)
- Orb sprites: `texture_progress` of HPBar and ManaBar becomes an `AtlasTexture` of the same PNG with region (0, 5, 48, 38) and `texture_progress_offset` (0, 5). Value 0 must look empty and 100 full; check with screenshots at 0, 1, 50, 99, 100.
- New `bind_stats(stats: PlayerStats)`, called from the Player instead of `player_damaged()`. HPBar follows `health_changed` (tween to health / max × 100), ManaBar follows `mana_changed`. Remove `update_hp`, the HUD's own HP math and the scene reload.
- On `damaged` the HUD appears and then starts its hide timer (same as after an attack).
- Connect `timer.timeout` to `dissapear` once in `_ready()`; `inactive()` only restarts the timer. No more double connects.

**Potions**
- `PotionData`: remove `Stat` enum, `stat_changed`, `amount`. Add `@export var buffs: Array[StatBuff]` (active for `duration_seconds`), `@export var heal_amount: float`, `@export var mana_amount: float`, `@export var corruption_amount: float` (instant, applied on drink). Keep `duration_seconds`, `is_instant()`, `max_stack = 5`.
- `use(user)`: apply the instant amounts and, when it has buffs and a duration, `add_buffs(buffs, key)` on `user.stats`. Return false when `user` has no stats.
- `GlobalInventory._on_buff_timeout`: `GlobalPlayerManager.player_stats.remove_buffs(key)`. Use one shared key for adding and removing (the existing `_get_item_key()` logic; move it to `ItemData` if both sides need it).
- `ItemsPage`: confirming a potion slot calls `GlobalInventory.use_item()`; the count updates, an empty slot disappears and focus moves to a valid slot.
- Potion data (placeholder values, edit in the Inspector):

| Potion | File (id) | Effect | Duration |
|---|---|---|---|
| Berserk | `potion.tres` (`berserk_potion`) | DAMAGE MULTIPLY 1.25 | 60 s |
| Fortune-Teller | new `fortune_teller_potion.tres` | LUCK ADD 5 | 60 s |
| Turtle | new `turtle_potion.tres` | DURABILITY ADD 25 | 60 s |
| Vigor | new `vigor_potion.tres` | MAX_HEALTH MULTIPLY 1.25 | 60 s |
| Saint | new `saint_potion.tres` | FAITH ADD 5 | 60 s |
| Decay | `decayed_potion.tres` (`decayed_potion`) | DISGRACE ADD 5, max_stack 5, fix description | 60 s |
| Maturation | `maturation_potion.tres` | corruption_amount −10 | instant |
| Mana | new `mana_potion.tres` | mana_amount 30 | instant |

New potions use unused icons from `res://Assets/Potions/items/` (list which in the handoff). Add one of each new potion to `starting_inventory.tres` for testing.

**Armor**
- Whenever equipment changes, including the first `set_equipped()` in `GlobalInventory._ready()`, call `GlobalPlayerManager.player_stats.apply_equipment(...)` with the worn pieces. Field mapping, all ADD: health → MAX_HEALTH, damage → DAMAGE, durability → DURABILITY, corruption_durability → CORRUPTION_DURABILITY, disgrace → DISGRACE, corruption_gain → CORRUPTION_GAIN, stance → STANCE, dash_distance_modifier → DASH_DISTANCE, attack_speed_modifier → ATTACK_SPEED.

## 6. Starting values (all exported, tunable)

| Stat | Base | Per point |
|---|---|---|
| Max health | 90 | +6 |
| Max mana | 100 | +5 |
| Damage | 10 | +1 |
| Durability | 5 | +2 |
| Corruption durability | 5 | +2 |
| Luck | 0 | +1 (= +1 % crit) |
| Faith | 0 | +1 |
| Disgrace | 0 | +1 |

Test skeleton (`enemy_stats.tres`): max health 30, damage 8, durability 0, orb_reward 2, crit chance 0. With 10 player damage it still dies in 3 hits, as now.

## 7. Phases and acceptance criteria

Work in order. After each phase run the game and the TestRunner, read `editor_get_console`, and update the Notion callout. Do not start a phase before the previous one passes.

### Phase 0: Audit
- Read every file in section 2, confirm the facts, run `Tests/TestRunner.tscn` and note the baseline result. Change nothing.
- Acceptance: short report in the reply (what matches, what differs from this PRD). Stop and ask if anything important differs.

### Phase 1: Stat core
- `HitData`, `StatBuff`, `Stats`, then rescan, then `PlayerStats`, `EnemyStats`, both `.tres` files, `GlobalPlayerManager.player_stats`.
- New `Tests/Scripts/Cases/test_stats.gd` covering: setup gives base values and full health and mana; ADD before MULTIPLY; two MULTIPLY buffs multiply; same source replaces, remove by source restores the exact value; recalculating twice changes nothing; level-up spends the right orbs, raises one stat and the level, refuses without enough orbs and for equipment-only stats; level cost 2, 6, 63 for levels 1, 2, 10; durability formula; crit chance from luck and clamp at 1; max health up and down keeps the missing amount and never goes below 1; `health_depleted` fires once; `spend_mana` refuses when short; corruption gain reduced by corruption durability, clamped 0..100; duplicated EnemyStats do not share health.
- Acceptance: all new and old tests pass.

### Phase 2: Damage, enemies, death
- HurtBox / HitBox / HitData flow, Player and Enemy wiring, combo multipliers, mana on hit, orbs on kill, enemy death fix, debug key, placeholder death.
- Acceptance (in game): the skeleton dies in 3 normal hits and is freed after its death animation; orbs increase by 2 once per kill; hits during the stun do not count and give no mana; mana rises by 5 per landed hit; the `take_dmg` key lowers health by 15 × 100 / 105; dying reloads the floor with the player at the spawn, full health and mana, orbs kept, no errors in the console.

### Phase 3: HUD
- Orb sprite fix, `bind_stats`, health and mana bars, appear on damage, single timer connection.
- Acceptance: screenshots at 100 %, about 50 % and near 0 % health match the real values; the HUD appears on damage and hides after its timer; repeated attacks and hits give no "already connected" errors.

### Phase 4: Potions and armor
- PotionData rewrite, potion files, new input actions, drinking from the Potions page, buff removal on timeout, armor bonuses.
- Acceptance: each potion changes the right stat (check with `runtime_get_script_vars` or a log) and its timed buff ends after its duration; re-drinking refreshes without stacking; Vigor heals by its bonus and takes it back at the end without going below 1; Maturation lowers corruption, Mana Potion restores mana; keys 1 and 2 do nothing while the menu is open; equipping and unequipping armor changes stats and does not heal; `test_inventory.gd` and `test_stats.gd` pass (extend the tests for potions and armor).

### Phase 5: Wrap-up
- Full play-through on Floor1: attack, kill, drink, equip, die. Console without errors.
- Write `Tests/PRDs/StatSystem_Handoff.md` (like the earlier handoffs): files changed, public API, where to tune numbers, known limits.

## 8. Working rules for Claude Code

- Code is edited in VS Code (Godot's external editor), and GitHub Copilot may change files while you work: re-read a file right before editing it.
- Write and edit `.gd` files directly. Create and change scenes, nodes and `.tres` resources through the Godot editor or the `godot-mcp-toolkit` tools; a `.tres` changed as text outside the editor gets overwritten by the editor's copy. Do not hand-edit `.tscn` files or UIDs unless a tool cannot do it, and re-open the scene afterwards to check it loads.
- After creating files outside MCP, call `extensions_refresh` (rescan) before running the game, or the UID cache warns about invalid UIDs.
- `script_check` reports false errors for `class_name X extends Y` on one line: verify by running the game and reading the console.
- `execute_code` does not see autoloads or `load()`: put tests in `res://Tests/Scripts/Cases` and run `Tests/TestRunner.tscn`; autoloads via `get_node("/root/Name")`.
- Pass typed arrays to autoload methods (`var x: Array[T] = [...]` first); an untyped literal freezes the game in the debugger.
- Before `game_start`, check for unsaved editor tabs: it saves them.
- Follow the project conventions from the Notion "Project structure" callout: `class_name` in CamelCase, public `update_player_data()`, private `_update_player_data()`, constants in caps, typed variables. Prefer signals over polling; no hard-coded node paths across scenes.
- Do not run any Git command, not even read-only ones (`git diff`, `git status`). The user handles Git.
- Do not change anything outside this PRD's scope. If something outside scope blocks you, stop and ask. If the PRD and Notion disagree, ask the user.

## 9. Notion progress callout

In the Notion page "Sinfulness", create one callout titled "Staty – postup" (distinct icon and color), short and in Czech, like the other "– postup" callouts. Update the same callout, do not add new ones.

- "Hotovo": one line per finished phase.
- "Chyby a poučení": one short line per real mistake (what went wrong and what to do next time).
- Before each phase, read the "Chyby a poučení" lines of every "– postup" callout and do not repeat those mistakes.
- Also add "Mana" to the two Stats lists in the "Mechaniky" callout.

If you do not have Notion access, tell the user and keep the same notes in your replies until it is enabled.

## 10. Assumptions to confirm

- Max health / mana changes keep the missing amount (decision 10). This replaces the earlier idea "when Vigor ends, cut health down to the new max", because that version lets the player heal for free by unequipping and re-equipping armor.
- Turtle adds a flat +25 durability instead of +25 %: durability starts at 5, so a percentage would add almost nothing.
- Potion names, amounts and durations, the Mana Potion name, and all values in section 6 are placeholders for playtesting.
- Combo hits 2 and 3 often land while the enemy is stunned and invulnerable, so the 1.1 / 1.4 multipliers rarely matter against a single enemy. This PRD does not change the stun rules; note it for playtesting.
