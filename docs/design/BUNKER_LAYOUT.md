# Bunker 14 — initial measured layout

North is negative Z. Interior ceiling is 2.8m. Corridor is 2.6m wide.

| Space | X bounds | Z bounds | Function |
| --- | --- | --- | --- |
| Central passage | -1.3 to 1.3 | -6 to 6 | Connects the four functions |
| Command | 1.3 to 7.3 | -2 to 4 | Telemetry and orders |
| Workshop | -7.3 to -1.3 | -2 to 4 | Assembly, repairs and drone staging |
| Life support | -3.3 to 3.3 | 6 to 10 | Power, O2, heat and rations |
| Airlock | -2.3 to 2.3 | -10 to -6 | Interlocked access to surface |

Command/workshop entries are 2m wide; life-support entry 1.8m; airlock doors
1.7m. Clear door height is 2.3m versus the player's 1.7m capsule. Sliding doors
are a custom low-poly functional draft and will receive the source-texture pass.
The outer door stays unauthorized during normal unsuited bunker walking.

M05 checks geometry, walkability and interlocks using diagnostic flat materials.
M06–M09 replace the presentation with the mandatory PS1 renderer and asset pass.
