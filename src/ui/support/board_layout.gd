extends RefCounted
class_name BoardLayout

static func for_screen(viewport_size: Vector2) -> Dictionary:
	var margin := 18.0
	var header_h := 74.0
	var info_w := clampf(viewport_size.x * 0.155, 190.0, 220.0)
	var board_left := margin
	var info_x := viewport_size.x - info_w - margin
	var board_right := info_x - 18.0
	var center_left := board_left
	var center_right := board_right
	var center_w := center_right - center_left
	var center_x := center_left + center_w * 0.5
	var bottom_y := viewport_size.y - 144.0

	var country_size := Vector2(clampf(center_w * 0.255, 246.0, 286.0), clampf(viewport_size.y * 0.172, 118.0, 136.0))
	var country_gap := 10.0
	var hand_card_size := Vector2(104.0, 126.0)
	var hand_step := Vector2(112.0, 0.0)
	var hand_count_w := hand_card_size.x + hand_step.x * 4.0
	var hand_x := clampf(center_x - hand_count_w * 0.5, center_left, center_right - hand_count_w)
	var hand_panel_pos := Vector2(hand_x - 20.0, bottom_y - 14.0)
	var hand_panel_size := Vector2(hand_count_w + 40.0, hand_card_size.y + 30.0)

	var world_size := Vector2(center_w, clampf(viewport_size.y * 0.255, 178.0, 196.0))
	var world_pos := Vector2(center_left, header_h + 6.0)
	var negotiation_size := Vector2(minf(584.0, center_w - country_size.x * 2.0 - 18.0), 78.0)
	var negotiation_pos := Vector2(center_x - negotiation_size.x * 0.5, world_pos.y + world_size.y + 10.0)
	var policy_slot_size := Vector2(286.0, 82.0)
	var policy_slot_pos := Vector2(center_x - policy_slot_size.x * 0.5, negotiation_pos.y + negotiation_size.y + 8.0)
	var resolution_flow_size := Vector2(minf(center_w - 140.0, 840.0), 70.0)
	var resolution_flow_pos := Vector2(center_x - resolution_flow_size.x * 0.5, policy_slot_pos.y + policy_slot_size.y + 8.0)
	var world_track_gap := 8.0
	var world_track_w := (world_size.x - 76.0 - world_track_gap * 6.0) / 7.0

	var worker_size := Vector2(60.0, 60.0)
	var worker_total_w := worker_size.x * 5.0 + 12.0 * 4.0
	var worker_x := clampf(policy_slot_pos.x + policy_slot_size.x + 28.0, center_left, center_right - worker_total_w)
	var worker_y := policy_slot_pos.y + 18.0

	var action_size := Vector2(48.0, 48.0)
	var command_origin := Vector2(center_right - 292.0, 27.0)
	var event_pos := Vector2(info_x, header_h + 12.0)
	var event_size := Vector2(info_w, 128.0)
	var seat_y := world_pos.y + world_size.y + 10.0
	var left_x := center_left + 12.0
	var right_x := center_right - country_size.x - 12.0
	var right_log_y := event_pos.y + event_size.y + 12.0
	var detail_h := clampf(viewport_size.y * 0.17, 116.0, 134.0)
	var log_h := maxf(82.0, bottom_y - right_log_y - detail_h - 16.0)

	return {
		"play_surface_pos": Vector2(center_left, header_h),
		"play_surface_size": Vector2(center_w, bottom_y - header_h - 18.0),
		"hand_panel_pos": hand_panel_pos,
		"hand_panel_size": hand_panel_size,
		"title_pos": Vector2(30.0, 31.0),
		"title_size": Vector2(220.0, 44.0),
		"turn_pos": Vector2(240.0, 39.0),
		"turn_size": Vector2(330.0, 28.0),
		"phase_pip_start": Vector2(center_x - 190.0, 40.0),
		"phase_pip_step": Vector2(62.0, 0.0),
		"phase_pip_size": Vector2(48.0, 18.0),
		"command_origin": command_origin,
		"action_size": action_size,
		"event_pos": event_pos,
		"event_size": event_size,
		"world_panel_pos": world_pos,
		"world_panel_size": world_size,
		"world_tracks_origin": world_pos + Vector2(38.0, 54.0),
		"world_track_step": Vector2(world_track_w + world_track_gap, 0.0),
		"world_track_size": Vector2(world_track_w, world_size.y - 74.0),
		"agenda_origin": negotiation_pos + Vector2(18.0, 14.0),
		"agenda_step": Vector2((negotiation_size.x - 34.0) / 4.0, 0.0),
		"agenda_size": Vector2(112.0, 60.0),
		"negotiation_pos": negotiation_pos,
		"negotiation_size": negotiation_size,
		"country_seat_positions": [
			Vector2(left_x, seat_y),
			Vector2(right_x, seat_y),
			Vector2(left_x, seat_y + country_size.y + country_gap),
			Vector2(right_x, seat_y + country_size.y + country_gap)
		],
		"country_seat_size": country_size,
		"policy_slot_pos": policy_slot_pos,
		"policy_slot_size": policy_slot_size,
		"resolution_flow_pos": resolution_flow_pos,
		"resolution_flow_size": resolution_flow_size,
		"score_pos": Vector2(info_x, 65.0),
		"score_size": Vector2(info_w, 20.0),
		"log_pos": Vector2(info_x, right_log_y),
		"log_size": Vector2(info_w, log_h),
		"country_detail_pos": Vector2(info_x, right_log_y + log_h + 8.0),
		"country_detail_size": Vector2(info_w, detail_h),
		"worker_origin": Vector2(worker_x, worker_y),
		"worker_step": Vector2(68.0, 0.0),
		"worker_size": worker_size,
		"hand_origin": Vector2(hand_x, bottom_y),
		"hand_step": hand_step,
		"hand_card_size": hand_card_size
	}
