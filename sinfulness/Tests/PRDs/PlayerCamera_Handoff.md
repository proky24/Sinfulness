# Player camera – session handoff (2026-10-20)

Context for the next Claude Code session. The task was `Tests/PRDs/PRD_PlayerCamera.md` (PRD 6): smooth look-ahead, attack zoom and no choppiness. **All four phases are done; the user said it feels good.**

Working rules are the same as in `NewFloor1_Handoff.md` §1:
- phased work, with the report in the chat message;
- no Git;
- re-read files before editing;
- ask first;
- Czech Notion lines in the callout **"Kamera – postup"** at the end of the page "Sinfulness".

## 1. Files

| File | What |
|---|---|
| `Entities/Player/Scripts/camera_2d.gd` | `class_name PlayerCamera extends Camera2D`. Owns all camera motion. The header comment explains the design. |
| `Entities/Player/Scripts/States/state_attack.gd` | Camera parts only: `camera.start_attack(player.cardinal_dir)` in `enter()` after the early-return guard, and a new `_ready()` that connects `AttackComboTimer.timeout → camera.end_attack` once. |
| `Entities/Player/Scripts/States/state_idle.gd`, `state_walk.gd` | The old `update_offset` calls and the `camera` variables are removed. They don't touch the camera any more. |
| `Entities/Player/Player.tscn` → Camera2D | `zoom = 1.8`, `process_callback = 0` (Physics). `limit_smoothed` was removed; it only works with position smoothing, which isn't used. |
| `project.godot` | `physics/common/physics_interpolation = true`. `rendering/2d/snap/*` stays off (the user's choice). |

## 2. How the camera works

- **The camera sets its own targets every physics tick.** It reads `player.direction` and whether `player.state_machine.curr_state is StateAttack`. The states never push offsets.
- **Smoothing:** `value = value.lerp(target, 1 - exp(-sharpness * delta))` for both offset and zoom. No tweens anywhere.
- **Look-ahead:**
  - The target is `player.direction * look_ahead_distance`. It works in 8 directions; diagonals use the normalized vector.
  - Leaning out uses `look_ahead_sharpness`, and coming back uses `return_sharpness`. The camera picks by whether the target is farther from the centre than the current offset, so a reversal glides through the centre.
  - **Return delay:** when input stops, the target is the *current* offset for `return_delay` seconds, then zero. The camera doesn't keep leaning toward the old target, so a quick tap moves it only a few px.
- **Attack:**
  - `start_attack(dir)` sets "combo active" and the lean direction. Calling it again during a combo only updates the direction.
  - `end_attack()` comes from `AttackComboTimer.timeout`.
  - The offset target is the lean (`_attack_dir * attack_lean_distance`) while the state is Attack, or while the combo is active and the player stands still. Otherwise it's the look-ahead, so walking off brings the look-ahead back at once.
  - The zoom target is `attack_zoom` while the combo is active (held through the combo, also when walking off), and `base_zoom` after it.
- **No drift while zooming:** the offset is stored in screen space (`_screen_offset`, px at `base_zoom`) and applied as `offset = _screen_offset * base_zoom / zoom`.
- **Limits:**
  - `GlobalLevelManager.tilemap_bounds_changed → update_limits()` (guard `bounds.size() < 2`).
  - **Godot 4 applies `offset` after the limits**, so the camera clamps the offset itself (`_clamp_to_limits`). It clamps the stored value too, so nothing builds up out of sight at a wall.
- **Interpolation:**
  - With physics interpolation on, Godot 4.7 forces Camera2D into physics mode, and it warns if `process_callback` is Idle. So the callback is Physics, and the smoothing runs in `_physics_process`.
  - Godot interpolates the camera transform, including offset and zoom.
  - A test with the smoothing in `_process` gave uneven zoom steps, which is why it moved.

## 3. Final tuning (exports in the "Tuning" group, read every tick, tunable in the Remote inspector)

| Export | Value | Note |
|---|---|---|
| `base_zoom` | 1.8 | smooth fractional zoom (the user's choice) |
| `attack_zoom` | 2.0 | |
| `look_ahead_distance` | **24.0** | PRD start 16; set by the user in Phase 3 |
| `attack_lean_distance` | **12.0** | PRD start 6; set by the user in Phase 3 |
| `look_ahead_sharpness` | 3.5 | about 95% of the way in 0.85 s (3 ÷ sharpness) |
| `return_sharpness` | 5.5 | ≈ 0.55 s |
| `zoom_in_sharpness` | 12.0 | ≈ 0.25 s |
| `zoom_out_sharpness` | 4.5 | ≈ 0.65 s |
| `return_delay` | 0.25 s | |

## 4. Measured results (144 Hz monitor, 60 physics ticks)

| | Before (Phase 0) | After |
|---|---|---|
| Offset tweens alive | up to 117 (one new per rendered frame) | 0 |
| Diagonal after a turn | 71 back-and-forth reversals in 0.9 s (`cardinal_dir` kept the old direction) | 1 |
| Player drift during attack zoom | 15.4 px | none |
| Drawn camera move per frame, walking | 1.83 px on tick frames vs 0.20 px without (95% variation) | 0.77 vs 0.77 px (8% variation) |
| Camera past the map edge | up to 32 px (old look-ahead) | never |

**How it was measured:**
- A runtime-only logger: a `GDScript` built through `execute_code` by duplicating an autoload's script, setting `source_code`, calling `reload()` and adding the result as a child of `/root`.
- It wrote one CSV row per rendered frame to `user://camlog.csv`.
- With interpolation on, the drawn camera centre is `get_viewport().get_canvas_transform().affine_inverse() * (visible_rect.size / 2)`. The drawn player is the previous and current tick positions blended by `Engine.get_physics_interpolation_fraction()`.
- **Pitfall:** `get_global_transform_interpolated()` exists only in 3D. Calling it froze the game in the debugger.

## 5. Decisions

- **Interpolation:** on, project-wide. Only the Player moves with physics. `enemy.gd` uses `move_and_slide` too, but no enemy is placed yet.
- **Teleports:** no code sets the player's position at runtime yet. A future spawn or level change **must call `player.reset_physics_interpolation()`** after setting the position, or the player slides from the old position for one tick.
- **Pixel snapping:** `snap_2d_transforms_to_pixel` was tested and the user chose **OFF**.
  - It is the only rounding option that works with interpolation. Camera2D has no rounding setting, and rounding in the script wouldn't reach the drawn position.
  - Tile "crawl" stays either way, because zoom 1.8 × stretch 3 = 5.4 screen px per texel. Only a whole-number zoom removes it.
- **Test scene:** `Tests/FloorTest.tscn` (floor `Floors/Level1/Floor1/Floor1.tscn`, whose root node is still called `NewFloor1`, then the Player at (136, 616)).
  - The user removed the extra Player that had been added inside `Floor1.tscn`, and deleted the old Floor1.
  - The floor is the main scene.

## 6. Bugs reported, not fixed (the user said to leave them)

- `GUI/PlayerHUD/player_hud.gd:50`: `inactive()` connects `timer.timeout → dissapear` on every call, which logs "Signal 'timeout' is already connected" on attacks.
- `state_attack.gd`:
  - **Early return:** if `enter()` returns early (`AttackTimer` still running), `exit()` still disconnects signals that were never connected. With the current timings (0.5 s timer, shortest animation 0.567 s) this can't happen.
  - **`attack_combo_timeout()` never runs:** `exit()` always disconnects it first, and `attack_combo = 0` is clamped to 1 anyway.
  - **Dead code:** `hurt_box_timer` and the trailing `await` do nothing.
- `Player.speed = 75` is unused. Walking uses `StateWalk.speed = 100`.

## 7. Open items

- **Screen shake, hit-stop and flashes:** later, driven by the hit/hurt box signals once enemies exist. Add them as an extra offset on top of `_screen_offset` (or a separate shake vector applied after `_clamp_to_limits`, so it isn't clamped). Keep the smoothing and its targets untouched.
- **Quick taps:** an 80 ms tap moves the view about 4 px at sharpness 3.5, probably more now with distance 24. If it ever bothers the user, add a short "start delay" before the look-ahead starts, or lower `look_ahead_sharpness`.
- A future level transition needs `reset_physics_interpolation()` (see §5).

## 8. MCP notes from this session

- `input_simulate` key events need **both** `keycode` and `physical_keycode`, because the input map uses physical keys. Attacks: `{"event_type": "action", "event_data": {"action": "attack", "pressed": true}}`.
- `script_check` flags every `class_name X extends State` script with false "not a node" errors, because its offline copy can't resolve the base class. Verify by running the game and reading `debugger_get_log`.
- **Runtime errors in `execute_code`-built scripts freeze the game in the debugger.** Read them with `debugger_get_log source: "file"` after `game_stop`.
- **Godot warnings at startup** (like the Camera2D override) show up only in `debugger_get_log source: "file"`, not in the buffer.
- In PowerShell analysis scripts, set `[Threading.Thread]::CurrentThread.CurrentCulture = InvariantCulture` (the Czech locale writes decimal commas), and don't name a parameter like a loop variable (`$Out` = `$out`).
