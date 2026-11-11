# Ability system – context for discussion (2026-11-11)

Context for a Claude Code session on another computer. **This is not a finished PRD.** The user wants to discuss the design first. Nothing described in §4 is built yet.

**Rules for that session:**
- Discuss first, and don't change code until the user asks.
- No Git commands at all (not even `git status` or `git diff`); the user handles Git.
- Re-read a file right before editing it.
- Change `.tscn` / `.tres` only through the Godot editor or MCP tools.
- If this file and Notion disagree, ask the user.

Design source: the Notion page "Sinfulness" (id `379f4675-ea8f-808d-97a9-d3fa80343d85`, Czech). Relevant parts: the "Mechaniky" callout (the six abilities), "Corruption", "Scopnosti - postup", "Controls" and the "Todo List". Earlier handoffs with project conventions: `Tests/PRDs/StatSystem_Handoff.md` (stats API, most relevant), `PlayerCamera_Handoff.md`, `NewFloor1_Handoff.md`.

## 1. What exists today

**Input (`project.godot`):**
- `first_ability` = Q, `second_ability` = E, `third_ability` = X, `switch_stance` = R.
- Keyboard only for now. The Notion "Controls" callout plans gamepad buttons (🟥 / ❌ / 🔼 / ⭕).

**`Entities/Player/Scripts/States/state_ability.gd`** (`class_name StateAbility extends State`, node `StateMachine/Ability` in `Player.tscn`):
- `enum Stances {PURRIFIED, CORRUPTED}` and `var stance`, starting as CORRUPTED.
- `var event: String`. It is set by Idle / Walk before entering the state.
- `enter()` plays `event + "_" + str(stance)`, for example `Q_1`, and connects `animation_finished`. When the animation ends, `process()` returns to Idle or Walk.
- `@onready` references to the effect sprites `%Cleanse`, `%GodsSoldier`, `%RageOverflow`, `%MeetTheEnd`, `%TasteYourOwnHate`.
- A comment in `exit()` says "player spend mana"; nothing spends mana yet.

**`state_idle.gd` and `state_walk.gd`** (the same code in both):
- `switch_stance` toggles `ability.stance`.
- Any of the three ability actions sets `ability.event = event.as_text()` and returns the Ability state.

**Animation naming** (renamed from `corrupted_first_ability` and similar), in the Player's AnimationPlayer:
- Letter = slot: Q first, E second, X third.
- Digit = stance: 0 = purified, 1 = corrupted.
- Existing animations: `Q_0`, `Q_1`, `E_1`, `X_0`, `X_1`. **There is no `E_0` (Sunrise).**
- The effect sprites are under `AbilitiesSpriteHolder/Purrified` (Cleanse, GodsSoldier) and `AbilitiesSpriteHolder/Corrupted` (RageOverflow, MeetTheEnd, TasteYourOwnHate).

**Systems the abilities can use** (details in `StatSystem_Handoff.md` §2–3):
- **Player stats:** `GlobalPlayerManager.player_stats` (`PlayerStats`), with:
  - `spend_mana(n) -> bool`, `restore_mana(n)`;
  - `heal(n)`, `add_corruption(n)` (negative values lower it), `corruption`, `max_corruption`;
  - `get_stat(Stats.Stat.FAITH / DISGRACE / DAMAGE ...)`;
  - `add_buffs(buffs: Array[StatBuff], source)` / `remove_buffs(source)`. Adding again with the same source replaces the old buffs.
- **Hits:**
  - `HurtBox.hit_landed(target: HitBox, hit: HitData)` fires when the player's attack actually damaged an enemy.
  - `HitData` has `amount`, `is_crit`, `corruption`, `source_position` and `applied`, but **no reference to the attacker**.
- **Enemy (`Entities/Enemies/Parent/Scripts/enemy.gd`):**
  - `stats: EnemyStats`: a per-enemy copy, with `health_changed` and `is_dead()`.
  - `_take_damage(hit)` ignores hits while `invulnerable` (stun), and the killing hit gives orbs once.
  - States: idle, wander, stun, destroy. **Enemies have no attacks yet, and they are in no group.**
- **Stance (block / parry) does not exist yet,** but `Stats.Stat.STANCE` exists as a value.
- `state_idle.gd` has a commented-out `shoot_radial(origin, count)`: the user's first idea for Sunrise bolts.

## 2. The six abilities (from Notion, translated)

| Slot | Corrupted (1), scales with Disgrace | Purified (0), scales with Faith |
|---|---|---|
| Q | **Rage Overflow**: each successful hit does more damage (like `combo_damage_multipliers` in `state_attack.gd`), but each hit also adds more and more corruption; time-limited. | **Cleanse**: heals part of the health and a small part of the gathered corruption. |
| E | **Meet the End**: marks the nearest enemy; if its health drops below a threshold (for example 5 %), it is killed at once. If the player manages that within 3–5 s (playtesting), the mark moves to the next nearest enemy (max 3 enemies). | **Sunrise**: shoots light around the player and instantly breaks the stance of all enemies. |
| X | **Taste your own Hate**: pressed instead of a parry, the enemy's attack is turned back on it; simplest version: a swoosh animation travels to the enemy and kills it. | **Gods Soldier**: removes all gathered corruption. |

Other notes from Notion:
- **Todo List:** using corrupted abilities adds corruption, which later changes visuals and gameplay.
- **Mana** is for abilities. It refills only by landing hits (+5) and with the Mana Potion.

**The user's own ideas:**
- **Meet the End:** E_1 checks for nearby enemies, picks the closest, plays an animation **on the enemy** (in `Enemy.tscn`), then applies the ability.
- **Sunrise:** needs several bolts, and sprites can't be duplicated in an AnimationPlayer, so Sunrise should be **its own scene** that the code instantiates.

## 3. Problem found: `event.as_text()`

`as_text()` returns the text of the pressed key or button, not the action name. It only works for plain Q / E / X:
- **Gamepad:** gives `"Joypad Button 2 (…)"`.
- **Modifier held:** Shift + Q gives `"Shift+Q"`. Shift is the planned dash key.
- **Rebinding:** a different key gives a different letter.

**Fix discussed:** decide the letter from the action that fired (`first_ability` → `"Q"`, `second_ability` → `"E"`, `third_ability` → `"X"`). The same value can then act as the ability's `slot`.

## 4. Proposed design (discussed, not decided)

**Recommendation:** keep one `StateAbility`, and add a base class `Ability` with one subclass per ability.
- The state lives only while it is active (it exits when the animation ends). Rage Overflow (timed, reacts to hits) and Meet the End (a mark lasting 3–5 s, moving between enemies) must outlive it.
- Keeping all six abilities in `state_ability.gd` would mean one big `match`, with timers and signals that stop when the state exits.

```
Player
└─ StateMachine
   └─ Ability (StateAbility)        ← locks movement, plays the animation, returns to Idle/Walk
      ├─ RageOverflow     (Q, corrupted)
      ├─ MeetTheEnd       (E, corrupted)
      ├─ TasteYourOwnHate (X, corrupted)
      ├─ Cleanse          (Q, purified)
      ├─ Sunrise          (E, purified)
      └─ GodsSoldier      (X, purified)
```

**`Ability extends Node`.** A Node rather than a Resource, because abilities need timers, signals and `get_tree()`.
- **Exports:**
  - `slot` (Q / E / X) and `stance`;
  - `mana_cost` and `cooldown`;
  - `corruption_on_use` (for corrupted abilities).
- **Methods:**
  - `can_use()`: enough mana, not on cooldown, and a target exists for Meet the End;
  - `activate()`: spend mana, start the cooldown, add `corruption_on_use`;
  - `trigger()`: the effect itself;
  - `get_power()`: scaling by Faith (purified) or Disgrace (corrupted), in one place.

**`StateAbility`:**
- picks the child matching `slot` + `stance`;
- calls `can_use()` **before** entering, so the state isn't entered without mana;
- calls `activate()`, plays `<slot>_<stance>` and returns to Idle/Walk when the animation ends.

**Rules:**
- **Spend mana in `activate()`, not in `exit()`.** `exit()` also runs when the state is interrupted.
- **Timing:** a **Call Method track** in each ability animation calls `trigger()` at the impact frame, so the effect matches the visual.
- **Stance toggle:** move it from Idle and Walk into one `StateAbility.toggle_stance()`.

**Per ability:**
- **Rage Overflow:**
  - while active, listen to `player.hurt_box.hit_landed`;
  - on every hit, re-add a bigger DAMAGE MULTIPLY buff under one source (`&"rage_overflow"`, which replaces the previous stack) and call `add_corruption()`;
  - a timer ends it with `remove_buffs(&"rage_overflow")`.
- **Meet the End:**
  - find the nearest enemy in range; this needs an `"enemies"` group or another way to list them;
  - call `enemy.mark()`, which plays the mark animation on a **separate** overlay sprite with its **own** AnimationPlayer in `Enemy.tscn`, so it doesn't fight the enemy's state animations;
  - listen to `enemy.stats.health_changed`;
  - below the threshold (scaled by Disgrace?), execute the enemy through its own damage path, so orbs and the death state still work;
  - if that happened within the window, move the mark to the next nearest enemy, max 3.
- **Taste your own Hate:** blocked until enemy attacks and parry exist. Later: a short window where the next incoming hit is reflected. `HitData` will need a reference to the attacker.
- **Cleanse:** instant. `heal()` a share of max health and `add_corruption(-x)`, scaled by Faith.
- **Sunrise:**
  - instantiate `Sunrise.tscn` at the player;
  - each bolt is its own node (sprite + animation + Area2D), spread like `shoot_radial()`;
  - stance doesn't exist yet, so for now hitting an enemy could call something like `enemy.break_stance()`, which puts it into the stun state.
- **Gods Soldier:** set corruption to 0. This is the simplest one, a good first test of the base class.

**Suggested order:**
1. Base class + `StateAbility` lookup + mana + cooldown, with Gods Soldier and Cleanse.
2. Rage Overflow.
3. Meet the End.
4. Sunrise.
5. Taste your own Hate, after enemy attacks and parry exist.

## 5. Open questions for the user

1. Mana cost and cooldown for each ability. Is there a global cooldown between abilities?
2. **Corruption from corrupted abilities:** a flat amount per use, or only from the effect, for example Rage Overflow per hit?
3. **Faith / Disgrace scaling:** what should they change? Strength (heal %, damage bonus, execute threshold), duration, or cost?
4. **Rage Overflow:** bonus per hit, maximum stacks, duration, and corruption per hit. Does a missed attack end it?
5. **Meet the End:**
   - the search range;
   - what happens if no enemy is near (refuse with no mana spent, or cast anyway);
   - the threshold (5 %?) and window (3–5 s);
   - is the threshold checked only on the player's hits?
6. **Sunrise:** how many bolts, does it also do damage, and what does "break stance" mean until stance exists (stun? for how long?).
7. **Cleanse:** what share of health and corruption it removes.
8. **Can the player move or be interrupted while casting?** Today the state sets velocity to 0 and waits for the animation.
9. **Mid-cast stance switch:** what happens when the player presses R while an ability is active (for example during Rage Overflow)?
10. **The Abilities page in the pause-menu book** (Notion "UI": icon, name, description for 3 + 3): part of this work or later?
11. **The gamepad buttons** from Notion "Controls": add them to the Input Map now?
