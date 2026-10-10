# Save format and flow

Current format: version 13 adds suit supplies, failure and escort state.
Version 12 adds derelict decisions, physical bodies, tow owner,
cutting timer and component cargo. Version 11 adds salvage ownership and carried-mass checks.
Version 10 adds breadcrumb routes/retrace cursor; version 9 adds frame wear,
faults and sampling schedule; version 8 adds radio dropout schedule and RNG.
Version 7 adds the home-charging switch. Version 6 adds the
camera discovery/carrier, version 5 deployment state. Earlier versions migrate
with untouched discovery and enabled home charging.

Version 4 adds inventory stock and a paid fabrication queue with
remaining time. Versions 1–3 migrate with opening stock and no active job.

Version 3 adds fleet identity, hulls, modules, condition, cargo,
battery and pose. Version 1/2 saves migrate with the opening fleet. Duplicate
identities and incompatible module/payload state are rejected before restore.

Version 2 stores operator position/yaw/pitch, elapsed simulation time, local
panel/light power states, the interlocked airlock's settled state and life support
(supplies, temperature, circuit toggles, delivered-power fraction, grace timer and
fractional integration time). Version 1 saves migrate with the opening life-support
supplies because that version predates the system. Subsequent writes use version 2.
Future
systems must extend capture/validation/restore together and add round-trip tests.
Unsupported versions are rejected; no implicit new game or backup downgrade is
performed when the main save belongs to another version.

Default slot: `user://outpost/save.json`. Settings use a separate file.
The file is JSON containing a format identifier, a JSON payload string and its
SHA-256 checksum. Only validated data is applied; resources/scripts are not loaded
from save contents. The size limit is 8MiB.

Writing creates `.tmp`, flushes/closes it and reads it back through the validator.
A validated existing main file rotates to `.bak` before the temp file is renamed
to the committed slot. On missing/damaged main files, Continue can recover the
validated backup and clearly reports recovery. Stale temp files are ignored.
This guards normal interrupted-write cases; it is not a claim of filesystem-level
durability against every hardware failure.

Pause offers Save Game. Returning to the main menu and Quit/window-close also save
before discarding the world. Failed saves retain the current world and show the
error. An airlock mid-cycle must finish before saving so no half-open state is
serialized. Resume the simulation to let it finish if currently paused.

Death cannot overwrite the save, including on Quit/window-close or Return to Menu.
Reload restores the living saved state; a saved active grace timer remains active.

Tests use isolated slots under `user://tests/`, never the player's default slot.
The live M12 restart check also uses its own test slot.
