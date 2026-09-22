# Save format and flow

Version 1 stores operator position/yaw/pitch, elapsed simulation time, local
panel/light power states and the interlocked airlock's settled state. Future
systems must extend capture/validation/restore together and add round-trip tests.
Unsupported versions are rejected; no implicit new game or backup downgrade is
performed when the main save belongs to another version.

Default slot: `user://outpost/save.json`. Settings will use a separate file.
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

Tests use isolated slots under `user://tests/`, never the player's default slot.
The live M12 restart check also uses its own test slot.
