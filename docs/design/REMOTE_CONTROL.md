# Remote control

M17: sealed loader transfer takes eight simulation seconds. Both airlock doors
must be closed; transfers reserve the interlock and check receiving-space physics
before starting and before releasing a machine. This is an abstract transport
animation: the loader hides the hull, then places it at the receiving cradle.
It does not claim the drone drives from its workshop bay through both doors.
Recall is available only within eight metres of the outside cradle, never at
arbitrary distance. Saves are rejected during an unfinished transfer by the
existing airlock-busy rule; pause freezes it.

WASD uses the user's bindings: forward/back throttle and left/right steering.
The desk also offers hold-to-steer buttons. Only the selected machine receives
manual input, while the operator stays put. Switching, leaving or pausing clears
held commands. Movement is physical against terrain/bounds. Ordinary controls
are instruments and delayed piloting once radio is added; Neural Core later
improves precision. No ordinary optical view is available without a camera.

Version 5 persists deployed/workshop state; versions 1–4 migrate to workshop
unless their fleet already contains that state. The terminal selection is transient.
