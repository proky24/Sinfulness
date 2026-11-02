# Graph Report - sinfulness  (2026-11-02)

## Corpus Check
- 41 files · ~77,104 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 2872 file(s) not represented in the graph (top: .import 2304, .gd 194, .uid 193)

## Summary
- 425 nodes · 403 edges · 35 communities (28 shown, 7 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `cc0dc726`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Extensions (supported)
- Multi-Instance / Multiplayer Setup
- mcp-extension-creator/SKILL.md
- godot-mcp-toolkit/SKILL.md
- Advanced Configuration
- Godot Version Compatibility
- PRD: Inventory System for Sinfulness (Godot 4.7.2)
- PRD 4: NewFloor1, a clean tile-only floor (Sinfulness, Godot 4.7.2)
- 3. Requirements
- PRD: Stat System for Sinfulness (Godot 4.7.2)
- 3. Requirements
- PRD 2: Loadout tab stage 2, two-way page flip, last-used tab (Sinfulness, Godot 4.7.2)
- PRD 5: NewFloor1 props, decorating the floor (Sinfulness, Godot 4.7.2)
- NewFloor1 – session handoff (2026-10-15)
- PRD 3: Item pickup fix and pickup message (Sinfulness, Godot 4.7.2)
- Attributions (godot-mcp-toolkit)
- C# extensions
- Per-tool agent-side blocking
- Player camera – session handoff (2026-10-20)
- Stat system – session handoff (2026-10-27)
- Torch light – session handoff (2026-10-21)
- Type wrappers for `node_set_property`
- newfloor1_maps.ps1
- `input_simulate` event reference
- Parallel sessions (multi-agent concurrency)
- Cooperative cancellation
- Exporting your game (extension scripts in builds)
- godot-mcp-toolkit
- type-coercion.md
- CLAUDE.md
- .claude/CLAUDE.md

## God Nodes (most connected - your core abstractions)
1. `Extensions (supported)` - 23 edges
2. `NewFloor1 – session handoff (2026-10-15)` - 13 edges
3. `PRD: Inventory System for Sinfulness (Godot 4.7.2)` - 11 edges
4. `PRD: Stat System for Sinfulness (Godot 4.7.2)` - 11 edges
5. `Attributions (godot-mcp-toolkit)` - 11 edges
6. `C# extensions` - 11 edges
7. `PRD 4: NewFloor1, a clean tile-only floor (Sinfulness, Godot 4.7.2)` - 10 edges
8. `Godot Version Compatibility` - 10 edges
9. `PRD 2: Loadout tab stage 2, two-way page flip, last-used tab (Sinfulness, Godot 4.7.2)` - 9 edges
10. `PRD 5: NewFloor1 props, decorating the floor (Sinfulness, Godot 4.7.2)` - 9 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (35 total, 7 thin omitted)

### Community 0 - "Extensions (supported)"
Cohesion: 0.07
Nodes (28): Concurrency: scene lease and mutation lock, Cooperative cancellation, Discovery rules, Distributable extensions, Error handling contract, Exclusive execution, Exporting games with extensions, Extending the MCP Toolkit (+20 more)

### Community 1 - "Multi-Instance / Multiplayer Setup"
Cohesion: 0.10
Nodes (19): Bundled agent skills, `godot-mcp-toolkit` — the toolkit workflow skill, `mcp-extension-creator` — the extension-authoring skill, Deterministic ports for parallel runs (pinning), GDScript LSP in two editors at once, Multi-Instance / Multiplayer Setup, Pattern A -- Two copies in different directories: SUPPORTED (recommended), Pattern B -- Godot's built-in "Run Multiple Instances": MOSTLY SUPPORTED (+11 more)

### Community 2 - "mcp-extension-creator/SKILL.md"
Cohesion: 0.08
Nodes (23): C# extensions, Cancellation, Common pitfalls, Concurrency, Distributable addon layout, Doc comments (`##` for GDScript), Error handling, Exporting your game (+15 more)

### Community 3 - "godot-mcp-toolkit/SKILL.md"
Cohesion: 0.09
Nodes (22): 10. Parallel sessions, 1. Quick reference, 2. Tool selection, 3. Workflow patterns, 4. Tool availability, 5. Headless mode, 6. Key constraints, 7. Error recovery (+14 more)

### Community 4 - "Advanced Configuration"
Cohesion: 0.09
Nodes (23): Advanced Configuration, An environment variable is not a sync channel, Concurrency, Crash- and concurrency-safety, Editor responsiveness while unfocused, `GODOT_MCP_LSP_HOST` — default: discovered (else `127.0.0.1`), `GODOT_MCP_LSP_PORT` — default: discovered (else `6005`), Language server (LSP) (+15 more)

### Community 5 - "Godot Version Compatibility"
Cohesion: 0.09
Nodes (22): C# (.NET) editor requirement, CI/pipeline usage, Data format notes, Degraded behavior by version, Detection, Disabling the plugin safely, `editor_description` tooltip timer (Godot 4.3 engine issue), EditorFileSystem indexing (all versions) (+14 more)

### Community 6 - "PRD: Inventory System for Sinfulness (Godot 4.7.2)"
Cohesion: 0.11
Nodes (17): 10. Assumptions to confirm, 1. Goal, 2. Project context (verified, do not re-guess), 3. Locked design decisions, 4. Data model, 5. Input, 6. Menu behavior, 7. Phases and acceptance criteria (+9 more)

### Community 7 - "PRD 4: NewFloor1, a clean tile-only floor (Sinfulness, Godot 4.7.2)"
Cohesion: 0.11
Nodes (17): 1. Goal, 2. Diagnosis of the old Floor1 (verified, do not repeat these mistakes), 3. Conventions for the new scene (must follow), 4. Layout requirements (handmade), 5. Camera bounds, 6. Phases and acceptance criteria, 7. Working rules, 8. Notion progress callout (+9 more)

### Community 8 - "3. Requirements"
Cohesion: 0.11
Nodes (17): 1. Goal, 2. Current state (verified), 3.1 The camera owns its motion, 3.2 Look-ahead (walking), 3.3 Attack zoom and lean, 3.4 Smoothness at the base, 3.5 Tuning and code quality, 3. Requirements (+9 more)

### Community 9 - "PRD: Stat System for Sinfulness (Godot 4.7.2)"
Cohesion: 0.11
Nodes (17): 10. Assumptions to confirm, 1. Goal, 2. Project context (verified on 2026-10-27, do not re-guess), 3. Locked design decisions, 4. Data model and API, 5. Integration, 6. Starting values (all exported, tunable), 7. Phases and acceptance criteria (+9 more)

### Community 10 - "3. Requirements"
Cohesion: 0.11
Nodes (17): 1. Goal, 2. Current state (verified), 3.1 Occlusion layer, 3.2 Doorway occluders, 3.3 Wall occluders, 3.4 Torch light settings (`TorchSmall.tscn`), 3.5 Known side effects to check, 3.6 Automated test (+9 more)

### Community 11 - "PRD 2: Loadout tab stage 2, two-way page flip, last-used tab (Sinfulness, Godot 4.7.2)"
Cohesion: 0.13
Nodes (14): 1. Goals, 2. Changes to earlier decisions (supersede PRD 1), 3. Current state (verified, read these files first), 4. Part A: two-way page flip and last-used tab, 5. Part B: Loadout tab, stage 2, 6. Order of work, 7. Working rules, 8. Notion progress callout (+6 more)

### Community 12 - "PRD 5: NewFloor1 props, decorating the floor (Sinfulness, Godot 4.7.2)"
Cohesion: 0.13
Nodes (14): 1. Goal, 2. Current state (verified), 3. Prop scene changes (approved by the user), 4. Prop textures (variants), 5. Placement rules, 6. Density targets (rooms from handoff §4), 7. Phases and acceptance, 8. Working rules (+6 more)

### Community 13 - "NewFloor1 – session handoff (2026-10-15)"
Cohesion: 0.14
Nodes (13): 10. Not possible with the existing tiles (reported to the user), 11. Open items / next steps, 12. Props (PRD 5), 1. How the user wants to work, 2. Files, 3. Layers and draw order (most important design decision), 4. Layout (64 × 48 tiles, 16 px; camera bounds (0, 0)–(1024, 768)), 5. Tile reference (atlas coords `x:y`) (+5 more)

### Community 14 - "PRD 3: Item pickup fix and pickup message (Sinfulness, Godot 4.7.2)"
Cohesion: 0.14
Nodes (13): 1. Goals, 2. Diagnosis (verified by reading the code), 3. Requirements, 4. Order of work, 5. Working rules, 6. Notion progress callout, 7. Assumptions to confirm, Bug 1: the pickup writes to the wrong inventory (+5 more)

### Community 15 - "Attributions (godot-mcp-toolkit)"
Cohesion: 0.17
Nodes (11): AndreaTerenz/WebSocket, Artwork, Attributions (godot-mcp-toolkit), Coding-Solo/godot-mcp, ee0pdt/Godot-MCP, Notes, rayxuln/hastur-operation-plugin, salvo10f/godotiq (+3 more)

### Community 16 - "C# extensions"
Cohesion: 0.17
Nodes (11): C# extensions, Cancellation (C#), Discovery workflow (C# needs a build), Doc comments (`///`), Exporting, Graceful missing-toolkit handling, Headless, Options builder from the registry factory (+3 more)

### Community 17 - "Per-tool agent-side blocking"
Cohesion: 0.20
Nodes (9): Built-in read-only mode, Claude Code, Cursor, General guidance, Google Gemini CLI, High-risk tools, OpenAI Codex / Agents SDK, Per-tool agent-side blocking (+1 more)

### Community 18 - "Player camera – session handoff (2026-10-20)"
Cohesion: 0.20
Nodes (9): 1. Files, 2. How the camera works, 3. Final tuning (exports in the "Tuning" group, read every tick, tunable in the Remote inspector), 4. Measured results (144 Hz monitor, 60 physics ticks), 5. Decisions, 6. Bugs reported, not fixed (the user said to leave them), 7. Open items, 8. MCP notes from this session (+1 more)

### Community 19 - "Stat system – session handoff (2026-10-27)"
Cohesion: 0.20
Nodes (9): 1. Files, 2. Public API, 3. How it works, 4. Where to tune numbers, 5. Verified, 6. Known limits and open items, 7. Torch light test, 8. MCP notes from this session (+1 more)

### Community 20 - "Torch light – session handoff (2026-10-21)"
Cohesion: 0.20
Nodes (9): 1. Files, 2. Occluders (FloorWallTile, occlusion layer 0), 3. Light settings (TorchSmall), 4. Decisions (Phase 0 / Phase 3), 5. Verification, 6. Things found on disk (not changed by this session, reported to the user), 7. Open items, 8. MCP notes from this session (+1 more)

### Community 21 - "Type wrappers for `node_set_property`"
Cohesion: 0.22
Nodes (8): Anchor caveat, Compound property paths, Layer masks, Packed arrays, Resources, Scalar and vector types, Transforms, Type wrappers for `node_set_property`

### Community 22 - "newfloor1_maps.ps1"
Cohesion: 0.31
Nodes (5): C(), FaceK(), IsOpen(), Rows(), Save()

### Community 23 - "`input_simulate` event reference"
Cohesion: 0.25
Nodes (7): Coordinate modes (mouse events), Event shape, Event types, Focus and routing, `input_simulate` event reference, `send_text` return fields, Timing warning

### Community 24 - "Parallel sessions (multi-agent concurrency)"
Cohesion: 0.25
Nodes (7): Best practices, How to tell you are contended, Parallel sessions (multi-agent concurrency), Tab-dependent work (may queue), Tab-independent work (no waiting), The precise routing rule, What happens behind the scenes

### Community 26 - "Cooperative cancellation"
Cohesion: 0.33
Nodes (5): C#, Cooperative cancellation, Enabling it, Observing cancellation, Rules

### Community 27 - "Exporting your game (extension scripts in builds)"
Cohesion: 0.40
Nodes (4): C#, Exporting your game (extension scripts in builds), For a clean strip, The binary-token caveat (Godot 4.3+)

### Community 28 - "godot-mcp-toolkit"
Cohesion: 0.40
Nodes (4): GODOT_MCP_CONFIG_VERSION, cmd, godot-mcp-toolkit, @npgamedev/godot-mcp-server

## Knowledge Gaps
- **3 isolated node(s):** `cmd`, `@npgamedev/godot-mcp-server`, `GODOT_MCP_CONFIG_VERSION`
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 349 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Extending the MCP Toolkit` connect `Extensions (supported)` to `Multi-Instance / Multiplayer Setup`?**
  _High betweenness centrality (0.029) - this node is a cross-community bridge._
- **What connects `cmd`, `@npgamedev/godot-mcp-server`, `GODOT_MCP_CONFIG_VERSION` to the rest of the system?**
  _3 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Extensions (supported)` be split into smaller, more focused modules?**
  _Cohesion score 0.07142857142857142 - nodes in this community are weakly interconnected._
- **Why does `Advanced Configuration` connect `Advanced Configuration` to `Multi-Instance / Multiplayer Setup`?**
  _High betweenness centrality (0.026) - this node is a cross-community bridge._
- **Should `Multi-Instance / Multiplayer Setup` be split into smaller, more focused modules?**
  _Cohesion score 0.09666666666666666 - nodes in this community are weakly interconnected._
- **Should `mcp-extension-creator/SKILL.md` be split into smaller, more focused modules?**
  _Cohesion score 0.08333333333333333 - nodes in this community are weakly interconnected._
- **Should `godot-mcp-toolkit/SKILL.md` be split into smaller, more focused modules?**
  _Cohesion score 0.08695652173913043 - nodes in this community are weakly interconnected._