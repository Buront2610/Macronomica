extends RefCounted
class_name BoardLayout

static func for_screen(viewport_size: Vector2) -> Dictionary:
	var right_panel_x := minf(viewport_size.x - 256.0, 1038.0)
	var command_x := minf(viewport_size.x - 250.0, 1080.0)
	return {
		"title_pos": Vector2(30, 72),
		"title_size": Vector2(180, 42),
		"turn_pos": Vector2(210, 88),
		"turn_size": Vector2(190, 24),
		"phase_pip_start": Vector2(38, 128),
		"phase_pip_step": Vector2(50, 0),
		"phase_pip_size": Vector2(36, 16),
		"command_origin": Vector2(command_x, 90),
		"event_pos": Vector2(48, 182),
		"event_size": Vector2(258, 156),
		"world_tracks_origin": Vector2(46, 356),
		"world_track_step": Vector2(88, 54),
		"world_track_size": Vector2(78, 48),
		"agenda_origin": Vector2(520, 248),
		"agenda_step": Vector2(112, 0),
		"agenda_size": Vector2(104, 74),
		"country_seat_positions": [Vector2(356, 372), Vector2(562, 372), Vector2(356, 498), Vector2(562, 498)],
		"country_seat_size": Vector2(170, 72),
		"policy_slot_pos": Vector2(818, 604),
		"policy_slot_size": Vector2(178, 92),
		"status_x": right_panel_x,
		"worker_origin": Vector2(484, 82),
		"worker_step": Vector2(82, 0),
		"hand_origin": Vector2(70, 572),
		"hand_step": Vector2(88, 0)
	}
