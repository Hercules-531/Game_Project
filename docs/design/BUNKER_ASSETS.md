# Bunker PSX art pass

All sources below are inside `Textures/PSX modular house interior pack/`.
Exact resource paths are preloaded in `scripts/bunker/bunker_art.gd`; no fallback
pack or invented texture is used. The live imported GLB materials reference the
supplied external PNGs, and every surface is replaced with our nearest-sampled
PS1 ShaderMaterial. Embedded high-resolution materials are not left active.

| Source relative to that pack | Placement |
| --- | --- |
| geometry/wallPlaster_albedo.png | Warm plaster and muted green lower wall paint |
| geometry/floorStone_albedo.png | Worn concrete/stone floor |
| geometry/ceilingConcrete_albedo.png | Ceiling |
| geometry/cornerPillarMetal_albedo.png | Airlock ribs/latch, skirting, service conduits |
| props/table.glb + props/table_albedo.png | Command desks, workshop bench |
| props/tv.glb + props/tv_albedo.png + props/tv_screenAlbedo.png | Three command CRTs |
| props/radio.glb + props/radio_albedo.png | Command radio and bench instrument housing |
| props/chair.glb + props/chair_albedo.png | Operator chair |
| props/shelves.glb + props/shelves_albedo.png | Workshop storage |
| props/box.glb + props/box_albedo.png | Cargo and spare stock |
| props/pallet.glb + props/pallet_albedo.png | Cargo staging |
| props/cabinetBig.glb + props/cabinetBig_albedo.png | Command and ration storage |
| props/breakerBox.glb + props/breakerBox_albedo.png | Life-support/power housings |
| props/lightSwitch.glb + props/lightSwitch_albedo.png | Room controls |
| props/powerSocket.glb + props/powerSocket_albedo.png | Desk/bench supply points |
| props/radiator.glb + props/radiator_albedo.png | Heating equipment |
| props/ceilingLight.glb + props/ceilingLight_albedo.png | Six room/corridor fixtures |

All 18 active textures are verified at 64×64 with no mipmaps. Source PNG bytes
are preserved; 17 import sidecars change here, with floorStone already set in M07.
The supplied black TV screen is intentionally unpowered until M10 connects
station interaction. No fictional telemetry is painted onto it.

Wall/floor box UV projection tiles in local metres instead of stretching a tiny
texture over whole rooms. The existing measured collision shell is retained.
Furniture has fitted bounding-box collisions; decorative skirting, door detail
and overhead conduits have no extra collision. Room routes remain clear.

Custom meshes in this pass are structural boxes: airlock ribs, crossbars, latch,
paint panels, skirting and service conduits. The rendered airlock and corridor
review is recorded in verification/M09. Dedicated industrial kit remains a gap
for later gameplay milestones; house furniture is not claimed as functional
fabrication or life-support simulation before those systems exist.
