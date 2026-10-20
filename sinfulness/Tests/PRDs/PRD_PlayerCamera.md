# PRD 6: Player camera feel, smooth look-ahead and attack zoom (Sinfulness, Godot 4.7.2)

Owner: Proke. Status: ready for implementation. Notion page "Sinfulness" (`379f4675-ea8f-808d-97a9-d3fa80343d85`) has the project conventions.

## 1. Goal

Make the player camera feel responsive and smooth:
- **Look-ahead:** the camera leans a little in the direction the player is moving (8 directions), so the player sees where they are going. Only a little.
- **Attack zoom:** when the player attacks, the camera zooms in on them, leans slightly toward the attack direction, holds through the combo, and eases back when the combo ends.
- **No choppiness:** no stutter, no fighting animations, no jitter from movement and drawing running at different rates.

The user already has a first version in these files. Keep their intent and fix how it is done:
- `res://Entities/Player/Scripts/camera_2d.gd` (`class_name PlayerCamera extends Camera2D`)
- `res://Entities/Player/Scripts/States/state_idle.gd`
- `res://Entities/Player/Scripts/States/state_walk.gd`
- `res://Entities/Player/Scripts/States/state_attack.gd`

### Out of scope
- Screen shake, hit-stop, flashes and other combat effects. They come later, driven by hit/hurt box signals when enemies exist. Do not add a shake API now.
- New player states, movement speed, animations, HUD, enemies.
- Changing the stretch mode, viewport size or base zoom style. The user chose **smooth fractional zoom**.
- The block state, unless it calls the camera (it currently doesn't).

## 2. Current state (verified)

- **Camera2D** is a child of `Player` (CharacterBody2D) in `res://Entities/Player/Player.tscn`: `zoom = (1.8, 1.8)`, `limit_smoothed = true`, no position smoothing, default process callback (idle). Its limits come from `GlobalLevelManager.tilemap_bounds_changed` → `update_limits()`. Keep that, including the `bounds.size() < 2` guard.
- **Player:** `player.gd` reads input in `_process` into `direction` (normalized, 8-way) and calls `move_and_slide()` in `_physics_process` (60 ticks). `set_dir()` updates `cardinal_dir` only on pure horizontal or vertical input, so diagonals keep the previous cardinal direction.
- **State machine:** `state_machine.gd` calls `curr_state.process()` every frame, `physics_process()` every physics tick, and `_handle_input()` on unhandled input.
- **Project:**
  - viewport 640×360, window override 1920×1080;
  - stretch `canvas_items`, aspect `keep`, scale mode `integer`;
  - `rendering/2d/snap/*` off;
  - `physics/common/physics_interpolation = false`, 60 physics ticks per second.

### Causes of the choppiness (diagnosed, fix all)
1. **A new tween every frame.** `StateWalk.process()` calls `camera.update_offset(player.cardinal_dir)` every frame. Each call creates a new 0.8 s `get_tree().create_tween()` on `offset`, and none are killed. Dozens of tweens fight over `offset`, each restarting from the current value. `StateIdle.enter()` adds another one toward zero while the walk tweens are still alive, so the camera stutters on stop.
2. **Hard 4-direction switches.** The offset target only uses `cardinal_dir`. A turn makes the target jump 64 px, and diagonals lean only sideways.
3. **Movement and drawing at different rates.** The body moves at 60 Hz while frames render at the monitor's rate, and physics interpolation is off. On screens faster than 60 Hz this gives uneven steps.
4. **Overlapping zoom tweens.** `StateAttack.enter()` calls `camera.zoom_in()` on every combo hit, and each call creates a new tween from the tree. `zoom_out()` is tied to `AttackComboTimer.timeout`. Also, the zoom happens around the offset camera centre, so the player drifts during the zoom.
5. **Uneven pixels:** zoom 1.8 / 2.0 with snapping off. Accepted by the user (smooth fractional zoom), but reduce the visible effect where it costs nothing (see §3.4).

## 3. Requirements

### 3.1 The camera owns its motion
- `PlayerCamera` updates itself every frame with frame-rate-independent exponential smoothing, e.g. `value = value.lerp(target, 1.0 - exp(-sharpness * delta))`. Use this for both `offset` and `zoom`.
- **No tweens** for offset or zoom. If a tween is used for anything else, create it with `create_tween()` on the camera and kill the previous one first.
- The states no longer push offsets every frame:
  - Remove the `update_offset` calls from Idle and Walk.
  - The camera reads `player.direction` (and whether the player is attacking) itself.
- The attack state talks to the camera through **one small API**, for example `camera.start_attack(dir: Vector2)` on attack enter and `camera.end_attack()` when the combo is over. Choose names that fit the conventions. Calling it again during a combo must not stack anything.
- Remove or replace the old `update_offset`, `reset_offset`, `zoom_in` and `zoom_out`. Grep the project for other callers first, and ask if any exist outside these four files.

### 3.2 Look-ahead (walking)
- Target offset = `player.direction * look_ahead_distance`, in 8 directions. Diagonals use the normalized vector, so the distance stays the same.
  - Start value: `look_ahead_distance = 16.0` px, in world units. It was 32. The user wants "just a little".
- Asymmetric response:
  - leaning out is a bit slower and smooth (e.g. `look_ahead_sharpness ≈ 3–4`);
  - returning toward the centre is a little faster (≈ 5–6).
- **Return delay:** when input stops, wait a short moment (e.g. `return_delay = 0.25` s) before re-centring, so quick taps or short stops don't wobble the view.
- **Short taps:** a single quick tap must not throw the camera visibly. The delay plus the smoothing should handle it. Check it.
- **Reversals:** turning from left to right glides smoothly through the centre, with no jump.
- **Limits:** near the map edge, the look-ahead must not fight the camera limits (no bouncing or snapping at the bounds). Verify at a corner of the map. Keep `limit_smoothed` only if it doesn't cause a visible lag or overshoot with the new smoothing. Decide by testing and document the choice.

### 3.3 Attack zoom and lean
- **On attack start:** the zoom target goes from the base zoom to the attack zoom.
  - Start values: base `1.8`, attack `2.0`, both exported.
  - The zoom-in is quick (`zoom_in_sharpness ≈ 10–14`).
- **Lean:** while attacking, the offset target changes from the walking look-ahead to a **small lean toward the attack direction**: `player.cardinal_dir` at attack start, times `attack_lean_distance` (start at `6.0` px). The lean takes over smoothly from whatever look-ahead was active.
- **Through the combo:** zoom and lean are held for the whole combo. Further hits don't restart, stack or re-trigger anything. If the facing direction changes between combo hits, the lean target may update to the new direction (smoothly).
- **End of combo:** after the combo ends (use the existing `AttackComboTimer` logic or the attack state's exit, whichever matches "combo over" correctly), ease back softly (`zoom_out_sharpness ≈ 4–5`) to the base zoom and normal look-ahead.
  - Also handle the case where the player walks off before the combo timer ends: walking resumes the look-ahead, and the zoom still eases out once the combo is over. Describe the chosen behaviour in your report.
- **Player stays centred:** during the zoom the player must stay where the offset puts them, with no drift from zooming around a different centre.
- Keep the existing attack logic intact: combo counter, hurt box timing, `PlayerHud.appear()` / `inactive()`, and the signal connects and disconnects. Only change the camera parts.
  - If you notice bugs in the signal connect/disconnect handling (e.g. connecting `timeout` on every enter), **report them but don't fix them** unless they break the camera. Ask first.

### 3.4 Smoothness at the base
- **Turn on 2D physics interpolation** (`physics/common/physics_interpolation = true`). This is a project-wide change; the user approved it in principle.
  - Check that the player, the camera and other moving things look right. Godot may need `reset_physics_interpolation()` after teleports such as a level change or spawn. Find and report any place that sets the player's position directly.
  - If the camera then needs a matching process callback (physics vs idle) to stay in step with the interpolated player, choose the right one, test it, and document it.
- Pixel unevenness is accepted. Still try whether `Camera2D` rounding of the final position (or `rendering/2d/snap/snap_2d_transforms_to_pixel`) reduces tile "crawl" during scrolling **without** making the motion stepped. Show the user a before/after comparison and let them choose. Default to the smoother one.

### 3.5 Tuning and code quality
- All tuning values are `@export` in one group at the top of `camera_2d.gd`, typed, with sensible start values (the ones above):
  - `base_zoom`, `attack_zoom`
  - `look_ahead_distance`, `attack_lean_distance`
  - `look_ahead_sharpness`, `return_sharpness`, `zoom_in_sharpness`, `zoom_out_sharpness`
  - `return_delay`
- Follow the Notion "Project structure" conventions: typed variables, public `func update_x()`, private `func _update_x()`, `class_name` in CamelCase.
- Add a short header comment in `camera_2d.gd` that explains how it works: who sets the targets, the smoothing formula, attack handling and interpolation.
- Make the values easy to tune live, e.g. so the user can change exports in the remote inspector while the game runs.

## 4. Phases and acceptance

Stop after each phase, report **in the chat message itself** (not only in the end-of-turn summary), and wait for the user's OK.

### Phase 0: audit (report only, change nothing)
- Re-read the four scripts, `player.gd`, `state_machine.gd`, the Camera2D node in `Player.tscn`, `GlobalLevelManager`, and every caller of the camera functions (grep).
- Confirm the diagnosis in §2 and add anything else you find, e.g. how often `process()` runs relative to physics, or where the player is teleported.
- Measure the current jitter: run `Tests/FloorTest.tscn`, walk with key input (numeric codes W 87, A 65, S 83, D 68), and log the camera's final screen centre (`get_screen_center_position()`) and the player's position per rendered frame for a few seconds. Report the frame-to-frame deltas (spikes and reversals). This gives the "before" numbers.
- Report the plan for §3 and any questions.

### Phase 1: camera rewrite
- Implement §3.1 to §3.3 and §3.5. Update the three states to the new API.
- **Acceptance:**
  - no tweens on offset or zoom;
  - no per-frame camera calls from the states;
  - the scripts check clean (`script_check`);
  - the game runs with no errors or warnings in `debugger_get_log`.
  - The same per-frame log as Phase 0 shows smooth, non-reversing offset changes while walking straight, smooth reversal, no jump on stop, and no zoom stacking during a 3-hit combo.
  - Short screenshot sequences (or a few frames at key moments) of walking, stopping, turning and the attack combo.

### Phase 2: base smoothness
- Implement §3.4: turn on physics interpolation and test the camera process callback and the pixel rounding options.
- **Acceptance:**
  - before/after per-frame logs and screenshots;
  - the user picks the rounding option;
  - nothing else in the project visibly breaks (walk through `Tests/FloorTest.tscn`, open the old `Floor1` if it is used anywhere);
  - no console errors.

### Phase 3: tuning with the user
- Give the user a short list of what each export does and suggested ranges. Adjust values from their feedback. The user plays and reports.
- **Acceptance:** the user says it feels good.

## 5. Working rules

- The user edits in VS Code with Copilot active. **Re-read every file right before editing it.**
- **No Git commands at all**, not even read-only ones.
- Ask instead of guessing. If the PRD disagrees with the code, ask.
- Don't change anything outside this PRD's scope (§1).
- Test through `res://Tests/FloorTest.tscn`. Don't add a Player to floor scenes. Check that `FloorTest` still has NewFloor1 before the Player, so the bounds are set before the camera's `_ready`.
- Use the godot-mcp-toolkit tools: `game_start`/`game_stop`, `input_simulate`, `runtime_screenshot`, `runtime_get_script_vars`, `debugger_get_log`. See `Tests/PRDs/NewFloor1_Handoff.md` §7 for tool pitfalls (eager vs group tools, `execute_code` is one expression only, numeric key codes, imprecise hold durations).
- Notion: in the page "Sinfulness", add a short Czech callout **"Kamera – postup"** (or update an existing one):
  - one line per finished phase under *Hotovo*;
  - one line per real mistake under *Chyby a poučení*;
  - read the existing mistake lines in the other callouts first. No long text, no code.
- At the end, write a short handoff `Tests/PRDs/PlayerCamera_Handoff.md`: how the camera works, the final tuning values, the interpolation and rounding decisions, and the open items (screen shake and hit-stop later via hit/hurt box signals).
