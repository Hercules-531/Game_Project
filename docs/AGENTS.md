# AGENTS.md — Operating Instructions for Astra

## Project
- Engine: Godot 4.7+ (GDScript primary; C# only where GDScript is a real bottleneck) —
  matches the installed version and is also hi-godot/godot-ai's minimum
- Design reference: docs/GDD.md — read this in full before planning any feature
- This file = technical/operating rules. docs/GDD.md = creative content. Keep them separate.

## What's on you vs. what's on Astra
Astra can clone repos, edit files, run headless Godot, and commit. It cannot:
click GUI buttons, restart its own Codex host session, or make creative calls.
Concretely, these are yours:
- Installing Godot, Node.js/uv, and export templates locally
- Registering the MCP server with Codex (`codex mcp add ...` or the in-editor
  "Configure" button) and restarting Codex afterward
- Opening the Godot editor once to confirm the MCP bridge actually connects
- Picking ONE art style block below and deleting the other
- Pushing to GitHub, reviewing diffs, and merging
- Playtesting every few milestones — Astra can confirm "it runs," not "it's fun"

## Bootstrap (Astra's first task, run once)
Clone and wire up tooling before touching gameplay code. Do this yourself —
don't wait for the user to do it manually.

1. **Godot MCP** (live editor control, screenshots, in-editor testing) — pick one:

   **Option A — hi-godot/godot-ai** (more tools, has a client auto-configure dock):
   - Requires Godot 4.7+ within the 4.x line, and `uv` for the Python server.
   - Install from the release package at github.com/hi-godot/godot-ai/releases
     (not the source zip) into `addons/godot_ai/`.
   - Enable: Project Settings → Plugins → Godot AI (or add to project.godot's
     `[editor_plugins]`).
   - The user opens the Godot AI dock and clicks "Configure" next to Codex,
     then restarts Codex — you (Astra) can't do this part.

   **Option B — mkdevkit/godot-mcp** (lighter, no `uv` dependency):
   ```
   git clone https://github.com/mkdevkit/godot-mcp /tmp/godot-mcp
   cp -r /tmp/godot-mcp/addons/godot_mcp ./addons/
   cd /tmp/godot-mcp/server && npm install && npm run build
   ```
   Enable it: Project Settings → Plugins → Godot MCP → Enable
   (or add it directly to project.godot's `[editor_plugins]` list).
   After building, report the absolute path to `server/build/index.js` so
   the user can run `codex mcp add godot-mcp -- node <that path>` and
   restart Codex.

2. **Gameplay addons** — clone each into `addons/<name>/`, enable in project.godot:
   - Dialogic (dialogue/narrative) — if the GDD has story/dialogue beats
   - Phantom Camera (cinematic camera rigs)
   - Godot Jolt (physics) — only if pursuing the HL2-style physics route
   - GodotSteam — only once close to a shippable build

3. **GUT** (GDScript unit testing) — clone into `addons/gut/`, enable it.

## Art style — pick ONE block, delete the other
### Option A: PS1 / analog-horror (Mouthwashing-inspired)
Current user override (22 September 2026): use stable perspective-correct UVs,
disable vertex snapping during normal gameplay, and render at 640×480 with
softer post effects. The user reported swimming textures and excessive pixelation.
This override takes precedence over the original snapping/affine requirements below;
the legacy distortion switches remain diagnostic options only.

- Vertex snapping + affine texture warping (no perspective correction)
- Render internally at a low fixed resolution, upscale with nearest-neighbor
- Textures: 32–64px, no mipmaps, no filtering
- Post-processing (dithering, chromatic aberration, grain) as a CompositorEffect —
  never baked into the textures themselves

### Option B: HL2-style grounded realism
- Real PBR materials (albedo/normal/roughness) — see Textures/README.md
- Godot Jolt for physics interactions; SDFGI or baked lightmaps for lighting
- Linear + anisotropic filtering on

## Assets
- Textures live in `Textures/` at the project root — always use the exact
  files there. Never invent a placeholder path.
- If going PBR (Option B), maintain `Textures/README.md` listing which map
  (albedo/normal/roughness/etc.) each file provides — don't guess from filenames.

## Workflow
1. Read docs/GDD.md and this file fully before planning anything.
2. Write an implementation plan broken into small milestones. Share it before
   implementing; if a step is unambiguous, start it but flag your assumption.
3. One milestone at a time. After each: use the Godot MCP tools
   (`play_scene` + `get_game_screenshot`, or a headless run) to confirm it
   actually works before moving to the next milestone.
4. Commit to git with a clear message after each working milestone.
5. If the GDD is ambiguous on something that meaningfully changes gameplay
   or look, ask — don't guess.

## Boring-but-essential systems (build as real milestones, not "later")
- Save/load
- Pause menu
- Settings menu (volume, key rebinding)
- Main menu wired into the actual game flow

## Testing & CI
- Use GUT for gameplay logic tests.
- Add a GitHub Action that exports the project on every push (needs matching
  export templates available to the CI runner).
