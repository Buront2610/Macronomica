extends RefCounted
class_name WorldState

var tracks: Dictionary = {}
var event_deck: Array = []
var event_discard: Array = []
var current_event: Dictionary = {}

func _init(starting_tracks: Dictionary = {}) -> void:
	tracks = starting_tracks.duplicate(true)

func apply_effects(effects: Dictionary) -> void:
	for key in effects.keys():
		tracks[key] = int(tracks.get(key, 0)) + int(effects[key])

func clamp_tracks() -> void:
	for key in tracks.keys():
		if ["trade_openness", "international_financial_instability", "depression", "protectionism", "global_coordination"].has(key):
			tracks[key] = clampi(int(tracks[key]), 0, 10)
		else:
			tracks[key] = clampi(int(tracks[key]), -5, 5)

func depression_level() -> int:
	return int(tracks.get("depression", 0))
