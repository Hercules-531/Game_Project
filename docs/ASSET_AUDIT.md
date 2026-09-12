# Project Outpost asset audit

Audit date: 13 September 2026. Sources: the local Textures/ directory, image dimensions, model metadata, and supplied license text. This is an inventory, not an assertion that every image has been visually approved for the game. The complete file list is in ASSET_INVENTORY.csv; Godot .import sidecars are excluded from that list.

## Selection rule

Use PSX modular house interior pack first. Use another installed pack only for a required asset the PSX pack cannot supply. SBS versus Torment has no user-specified ranking: choose according to the missing surface, after inspecting it. All texture references must resolve to actual files beneath Textures/. No downloaded textures, invented paths, or silent placeholder substitutions.

## Inventory

| Pack | Contents | Available asset families |
| --- | --- | --- |
| PSX modular house interior pack | 131 geometry GLBs, 136 prop GLBs, 546 PNGs, 2 demo OGGs | Modular walls, floors, ceilings, arches, doors, windows, stairs, rails/guards for stairs; domestic furniture, storage, lamps, electrical props, TV, radio, food and clutter |
| SBS - Horror Texture Pack 256x256 | 100 PNGs and License.txt | Brick 14, Floor 14, Metal 14, Misc 15, Stains 15, Stone 14, Wall 14 |
| Torment Textures 1.1 | 99 True Colour PNGs, 97 Quake Palette BMPs, 1 cover PNG, 1 WAD, attribution/license text | Metal floors, general metal, panels, machinery-like surfaces, grates, rotten wood, stone, rubble, wasteland and organic/blood surfaces |

PSX image filename suffixes: 265 albedo, 265 roughness, 12 emission, 1 screenAlbedo, 1 screenRoughness, 1 raw, and 1 checker128. These suffixes describe the inventory; inspect actual model material mappings before assignment. The TV GLB inspected contains embedded albedo/roughness images for both its body and screen, so changing external PNG imports alone will not guarantee compliant GLB materials.

## GDD coverage and gaps

| GDD requirement | Verified candidates | Gap / action before use |
| --- | --- | --- |
| Tactile bunker command area | PSX props/tv.glb, radio.glb, table.glb, chair.glb, lightSwitch.glb, breakerBox.glb, powerSocket.glb | These provide housings and props. No complete command terminal or authored instrument layout. Review layout and build functional screen content. |
| Bunker interior and workshop | PSX geometry/ceilingConcrete.glb, floorStone.glb, wallPlaster.glb; props/cabinet.glb, shelves.glb, pallet.glb, box.glb | No dedicated fabrication rig or sealed industrial airlock. Domestic wood doors are not automatically substitutes for a pressure door. |
| Life support | PSX props/radiator.glb, breakerBox.glb, fridge.glb and food/product props | No dedicated O2 plant, generator, filter assembly, or fuel system identified. |
| Surface ground and ruins | PSX stone/brick modules; fallback Torment True Colour/str_wasteland1.png through str_wasteland6.png, stone/rubble families; SBS stone/metal/wall families | No explicitly identified snow, ice, frozen soil, geothermal vent, acid pool, or toxic-smog texture. Wasteland names alone do not establish the required frozen appearance. Review candidates before selecting. |
| Opening drones and four hull archetypes | Generic metal surfaces available across packs | No dedicated Mule, tracked wedge, Goliath, biped, or hovering scout mesh/texture set. |
| Sockets and modules | Generic metal/electrical surfaces; PSX flashlight.glb is a possible light housing only | No dedicated sonar, IR/CCD module, cell, jumper, winch, drill, torch, tread scraper, turret, shielding, tender, or umbilical asset set. |
| Relays, pylons, substation, FOBs | Generic structural and metal surfaces | No dedicated dish, power pylon, substation apparatus, charging station, or FOB kit. |
| Mutants and nests | Torment has organic/blood textures | No mutant model, skin set, animation, or nest asset identified. Organic textures are not approval to invent the creature design. |
| Human sortie | PSX flashlight.glb exists | No hazard suit, gloves, scratched visor, oxygen/filter assembly, or jumper asset set. |
| Tunnels, rail, defenses | Generic stone/metal/grating textures | Stair rails are not railway tracks. No rail vehicle/track kit, tunnel reinforcement kit, fence, trap, or sentry set identified. |
| Artifacts | None dedicated | Thermal Siphon, Neural Interface Core and Photonic Converter appearances are unspecified and have no identified dedicated assets. |
| Audio | Two PSX demo music OGGs | No identified footsteps, machinery, sonar, UI, weather, mutant or suit sound library. Do not assign demo music as the soundtrack without review. |

Procedural sonar, thermal displays, live camera feeds and UI are game rendering, not missing disk texture paths. Their appearance still needs to follow the GDD. Missing mesh/texture appearances remain a design gate; no placeholder has been introduced by this audit.

## PS1 compliance findings

- PSX PNGs: 137 at 64x64, 399 at 128x128, 10 at 256x256.
- SBS PNGs: all 100 at 256x256.
- Torment images including cover: 166 at 256x256, 16 at 32x256, 12 at 512x512, 2 at 64x64, and the 630x500 cover. Cover art is not a gameplay texture.
- The inspected PSX tv_albedo.png.import enables mipmaps and has no size limit. Audit and configure every texture actually used; do not infer all imports from this sample.
- Planned approach: preserve original files, cap imported gameplay surface textures at 64px (or 32px where approved), disable mipmaps, and apply nearest sampling. Explicit material overrides must also handle images embedded in GLBs.
- Vertex snapping and affine texture interpolation are required. Dithering, chromatic aberration and grain belong in a CompositorEffect, not in edited source images. Fixed internal resolution and nearest enlargement are required; exact resolution is proposed in the plan for approval.

## Supplied license metadata

SBS includes a CC0 notice. Torment permits use/modification and requires attribution for open-source redistribution; preserve its attribution if used. No PSX license document was present in this inventory. No assets have been published or uploaded during this audit.
