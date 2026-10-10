# Drone energy

M20 provisional rates: cells retain hull capacities (Mule 1kWh, support 0.8kWh).
Field idle/module draw is joined by 1.2kW cold drain and throttle-proportional
travel draw (2.5kW Mule / 3.5kW hover), raised by cargo fraction. Rates live in
drone_power.tres. Depletion clamps at zero, stops the actual collision body and
disables new sensor frames/pings. A stranded machine remains at its position.

Home chargers request up to 2kW per machine and only the energy needed to reach
capacity. Delivered charge is issued by the same one-second grid step that paid
for it, using its fresh delivered fraction. A previous frame's supply fraction
cannot create energy in blackout. Requests exclude field/transferring machines;
the home-charging switch persists in version 7. Cells/stranding remain fleet state.
Weather/pylons/convoy sources integrate later; no free field charger exists yet.
