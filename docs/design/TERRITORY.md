# Field network — M32 engineering choices

The six existing 100m bands remain fixed. Home holds band 1 (index 0).
Survey/construction pads sit at x=8, z=-125/-225/-325/-425/-525, one in each
subsequent band. Only the immediately next band can be claimed. Claiming requires
a powered, linked high-gain dish scout parked within 6m of its pad; that machine
then supplies the relay, consuming its real cell and a utility socket. Moving,
faulting or losing that scout breaks the link, while the previously earned site
remains recorded. A replacement scout can restore an already earned relay; that
maintenance creates no new territory. A scout cannot anchor two sites. No arbitrary placement bypass.

Relay edges use the existing distance, solid occlusion and weather rules. The
weakest adjacent hop limits downstream quality; no hop skips an offline site.
Aurora still disables wireless control. A dish costs 18 scrap / 45 fabricator
seconds after field-network research, weighs 4kg and draws 0.16kW.

Goliaths with prefab winches load a paid physical structure at the exterior home
gantry, carry its mass to an earned pad, and perform powered, noisy construction:
pylon 600kg / 80 scrap / 180 seconds; FOB 1400kg / 150 scrap / 300 seconds.
Only one prefab per hull; no remote cargo creation. A lost link, moved hull,
faulty tool or absent tender/pylon supply holds construction without refunds.
The carrier is tied up while working. A blocked structure footprint is rejected.
FOBs require a pylon and add a sheltered depot; rails and defenses come later.

Pylons start empty. Their visible northward conduit chain must be intact back to
home before grid charging can request up to 1kW each. Every credited joule comes
from the current grid payment. Each finite 12kWh bank supplies a 0.03kW relay,
nearby cells at 1kW, or heavy hulls on a visible <=6m cable at up to 64kW, 90%
transfer efficiency. Cables break on distance/solid cover; energy is never
transmitted through radio. Tender convoys are still required between pylons.

These are tunable implementation values for the GDD's relay/pylon/FOB mechanics,
not proof of final campaign pacing. All authored meshes use already verified PSX
metal/concrete/stone textures. Rendered mesh review precedes playable acceptance.
