class_name AIDifficultyProfile
extends RefCounted

const NAMES := ["Novice", "Soldier", "Commander", "Warlord", "Grandmaster"]
const PROFILES: Array[Dictionary] = [
	{"memory_weight": 0.0, "randomness_multiplier": 3.0, "lookahead_weight": 0.0,
		"ability_awareness_weight": 0.0, "active_ability_weight": 0.0,
		"active_ability_threshold": 999999, "max_active_ability_uses_per_turn": 0,
		"min_deployment_score": -999999},
	{"memory_weight": 0.35, "randomness_multiplier": 2.1, "lookahead_weight": 0.20,
		"ability_awareness_weight": 0.25, "active_ability_weight": 0.25,
		"active_ability_threshold": 95, "max_active_ability_uses_per_turn": 1,
		"min_deployment_score": 0},
	{"memory_weight": 0.65, "randomness_multiplier": 1.35, "lookahead_weight": 0.50,
		"ability_awareness_weight": 0.60, "active_ability_weight": 0.60,
		"active_ability_threshold": 78, "max_active_ability_uses_per_turn": 1,
		"min_deployment_score": 12},
	{"memory_weight": 0.90, "randomness_multiplier": 0.85, "lookahead_weight": 0.85,
		"ability_awareness_weight": 0.95, "active_ability_weight": 0.95,
		"active_ability_threshold": 60, "max_active_ability_uses_per_turn": 2,
		"min_deployment_score": 18},
	{"memory_weight": 1.15, "randomness_multiplier": 0.45, "lookahead_weight": 1.15,
		"ability_awareness_weight": 1.20, "active_ability_weight": 1.20,
		"active_ability_threshold": 45, "max_active_ability_uses_per_turn": 2,
		"min_deployment_score": 24},
]


static func display_name(level: int) -> String:
	return NAMES[clampi(level, 0, NAMES.size() - 1)]


static func values(level: int) -> Dictionary:
	return PROFILES[clampi(level, 0, PROFILES.size() - 1)].duplicate(true)
