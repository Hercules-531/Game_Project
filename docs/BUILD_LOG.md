# Project Outpost build log

## M01 — Runnable project and local Git baseline

Status: verified; included in the milestone's local Git commit.

- User approved starting implementation after reviewing IMPLEMENTATION_PLAN.md.
- Fresh project; preserve the existing Godot AI bridge and supplied source assets.
- Main scene hosts an explicitly labeled bootstrap diagnostic with process-frame,
  physics-tick and elapsed-time counters. It does not represent the game's final UI.
- No gameplay textures or substitute asset paths are used in this milestone.
- Live MCP run succeeded twice with the game helper live and no reported run errors.
- Over 0.504 seconds, process frames advanced 3261 to 3382 and physics ticks
  advanced 820 to 851. The displayed values matched the sampled simulation state.
- The inspected game screenshot was fresh (stale_frame=false), 1152x648.
- Stop/restart reset elapsed time to 0.228 seconds with one Main instance.
- Source/assets/addon are included in the initial baseline; .godot caches and local
  outputs are ignored. Origin points to the user's repository; nothing was pushed.
- Project-owned diff whitespace checks pass. The full baseline check reports only
  pre-existing whitespace in the SBS license and two Godot AI addon files, preserved
  without modification.
- Evidence: [verification/M01.md](verification/M01.md).

## M02 — Test tooling and verified export pipeline

Status: verified; included in its own local milestone commit.

- GUT 9.7.1 / Phantom Camera 0.11.0.3 installed and registered in the live editor.
- Passing tests and intentional-failure exit behavior verified.
- Official matching templates downloaded and SHA512 verified.
- Windows export runs its behavior probe successfully, without the MCP helper.
- Reusable PowerShell verification and GitHub export workflow added.
- Runtime screenshot and detailed evidence: [verification/M02.md](verification/M02.md).
- Hosted CI awaits a user push. No push performed.

## M03 — Grounded bunker player movement

Status: verified; committed separately.

- Physical WASD, 2.6 m/s walking, acceleration/deceleration, grounded collision.
- Four GUT tests / thirteen assertions pass, including 30/120 Hz travel agreement.
- Live MCP input reached the wall and stopped without clipping or falling.
- [Evidence and screenshot](verification/M03.md).

## M04 — First-person camera and input capture

Status: verified; committed separately.

- Mouse look, clamped pitch, eye-level camera and shared WALK/TERMINAL/MENU input.
- Six tests / twenty-one assertions pass. Live mouse and Escape events verified.
- [Evidence and screenshot](verification/M04.md).

## M05 — Bunker collision layout and airlock

Status: verified; committed separately.

- Main scene is now the walkable bunker with four functional areas and signage.
- Interlocked sliding airlock doors; outer access requires authorization.
- Ten tests / fifty-three assertions pass, including full-room traversal and
  opening a door while standing against it. Fixed unintended platform carry.
- [Evidence and rendered shell](verification/M05.md).

## M06 — Fixed-resolution presentation

Status: verified; committed separately.

- Fixed 320×240 framebuffer, nearest integer enlargement, centered letterboxing.
- Three actual launch sizes and transformed GUI clicks verified through live MCP.
- Ten tests / fifty-three assertions pass.
- [Evidence and calibration screenshots](verification/M06.md).

## M07 — PS1 surface materials

Status: verified; committed separately.

- Vertex snapping and affine UV mapping applied to all 42 bunker meshes.
- Verified PSX stone texture imports at 64×64 without mipmaps.
- Live toggle comparisons, camera turn and near-plane case captured.
- Ten tests / fifty-three assertions pass.
- [Evidence and comparisons](verification/M07.md).

## M08 — PS1 compositor effects

Status: verified; committed separately.

- GPU compositor provides Bayer dithering, chromatic separation and fine grain.
- Separate effect comparisons and integrated bunker appearance verified.
- Ten tests / fifty-three assertions pass; no live GPU errors.
- [Evidence and comparisons](verification/M08.md).

## M09 — PSX bunker art

Status: verified; committed separately.

- Furnished command, workshop and life-support rooms; textured shell and airlock.
- All 147 world meshes use PS1 materials; all 18 textures are verified PSX 64px.
- Eleven tests / fifty-five assertions pass, including furniture collision.
- Updated Windows export passes headless and rendered startup probes.
- [Evidence and room tour](verification/M09.md).

## M10 — Tactile station interactions

Status: verified; committed separately.

- E-to-use with range/occlusion checks, physical CRT panels and room switches.
- Fixed airlock controls on both sides; occupied aperture blocks closing.
- Fifteen tests / seventy-two assertions pass; live E/Escape/mouse checks pass.
- [Evidence and panels](verification/M10.md).

Next milestone: M11, main menu and pause flow.
