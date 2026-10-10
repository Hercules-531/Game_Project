# Radio link

M21 provisional baseline: exterior antenna at (0,6,-13), 160m nominal range,
linear distance loss, physical occlusion multiplying strength by 0.3, and an
8% floor. Local workshop controls do not need a field link. Cold/depleted field
cells cannot transmit. Weather later supplies range/latency modifiers.

Every 12 simulation seconds, a seeded 1.5% per-field-machine roll can cause a
two-second drop even inside range. Version 8 saves the next roll, active drops
and exact RNG state as a decimal string, avoiding JSON floating-point loss.

Normal commands take 0.1s plus up to 0.25s for weak signal. Throttle packets are
short leases; loss, station exit, switching and load clear queues and actions.
No old throttle is replayed on reconnect. Ping/recovery commands use the same
delayed channel. Missing links reject new actions. The desk preserves last received
telemetry and hides fresh sensors; a second connected camera can still observe
the first drone. CCD interference rises as signal weakens.
