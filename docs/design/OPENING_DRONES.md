# Opening fleet — M14

The GDD opening loadout and prototype status establish a blind quadruped hauler
and hovering CCD support machine. The hover chassis is an opening support hull;
it does not replace the four later engineering archetypes. Hull roles come from
socketed modules, not dedicated builder/combat classes.

| Machine | Hull / sockets | Opening equipment |
| --- | --- | --- |
| mule_01 | Light quadruped; two small sensor sockets, tool, utility | Sonar, IR, light winch; utility empty |
| hover_01 | Hover support; small sensor and utility | Monochrome CCD and cargo rack |

Provisional engineering values: Mule 100kg payload, 1kWh cell, 0.08kW hull idle;
hover 40kg payload, 0.8kWh cell, 0.18kW hull idle. Modules consume payload and
add draw. These values are exposed in `resources/drones/opening_fleet.tres`.
Condition travels with an installed part or a removed part, rather than resetting
when moved. Category, socket size, occupied slot and remaining payload are checked
before installation. Battery/surface motion are connected in later checkpoints.

Custom low-poly forms were rendered from front and rear in the review scene before
their first bunker placement: articulated four-foot salvage frame, compact hover
body with paired lift ducts, distinct sonar/IR pods, lens housing, winch and rack.
The metal and sensor/equipment textures reuse these verified PSX house files:

- `Textures/PSX modular house interior pack/geometry/cornerPillarMetal_albedo.png`
- `Textures/PSX modular house interior pack/props/radio_albedo.png`

They import at 64px without mipmaps and use the stable perspective-correct shader.
No external assets or fabricated texture paths were added. The missing dedicated
drone assets noted in the initial audit are addressed by these custom meshes.

Gate C decisions for subsequent sensor/control work: the support CCD is the GDD's
15fps grainy monochrome tier. The first camera discovery equips the otherwise blind
Mule with that tier through scavenged hardware; it is not a free tech unlock. A
Neural Interface Core later improves command response/manual precision; ordinary
piloting still passes through the imperfect radio link. Higher optical tiers remain
separate hardware progression.

Save version 3 persists machine identities, hulls, sockets, condition, cargo mass,
battery and pose. Older saves instantiate the opening fleet. Duplicate identities,
unknown parts, incompatible sockets, invalid condition and excess payload are
rejected before restore. Later fleet checkpoints extend this state together with
their tests.
