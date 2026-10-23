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

## M26 — Standing rule blocks

Status: verified; committed and pushed separately.

- Editable ordered waypoints, standing battery/silence/load conditions,
  physical return/docking, manual interruption and version 14 programs.
- Fixed loader motor availability exposed by autonomous return.
- Full 72 tests / 577 assertions plus extended five-test checks and live MCP pass.
- [Evidence](verification/M26.md).

Next milestone: M27a, seeded weather state and forecasts.

## M27a — Weather schedule

Status: verified; committed and pushed separately.

- Seeded condition windows and two-window terminal forecast; version 15 schedule.
- Weather transition/partition/save tests and live MCP forecast match passed.
- [Evidence](verification/M27a.md).

Next milestone: M27b, sunlight and real solar charging.

## M27b — Sunlight

Status: verified; committed and pushed separately.

- Optional paid collector, funded grid charging, 75% sunlight bonus and brighter
  exterior environment; version 16 solar construction/switch state.
- Full 76 tests / 602 assertions and live exact 1.75 charge ratio passed.
- [Evidence](verification/M27b.md).

Next milestone: M27c, ion smog radio and optical effects.

## M27c — Ion smog

Status: verified; committed and pushed separately.

- Reduced radio range, delayed commands, exterior fog/static and preserved IR.
- Four weather tests / 34 assertions plus live loss/recovery/restore passed.
- [Evidence](verification/M27c.md).

Next milestone: M27d, abrasive ash and a persistent exposed cache.

## M27d — Abrasive ash

Status: verified; committed and pushed separately.

- Doubled wear/fault probability, real buried cache, physical pickup and v17 migration.
- Full 79 tests / 632 assertions; live exposure/drive/pickup/reload passed.
- [Evidence](verification/M27d.md).

Next milestone: M27e, acid rain and hotspot contamination.

## M27e — Acid rain

Status: verified; committed and pushed separately.

- Seeded external shorts/fouling, armor corrosion, suit filter risk, real hotspot cleaning and v18 persistence.
- Focused weather/power/human suites: 14 tests / 132 assertions; clean live render and saved-state checks.
- [Evidence](verification/M27e.md).

Next milestone: M27f, geothermal cold relief and local vent/ground hazards.

## M27f — Geothermal pockets

Status: verified; committed and pushed separately.

- Spatial cold relief, unstable inner footing, vent damage/jams and v19 exposure.
- Weather/power suites: 12 tests / 102 assertions; live physical entry and exact 1kW relief.
- [Evidence](verification/M27f.md).

Next milestone: M27g, aurora blackout and temporary local scripted power.

## M27g — EM aurora

Status: verified; committed and pushed separately.

- Full wireless blackout, preloaded local operations on ambient supply, no stored free charge, normal constraints restored afterward.
- Full 83 tests / 687 assertions; live zero-cell movement/pickup, reload and event end passed.
- [Evidence](verification/M27g.md).

Next milestone: M28a, tracked fabrication, incline/mud behavior and tread scrapers.

## M28a — Tracked wedge

Status: verified; committed and pushed separately.

- Paid tracked fabrication, collision-checked incline travel, real mud slowdown, scrapers and passive sealing.
- Full 86 tests / 705 assertions; live physical ascent and PSX model review passed.
- [Evidence](verification/M28a.md).

Next milestone: M28b, externally powered Goliath and finite tender convoy.

## M28b — Goliath and tender

Status: verified; committed and pushed separately.

- Finite convoy supply, physical cable obstruction/reach, scripted heavy control,
  portable solar, size-3 tooling and paid exterior gantry unloading; v20 bindings.
- Full 88 tests / 735 assertions plus final focused regressions; live convoy,
  cable break, actual gantry assembly and readable 640px panel passed.
- [Evidence](verification/M28b.md).

Next milestone: M28c, narrow-profile biped mobility and maintenance cost.

## M28c — Biped platform

Status: verified; committed and pushed separately.

- Narrow hull, higher collision-checked step/slope limits, balanced hardpoints,
  paid fabrication and triple joint wear.
- Focused 16 tests / 161 assertions; live radio gap traversal and ledge climb.
- [Evidence](verification/M28c.md).

Next milestone: M29, mutant sensing, patrols and weather responses.

## M29 — Mutant sensing and patrols

Status: verified; committed and pushed separately.

- Reviewed angular organic scout; physical patrol/hunt/shelter/light response,
  acoustic/radio/thermal sensing, structural hull damage, suit flash and intact
  derelict escort recovery. Save v21 preserves threats and emissions.
- Full 96 tests / 804 assertions; final focused mutant/save suites 12 / 96.
- Live pursuit, serious-hit destruction, rain shelter, actual flash interaction,
  breach death and isolated last-save reload passed.
- A live save-path mistake replaced the default slot. User notified; resulting
  files preserved. Runtime path switching fixed and regression-tested. Prior
  slot was not recoverable from the rotated backup.
- [Evidence](verification/M29.md); [tuning choices](design/MUTANT_BEHAVIOR.md).

Next milestone: M30, sector trace and independent nest escalation.

## M30 — Sector trace and independent nests

Status: verified; committed and pushed separately.

- Six persistent sector traces; real shielded radio/vibration/heat inputs;
  independently growing nests, collision-checked recruits and homeward patrols.
- Paid signal shielding; camera-frustum/cover-limited surveys with stale intel;
  nest destruction stops recruitment without deleting surviving patrols. Save v22.
- Full 103 tests / 862 assertions; final focused 14 tests / 124 assertions.
- Live physical patrols, independent clocks, local survey, isolated reload and
  complete 640px panel fit passed. No default-slot writes in this checkpoint.
- [Evidence](verification/M30.md); [tuning choices](design/TRACE_AND_NESTS.md).

Next milestone: M31, research and capability progression.

## M31 — Recovered knowledge and research

Status: verified; committed and pushed separately.

- Physical PSX-book archives, paid grid-driven research, prerequisites and
  recipe gates. Save v23 preserves cargo, queue payment and earned technology;
  older saves retain previously available recipes.
- Full 108 tests / 939 assertions; focused research 5 / 73. Live radio pickup,
  real loader, isolated mid-job save/Continue, completion and menu routes passed.
- No default-slot writes. [Evidence](verification/M31.md).

Next milestone: M32, adjacent northward relays, charging pylons and FOBs.

## M32 — Northward relay, pylon and FOB expansion

Status: verified; committed and pushed separately.

- Adjacent-only parked dish relays; real multi-hop signal loss; paid Goliath
  prefab carriage/construction; finite wired pylon charging and physical heavy
  cables; sheltered depots. Save v24 preserves ground, work, cargo and energy.
- Full 114 tests / 1,029 assertions; final affected 20 / 217. Live construction,
  convoy consumption, isolated reload and upstream failure/recovery passed.
- An actual mutant destroyed the live test's relay Mule: powered pylon recovery
  restored the downstream link. No default-slot writes.
- [Evidence](verification/M32.md); [choices](design/TERRITORY.md).

Next milestone: M33, perimeter defenses and coordinated siege response.

## M33a — Defensive hardware and powered perimeters

Status: verified; committed and pushed separately.

- Socketed sentry/trap/floodlight/decoy hardware; finite paid ammunition and
  trap cargo; sensor-limited delayed fire; paid physical fence prefabs, finite
  power/contact damage, destruction and repair. Save v25 preserves these.
- Full 121 tests / 1,129 assertions; final affected 19 / 244. Live terminal fire,
  pending-order reload, powered construction, blackout, repair/reload and physical
  light avoidance passed. No default-slot writes.
- [Evidence](verification/M33a.md); [choices](design/DEFENSE.md).

Next milestone: M33b, coordinated trace-driven siege response.

## M33b — Coordinated siege response

Status: verified; committed and pushed separately.

- Existing home-known nest packs gather, attack physical barriers, retreat and
  retain independent cooldowns. Light/stun/weather countermeasures still apply.
  Save v26 preserves coordination, grip contact and genuine retreat homes.
- Full 126 tests / 1,169 assertions; final siege 6 / 44. Live powered/unpowered
  comparison, actual crossing, assault reload, rain retreat and cooldown reload
  passed. The existing default save stayed byte-identical.
- [Evidence](verification/M33b.md); [choices](design/DEFENSE.md).

Next milestone: M34, scaling artifact sockets and their nine GDD effects.

## M34 — Universal artifacts and nine scaling effects

Status: verified; committed and pushed separately.

- Physical rare devices, conserved cargo, one universal socket, all small/
  heavy/breaker effects, local thaw, crisp neural feed, direct heavy piloting,
  triple rule evaluation and finite photonic contributions. Save v27.
- Full 133 tests / 1,285 assertions; final affected 24 / 267. Live loader/socket,
  all effect contexts, native frame/rule cadence and isolated reload passed.
- Aurora command holding and floating-point clock regressions were caught and
  fixed. Default save stayed byte-identical.
- [Evidence](verification/M34.md); [choices](design/ARTIFACTS.md).

Next milestone: M35, earned multispectrum optics and classification.

## M35 — Earned multispectrum optics

Status: verified; committed and pushed separately.

- Paid researched optical head, clean 640x480/60Hz source, night processing,
  digital zoom, bounded/occluded class tags, condition/repair and fault behavior.
  Save v28 persists modes without granting absent hardware.
- Full 139 tests / 1,350 assertions. Live paid fabrication/fitting, actual feed,
  night/zoom controls, wall occlusion, fault/link loss and reload passed.
- Tag layout and night-tone compression keep the compact feed readable; controls
  fit 640x480. Default save stayed byte-identical.
- [Evidence](verification/M35.md); [choices](design/ADVANCED_OPTICS.md).

Next milestone: M36, delegated excavation between held surface hubs.

## M36 — Delegated excavation

Status: verified; committed and pushed separately.

- Marked held-hub routes and room footprints, paid volume/time, compatible drill
  reservations, fresh partial supply credits and generated closed geometry.
  Cancellation, loss, parallel work and reload preserve resource accounting.
  Save v29.
- Full 147 tests / 1,455 assertions; final excavation 9 / 119. Live terminal
  assignment, expansion reload, paid tunnel completion, real capsule floor
  contact and joined-passage collision passed. Default save stayed unchanged.
- [Evidence](verification/M36.md); [choices](design/EXCAVATION.md).

Next milestone: M37, automatic underground rail freight between hubs.

## M37a — Rail stations and finite depot power

Status: verified; committed and pushed separately.

- Completed-tunnel tracks, stations and distinct depot stock; paid single-car
  assembly, empty portable-pack fabrication, capped fresh grid charging and
  efficient pack-to-pylon transfer. Save v30 validates global stock identities
  and migrates older tunnels without free cargo or vehicles.
- Full 155 tests / 1,561 assertions; final affected 23 / 278. Live terminal
  construction, real powered progress, blackout, reload, fabrication, charging,
  field transfer and rendered review passed. Default save stayed unchanged.
- [Evidence](verification/M37a.md); [choices](design/RAIL_LOGISTICS.md).

Next milestone: M37b, automatic freight and field-depot services.

## M37b — Automatic freight and field services

Status: verified; committed and pushed separately.

- Rotating minimum-stock rules, physical 200kg car, fresh paid motor reserve,
  source approach and conserved batteries/rations/scrap/spares (plus fuel).
  Full stores hold cargo, loaded disabled rules finish, and returning empty
  packs can recharge. Save v31 retains trips, cargo and depot service settings.
- Founded nearby FOBs accept resource/stripped-part unloading and provide
  local fit/remove/repair stock; optional unload and pack-to-pylon automation.
  Rare discoveries keep their home recovery path.
- Full 168 tests / 1,696 assertions; final freight 13 / 136. Live rule creation,
  physical movement/reload, actual deliveries, local repair/replenishment and
  identity-preserving full/empty pack round trip passed. Default save unchanged.
- [Evidence](verification/M37b.md); [choices](design/RAIL_LOGISTICS.md).

Next milestone: M38, underground passenger boarding, travel and disembarkation.

## M38 — Underground passenger travel

Status: verified; committed and pushed separately.

- Paid passenger retrofit, sealed service hatch/ladder and lined home passage,
  local platform controls, shared-car reservations, finite powered rides and
  safe capsule/ground checks for disembarkation. Save v32 preserves rider,
  climb, camera and shared motor state without granting a surface sortie.
- Paid access volume is excluded from subsequent excavation charges; saved
  job quotes retain the same baseline. Travel-facing 50W lighting and exterior
  environment bounds keep the underground view usable and sealed.
- Full 184 tests / 1,903 assertions; final passenger 16 / 209 and weather
  10 / 107. Live paid retrofit, physical access, both-direction travel,
  climbing/rider reload, disembarkation and actual return to bunker passed.
  Suit values and default save stayed unchanged.
- [Evidence](verification/M38.md); [choices](design/PASSENGER_TRAVEL.md).

Next milestone: M39, infrastructure wear, extra draw and paid maintenance.

## M39 — Infrastructure condition and maintenance

Status: verified; committed and pushed separately.

- Separate rail/conduit condition, actual traffic wear, paid throughput/age,
  shared part bands, jams/shorts, root-priced losses and source breakers.
  Maintenance reserves real torch hulls, consumes source-hub scrap once and
  needs fresh port power. Save v33 retains faults, cycles, RNG and paid jobs.
- Full 199 tests / 2,079 assertions; infrastructure 14 / 161. Live paid hull/
  torch preparation, slowdown, exact energy debit, jam, short/isolation,
  maintenance progress/blackout/reload, repair and retained delivery passed.
- JSON-restored job completion initially exposed a numeric key bug; validation
  preserved the old save, and canonical keys plus completion/reload coverage
  fixed it. Default save stayed byte-identical.
- [Evidence](verification/M39.md); [choices](design/INFRASTRUCTURE.md).

Next milestone: M40, underground trace and forced base entrances.

## M40a — Underground trace and two-seal airlock forcing

Status: verified; committed and pushed separately.

- Paid-work/distance vibration pulses feed the existing emissions, senses and
  trace system. Owned seal condition, paid plating/repair, contact-gated forcing
  and actual two-door ingress use existing organic actors without spawning them
  inside. Save v34 preserves seals, actors' ingress stages, clocks and RNG.
- Full 210 tests / 2,180 assertions. Final breach 11 / 95, drill 10 / 133,
  defense 7 / 95 and life support 8 / 81 passed. Live paid research/plating, real contact, two-stage
  passage, reload, occupied sealing, repair and intrusion death passed. Last
  valid test save and default save were protected.
- [Evidence](verification/M40a.md); [choices](design/BREACHES.md).

Next milestone: M40b, physical rail-mouth and weakened-wall ingress paths.

## M40b — Physical rail-mouth, weakened-lining and hatch ingress

Status: verified; committed and pushed separately.

- Fixed native switchback chases connect only earned segments. Solid slabs,
  clipped ground, real seals, paid lamps and local repair/plating accompany
  persistent actor routing and a swept service-ladder climb. Save v35 keeps
  layouts/routes and migrates old seals and already-paid excavation work.
- Full regression: 219 tests / 2,253 assertions passed. Final ingress and
  legacy-work coverage: 8 tests / 72 assertions passed. Live actors crossed
  each distinct entrance, stopped at real barriers, survived reload, and
  followed the tunnel/ladder through to actual operator death. Default save
  remained byte-identical. Human encounter balance remains a playtest task.
- [Evidence](verification/M40b.md); [choices](design/BREACHES.md).

Next milestone: M41, synthesized operational and threat audio.

## M41 — Synthesized operational and threat audio

Status: verified; committed and pushed separately.

- Native cached PCM supplies spatial machine/rail/impact/footstep/sonar and
  local instrument/suit/weather cues. Hearing follows the operator or linked
  sensor eye with actual distance/cover/link gating. Existing emissions drive
  audible work; no new AI stimulus or recording source is introduced.
- Full 226 tests / 2,413 assertions passed; final audio 7 / 153 and existing
  senses 6 / 51 passed. Native WASAPI capture verified left/right reversal,
  distance/cover attenuation, pause silence and Effects mute at Master.
  Actual moving/silent hulls, fresh sonar/hostile return and a clean restarted
  runtime passed. Default save/settings were protected. Human mix review remains.
- [Evidence](verification/M41.md); [choices](design/AUDIO_PLAN.md).

Next milestone: M42a, restoration checklist and exactly-once ending.

## M42a — Restoration checklist and exactly-once ending

Status: verified; committed and pushed separately.

- Six-band held/nest/perimeter checks and strict residual-density threshold
  feed the physical command checklist. Completion latches once, saves v36,
  pauses into credits and survives Continue without automatic replay. Failed
  saves remain visible/retryable; settings and post-ending operations work.
- Full 233 tests / 2,514 assertions passed; restoration 7 / 101 passed.
  Native final-section failure/completion, settings, resume and reload passed.
  Both checklist/credits fit 640×480. Default save stayed byte-identical.
  Controlled completion does not establish campaign pacing/content readiness.
- [Evidence](verification/M42a.md); [choices](design/RESTORATION.md).

Next milestone: M42b, authored band 01, followed by one commit per band 02–06.

## M42b — Authored band 01: Approach

Status: verified; committed and pushed separately.

- Data-driven authored content adds a drivable approach/nest route, two native
  shelters and finite physical supplies while preserving the opening objectives.
  Save v37 tracks authored-band count for additive, nonduplicating migration.
  Shelter rain clipping and reserved perimeter/ingress clearance are integrated.
- Full 237 tests / 2,596 assertions passed; campaign 4 / 82 and ingress 8 / 72.
  Live starter steering, paid-ammo observed nest clearance, real crate/loader
  delivery, saved rewards/state and native shelter/rain review passed. Default
  save stayed byte-identical. Geometry fixtures do not establish sortie balance.
- [Evidence](verification/M42b.md); [content plan](design/CAMPAIGN_BANDS.md).

Next milestone: M42c, authored band 02: Buffer.

## M42c — Authored band 02: Buffer

Status: verified; committed and pushed separately.

- Second-band route/shelters and richer finite supplies preserve adjacent
  expansion. Generic route margins prevent crate obstruction. Fence planning
  accepts commissioned lining foundations while retaining foreign/gate blocking.
- Campaign 6 / 164, defense 7 / 95, ingress 8 / 72 passed. Native eight-point
  steering, seven paid observed shots, retained nest/rounds/energy and earned
  pad clearance passed with fresh screenshots/logs. Additive migration retains
  earlier delivered rewards. Default save remained unchanged.
- [Evidence](verification/M42c.md); [content plan](design/CAMPAIGN_BANDS.md).

Next milestone: M42d, authored band 03: Substation.

## M42d — Authored band 03: Substation

Status: verified; committed and pushed separately.

- Richer finite supply/shelter content and a ten-point drivable route enter
  the existing substation archive site before approaching its stronger nest.
- Campaign 6 / 250 and research 5 / 73 passed. Native full route, nine paid
  observed shots, retained nest/ammo/energy and separate fresh archive pickup/
  carried reload passed. Pad clearance, three-band additive migration and
  current native logs/screenshots passed. Default save stayed unchanged.
- [Evidence](verification/M42d.md); [content plan](design/CAMPAIGN_BANDS.md).

Next milestone: M42e, authored band 04: Excavation frontier.

## M42e — Authored band 04: Excavation frontier

Status: verified; committed and pushed separately.

- Bulk finite supplies/shelters and an eleven-point route visit the actual
  excavation/neural discoveries before the stronger west nest. Uncollected
  archive cargo is physically bypassed rather than removed by the route.
- Campaign 6 / 343 passed. Native route, eleven paid observed shots, retained
  nest/ammo/energy, fresh book/artifact pickup and rack-vs-winch limits passed.
  Screenshots/logs and default-save hash passed; no campaign pacing claim.
- [Evidence](verification/M42e.md); [content plan](design/CAMPAIGN_BANDS.md).

Next milestone: M42f, authored band 05: Optical frontier.
