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

## M11 — Main menu and pause flow

Status: verified; committed separately.

- New Game starts the bunker; Escape pauses/resumes the same simulation.
- Return to menu removes the world and restores menu input.
- Seventeen tests / eighty-two assertions pass; live pause tick check passes.
- [Evidence and menus](verification/M11.md).

Next milestone: M12, versioned save/load and Continue.

## V01 — User-requested texture stability and higher resolution

Status: verified; committed separately before M12.

- Stable perspective UVs and no vertex snapping during normal gameplay.
- 640×480 framebuffer, 1280×960 window, proportionally sized UI, softer post effects.
- Seventeen tests / eighty-two assertions pass; live movement/UI checks and
  headless/rendered Windows export probes pass.
- [Evidence and updated screenshots](verification/V01.md).

Next milestone remains M12, versioned save/load and Continue.

## M12 — Versioned save/load and Continue

Status: verified; committed separately.

- Save/Continue restores pose, elapsed time, control power and airlock state.
- Staged validated writes, last-good backup, explicit recovery/version errors.
- Twenty-two tests / 120 assertions pass; live full-process restart passes.
- Updated Windows export passes its runtime probe.
- [Evidence and restart check](verification/M12.md).

Next milestone: M13a, persistent settings and key rebinding.

## M13a — Persistent settings and key rebinding

Status: verified; committed separately.

- Main/pause settings: three audio buses, mouse sensitivity, physical movement
  and use bindings, duplicate-key swapping, defaults and independent persistence.
- Interaction prompts follow rebinding; Escape capture preserves pause.
- Twenty-six tests / 148 assertions pass; rendered UI inspection and Windows
  export runtime pass. MCP unavailable this session; direct engine checks used.
- [Evidence and menus](verification/M13a.md).

Next milestone: M13b, bunker life-support simulation.

## M13b — Bunker life-support simulation

Status: verified; committed separately.

- Oxygen, cabin heat, fuel, battery and rations run on simulation time; local
  generator/recycler/heater controls affect demand and output.
- Warnings, recovery grace and death with last-save reload, as selected by user.
- Version 2 saves preserve supplies/circuits/countdown; version 1 migration.
- Thirty-four tests / 229 assertions pass. Live MCP panel, recovery, death,
  reload, pause and screenshots pass; Windows release probes pass.
- [Evidence](verification/M13b.md) and [provisional rates](design/LIFE_SUPPORT.md).

Next milestone: M14, opening drone hulls and sockets.

## M14 — Opening drone hulls and sockets

Status: verified; committed and pushed separately.

- Custom PSX-textured light quadruped and hovering support, reviewed before use.
- Two opening machines, typed sockets, payload/draw accounting and part condition.
- Version 3 saves preserve fleet identity/configuration; older saves migrate.
- Thirty-eight tests / 260 assertions, MCP model/workshop and save round trip,
  Windows export/runtime pass. [Evidence](verification/M14.md).

Next milestone: M15, workshop fitting, repair and fabrication.

## M15 — Workshop fitting, repair and fabrication

Status: verified; committed and pushed separately.

- Stock-backed fitting/removal, scrap repair, paid fabrication and clear-bay hull
  assembly; finite fuel/ration transfers into life support.
- Fabrication follows delivered power and persists payment/time in version 4.
- 44 tests / 316 assertions, live MCP mid-job save/Continue and three rendered
  panels, Windows export/runtime pass. [Evidence](verification/M15.md).

Next milestone: M16, southern surface and dead-pylon approach.

## M16 — Southern surface and pylon route

Status: verified; committed and pushed separately.

- Finite frozen strip, dead pylons at 35m spacing, rubble/vent and contested
  substation; custom kit reviewed from drone height before integration.
- 45 tests / 334 assertions pass. Clear route and physical bounds checked.
- Live MCP review and integrated New Game pass. [Evidence](verification/M16.md).

Next milestone: M17, deployment and remote control ownership.

## M17 — Deployment and remote control ownership

Status: verified; committed and pushed separately.

- Timed interlocked loader transfer, local docking, physical steering and selected
  input ownership; version 5 deployment persistence.
- 47 tests / 355 assertions and live MCP drive/desk pass. Operator stays inside.
- [Evidence](verification/M17.md); loader abstraction is explicitly documented.

Next milestone: M18, blind sonar and thermal instruments.

## M18 — Blind sonar and thermal instruments

Status: verified; committed and pushed separately.

- Ping-painted physical echoes and occluded heat-only gradients; no camera on Mule.
- 49 tests / 368 assertions pass. Live MCP returns and rendered display pass.
  [Evidence](verification/M18.md).

Next milestone: M19, degraded CCD and first camera discovery.

## M19 — CCD and first camera discovery

Status: verified; committed and pushed separately.

- Real 15 FPS monochrome optical viewport; recover/deliver/fit an approach CCD.
- Version 6 carried-discovery state; workshop actions require a machine at home.
- 51 tests / 386 assertions, live rendered cadence and recovery/fitting, Windows
  export/runtime pass. [Evidence](verification/M19.md).

Next milestone: M20, drone power and bounded charging.

## M20 — Drone power and bounded charging

Status: verified; committed and pushed separately.

- Field motion/module/cold drain, real stranding and grid-paid home chargers.
- Version 7 charger preference; saved drained/empty cells retain their state.
- 54 tests / 400 assertions and live MCP depletion/charge pass.
  [Evidence](verification/M20.md).

Next milestone: M21, radio distance, occlusion and command delay.

## M21 — Radio distance, occlusion and command delay

Status: verified; committed and pushed separately.

- Seeded/persisted dropouts, physical attenuation, delayed leased commands/actions.
- Cached last telemetry and no fresh sensor image on link loss.
- 56 tests / 413 assertions and live MCP range/desk pass.
  [Evidence](verification/M21.md).

Next milestone: M22, condition wear, efficiencies and malfunctions.

## M22 — Condition wear, efficiency and faults

Status: verified; committed and pushed separately.

- GDD bands affect motors, energy and sensors; distance/load wear, minute-cycle
  seeded faults and scrap service for frame components and installed parts.
- Version 9 persists faults, frame condition and sampling schedule.
- 58 tests / 434 assertions and live MCP speed/jam/repair pass.
  [Evidence](verification/M22.md).

Next milestone: M23, freeze and breadcrumb retrace failsafes.

## M23 — Freeze and breadcrumb retrace

Status: verified; committed and pushed separately.

- Hardware-gated physical retrace over remembered positions, immediate freeze,
  blocked-route stop, manual rearm and version 10 breadcrumb persistence.
- 60 tests / 445 full-suite assertions plus three extended round-trip assertions;
  live MCP obstacle route/cut/return and fresh diagnostic capture pass.
- [Evidence](verification/M23.md).

Next milestone: M24a, salvage cargo and once-only delivery.

## M24a — Salvage cargo

Status: verified; committed and pushed separately.

- Verified PSX boxes, attachment/payload limits, physical hauling and once-only
  bunker delivery; version 11 validates carried ownership and mass.
- 62 tests / 468 assertions; live MCP pickup, drive and dock passed.
- [Evidence](verification/M24a.md).

Next milestone: M24b, hotwire, constrained towing and field stripping.

## M24b — Recovery choices

Status: verified; committed and pushed separately.

- Finite jumper rescue, inherited tracked frame, physical slow/noisy cable tow,
  timed torch stripping, retained landmark and version 12 persistence.
- Full 65-test suite plus extended recovery regressions and live MCP pass.
- [Evidence](verification/M24b.md).

Next milestone: M25, emergency human sortie and escorted recovery.

## M25 — Human recovery

Status: verified; committed and pushed separately.

- Paid analog suit, physical airlock traversal, finite jumper, local collision
  escort, exterior waiting cradle and death/load protection; version 13 state.
- 68 tests / 550 assertions; live door-to-machine-to-bunker route passed.
- [Evidence](verification/M25.md).

Next milestone: M26, terminal rule blocks and local autonomy.
