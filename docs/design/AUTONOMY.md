# Terminal rule blocks

The command desk edits up to 32 blocks with buttons and numeric coordinates,
without entering code. Waypoints run in their displayed order. Conditions
remain standing rules after arrival until the operator stops or interrupts them.

Priority is human escort/manual interruption, ordinary radio failsafe, battery
below 20%, hostile-contact silence, nearby cargo and then waypoint travel.
Exactly 20% does not abort. Low cell returns over the recorded outward route
and requests the normal paid-time loader at its exterior cradle. No remembered
path means a stopped/blocked program; no guessed shortcut through rubble.

A hostile rule requires the hull's operational sonar to receive a fresh,
unoccluded hostile acoustic signature within 30 m. It receives positions,
not creature identities or global threat knowledge. Silence disables active
sonar and limits travel to 35% speed; signatures expire after eight seconds.
Creature emission and trace use this state in M29/M30.

Salvage rules only probe the current 3 m attachment reach and apply existing
hardware/payload constraints. They do not search the entire map. The operator
still has to provide a route. Any blocked segment stops after three seconds.

Normal wireless loss yields to freeze/retrace. M27g explicitly permits
already-transmitted local programs during an EM power window. Editing or
starting a program requires radio. Programs, cursors, mode and obstruction
time persist in version 14. Loading does not replay an old manual command.
