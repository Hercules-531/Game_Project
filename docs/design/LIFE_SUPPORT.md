# Bunker life support — M13b

The GDD requires oxygen, heating, power generation and rations, but supplies no
rates. These opening values are provisional tuning for playtesting, not GDD
constants. On 26 September the user selected warnings and a recovery grace
period, then operator death with reload from the last save.

| System | Opening value / rate |
| --- | --- |
| Battery | 2 kWh, starts full |
| Generator | 4 kW; 120 minutes of fuel; consumes one fuel-minute per real simulation minute |
| Baseline load | 0.3 kW for bunker instruments and lighting |
| Oxygen recycler | 0.8 kW; adds 0.08 reserve points per second when fully supplied |
| Oxygen use | 0.03 reserve points per second; reserve starts at 100, capped at 100 |
| Heater | 1.8 kW; adds 0.012°C per second when fully supplied |
| Heat loss | 0.004°C per second; cabin starts at 18°C and caps at 18°C |
| Rations | 8 units; one unit consumed per 30 simulation minutes |
| Critical state | Oxygen zero, cabin at/below 0°C, or rations zero |
| Grace | 120 consecutive seconds of critical conditions; clears once all are safe |

Rates live in `resources/balance/life_support.tres` through its resource script.
Elapsed physics time feeds one-second integration steps; fractional time is saved.
Generator fuel limits generated energy, then battery and generated energy supply
the requested load. Demand beyond available energy receives a proportional supply
fraction. Oxygen and heating output follow that fraction. Excess generation at a
full battery is discarded; fuel continues burning until the generator is switched
off. Fuel, battery, oxygen and rations cannot become negative. No off-screen time
passes while the application is closed.

Local life-support and power panels open the same instrument view. Generator,
oxygen recycler and heater toggles work during a blackout so power can be restored.
The baseline circuits lose their CRT displays and command/workshop lighting when
no energy can be delivered. The mechanical toggles remain accessible.

Warnings appear before critical conditions (oxygen below 25, temperature below
8°C, rations below 1, battery below 0.4 kWh, fuel below 15 minutes). During the grace
period, the panel and overlay show the reason and remaining seconds. Panels keep
simulation running; pause and settings freeze it. Resupply integration belongs to
the later salvage/inventory milestones; this foundation adds no free refill button.

Death freezes the world and locks walking/resume. Reload Last Save restores the
most recent valid slot; returning to the menu or quitting after death leaves that
slot untouched. With no valid save, the death screen offers a new run. A save made
during the grace period retains its elapsed countdown and circuit state, so reload
does not reset the warning. Fleet loss still leads to the GDD's human recovery
sortie in M25; bunker life-support death is a separate consequence.
