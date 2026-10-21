# M38 — Passenger rail travel

Engineering choices under the user's authorization to resolve checkpoints:

- A 25-scrap / 90 fresh grid-second / 0.6kW retrofit adds a passenger seat and
  a sealed home access passage. It requires the paid freight car and an earned
  excavated route. It creates no surface claim or northern destination.
- A service hatch in the life-support room (E0, S8) opens to a native ladder
  and lined passage at Y=-6 leading to the home platform. Climbing follows a
  continuous 9m approach/descent/exit path at 0.8m/s using human effort, with
  no electrical charging or suit expenditure. E reverses a climb; pause stops
  it. The hatch closes around the shaft when the operator is below it.
  Two access-passage lamps draw 0.04kW total and use fresh grid payment.
  The commissioned volume is included in subsequent excavation quotes, so it
  cannot be charged as rock again. Overlapping jobs wait during commissioning;
  independent field excavation can continue. Saves validate against that same
  paid access baseline.
- The existing car and its finite motor reserve carry either freight or the
  operator. Calls reserve it, finish loaded freight, cancel an empty freight
  approach, and physically approach the requested platform. Boarding is local;
  no remote map teleport. Empty calls can be cancelled to resume freight.
- The seated operator retains first-person mouse look. Movement/gravity are
  locked to the moving car, collision settings are retained, and camera yaw
  follows track turns while preserving the player's look offset. E opens local
  ride controls. Travel costs the same 1.5kW / 2m/s as freight.
  A headlamp facing the travel direction adds 0.05kW only while occupied, with brightness
  credited from the current grid step. It starts dark on reload and goes out
  on an unfunded step or disembarkation.
- Only excavated connected hubs are destinations. Disembarkation requires a
  stopped car and a real clear capsule/ground query at a platform; an occupied
  platform holds the rider. Releasing the seat resumes standing freight rules.
- Underground access/rail never authorizes the surface airlock, equips a suit,
  or spends its O2/filter/jumper. Bunker life support continues normally.
- Save v32 preserves retrofit payment, calling/waiting/riding state, shared
  paid motor reserve, car position, operator camera and climb progress. Older
  saves receive no free retrofit or passenger reservation.

Files: passenger_controller.gd, service_access.gd, passenger_car/platform scenes
and native visuals, passenger_panel.gd, operator_controller.gd, freight_controller
and rail/life/save integration. PSX metal/stone/concrete already verified for
the bunker/rail provide all surfaces; no new raster asset or placeholder path.

Verify paid construction/blackout and migration, actual capsule continuity from
bunker to home, two-hub boarding/travel/disembarkation, freight arbitration,
occupied exits, camera/collision, weather/wireless independence, pause, save in
transit and on ladder, return to bunker and unchanged suit/default-save state.
Review native hatch, seat, platforms and the rider's live camera before commit.
