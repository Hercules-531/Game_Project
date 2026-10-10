# M29 — isolated mutant scout

The GDD specifies largely blind, light-sensitive organic mutants guided by vibration, radio and heat. Under the user's instruction to continue every checkpoint without further approval, the following are explicit engineering assumptions, subject to playtest tuning.

- One isolated scout starts at E42 / N102 (world 42, -112), away from the first salvage line. A small rock overhang at E43 / N104 provides physical rain shelter. Packs and nest clocks follow in M30.
- The custom creature has an angular, eyeless head, hunched torso and four long jointed limbs. It uses only `Textures/PSX modular house interior pack/geometry/floorStone_albedo.png`, tinted brown-grey. There is no dedicated skin texture in the supplied packs. Rendered self-review precedes enabling its controller.
- Moving vibration reaches Mule 8m, hover 14m, tracked 35m, tender 30m, biped 20m, Goliath 240m. Work noise adds 20m per unit. Silent movement reduces vibration to 25%; a sonar ping remains a deliberate 60m acoustic pulse. Powered linked machines transmit a 40m heartbeat every two seconds. Heat reaches 12m, scaled by actual draw, capped at 45m. Static warm landmarks also attract investigation.
- Smog halves all sensory reaches. Solid cover reduces acoustic/radio reach to 35%, and blocks heat/contrast. Close visual contrast reaches only 8m (12m in crisp sunlight). No AI target is exposed as an identified object on Tier 0 feeds.
- Patrol speed 1.1m/s; hunt 2.2m/s; last detected location persists for 16 seconds. Targets are sensed again rather than tracked through walls. Rain sends patrols under actual shelter unless a stimulus is within 5m. Floodlights repel within 12m; emergency flashes stun for three seconds.
- A serious strike deals 45 structural damage every two seconds within 1.8m and clear reach. Hull integrity: Mule 30, hover 50, tracked 120, tender 150, biped 100, Goliath 500. Structural damage is separate from 0–100 part condition. A destroyed frame cannot be jump-started; modules and attached cargo remain on its persistent corpse. No inventory is credited by destruction.
- The emergency suit has a short flash using 0.025kWh from its jumper, with a 10-second cooldown and 2m line-of-sight interaction reach. It buys escape time; a mutant strike breaches the suit and invokes the existing last-save death flow. Dormant intact derelicts remain recoverable when the original fleet is destroyed.
- Patrol position, investigation memory, attack/flash cooldowns, structural damage and pending emission pulses persist. Older saves migrate to intact hulls and the initial scout.

These constants do not establish fun, horror readability or the ~40-hour campaign target; those require human playtesting.
