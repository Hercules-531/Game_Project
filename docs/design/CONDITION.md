# Condition and malfunctions

M22 resolves the overlapping GDD boundary conservatively: 0–20 inclusive is
35% efficiency / 50% malfunction; above 20 through 80 is normal / 10%; above 80
is 120% efficiency / no condition malfunction. These probabilities are sampled
once per 60s field work cycle per installed/base part, never every frame. A fault
lasts eight simulation seconds and also clears with paid workshop service.
Weather short-circuit risks are separate later hazards.

Joints change real movement speed; cell efficiency reduces energy consumed at a
fixed nominal capacity (+20% operating duration in the top band). Sonar/IR gain
range, CCD gains cleaner noise/detail, winch/rack faults reject loading, retrace
faults will disable its failsafe. Cell/joint faults stop power/movement. Armor
condition is reserved for actual damage mitigation when threats arrive.

Provisional wear: joints 0.004%/m, modules 0.003%/m plus 0.00025%/s, cell 5%/kWh
discharged, armor 0.0003%/s in field. Payload and environment multiply wear.
Workshop component choices service joints, cell and armor using the same scrap
formula as socket parts. Frame, fault timers, work-cycle remainder and RNG persist
in version 9. Older fleets migrate with intact frame components; loading resets
the transient distance/energy origin so it cannot count travel twice.
