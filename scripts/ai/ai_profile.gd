extends RefCounted

const PROFILES := {
	"easy": {"interval": 6.0, "workers": [7, 12, 18, 24], "attack_threshold": 8, "age_timing": 220.0, "queue_limit": 2},
	"normal": {"interval": 3.0, "workers": [10, 17, 25, 34], "attack_threshold": 5, "age_timing": 150.0, "queue_limit": 3},
	"hard": {"interval": 1.5, "workers": [14, 21, 31, 42], "attack_threshold": 3, "age_timing": 105.0, "queue_limit": 3},
}

static func for_difficulty(difficulty: String) -> Dictionary:
	return PROFILES.get(difficulty, PROFILES["normal"])
