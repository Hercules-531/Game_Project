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

Next milestone: M04, first-person camera and input capture.
