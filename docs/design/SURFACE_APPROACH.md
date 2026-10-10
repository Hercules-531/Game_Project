# Southern surface

M16 establishes a 120m × 600m finite north/south strip, bunker at the south edge.
Six 100m bands are the provisional campaign choice within the GDD's five-to-eight
range. Only the approach route and substation structure are authored here; later
content milestones fill the remaining bands. North is negative Z.

The dead pylon spine runs from z=-35 to -245 at 35m spacing, six metres west of a
clear central lane. The substation at (12,-252) lies in the third, contested band.
Rubble and a warm vent offer distinct acoustic/thermal landmarks. Bounds are
physical ridges, not an infinite landscape. The substation has a six-metre opening.

No dedicated snow/ice bitmap was found in the asset audit. The reviewed treatment
uses PSX capRoofConcrete_albedo.png as pale frozen crust, floorStone_albedo.png
for rubble/ridges and cornerPillarMetal_albedo.png for pylons/switchgear. All are
verified Textures/ files; cold tint and light create the frozen palette. The new
concrete import has mipmaps disabled. Ground UV repeats are widened to limit
nearest-sampling aliasing. Surface UVs remain stable as the camera moves.

Custom pylons, dead capacitors, insulators and substation transformers were
rendered at 1.3m sensor height before main-scene integration. No sensor vision
is granted to the opening blind Mule by this diagnostic review.
