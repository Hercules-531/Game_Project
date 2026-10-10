# Salvage cargo

The first three supplied PSX box props contain 16 scrap (24 kg), 20 minutes
of fuel (10 kg), and four ration units (8 kg). They are cold sonar landmarks.
These quantities are balance choices, not additional GDD claims.

SALVAGE attaches the nearest available crate within 3 m. A functioning rack
accepts cargo within remaining payload; a winch accepts one load up to 50 kg
times its condition efficiency. Pickup changes carried mass and power use,
never bunker inventory. A carried box follows its hull without a blocking
collider. The sealed airlock loader unloads once into bunker stock.

Version 11 saves each crate's available/carried/delivered state and carrier.
Validation checks carrier existence and total carried mass, including the
first camera case. Loading a save does not award delivery again.
