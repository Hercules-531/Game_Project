# M33 defense engineering choices

M33a implements hardware and physical perimeter response. M33b coordinates
existing mutant packs into forming/attacking/retreat phases. Both are separate
verified commits. Underground ingress probabilities remain M40.

Field-network research leads to the recovered perimeter-defense archive.
Research permits a sentry tool (16kg, 0.18kW, 30 scrap/90s), trap-laying utility
(8kg, 0.04kW, 18 scrap/60s), floodlight utility (12kg, 0.2kW, 12 scrap/45s),
and noise-decoy utility (6kg, 0.03kW, 10 scrap/30s). These are socketed modules,
not predefined combat/builder hull roles. No sensors are included for free.

Sentries consume one of at most 60 carried rounds and 0.002kWh per shot; 20
rounds cost 10 scrap at the home workshop/gantry and weigh 0.4kg. Effective
range 35m, 40 damage scaled by module condition, cooldown 2s. The radio command
waits its real link latency and revalidates power, link, current observation,
solid line of fire and ammunition before spending. Contacts stay anonymous with
rudimentary sensors; the terminal does not list unseen actors or reveal health.

Trap-layers load up to eight 1kg traps at home, 6 scrap each. Laying one costs
one carried trap and requires held ground and a clear local footprint. A spring
trap triggers once on an actual mutant within 1.8m and clear reach, dealing 120
damage. No unlimited mine generation or automatic area damage through walls.

Floodlights illuminate the actual scene and repel the existing light-sensitive
mutants while powered. Silent running switches them off. A toggled decoy sends
100m acoustic pulses every two seconds, drawing its fitted module's real power.
It still leaves trace and requires a living powered machine.

A perimeter is an 800kg Goliath prefab, 60 scrap, 240 powered seconds; requires
defense plus heavy engineering. Five collidable 200-integrity fence sections
surround a 20m by 16m site, with a 4.5m southern gate opening. Home is centered
at N22; field pads retain their established centers. Footprint obstruction holds
construction. Energizing home fences adds 2kW to fresh grid demand; field fences
draw 2kW from their finite pylon bank. Paid fence contact deals 40 damage/second
scaled by actual supply. No electricity gives no contact damage. Physical mutant
strikes wear sections; destroyed sections cease blocking. A nearby linked
Goliath/prefab winch can repair damage for 0.1 scrap per integrity (rounded up).

These values are tunable, not final balance or a human pacing verdict. Meshes
reuse the verified PSX metal/stone textures. Native geometry is reviewed in a
render before playable acceptance; no external bitmap or sound assets are added.
