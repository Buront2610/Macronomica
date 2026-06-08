extends RefCounted
class_name BoardLayout

static func for_screen(viewport_size: Vector2) -> Dictionary:
	var margin := 28.0
	var header_h := 98.0
	var side_w := clampf(viewport_size.x * 0.215, 270.0, 320.0)
	var left_x := margin
	var right_x := viewport_size.x - side_w - margin
	var center_left := left_x + side_w + 32.0
	var center_right := right_x - 32.0
	var center_w := maxf(560.0, center_right - center_left)
	var center_x := center_left + center_w * 0.5
	var bottom_y := viewport_size.y - 148.0

	var country_size := Vector2(side_w, clampf(viewport_size.y * 0.172, 120.0, 142.0))
	var country_gap := 12.0
	var hand_card_size := Vector2(104.0, 126.0)
	var hand_step := Vector2(112.0, 0.0)
	var hand_count_w := hand_card_size.x + hand_step.x * 4.0
	var hand_x := clampf(center_x - hand_count_w * 0.5, center_left, center_right - hand_count_w)
	var hand_panel_pos := Vector2(hand_x - 20.0, bottom_y - 14.0)
	var hand_panel_size := Vector2(hand_count_w + 40.0, hand_card_size.y + 30.0)

	var world_size := Vector2(center_w, clampf(viewport_size.y * 0.285, 198.0, 248.0))
	var world_pos := Vector2(center_left, header_h + 14.0)
	var negotiation_size := Vector2(minf(436.0, center_w - 90.0), 78.0)
	var negotiation_pos := Vector2(center_x - negotiation_size.x * 0.5, world_pos.y + world_size.y + 10.0)
	var policy_slot_size := Vector2(204.0, 78.0)
	var policy_slot_pos := Vector2(center_x - policy_slot_size.x * 0.5, negotiation_pos.y + negotiation_size.y + 10.0)
	var resolution_flow_size := Vector2(minf(center_w, 700.0), 64.0)
	var resolution_flow_pos := Vector2(center_x - resolution_flow_size.x * 0.5, policy_slot_pos.y + policy_slot_size.y + 10.0)

	var worker_size := Vector2(50.0, 50.0)
	var worker_total_w := worker_size.x * 5.0 + 12.0 * 4.0
	var worker_x := clampf(policy_slot_pos.x + policy_slot_size.x + 28.0, center_left, center_right - worker_total_w)
	var worker_y := policy_slot_pos.y + 18.0

	var action_size := Vector2(48.0, 48.0)
	var command_origin := Vector2(center_right - 170.0, 36.0)
	var event_pos := Vector2(left_x, header_h + 24.0)
	var event_size := Vector2(side_w, 142.0)
	var left_seat_y := event_pos.y + event_size.y + 14.0
	var right_seat_y := header_h + 24.0
	var right_log_y := right_seat_y + country_size.y * 2.0 + country_gap + 14.0
	var detail_h := clampf(viewport_size.y * 0.17, 116.0, 134.0)
	var log_h := maxf(82.0, bottom_y - right_log_y - detail_h - 16.0)

	return {
		"play_surface_pos": Vector2(center_left - 18.0, header_h),
		"play_surface_size": Vector2(center_w + 36.0, bottom_y - header_h - 18.0),
		"hand_panel_pos": hand_panel_pos,
		"hand_panel_size": hand_panel_size,
		"title_pos": Vector2(30.0, 36.0),
		"title_size": Vector2(220.0, 44.0),
		"turn_pos": Vector2(240.0, 50.0),
		"turn_size": Vector2(330.0, 28.0),
		"phase_pip_start": Vector2(center_x - 170.0, 50.0),
		"phase_pip_step": Vector2(56.0, 0.0),
		"phase_pip_size": Vector2(42.0, 16.0),
		"command_origin": command_origin,
		"action_size": action_size,
		"event_pos": event_pos,
		"event_size": event_size,
		"world_panel_pos": world_pos,
		"world_panel_size": world_size,
		"world_tracks_origin": world_pos + Vector2(28.0, 52.0),
		"world_track_step": Vector2((world_size.x - 96.0) / 6.0, 0.0),
		"world_track_size": Vector2(58.0, world_size.y - 72.0),
		"agenda_origin": negotiation_pos + Vector2(16.0, 13.0),
		"agenda_step": Vector2(102.0, 0.0),
		"agenda_size": Vector2(94.0, 54.0),
		"negotiation_pos": negotiation_pos,
		"negotiation_size": negotiation_size,
		"country_seat_positions": [
			Vector2(left_x, left_seat_y),
			Vector2(right_x, right_seat_y),
			Vector2(left_x, left_seat_y + country_size.y + country_gap),
			Vector2(right_x, right_seat_y + country_size.y + country_gap)
		],
		"country_seat_size": country_size,
		"policy_slot_pos": policy_slot_pos,
		"policy_slot_size": policy_slot_size,
		"resolution_flow_pos": resolution_flow_pos,
		"resolution_flow_size": resolution_flow_size,
		"score_pos": Vector2(left_x, 76.0),
		"score_size": Vector2(252.0, 20.0),
		"log_pos": Vector2(right_x, right_log_y),
		"log_size": Vector2(side_w, log_h),
		"country_detail_pos": Vector2(right_x, right_log_y + log_h + 8.0),
		"country_detail_size": Vector2(side_w, detail_h),
		"worker_origin": Vector2(worker_x, worker_y),
		"worker_step": Vector2(62.0, 0.0),
		"worker_size": worker_size,
		"hand_origin": Vector2(hand_x, bottom_y),
		"hand_step": hand_step,
		"hand_card_size": hand_card_size
	}
