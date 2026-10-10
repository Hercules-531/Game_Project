extends RefCounted

static func efficiency(condition: float) -> float:
	return 0.35 if condition <= 20.0 else (1.0 if condition <= 80.0 else 1.2)

static func malfunction_chance(condition: float) -> float:
	return 0.5 if condition <= 20.0 else (0.1 if condition <= 80.0 else 0.0)
